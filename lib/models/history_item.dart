/// A single history entry from `GET /rider/orders/history`.
class HistoryItem {
  final String id;
  final String? orderNumber;
  final String? storeName;
  final String? customerName;
  final double amount;
  final String status;
  final String bucket; // ONGOING, COMPLETED, FAILED
  final String? paymentMode;
  final String? paymentStatus;
  final String? collectionMethod;
  final DateTime? placedAt;
  final DateTime? deliveredAt;
  final DateTime? collectedAt;

  const HistoryItem({
    required this.id,
    this.orderNumber,
    this.storeName,
    this.customerName,
    required this.amount,
    required this.status,
    required this.bucket,
    this.paymentMode,
    this.paymentStatus,
    this.collectionMethod,
    this.placedAt,
    this.deliveredAt,
    this.collectedAt,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      orderNumber: json['orderNumber'] as String?,
      storeName: json['storeName'] as String?,
      customerName: json['customerName'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? '',
      bucket: json['bucket'] as String? ?? 'ONGOING',
      paymentMode: json['paymentMode'] as String?,
      paymentStatus: json['paymentStatus'] as String?,
      collectionMethod: json['collectionMethod'] as String?,
      placedAt: json['placedAt'] != null
          ? DateTime.tryParse(json['placedAt'] as String)
          : null,
      deliveredAt: json['deliveredAt'] != null
          ? DateTime.tryParse(json['deliveredAt'] as String)
          : null,
      collectedAt: json['collectedAt'] != null
          ? DateTime.tryParse(json['collectedAt'] as String)
          : null,
    );
  }

  /// Display time: deliveredAt if delivered, else placedAt.
  DateTime? get displayTime => deliveredAt ?? placedAt;
}

/// Pagination metadata from history response.
class HistoryPagination {
  final String? nextCursor;
  final bool hasMore;

  const HistoryPagination({this.nextCursor, required this.hasMore});

  factory HistoryPagination.fromJson(Map<String, dynamic> json) {
    return HistoryPagination(
      nextCursor: json['nextCursor'] as String?,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}

/// Full history response including items + pagination.
class HistoryResponse {
  final List<HistoryItem> orders;
  final HistoryPagination pagination;

  const HistoryResponse({required this.orders, required this.pagination});

  factory HistoryResponse.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>?)
            ?.map((e) => HistoryItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final pagination = HistoryPagination.fromJson(
      json['pagination'] as Map<String, dynamic>? ?? {'hasMore': false},
    );
    return HistoryResponse(orders: items, pagination: pagination);
  }
}
