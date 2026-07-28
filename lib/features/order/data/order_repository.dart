import 'order_service.dart';
import 'payment_service.dart';
import 'models/active_order.dart';
import 'models/payment_qr.dart';
import 'models/payment_status.dart';

/// Wraps [OrderService] + [PaymentService] — the job/delivery flow and its
/// COD payment collection share one active order, so one repository.
class OrderRepository {
  final OrderService _orderService = OrderService();
  final PaymentService _paymentService = PaymentService();

  Future<ActiveOrder?> getActive() => _orderService.getActive();

  Future<void> reachedStore(String orderId) => _orderService.reachedStore(orderId);

  Future<void> pickedUp(String orderId) => _orderService.pickedUp(orderId);

  Future<String> requestDeliveryOtp(String orderId) =>
      _orderService.requestDeliveryOtp(orderId);

  Future<void> completeDelivery(String orderId, String code) =>
      _orderService.complete(orderId, code);

  Future<PaymentStatus> collectCash(String orderId) =>
      _paymentService.collectCash(orderId);

  Future<PaymentQr> getPaymentQr(String orderId) =>
      _paymentService.getPaymentQr(orderId);

  Future<PaymentStatus> getPaymentStatus(String orderId) =>
      _paymentService.getPaymentStatus(orderId);
}
