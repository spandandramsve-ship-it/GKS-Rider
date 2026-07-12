import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/location_service.dart';
import '../core/socket_service.dart';
import '../models/active_order.dart';
import '../models/payment_qr.dart';
import '../models/payment_status.dart';
import '../services/order_service.dart';
import '../services/payment_service.dart';

/// Manages the active order state — the single source of truth for
/// which job screen to show and what actions are available.
///
/// Golden rule: every socket event is a nudge; we always refetch
/// GET /rider/orders/active to get the authoritative status.
class ActiveOrderState extends ChangeNotifier {
  final OrderService _orderService = OrderService();
  final PaymentService _paymentService = PaymentService();

  ActiveOrder? _order;
  ActiveOrder? get order => _order;
  bool get hasOrder => _order != null;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  // Payment QR state
  PaymentQr? _paymentQr;
  PaymentQr? get paymentQr => _paymentQr;

  PaymentStatus? _paymentStatus;
  PaymentStatus? get paymentStatus => _paymentStatus;
  bool get canCompleteDelivery =>
      _paymentStatus?.canCompleteDelivery ?? false;

  Timer? _paymentPollTimer;
  bool _isPollingPayment = false;

  // Socket subscriptions
  StreamSubscription? _assignedSub;
  StreamSubscription? _statusSub;

  // ── Initialize (call after auth) ──────────────────────────────────

  void listenToSocket() {
    _assignedSub?.cancel();
    _statusSub?.cancel();

    _assignedSub = SocketService.instance.onOrderAssigned.listen((_) {
      debugPrint('[ActiveOrderState] order:assigned → refetching');
      fetchActiveOrder();
    });

    _statusSub = SocketService.instance.onOrderStatus.listen((_) {
      debugPrint('[ActiveOrderState] order:status → refetching');
      fetchActiveOrder();
    });
  }

  // ── Fetch active order (#7) ───────────────────────────────────────

  Future<void> fetchActiveOrder() async {
    try {
      _order = await _orderService.getActive();
      _error = null;

      // If delivered or no order, stop tracking.
      if (_order == null || _order!.status == 'DELIVERED') {
        LocationService.instance.stopTracking();
        _stopPaymentPolling();
      }

      // If picked up, start tracking if not already.
      if (_order != null && _order!.status == 'PICKED_UP') {
        if (!LocationService.instance.isTracking) {
          LocationService.instance.startTracking();
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('[ActiveOrderState] fetchActive failed: $e');
      _error = extractApiException(e).message;
      notifyListeners();
    }
  }

  // ── Reached Store (#8) ────────────────────────────────────────────

  Future<bool> reachedStore() async {
    if (_order == null) return false;
    _setLoading(true);
    _error = null;

    try {
      await _orderService.reachedStore(_order!.id);
      // Status might not change immediately (PACKING stays PACKING).
      // Always refetch to get the authoritative state.
      await fetchActiveOrder();
      _setLoading(false);
      return true;
    } catch (e) {
      _error = extractApiException(e).message;
      _setLoading(false);
      return false;
    }
  }

  // ── Picked Up (#9) ───────────────────────────────────────────────

  Future<bool> pickedUp() async {
    if (_order == null) return false;
    _setLoading(true);
    _error = null;

    try {
      await _orderService.pickedUp(_order!.id);
      await fetchActiveOrder();
      // Start location tracking after pickup.
      LocationService.instance.startTracking();
      _setLoading(false);
      return true;
    } catch (e) {
      final apiErr = extractApiException(e);
      if (apiErr.statusCode == 409) {
        // Stale state — refetch.
        await fetchActiveOrder();
      }
      _error = apiErr.message;
      _setLoading(false);
      return false;
    }
  }

  // ── Request Delivery OTP (#11) ────────────────────────────────────

  Future<String?> requestDeliveryOtp() async {
    if (_order == null) return null;
    try {
      return await _orderService.requestDeliveryOtp(_order!.id);
    } catch (e) {
      return extractApiException(e).message;
    }
  }

  // ── Complete Delivery (#12) ───────────────────────────────────────

  Future<bool> completeDelivery(String code) async {
    if (_order == null) return false;
    _setLoading(true);
    _error = null;

    try {
      await _orderService.complete(_order!.id, code);
      LocationService.instance.stopTracking();
      _stopPaymentPolling();
      await fetchActiveOrder();
      _setLoading(false);
      return true;
    } catch (e) {
      final apiErr = extractApiException(e);
      if (apiErr.statusCode == 409) {
        // "collect payment first" or "request the code first"
        await fetchActiveOrder();
      }
      _error = apiErr.message;
      _setLoading(false);
      return false;
    }
  }

  // ── Collect Cash (#13) ────────────────────────────────────────────

  Future<bool> collectCash() async {
    if (_order == null) return false;
    _setLoading(true);
    _error = null;

    try {
      _paymentStatus = await _paymentService.collectCash(_order!.id);
      await fetchActiveOrder();
      _setLoading(false);
      return true;
    } catch (e) {
      final apiErr = extractApiException(e);
      if (apiErr.statusCode == 409) {
        // Already paid or wrong state — refetch.
        await _refreshPaymentStatus();
      }
      _error = apiErr.message;
      _setLoading(false);
      return false;
    }
  }

  // ── Payment QR (#14) ──────────────────────────────────────────────

  Future<bool> fetchPaymentQr() async {
    if (_order == null) return false;
    _setLoading(true);
    _error = null;

    try {
      _paymentQr = await _paymentService.getPaymentQr(_order!.id);
      _setLoading(false);
      // Start polling for payment status.
      _startPaymentPolling();
      return true;
    } catch (e) {
      final apiErr = extractApiException(e);
      if (apiErr.statusCode == 422) {
        // Amount not payable by QR → fall back to cash.
        _error = 'QR payment unavailable for this amount. Use cash instead.';
      } else if (apiErr.statusCode == 502) {
        _error = 'Payment gateway issue. Try again in a moment.';
      } else if (apiErr.statusCode == 409) {
        await _refreshPaymentStatus();
        _error = apiErr.message;
      } else {
        _error = apiErr.message;
      }
      _setLoading(false);
      return false;
    }
  }

  // ── Payment Status Polling (#15) ──────────────────────────────────

  void _startPaymentPolling() {
    _stopPaymentPolling();
    _isPollingPayment = true;
    _paymentPollTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _refreshPaymentStatus(),
    );
  }

  void _stopPaymentPolling() {
    _paymentPollTimer?.cancel();
    _paymentPollTimer = null;
    _isPollingPayment = false;
  }

  bool get isPollingPayment => _isPollingPayment;

  Future<void> _refreshPaymentStatus() async {
    if (_order == null) return;
    try {
      _paymentStatus = await _paymentService.getPaymentStatus(_order!.id);
      if (_paymentStatus!.canCompleteDelivery) {
        _stopPaymentPolling();
        // Refetch order to get updated payment info.
        await fetchActiveOrder();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[ActiveOrderState] payment-status poll failed: $e');
    }
  }

  // ── Clear state ───────────────────────────────────────────────────

  void clear() {
    _order = null;
    _paymentQr = null;
    _paymentStatus = null;
    _error = null;
    _stopPaymentPolling();
    LocationService.instance.stopTracking();
    _assignedSub?.cancel();
    _statusSub?.cancel();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  @override
  void dispose() {
    _assignedSub?.cancel();
    _statusSub?.cancel();
    _stopPaymentPolling();
    super.dispose();
  }
}
