import 'package:flutter/foundation.dart';

import '../models/page_model.dart';

/// A list read from the server a page at a time, with a "load more" (B26).
///
/// Moved out of the leave screen (step 26b2a) so a screen can hold several,
/// as the news tabs do. It only keeps the data; the screen draws it, listens
/// for changes with a ListenableBuilder, and says when something failed.
/// The observer pattern: this changes, then tells whoever listens.
class PagedList<T> extends ChangeNotifier {
  /// Loads one page; the screen decides which endpoint that is.
  final Future<ListPage<T>> Function(int page) _fetch;
  /// Tells rows apart, to drop one that comes back on the next page (B69).
  final int Function(T) _idOf;

  PagedList({
    required Future<ListPage<T>> Function(int page) fetch,
    required int Function(T) idOf,
  })  : _fetch = fetch,
        _idOf = idOf;

  // Unmodifiable, so a screen cannot add a row without anyone being told.
  List<T> _items = List.unmodifiable(const []);
  int _page = 0;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _loadMoreFailed = false;
  Object? _error;
  // Raised by every reload. A page that was on its way when the list started
  // again belongs to the old list, and is dropped instead of appended.
  int _generation = 0;
  // A screen that closed has disposed this; notifyListeners would then throw.
  bool _disposed = false;

  /// The rows loaded so far, page 0 first.
  List<T> get items => _items;
  bool get hasMore => _hasMore;
  /// The first load, before there is anything to show.
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  /// The last page asked for failed. The footer then offers to try again
  /// instead of loading by itself, so a failing server is not asked again on
  /// every frame (B26 step 26c2).
  bool get loadMoreFailed => _loadMoreFailed;
  /// Why the first load failed; a later page answers through loadMore.
  Object? get error => _error;

  /// Loads the list again from page 0, dropping any older pages. The rows
  /// stay until the new ones arrive.
  Future<void> reload() async {
    final generation = ++_generation;
    try {
      final first = await _fetch(0);
      if (_disposed || generation != _generation) return;
      _items = List.unmodifiable(first.items);
      _page = first.page;
      _hasMore = first.hasMore;
      _error = null;
    } catch (e) {
      if (_disposed || generation != _generation) return;
      _error = e;
    }
    _loading = false;
    _loadingMore = false; // a page on its way is dropped, see loadMore
    _loadMoreFailed = false;
    notifyListeners();
  }

  /// Loads page 0 again and puts it in front, keeping the older pages already
  /// loaded - for a list that grows at the front while it is shown, as a chat
  /// does when it polls (B26 step 26d). reload, by contrast, drops them.
  ///
  /// Returns the fresh page, or null if it failed or was dropped, so the
  /// caller can look at what the server holds now rather than at rows loaded
  /// earlier.
  Future<ListPage<T>?> refresh() async {
    if (_disposed) return null;
    // Not raised, as reload does: refreshing must not cancel an older page
    // on its way, or a chat polling every 5 s would undo every scroll up.
    final generation = _generation;
    try {
      final first = await _fetch(0);
      if (_disposed || generation != _generation) return null;
      // The fresh copies first: one already shown is replaced, so a change
      // such as a message being read shows. Every other row is older.
      final fresh = first.items.map(_idOf).toSet();
      _items = List.unmodifiable(
          [...first.items, ..._items.where((item) => !fresh.contains(_idOf(item)))]);
      // _page stays: the older pages are still loaded. The total grows as
      // rows arrive.
      _hasMore = _page + 1 < first.totalPages;
      _loading = false;
      _error = null;
      notifyListeners();
      return first;
    } catch (e) {
      if (_disposed || generation != _generation) return null;
      // With rows on screen, a failed refresh changes nothing: they are still
      // right, and the next poll tries again. With nothing yet, say so.
      if (_loading || _error != null) {
        _loading = false;
        _error = e;
        notifyListeners();
      }
      return null;
    }
  }

  /// Adds the next page after the rows. If it fails, the rows already loaded
  /// stay and [loadMoreFailed] says so; nothing is returned, since the footer
  /// reads that instead (26c3).
  Future<void> loadMore() async {
    // The footer asks after a frame, which can come once the screen has
    // closed: notifyListeners after dispose would throw.
    if (_disposed) return;
    // The footer can ask again before the page came back, which would add it
    // twice. Ignored, not failed: loadMoreFailed stays as it is.
    if (_loadingMore) return;
    final generation = _generation;
    _loadingMore = true;
    _loadMoreFailed = false;
    notifyListeners();
    try {
      final next = await _fetch(_page + 1);
      if (_disposed || generation != _generation) return;
      final shown = _items.map(_idOf).toSet();
      _items = List.unmodifiable(
          [..._items, ...next.items.where((item) => !shown.contains(_idOf(item)))]);
      _page = next.page;
      _hasMore = next.hasMore;
      _loadingMore = false;
      notifyListeners();
    } catch (e) {
      // Dropped like a late page: after a reload or dispose nobody asked.
      if (_disposed || generation != _generation) return;
      _loadingMore = false;
      _loadMoreFailed = true;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
