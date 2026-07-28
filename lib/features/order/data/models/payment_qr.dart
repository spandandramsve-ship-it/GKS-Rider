/// Response from `POST /rider/orders/:id/payment-qr` (201).
class PaymentQr {
  final String imageUrl;
  final double amountRupees;
  final DateTime? expiresAt;

  const PaymentQr({
    required this.imageUrl,
    required this.amountRupees,
    this.expiresAt,
  });

  factory PaymentQr.fromJson(Map<String, dynamic> json) {
    return PaymentQr(
      imageUrl: json['imageUrl'] as String? ?? '',
      amountRupees: (json['amountRupees'] as num?)?.toDouble() ??
          (json['amount'] as num?)?.toDouble() ??
          0,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
    );
  }

  /// Whether the QR has expired.
  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  /// Seconds remaining until expiry, or 0 if expired.
  int get secondsRemaining {
    if (expiresAt == null) return 600; // default 10 min
    final diff = expiresAt!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }
}
