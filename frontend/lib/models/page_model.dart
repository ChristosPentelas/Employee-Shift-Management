/// One page of a list endpoint, as the server's PageResponse sends it (F9):
/// {"content": [...], "page": 0, "size": 50, "totalElements": .., "totalPages": ..}
/// Generic, so the same class reads a page of leaves, news or messages (B26).
class ListPage<T> {
  final List<T> items;
  /// Zero-based: the first page is 0.
  final int page;
  final int totalPages;

  const ListPage({
    required this.items,
    required this.page,
    required this.totalPages,
  });

  /// Whether the server has a page after this one. With nothing at all,
  /// totalPages is 0, and this is false as well.
  bool get hasMore => page + 1 < totalPages;

  /// [itemFromJson] turns one row into a T, e.g. LeaveRequest.fromJson.
  factory ListPage.fromJson(
      Map<String, dynamic> json, T Function(Map<String, dynamic>) itemFromJson) {
    return ListPage(
      items: (json['content'] as List<dynamic>)
          .map((item) => itemFromJson(item as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int,
      totalPages: json['totalPages'] as int,
    );
  }
}
