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

  /// Adds the next page after the rows. False only if that page failed, so
  /// the screen can say so; the rows already loaded stay either way.
  Future<bool> loadMore() async {
    // The footer asks after a frame, which can come once the screen has
    // closed: notifyListeners after dispose would throw.
    if (_disposed) return true;
    // A second tap before the page came back would add it twice. Not a
    // failure, so true: the screen must not say one.
    if (_loadingMore) return true;
    final generation = _generation;
    _loadingMore = true;
    _loadMoreFailed = false;
    notifyListeners();
    try {
      final next = await _fetch(_page + 1);
      if (_disposed || generation != _generation) return true;
      final shown = _items.map(_idOf).toSet();
      _items = List.unmodifiable(
          [..._items, ...next.items.where((item) => !shown.contains(_idOf(item)))]);
      _page = next.page;
      _hasMore = next.hasMore;
      _loadingMore = false;
      notifyListeners();
      return true;
    } catch (e) {
      // Dropped like a late page: after a reload or dispose nobody asked.
      if (_disposed || generation != _generation) return true;
      _loadingMore = false;
      _loadMoreFailed = true;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
