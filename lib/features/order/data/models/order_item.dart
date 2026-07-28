/// A single line item within an order.
class OrderItem {
  final String? name;
  final int quantity;
  final double price;
  final String? variant;
  final String? imageUrl;

  const OrderItem({
    this.name,
    required this.quantity,
    required this.price,
    this.variant,
    this.imageUrl,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      name: json['name'] as String? ??
          json['productName'] as String? ??
          'Item',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      variant: json['variant'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }
}
