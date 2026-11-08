import 'package:flutter/material.dart';

/// What a screen shows instead of its list when loading it failed (B41).
///
/// A short Greek sentence and a way to try again, never the error itself:
/// an exception's text is developer detail in English ("Exception: ...
/// SocketException ..."), and the user can do nothing with it. Whoever
/// caught the error logs it with developer.log instead.
///
/// PagedListFooter shows this too when a later page fails, so the app says it
/// one way (B81).
class LoadErrorView extends StatelessWidget {
  /// Starts the load again. The caller decides what that means: a new future
  /// for a FutureBuilder, PagedList.reload, or PagedList.loadMore in the
  /// footer.
  final VoidCallback onRetry;

  const LoadErrorView({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Δεν ήταν δυνατή η φόρτωση."),
          TextButton(onPressed: onRetry, child: const Text("Δοκιμάστε ξανά")),
        ],
      ),
    );
  }
}
