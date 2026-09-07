import 'dart:async';
import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../utils/session.dart';

class ChatScreen extends StatefulWidget {
  final User receiver;

  ChatScreen({required this.receiver});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _messagegeController = TextEditingController();
  List<Message> _messages = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _timer = Timer.periodic(Duration(seconds: 3), (timer) => _loadMessages());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _messagegeController.dispose();
    super.dispose();
  }

  void _loadMessages() async {
    try {
      final history = await _apiService.getChatHistory(widget.receiver.id);

      for (var msg in history) {
        if (msg.receiverId == Session.currentUser!.id && !msg.isRead) {
          await _apiService.markAsRead(msg.id);
        }
      }

      if (mounted) {
        setState(() {
          _messages = history;
        });
      }
    } catch (e) {
      print("Error loading chat: $e");
    }
  }

  void _send() async {
    if (_messagegeController.text.trim().isEmpty) return;

    String text = _messagegeController.text;
    _messagegeController.clear();

    bool success = await _apiService.sendMessage(widget.receiver.id, text);
    if (success) {
      _loadMessages();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.receiver.name)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context,index) {
                final msg = _messages[_messages.length - 1 - index];
                bool isMe = msg.senderId == Session.currentUser?.id;

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.all(8),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.teal[100] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Text(msg.content, style: TextStyle(fontSize: 16)),
                        Text(
                            "${msg.timestamp.hour}:${msg.timestamp.minute.toString().padLeft(2, '0')}",
                            style: TextStyle(fontSize: 10, color: Colors.black54)
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messagegeController,
              decoration: InputDecoration(hintText: "Γράψτε ένα μήνυμα..."),
            ),
          ),
          IconButton(icon: Icon(Icons.send, color: Colors.teal), onPressed: _send),
        ],
      ),
    );
  }
}