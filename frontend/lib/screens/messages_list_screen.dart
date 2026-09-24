
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message_model.dart';
import '../services/api_service.dart';
import '../services/api_providers.dart';
import '../state/auth_session.dart';
import 'chat_screen.dart';
import '../models/user_model.dart';

class MessagesListScreen extends ConsumerStatefulWidget {
  // Tests pass an ApiService with a fake client; the app uses the default.
  final ApiService? apiService;

  const MessagesListScreen({this.apiService});

  @override
  _MessagesListScreenState createState() => _MessagesListScreenState();
}

class _MessagesListScreenState extends ConsumerState<MessagesListScreen> {
  late final ApiService _apiService = widget.apiService ?? ref.read(apiServiceProvider);
  bool _isLoading = true;
  List<Message> _inbox = [];

  @override
  void initState() {
    super.initState();
    _loadInbox();
  }

  void _loadInbox() async {
    // Read once, before the first await: the session can end while a request
    // is on its way (B16), and ref may not be used after the screen closes.
    final me = ref.read(authProvider);
    if (me == null) return;

    try {
      final incoming = await _apiService.getInbox(me.user.id);
      final outgoing = await _apiService.getSent(me.user.id);

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
    final myId = ref.watch(authProvider)?.user.id;

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
            trailing: !msg.isRead && msg.receiverId == myId
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
                  id: msg.senderId == myId ? msg.receiverId : msg.senderId,
                  name: msg.senderName,
                  email: "",
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