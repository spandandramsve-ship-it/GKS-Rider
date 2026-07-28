import 'geo_point.dart';
import 'delivery_address.dart';
import 'order_item.dart';
import 'pricing.dart';
import 'payment.dart';

/// The full active order returned by `GET /rider/orders/active`.
///
/// This is the single source of truth for the delivery state machine.
/// Re-fetched after every socket event and on app resume.
class ActiveOrder {
  final String id;
  final String? orderNumber;
  final String status; // PACKING, PACKED, REACHED_STORE, PICKED_UP, DELIVERED
  final String? pickupToken; // handoff ID, e.g. "#0421"

  // Pickup (store)
  final String? storeName;
  final GeoPoint? storeLocation;
  final String? storePhone;

  // Customer
  final String? customerName;
  final String? customerPhone; // null until PICKED_UP
  final String? customerBlock; // optional block/apartment

  // Delivery (null until PICKED_UP)
  final DeliveryAddress? delivery;

  // Payment
  final Payment? payment;

  // Pricing
  final Pricing? pricing;

  // Items
  final List<OrderItem> items;

  // Timestamps
  final DateTime? placedAt;
  final DateTime? deliveredAt;

  // Packing ETA (minutes) — may come from socket or active-order
  final int? packingEtaMinutes;

  const ActiveOrder({
    required this.id,
    this.orderNumber,
    required this.status,
    this.pickupToken,
    this.storeName,
    this.storeLocation,
    this.storePhone,
    this.customerName,
    this.customerPhone,
    this.customerBlock,
    this.delivery,
    this.payment,
    this.pricing,
    this.items = const [],
    this.placedAt,
    this.deliveredAt,
    this.packingEtaMinutes,
  });

  factory ActiveOrder.fromJson(Map<String, dynamic> json) {
    // Parse store/pickup location
    GeoPoint? storeLoc;
    final pickup = json['pickup'] as Map<String, dynamic>?;
    if (pickup != null) {
      final loc = pickup['location'] as Map<String, dynamic>?;
      if (loc != null) {
        final coords = loc['coordinates'];
        if (coords is List && coords.length >= 2) {
          storeLoc = GeoPoint.fromGeoJson(coords);
        }
      }
    }

    // Parse customer
    final customer = json['customer'] as Map<String, dynamic>?;

    // Parse delivery address
    DeliveryAddress? deliveryAddr;
    final deliveryData = json['delivery'] as Map<String, dynamic>?;
    if (deliveryData != null) {
      deliveryAddr = DeliveryAddress.fromJson(deliveryData);
    }

    // Parse payment
    Payment? paymentData;
    final payJson = json['payment'] as Map<String, dynamic>?;
    if (payJson != null) {
      paymentData = Payment.fromJson(payJson);
    }

    // Parse pricing
    Pricing? pricingData;
    final priceJson = json['pricing'] as Map<String, dynamic>?;
    if (priceJson != null) {
      pricingData = Pricing.fromJson(priceJson);
    }

    // Parse items
    final itemsList = json['items'] as List<dynamic>?;
    final items = itemsList
            ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return ActiveOrder(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      orderNumber: json['orderNumber'] as String?,
      status: json['status'] as String? ?? 'UNKNOWN',
      pickupToken: json['pickupToken'] as String?,
      storeName: pickup?['storeName'] as String?,
      storeLocation: storeLoc,
      storePhone: pickup?['storePhone'] as String?,
      customerName: customer?['name'] as String?,
      customerPhone: customer?['phone'] as String?,
      customerBlock: customer?['block'] as String?,
      delivery: deliveryAddr,
      payment: paymentData,
      pricing: pricingData,
      items: items,
      placedAt: json['placedAt'] != null
          ? DateTime.tryParse(json['placedAt'] as String)
          : null,
      deliveredAt: json['deliveredAt'] != null
          ? DateTime.tryParse(json['deliveredAt'] as String)
          : null,
      packingEtaMinutes: json['packingEtaMinutes'] as int?,
    );
  }

  /// Whether payment is settled (ONLINE always, COD when paid).
  bool get isPaymentSettled {
    if (payment == null) return true; // no payment info → assume ok
    if (payment!.isOnline) return true;
    return payment!.isPaid;
  }
}
