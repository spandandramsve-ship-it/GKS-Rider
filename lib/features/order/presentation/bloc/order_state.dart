import 'package:equatable/equatable.dart';
import '../../../../core/failure.dart';
import '../../../../core/unset.dart';
import '../../data/models/active_order.dart';
import '../../data/models/payment_qr.dart';
import '../../data/models/payment_status.dart';

class OrderState extends Equatable {
  final ActiveOrder? order;
  final bool isLoading;
  final Failure? failure;
  final PaymentQr? paymentQr;
  final PaymentStatus? paymentStatus;
  final InfoMessage? deliveryOtpMessage;
  final bool isPollingPayment;

  const OrderState({
    this.order,
    this.isLoading = false,
    this.failure,
    this.paymentQr,
    this.paymentStatus,
    this.deliveryOtpMessage,
    this.isPollingPayment = false,
  });

  bool get hasOrder => order != null;
  bool get canCompleteDelivery => paymentStatus?.canCompleteDelivery ?? false;

  OrderState copyWith({
    Object? order = unset,
    bool? isLoading,
    Object? failure = unset,
    Object? paymentQr = unset,
    Object? paymentStatus = unset,
    Object? deliveryOtpMessage = unset,
    bool? isPollingPayment,
  }) {
    return OrderState(
      order: identical(order, unset) ? this.order : order as ActiveOrder?,
      isLoading: isLoading ?? this.isLoading,
      failure: identical(failure, unset) ? this.failure : failure as Failure?,
      paymentQr:
          identical(paymentQr, unset) ? this.paymentQr : paymentQr as PaymentQr?,
      paymentStatus: identical(paymentStatus, unset)
          ? this.paymentStatus
          : paymentStatus as PaymentStatus?,
      deliveryOtpMessage: identical(deliveryOtpMessage, unset)
          ? this.deliveryOtpMessage
          : deliveryOtpMessage as InfoMessage?,
      isPollingPayment: isPollingPayment ?? this.isPollingPayment,
    );
  }

  @override
  List<Object?> get props => [
        order,
        isLoading,
        failure,
        paymentQr,
        paymentStatus,
        deliveryOtpMessage,
        isPollingPayment,
      ];
}
