
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message_model.dart';
import '../services/api_service.dart';
import '../services/api_providers.dart';
import '../models/page_model.dart';
import '../state/auth_session.dart';
import '../state/paged_list.dart';
import '../widgets/paged_list_footer.dart';
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
  // One entry per person, newest conversation first, a page at a time (B26).
  // Kept apart by the other person's id, not the message's: a conversation
  // with a new message moves up, and may then come back on a later page.
  late final PagedList<({User other, Message latest})> _conversations =
      PagedList(fetch: _fetch, idOf: (c) => c.other.id);

  /// One page of conversations, each with the other person decided here, so
  /// build needs no user id of its own. The server picks each conversation's
  /// newest message and the order (26c1); this used to merge page 0 of inbox
  /// and of sent and group them, which lost every older conversation.
  Future<ListPage<({User other, Message latest})>> _fetch(int page) async {
    // Read once, before the await: the session can end while the request is
    // on its way (B16), and ref may not be used after the screen closes.
    final me = ref.read(authProvider);
    if (me == null) return const ListPage(items: [], page: 0, totalPages: 0);

    final messages = await _apiService.getConversations(page: page);
    return ListPage(
      items: [
        for (final msg in messages.items) (other: msg.otherPerson(me.user.id), latest: msg),
      ],
      page: messages.page,
      totalPages: messages.totalPages,
    );
  }

  @override
  void initState() {
    super.initState();
    _conversations.reload();
  }

  @override
  void dispose() {
    _conversations.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Μηνύματα"), backgroundColor: Colors.teal),
      // Rebuilt each time the list tells its listeners it changed.
      body: ListenableBuilder(
        listenable: _conversations,
        builder: (context, _) {
          if (_conversations.loading) {
            return Center(child: CircularProgressIndicator());
          } else if (_conversations.error != null) {
            // Not the raw error, which is for developers (B41).
            return Center(child: Text("Δεν ήταν δυνατή η φόρτωση των μηνυμάτων."));
          } else if (_conversations.items.isEmpty) {
            return Center(child: Text("Δεν υπάρχουν μηνύματα."));
          }
          return _buildList(_conversations.items);
        },
      ),
    );
  }

  Widget _buildList(List<({User other, Message latest})> conversations) {
    return ListView.builder(
        // One row more while the server has older conversations: the footer,
        // which loads them once it is scrolled into view.
        itemCount: conversations.length + (_conversations.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == conversations.length) {
            return PagedListFooter(list: _conversations);
          }
          final (:other, latest: msg) = conversations[index];
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
    );
  }
}