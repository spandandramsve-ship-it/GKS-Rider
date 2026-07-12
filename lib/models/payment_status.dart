/// Response from `GET /rider/orders/:id/payment-status`.
class PaymentStatus {
  final String paymentStatus; // PENDING, PAID, etc.
  final bool canCompleteDelivery;

  const PaymentStatus({
    required this.paymentStatus,
    required this.canCompleteDelivery,
  });

  factory PaymentStatus.fromJson(Map<String, dynamic> json) {
    return PaymentStatus(
      paymentStatus: json['paymentStatus'] as String? ?? 'PENDING',
      canCompleteDelivery: json['canCompleteDelivery'] as bool? ?? false,
    );
  }

  bool get isPaid => paymentStatus.toUpperCase() == 'PAID';
}
