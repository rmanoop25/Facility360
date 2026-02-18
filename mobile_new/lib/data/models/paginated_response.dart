/// Generic paginated response model matching Laravel pagination structure.
///
/// Works with Laravel's default pagination format:
/// ```json
/// {
///   "data": [...],
///   "meta": {
///     "current_page": 1,
///     "last_page": 10,
///     "per_page": 15,
///     "total": 150
///   },
///   "links": {...}
/// }
/// ```
class PaginatedResponse<T> {
  final List<T> data;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  const PaginatedResponse({
    required this.data,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  /// Check if there are more pages to load
  bool get hasMore => currentPage < lastPage;

  /// Check if this is the first page
  bool get isFirstPage => currentPage == 1;

  /// Check if this is the last page
  bool get isLastPage => currentPage >= lastPage;

  /// Check if the response is empty
  bool get isEmpty => data.isEmpty;

  /// Check if the response is not empty
  bool get isNotEmpty => data.isNotEmpty;

  /// Get the number of items in this page
  int get count => data.length;

  /// Get the next page number, or null if on last page
  int? get nextPage => hasMore ? currentPage + 1 : null;

  /// Get the previous page number, or null if on first page
  int? get previousPage => currentPage > 1 ? currentPage - 1 : null;

  /// Create from Laravel paginated JSON response
  ///
  /// [json] The raw JSON response
  /// [itemParser] Function to parse each item in the data array
  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemParser,
  ) {
    final meta = json['meta'] as Map<String, dynamic>?;
    final dataList = json['data'] as List<dynamic>? ?? [];

    return PaginatedResponse(
      data: dataList
          .map((item) => itemParser(item as Map<String, dynamic>))
          .toList(),
      currentPage: meta?['current_page'] as int? ?? 1,
      lastPage: meta?['last_page'] as int? ?? 1,
      perPage: meta?['per_page'] as int? ?? 15,
      total: meta?['total'] as int? ?? dataList.length,
    );
  }

  /// Create from simple paginated JSON without meta wrapper
  /// Some APIs return pagination info at root level
  factory PaginatedResponse.fromSimpleJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemParser,
  ) {
    final dataList = json['data'] as List<dynamic>? ?? [];

    return PaginatedResponse(
      data: dataList
          .map((item) => itemParser(item as Map<String, dynamic>))
          .toList(),
      currentPage: json['current_page'] as int? ?? 1,
      lastPage: json['last_page'] as int? ?? 1,
      perPage: json['per_page'] as int? ?? 15,
      total: json['total'] as int? ?? dataList.length,
    );
  }

  /// Create an empty response
  factory PaginatedResponse.empty() {
    return const PaginatedResponse(
      data: [],
      currentPage: 1,
      lastPage: 1,
      perPage: 15,
      total: 0,
    );
  }

  /// Create a response from a single page of data (non-paginated API)
  factory PaginatedResponse.fromList(List<T> items) {
    return PaginatedResponse(
      data: items,
      currentPage: 1,
      lastPage: 1,
      perPage: items.length,
      total: items.length,
    );
  }

  /// Copy with new data (useful for appending pages)
  PaginatedResponse<T> copyWith({
    List<T>? data,
    int? currentPage,
    int? lastPage,
    int? perPage,
    int? total,
  }) {
    return PaginatedResponse(
      data: data ?? this.data,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      perPage: perPage ?? this.perPage,
      total: total ?? this.total,
    );
  }

  /// Append another page's data to this response
  PaginatedResponse<T> appendPage(PaginatedResponse<T> nextPage) {
    return PaginatedResponse(
      data: [...data, ...nextPage.data],
      currentPage: nextPage.currentPage,
      lastPage: nextPage.lastPage,
      perPage: nextPage.perPage,
      total: nextPage.total,
    );
  }

  /// Map data to a new type
  PaginatedResponse<R> map<R>(R Function(T) transform) {
    return PaginatedResponse(
      data: data.map(transform).toList(),
      currentPage: currentPage,
      lastPage: lastPage,
      perPage: perPage,
      total: total,
    );
  }

  @override
  String toString() {
    return 'PaginatedResponse(page: $currentPage/$lastPage, items: ${data.length}/$total)';
  }
}
