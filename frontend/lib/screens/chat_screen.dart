import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message_model.dart';
import '../models/page_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/api_providers.dart';
import '../state/auth_session.dart';
import '../state/paged_list.dart';
import '../widgets/paged_list_footer.dart';
import 'dart:developer' as developer;

class ChatScreen extends ConsumerStatefulWidget {
  final User receiver;

  ChatScreen({required this.receiver});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late final ApiService _apiService = ref.read(apiServiceProvider);
  final TextEditingController _messageController = TextEditingController();
  // Newest first, a page at a time (B26 step 26d). The poll refreshes page 0
  // in front; scrolling up adds older pages behind. Repeats are dropped by id:
  // every message that arrives pushes one row of each older page onto the
  // next, so pages overlap a little, but none is skipped.
  late final PagedList<Message> _messages = PagedList(fetch: _fetch, idOf: (m) => m.id);
  Timer? _timer;
  // Was 3 s (F28). With no polling in the background and no loads piling up,
  // 5 s still feels live in a chat.
  static const _pollEvery = Duration(seconds: 5);
  late final AppLifecycleListener _lifecycle;

  // A load is never started while one is on its way: on a slow network the
  // replies would race, and each would mark the chat read again (B27). A
  // load asked for meanwhile - such as the one after sending - runs right
  // after it, so a sent message shows without waiting for the next tick.
  bool _loading = false;
  bool _reloadAfter = false;

  // Loads now, then every _pollEvery. The old timer is cancelled first: two
  // timers would poll twice as often, and the lost one could never be
  // cancelled.
  void _startPolling() {
    _loadMessages();
    _timer?.cancel();
    _timer = Timer.periodic(_pollEvery, (_) => _loadMessages());
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<ListPage<Message>> _fetch(int page) {
    // Read before the request: the session can end while it is on its way
    // (B16), and ref may not be used after the screen closes.
    final me = ref.read(authProvider);
    if (me == null) return Future.value(const ListPage(items: [], page: 0, totalPages: 0));
    return _apiService.getChatHistory(me.user.id, widget.receiver.id, page: page);
  }

  @override
  void initState() {
    super.initState();
    // No polling while the chat cannot be seen (another app, the home screen,
    // a minimized window), and a fresh load as soon as it can. onHide, not
    // onPause: desktop and web go hidden but never paused.
    _lifecycle = AppLifecycleListener(onHide: _stopPolling, onShow: _startPolling);
    _startPolling();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _timer?.cancel();
    _messages.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    if (_loading) {
      _reloadAfter = true;
      return;
    }

    // Read once, before the first await: the session can end while a request
    // is on its way (B16), and ref may not be used after the screen closes.
    final me = ref.read(authProvider);
    if (me == null) return;
    // Set only now: the return above is outside the try, so the finally
    // below would never clear it.
    _loading = true;

    try {
      // Page 0 again, put in front of the rows; older pages scrolled up to
      // stay (B26 step 26d). The list tells the screen itself. null: it
      // failed (the rows on screen stay) or the screen closed.
      final fresh = await _messages.refresh();
      if (fresh == null || !mounted) return;

      // Shown first, marked after: a failed read receipt must not hide the
      // chat. Only when something sent to me is unread, so an idle open chat
      // sends nothing (B27). Only on the page just fetched: a message from an
      // older page stays unread in the list, since only page 0 is fetched
      // again, and would send this every 5 s.
      if (fresh.items.any((msg) => msg.receiverId == me.user.id && !msg.isRead)) {
        await _apiService.markChatAsRead(widget.receiver.id);
      }
    } catch (e) {
      // Only the read receipt can throw here: refresh catches its own
      // failures, and the list keeps showing what it has.
      developer.log("Marking the chat read failed", name: "ChatScreen", error: e);
    } finally {
      // Cleared here, not after a success: a failed load must not stop the
      // polling for good. Not after dispose either: ref is gone by then.
      _loading = false;
      if (_reloadAfter && mounted) {
        _reloadAfter = false;
        _loadMessages();
      }
    }
  }

  void _send() async {
    if (_messageController.text.trim().isEmpty) return;

    String text = _messageController.text;
    _messageController.clear();

    bool success = await _apiService.sendMessage(widget.receiver.id, text);
    if (!mounted) return;
    if (success) {
      _loadMessages();
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(authProvider)?.user.id;

    return Scaffold(
      appBar: AppBar(title: Text(widget.receiver.name)),
      body: Column(
        children: [
          Expanded(
            // Rebuilt each time the list tells its listeners it changed.
            child: ListenableBuilder(
              listenable: _messages,
              builder: (context, _) => _buildMessages(myId),
            ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildMessages(int? myId) {
    // No spinner while the first page loads, as before: an empty chat until
    // then. Only a failed first load is said; a failed poll keeps the rows.
    if (_messages.error != null) {
      return Center(child: Text("Δεν ήταν δυνατή η φόρτωση των μηνυμάτων."));
    }
    final messages = _messages.items;
    return ListView.builder(
              // Index 0 at the bottom: messages are newest first, so the
              // newest is at the bottom and the footer - one row past the
              // oldest - at the top, where older pages load.
              reverse: true,
              itemCount: messages.length + (_messages.hasMore ? 1 : 0),
              itemBuilder: (context,index) {
                if (index == messages.length) {
                  return PagedListFooter(list: _messages);
                }
                final msg = messages[index];
                bool isMe = msg.senderId == myId;

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
    );
  }

  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(hintText: "Γράψτε ένα μήνυμα..."),
            ),
          ),
          IconButton(icon: Icon(Icons.send, color: Colors.teal), onPressed: _send),
        ],
      ),
    );
  }
}