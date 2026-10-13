import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/api_providers.dart';
import '../state/auth_session.dart';
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
  List<Message> _messages = [];
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
      final history = await _apiService.getChatHistory(me.user.id, widget.receiver.id);

      if (!mounted) return;

      setState(() {
        _messages = history;
      });

      // Shown first, marked after: a failed read receipt must not hide the
      // chat. Only when something sent to me is unread, so an idle open chat
      // sends nothing (B27).
      if (history.any((msg) => msg.receiverId == me.user.id && !msg.isRead)) {
        await _apiService.markChatAsRead(widget.receiver.id);
      }
    } catch (e) {
      developer.log("Loading the chat failed", name: "ChatScreen", error: e);
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
            child: ListView.builder(
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context,index) {
                final msg = _messages[_messages.length - 1 - index];
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