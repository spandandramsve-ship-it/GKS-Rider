import '../core/api_client.dart';
import '../models/active_order.dart';
import '../models/delivery_address.dart';

/// Order-related API calls (endpoints #7–#12).
class OrderService {
  final _dio = ApiClient.instance.dio;

  /// #7 GET /rider/orders/active — the hub call.
  /// Returns `null` when there is no active order.
  Future<ActiveOrder?> getActive() async {
    final res = await _dio.get('/rider/orders/active');
    if (res.data == null) return null;
    return ActiveOrder.fromJson(res.data as Map<String, dynamic>);
  }

  /// #8 PATCH /rider/orders/:id/reached-store
  Future<Map<String, dynamic>> reachedStore(String orderId) async {
    final res = await _dio.patch('/rider/orders/$orderId/reached-store');
    return res.data as Map<String, dynamic>? ?? {};
  }

  /// #9 PATCH /rider/orders/:id/picked-up
  Future<Map<String, dynamic>> pickedUp(String orderId) async {
    final res = await _dio.patch('/rider/orders/$orderId/picked-up');
    return res.data as Map<String, dynamic>? ?? {};
  }

  /// #10 GET /rider/orders/:id/delivery-location
  Future<DeliveryAddress> getDeliveryLocation(String orderId) async {
    final res = await _dio.get('/rider/orders/$orderId/delivery-location');
    return DeliveryAddress.fromJson(res.data as Map<String, dynamic>);
  }

  /// #11 POST /rider/orders/:id/request-delivery-otp
  Future<String> requestDeliveryOtp(String orderId) async {
    final res = await _dio.post(
      '/rider/orders/$orderId/request-delivery-otp',
    );
    if (res.data is Map<String, dynamic>) {
      return (res.data as Map<String, dynamic>)['message'] as String? ??
          'Delivery code sent';
    }
    return 'Delivery code sent';
  }

  /// #12 POST /rider/orders/:id/complete
  Future<Map<String, dynamic>> complete(String orderId, String code) async {
    final res = await _dio.post(
      '/rider/orders/$orderId/complete',
      data: {'code': code},
    );
    return res.data as Map<String, dynamic>? ?? {};
  }
}
