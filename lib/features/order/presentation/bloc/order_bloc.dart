import 'dart:async';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/api_client.dart';
import '../../../../core/failure.dart';
import '../../../../core/location_service.dart';
import '../../../../core/socket_service.dart';
import '../../data/models/active_order.dart';
import '../../data/order_repository.dart';
import 'order_event.dart';
import 'order_state.dart';

/// Manages the active order — the single source of truth for which job
/// screen to show and what actions are available.
///
/// Golden rule: every socket event is a nudge; we always refetch
/// GET /rider/orders/active to get the authoritative status.
class OrderBloc extends Bloc<OrderEvent, OrderState> {
  final OrderRepository _repository;

  Timer? _paymentPollTimer;
  StreamSubscription? _assignedSub;
  StreamSubscription? _statusSub;

  OrderBloc({OrderRepository? repository})
      : _repository = repository ?? OrderRepository(),
        super(const OrderState()) {
    on<OrderSocketListenRequested>(_onSocketListenRequested);
    on<OrderActiveRequested>(_onActiveRequested, transformer: droppable());
    on<OrderReachedStoreRequested>(_onReachedStoreRequested,
        transformer: droppable());
    on<OrderPickedUpRequested>(_onPickedUpRequested, transformer: droppable());
    on<OrderDeliveryOtpRequested>(_onDeliveryOtpRequested);
    on<OrderCompleteDeliveryRequested>(_onCompleteDeliveryRequested,
        transformer: droppable());
    on<OrderCollectCashRequested>(_onCollectCashRequested,
        transformer: droppable());
    on<OrderPaymentQrRequested>(_onPaymentQrRequested, transformer: droppable());
    on<OrderCleared>(_onCleared);
    on<OrderErrorCleared>((event, emit) => emit(state.copyWith(failure: null)));
    on<OrderPaymentStatusPolled>(_onPaymentStatusPolled);
  }

  void _onSocketListenRequested(
    OrderSocketListenRequested event,
    Emitter<OrderState> emit,
  ) {
    _assignedSub?.cancel();
    _statusSub?.cancel();
    _assignedSub = SocketService.instance.onOrderAssigned.listen((_) {
      if (!isClosed) add(const OrderActiveRequested());
    });
    _statusSub = SocketService.instance.onOrderStatus.listen((_) {
      if (!isClosed) add(const OrderActiveRequested());
    });
  }

  Future<void> _onActiveRequested(
    OrderActiveRequested event,
    Emitter<OrderState> emit,
  ) async {
    try {
      await _fetchAndApplyActive(emit);
      emit(state.copyWith(failure: null));
    } catch (e) {
      emit(state.copyWith(failure: Failure(extractApiException(e).message)));
    }
  }

  Future<void> _onReachedStoreRequested(
    OrderReachedStoreRequested event,
    Emitter<OrderState> emit,
  ) async {
    if (state.order == null) return;
    emit(state.copyWith(isLoading: true, failure: null));
    try {
      await _repository.reachedStore(state.order!.id);
      // Status might not change immediately (PACKING stays PACKING).
      // Always refetch to get the authoritative state.
      await _fetchAndApplyActive(emit);
      emit(state.copyWith(isLoading: false));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        failure: Failure(extractApiException(e).message),
      ));
    }
  }

  Future<void> _onPickedUpRequested(
    OrderPickedUpRequested event,
    Emitter<OrderState> emit,
  ) async {
    if (state.order == null) return;
    emit(state.copyWith(isLoading: true, failure: null));
    try {
      await _repository.pickedUp(state.order!.id);
      await _fetchAndApplyActive(emit);
      LocationService.instance.startTracking();
      emit(state.copyWith(isLoading: false));
    } catch (e) {
      final apiErr = extractApiException(e);
      if (apiErr.statusCode == 409) {
        // Stale state — refetch.
        await _fetchAndApplyActive(emit);
      }
      emit(state.copyWith(isLoading: false, failure: Failure(apiErr.message)));
    }
  }

  Future<void> _onDeliveryOtpRequested(
    OrderDeliveryOtpRequested event,
    Emitter<OrderState> emit,
  ) async {
    if (state.order == null) return;
    try {
      final msg = await _repository.requestDeliveryOtp(state.order!.id);
      emit(state.copyWith(deliveryOtpMessage: InfoMessage(msg)));
    } catch (e) {
      emit(state.copyWith(
        deliveryOtpMessage: InfoMessage(extractApiException(e).message),
      ));
    }
  }

  Future<void> _onCompleteDeliveryRequested(
    OrderCompleteDeliveryRequested event,
    Emitter<OrderState> emit,
  ) async {
    if (state.order == null) return;
    emit(state.copyWith(isLoading: true, failure: null));
    try {
      await _repository.completeDelivery(state.order!.id, event.code);
      LocationService.instance.stopTracking();
      _stopPaymentPolling(emit);
      await _fetchAndApplyActive(emit);
      emit(state.copyWith(isLoading: false));
    } catch (e) {
      final apiErr = extractApiException(e);
      if (apiErr.statusCode == 409) {
        // "collect payment first" or "request the code first"
        await _fetchAndApplyActive(emit);
      }
      emit(state.copyWith(isLoading: false, failure: Failure(apiErr.message)));
    }
  }

  Future<void> _onCollectCashRequested(
    OrderCollectCashRequested event,
    Emitter<OrderState> emit,
  ) async {
    if (state.order == null) return;
    emit(state.copyWith(isLoading: true, failure: null));
    try {
      final status = await _repository.collectCash(state.order!.id);
      emit(state.copyWith(paymentStatus: status));
      await _fetchAndApplyActive(emit);
      emit(state.copyWith(isLoading: false));
    } catch (e) {
      final apiErr = extractApiException(e);
      if (apiErr.statusCode == 409) {
        // Already paid or wrong state — refetch.
        await _refreshPaymentStatus(emit);
      }
      emit(state.copyWith(isLoading: false, failure: Failure(apiErr.message)));
    }
  }

  Future<void> _onPaymentQrRequested(
    OrderPaymentQrRequested event,
    Emitter<OrderState> emit,
  ) async {
    if (state.order == null) return;
    emit(state.copyWith(isLoading: true, failure: null));
    try {
      final qr = await _repository.getPaymentQr(state.order!.id);
      emit(state.copyWith(isLoading: false, paymentQr: qr));
      _startPaymentPolling(emit);
    } catch (e) {
      final apiErr = extractApiException(e);
      if (apiErr.statusCode == 422) {
        emit(state.copyWith(
          isLoading: false,
          failure: Failure(
            'QR payment unavailable for this amount. Use cash instead.',
          ),
        ));
      } else if (apiErr.statusCode == 502) {
        emit(state.copyWith(
          isLoading: false,
          failure: Failure('Payment gateway issue. Try again in a moment.'),
        ));
      } else if (apiErr.statusCode == 409) {
        await _refreshPaymentStatus(emit);
        emit(state.copyWith(isLoading: false, failure: Failure(apiErr.message)));
      } else {
        emit(state.copyWith(isLoading: false, failure: Failure(apiErr.message)));
      }
    }
  }

  Future<void> _onPaymentStatusPolled(
    OrderPaymentStatusPolled event,
    Emitter<OrderState> emit,
  ) async {
    await _refreshPaymentStatus(emit);
  }

  void _onCleared(OrderCleared event, Emitter<OrderState> emit) {
    _stopPaymentPolling();
    LocationService.instance.stopTracking();
    _assignedSub?.cancel();
    _statusSub?.cancel();
    emit(const OrderState());
  }

  // ── Shared helpers ────────────────────────────────────────────────

  Future<ActiveOrder?> _fetchAndApplyActive(Emitter<OrderState> emit) async {
    final order = await _repository.getActive();

    // If delivered or no order, stop tracking.
    if (order == null || order.status == 'DELIVERED') {
      LocationService.instance.stopTracking();
      _stopPaymentPolling(emit);
    }
    // If picked up, start tracking if not already.
    if (order != null &&
        order.status == 'PICKED_UP' &&
        !LocationService.instance.isTracking) {
      LocationService.instance.startTracking();
    }

    emit(state.copyWith(order: order));
    return order;
  }

  Future<void> _refreshPaymentStatus(Emitter<OrderState> emit) async {
    if (state.order == null) return;
    try {
      final status = await _repository.getPaymentStatus(state.order!.id);
      emit(state.copyWith(paymentStatus: status));
      if (status.canCompleteDelivery) {
        _stopPaymentPolling(emit);
        // Refetch order to get updated payment info.
        await _fetchAndApplyActive(emit);
      }
    } catch (_) {
      // Silent — this runs on a background poll timer; a transient
      // failure just gets retried on the next tick.
    }
  }

  void _startPaymentPolling(Emitter<OrderState> emit) {
    _stopPaymentPolling(emit);
    _paymentPollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!isClosed) add(const OrderPaymentStatusPolled());
    });
    emit(state.copyWith(isPollingPayment: true));
  }

  void _stopPaymentPolling([Emitter<OrderState>? emit]) {
    _paymentPollTimer?.cancel();
    _paymentPollTimer = null;
    if (emit != null) emit(state.copyWith(isPollingPayment: false));
  }

  @override
  Future<void> close() {
    _stopPaymentPolling();
    _assignedSub?.cancel();
    _statusSub?.cancel();
    return super.close();
  }
}
