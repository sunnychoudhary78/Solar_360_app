class PaginatedResult<T> {
  final List<T> data;
  final int total;
  final int page;
  final int limit;

  const PaginatedResult({
    required this.data,
    required this.total,
    required this.page,
    required this.limit,
  });

  bool get hasMore => page * limit < total;

  factory PaginatedResult.fromJson(
    dynamic json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (json is List) {
      final list = json
          .whereType<Map>()
          .map((e) => fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return PaginatedResult(
        data: list,
        total: list.length,
        page: 1,
        limit: list.length,
      );
    }

    final map = json is Map<String, dynamic>
        ? json
        : Map<String, dynamic>.from(json as Map);

    final raw = map['data'] ?? map['rows'] ?? [];
    final list = (raw is List)
        ? raw
            .whereType<Map>()
            .map((e) => fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <T>[];

    final total = (map['total'] is num)
        ? (map['total'] as num).toInt()
        : (map['meta'] is Map && map['meta']['total'] is num)
            ? (map['meta']['total'] as num).toInt()
            : list.length;
    final page = (map['page'] is num)
        ? (map['page'] as num).toInt()
        : (map['meta'] is Map && map['meta']['page'] is num)
            ? (map['meta']['page'] as num).toInt()
            : 1;
    final limit = (map['limit'] is num)
        ? (map['limit'] as num).toInt()
        : (map['meta'] is Map && map['meta']['limit'] is num)
            ? (map['meta']['limit'] as num).toInt()
            : 20;

    return PaginatedResult(
      data: list,
      total: total,
      page: page,
      limit: limit,
    );
  }
}
