import '../core/api_client.dart';
import '../models/payment_qr.dart';
import '../models/payment_status.dart';

/// Payment-related API calls (endpoints #13–#15, COD only).
class PaymentService {
  final _dio = ApiClient.instance.dio;

  /// #13 POST /rider/orders/:id/collect-cash
  Future<PaymentStatus> collectCash(String orderId) async {
    final res = await _dio.post('/rider/orders/$orderId/collect-cash');
    return PaymentStatus.fromJson(res.data as Map<String, dynamic>);
  }

  /// #14 POST /rider/orders/:id/payment-qr (returns 201)
  Future<PaymentQr> getPaymentQr(String orderId) async {
    final res = await _dio.post('/rider/orders/$orderId/payment-qr');
    return PaymentQr.fromJson(res.data as Map<String, dynamic>);
  }

  /// #15 GET /rider/orders/:id/payment-status
  Future<PaymentStatus> getPaymentStatus(String orderId) async {
    final res = await _dio.get('/rider/orders/$orderId/payment-status');
    return PaymentStatus.fromJson(res.data as Map<String, dynamic>);
  }
}
