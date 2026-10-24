import 'package:flutter/material.dart';

import '../state/paged_list.dart';

/// The last row of a paged list while the server has more (B26 step 26c2).
///
/// A ListView only builds the rows near the screen, so this one being built
/// means the user has scrolled close to the end: it then loads the next page
/// by itself - infinite scroll. Unlike a scroll listener, this also works when
/// the first page is too short to scroll at all.
///
/// The screen adds it only while `list.hasMore`, inside the ListenableBuilder
/// that redraws the list, so it needs no state of its own.
class PagedListFooter<T> extends StatelessWidget {
  final PagedList<T> list;

  const PagedListFooter({super.key, required this.list});

  @override
  Widget build(BuildContext context) {
    // After a failure, a button: never load again by itself, or a server that
    // keeps failing would be asked on every frame.
    if (list.loadMoreFailed) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Δεν ήταν δυνατή η φόρτωση."),
            TextButton(onPressed: list.loadMore, child: const Text("Δοκιμάστε ξανά")),
          ],
        ),
      );
    }

    if (!list.loadingMore) {
      // Not now: loadMore tells its listeners, and changing state while the
      // widgets are being built is an error. After this frame it is allowed.
      // This build can run several times before the page arrives, so the call
      // can be scheduled more than once; loadMore ignores a call while one is
      // running, so only one request goes out.
      WidgetsBinding.instance.addPostFrameCallback((_) => list.loadMore());
    }
    return const Padding(
      padding: EdgeInsets.all(12),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
