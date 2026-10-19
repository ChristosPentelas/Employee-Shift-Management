
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
  // One entry per person, newest conversation first. The other person is
  // decided here once, while the session is known to exist, so build needs
  // no user id of its own.
  List<({User other, Message latest})> _conversations = [];

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

      if (!mounted) return;

      // Sorted before de-duplicating, so the message kept for each person is
      // their newest. Grouped by id, not name: two people can share a name.
      // A message to myself is in both lists; it collapses into one row too.
      final messages = [...incoming, ...outgoing]
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final seen = <int>{};
      final conversations = [
        for (final msg in messages)
          if (seen.add(msg.otherPerson(me.user.id).id))
            (other: msg.otherPerson(me.user.id), latest: msg),
      ];

      setState(() {
        _conversations = conversations;
        _isLoading = false;
      });
    } catch (e) {
      if(mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Μηνύματα"), backgroundColor: Colors.teal),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: _conversations.length,
        itemBuilder: (context, index) {
          final (:other, latest: msg) = _conversations[index];
          return ListTile(
            // [0] on an empty string throws a RangeError.
            leading: CircleAvatar(child: Text(other.name.isEmpty ? "?" : other.name[0])),
            title: Text(other.name),
            subtitle: Text(msg.content, maxLines: 1, overflow: TextOverflow.ellipsis),
            // Only the newest message is checked: replying happens in the
            // chat, and opening the chat marks it read (F28).
            trailing: !msg.isRead && msg.senderId == other.id
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(receiver: other),
                  ),
                );
              }
          );
        },
      ),
    );
  }
}