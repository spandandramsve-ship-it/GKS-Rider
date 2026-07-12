/// Order pricing breakdown.
class Pricing {
  final double subtotal;
  final double deliveryFee;
  final double tax;
  final double discount;
  final double total;

  const Pricing({
    required this.subtotal,
    required this.deliveryFee,
    required this.tax,
    required this.discount,
    required this.total,
  });

  factory Pricing.fromJson(Map<String, dynamic> json) {
    return Pricing(
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ??
          (json['grandTotal'] as num?)?.toDouble() ??
          0,
    );
  }
}
