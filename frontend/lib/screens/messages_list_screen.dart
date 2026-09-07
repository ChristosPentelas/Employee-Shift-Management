
import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../services/api_service.dart';
import '../utils/session.dart';
import 'chat_screen.dart';
import '../models/user_model.dart';

class MessagesListScreen extends StatefulWidget {
  @override
  _MessagesListScreenState createState() => _MessagesListScreenState();
}

class _MessagesListScreenState extends State<MessagesListScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<Message> _inbox = [];

  @override
  void initState() {
    super.initState();
    _loadInbox();
  }

  void _loadInbox() async {
    try {
      final incoming = await _apiService.getInbox(Session.currentUser!.id);
      final outgoing = await _apiService.getSent(Session.currentUser!.id);

      setState(() {
        _inbox = [...incoming, ...outgoing];
        _inbox.sort((a,b) => b.timestamp.compareTo(a.timestamp));
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Μηνύματα"), backgroundColor: Colors.teal),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: _inbox.length,
        itemBuilder: (context, index) {
          final msg = _inbox[index];
          return ListTile(
            leading: CircleAvatar(child: Text(msg.senderName[0])),
            title: Text(msg.senderName),
            subtitle: Text(msg.content, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: !msg.isRead && msg.receiverId == Session.currentUser!.id
                ? Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            )
                : null,
              onTap: () {
                User otherUser = User(
                  id: msg.senderId == Session.currentUser!.id ? msg.receiverId : msg.senderId,
                  name: msg.senderName,
                  email: "",
                  password: "",
                  role: "EMPLOYEE"
                );

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(receiver: otherUser),
                  ),
                );
              }
          );
        },
      ),
    );
  }
}