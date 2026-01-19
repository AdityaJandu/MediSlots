import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_screen.dart'; // Import the individual chat screen

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  // This list will hold unique conversation partners
  List<Map<String, dynamic>> _conversations = [];

  @override
  void initState() {
    super.initState();
    _fetchConversations();
  }

  Future<void> _fetchConversations() async {
    final myId = _supabase.auth.currentUser!.id;

    // Fetch all messages where I am sender OR receiver
    // We order by created_at descending to get newest first
    final data = await _supabase
        .from('messages')
        .select(
            '*, sender:sender_id(full_name), receiver:receiver_id(full_name)')
        .or('sender_id.eq.$myId,receiver_id.eq.$myId')
        .order('created_at', ascending: false);

    final List<dynamic> messages = data;
    final Map<String, Map<String, dynamic>> uniqueChats = {};

    // Logic: Group messages by the "Other Person"
    for (var msg in messages) {
      final isMeSender = msg['sender_id'] == myId;
      final otherUserId = isMeSender ? msg['receiver_id'] : msg['sender_id'];

      // Since we ordered by Descending, the first time we see a user ID,
      // it is the LATEST message. We store it and ignore older ones.
      if (!uniqueChats.containsKey(otherUserId)) {
        // Figure out the other person's name safely
        String otherName = "Unknown User";
        if (isMeSender) {
          otherName = msg['receiver']?['full_name'] ?? "Unknown";
        } else {
          otherName = msg['sender']?['full_name'] ?? "Unknown";
        }

        uniqueChats[otherUserId] = {
          'userId': otherUserId,
          'name': otherName,
          'lastMessage': msg['content'],
          'time': msg['created_at'],
        };
      }
    }

    if (mounted) {
      setState(() {
        _conversations = uniqueChats.values.toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Messages")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? const Center(
                  child: Text(
                      "No messages yet.\nBook an appointment to start chatting!",
                      textAlign: TextAlign.center))
              : ListView.builder(
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) {
                    final chat = _conversations[index];

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal.shade100,
                          child: Text(chat['name'][0].toUpperCase()),
                        ),
                        title: Text(chat['name'],
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(chat['lastMessage'],
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () {
                          // Open the Chat Screen
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                      otherUserId: chat['userId'],
                                      otherUserName: chat['name']))).then((_) =>
                              _fetchConversations()); // Refresh when coming back
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
