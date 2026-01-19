import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';

class GlobalChatListener extends StatefulWidget {
  final Widget child;
  const GlobalChatListener({super.key, required this.child});

  @override
  State<GlobalChatListener> createState() => _GlobalChatListenerState();
}

class _GlobalChatListenerState extends State<GlobalChatListener> {
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _messageChannel;

  @override
  void initState() {
    super.initState();
    // ASK FOR PERMISSION IMMEDIATELY
    NotificationService().requestPermissions();
    _setupAuthListener();
  }

  void _setupAuthListener() {
    _supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        _subscribeToMessages(session.user.id);
      } else {
        _unsubscribe();
      }
    });
  }

  void _subscribeToMessages(String myUserId) {
    _unsubscribe();

    _messageChannel = _supabase
        .channel('public:messages:global')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: myUserId,
          ),
          callback: (payload) async {
            final msg = payload.newRecord;
            final senderId = msg['sender_id'];
            final content = msg['content'];

            // Fetch Sender Name
            String title = "New Message";
            try {
              final profile = await _supabase
                  .from('profiles')
                  .select('full_name')
                  .eq('id', senderId)
                  .single();
              title = profile['full_name'];
            } catch (e) {
              debugPrint("Could not fetch sender name: $e");
            }

            // Show the actual notification
            NotificationService()
                .showNotification(msg['id'].hashCode, title, content, senderId);
          },
        )
        .subscribe((status, error) {
      debugPrint("Chat Listener Status: $status");
      if (error != null) debugPrint("Listener Error: $error");
    });
  }

  void _unsubscribe() {
    if (_messageChannel != null) {
      _supabase.removeChannel(_messageChannel!);
      _messageChannel = null;
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
