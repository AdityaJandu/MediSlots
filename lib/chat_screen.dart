import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId; // The person you are talking to
  final String otherUserName;

  const ChatScreen(
      {super.key, required this.otherUserId, required this.otherUserName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _supabase = Supabase.instance.client;
  final _messageController = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  late RealtimeChannel _chatChannel;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _setupRealtime();
  }

  // 1. Initial Load
  Future<void> _fetchMessages() async {
    final myId = _supabase.auth.currentUser!.id;

    // Fetch messages where (sender=Me AND receiver=Them) OR (sender=Them AND receiver=Me)
    final data = await _supabase
        .from('messages')
        .select()
        .or('and(sender_id.eq.$myId,receiver_id.eq.${widget.otherUserId}),and(sender_id.eq.${widget.otherUserId},receiver_id.eq.$myId)')
        .order('created_at', ascending: true); // Oldest first for chat flow

    if (mounted) {
      setState(() {
        _messages = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    }
  }

  // 2. Realtime Listener
  void _setupRealtime() {
    _chatChannel = _supabase
        .channel('public:messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            // Check if the new message belongs to THIS conversation
            final newMsg = payload.newRecord;
            final myId = _supabase.auth.currentUser!.id;

            if ((newMsg['sender_id'] == myId &&
                    newMsg['receiver_id'] == widget.otherUserId) ||
                (newMsg['sender_id'] == widget.otherUserId &&
                    newMsg['receiver_id'] == myId)) {
              setState(() {
                _messages.add(newMsg);
              });
            }
          },
        )
        .subscribe();
  }

  // 3. Send Message
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final myId = _supabase.auth.currentUser!.id;
    _messageController.clear(); // Clear input immediately for better UX

    try {
      await _supabase.from('messages').insert({
        'sender_id': myId,
        'receiver_id': widget.otherUserId,
        'content': text,
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  void dispose() {
    _supabase.removeChannel(_chatChannel);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myId = _supabase.auth.currentUser!.id;

    return Scaffold(
      appBar: AppBar(title: Text(widget.otherUserName)),
      body: Column(
        children: [
          // Chat List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(child: Text("No messages yet. Say hi!"))
                    : ListView.builder(
                        padding: const EdgeInsets.all(10),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg['sender_id'] == myId;
                          final time = DateFormat('HH:mm').format(
                              DateTime.parse(msg['created_at']).toLocal());

                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 8),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 14),
                              decoration: BoxDecoration(
                                color: isMe ? Colors.teal : Colors.grey[300],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    msg['content'],
                                    style: TextStyle(
                                        color:
                                            isMe ? Colors.white : Colors.black),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    time,
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: isMe
                                            ? Colors.white70
                                            : Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Input Field
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                        hintText: "Type a message...",
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.teal),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
