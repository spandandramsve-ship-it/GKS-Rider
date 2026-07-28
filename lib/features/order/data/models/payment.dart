/// Payment information within an order.
class Payment {
  /// `COD` or `ONLINE`.
  final String mode;

  /// `PENDING`, `PAID`, etc.
  final String? status;

  /// `cash`, `upi`, etc.
  final String? collectionMethod;

  final double? amount;
  final DateTime? collectedAt;

  const Payment({
    required this.mode,
    this.status,
    this.collectionMethod,
    this.amount,
    this.collectedAt,
  });

  bool get isCod => mode.toUpperCase() == 'COD';
  bool get isOnline => mode.toUpperCase() == 'ONLINE';
  bool get isPaid => status?.toUpperCase() == 'PAID';

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      mode: json['mode'] as String? ?? 'ONLINE',
      status: json['status'] as String?,
      collectionMethod: json['collectionMethod'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      collectedAt: json['collectedAt'] != null
          ? DateTime.tryParse(json['collectedAt'] as String)
          : null,
    );
  }
}
