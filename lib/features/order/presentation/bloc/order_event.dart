import 'package:equatable/equatable.dart';

sealed class OrderEvent extends Equatable {
  const OrderEvent();

  @override
  List<Object?> get props => [];
}

/// Subscribes to `order:assigned`/`order:status` socket events — each one
/// triggers a refetch of the authoritative active-order state.
class OrderSocketListenRequested extends OrderEvent {
  const OrderSocketListenRequested();
}

class OrderActiveRequested extends OrderEvent {
  const OrderActiveRequested();
}

class OrderReachedStoreRequested extends OrderEvent {
  const OrderReachedStoreRequested();
}

class OrderPickedUpRequested extends OrderEvent {
  const OrderPickedUpRequested();
}

class OrderDeliveryOtpRequested extends OrderEvent {
  const OrderDeliveryOtpRequested();
}

class OrderCompleteDeliveryRequested extends OrderEvent {
  final String code;

  const OrderCompleteDeliveryRequested(this.code);

  @override
  List<Object?> get props => [code];
}

class OrderCollectCashRequested extends OrderEvent {
  const OrderCollectCashRequested();
}

class OrderPaymentQrRequested extends OrderEvent {
  const OrderPaymentQrRequested();
}

/// Reset — global 401 handler / logout.
class OrderCleared extends OrderEvent {
  const OrderCleared();
}

class OrderErrorCleared extends OrderEvent {
  const OrderErrorCleared();
}

/// Internal — one payment-status poll tick (every 4s while a QR is shown).
class OrderPaymentStatusPolled extends OrderEvent {
  const OrderPaymentStatusPolled();
}
