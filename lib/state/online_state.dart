import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/location_service.dart';
import '../services/auth_service.dart';
import '../models/rider_summary.dart';
import '../services/dashboard_service.dart';

/// Manages the rider's online/offline state and home summary.
class OnlineState extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final DashboardService _dashService = DashboardService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  bool _isOnline = false;
  bool get isOnline => _isOnline;

  RiderSummary? _summary;
  RiderSummary? get summary => _summary;

  // ── Go Online ─────────────────────────────────────────────────────

  Future<bool> goOnline() async {
    _setLoading(true);
    _error = null;

    try {
      final ok = await LocationService.instance.postGoOnline();
      if (!ok) {
        _error = 'Could not get your location. Enable GPS and try again.';
        _setLoading(false);
        return false;
      }
      _isOnline = true;
      _setLoading(false);
      return true;
    } catch (e) {
      _error = extractApiException(e).message;
      _setLoading(false);
      return false;
    }
  }

  // ── Go Offline ────────────────────────────────────────────────────

  Future<bool> goOffline() async {
    _setLoading(true);
    _error = null;

    try {
      await _authService.goOffline();
      _isOnline = false;
      LocationService.instance.stopTracking();
      _setLoading(false);
      return true;
    } catch (e) {
      final apiErr = extractApiException(e);
      // 409 = active job, can't go offline.
      _error = apiErr.message;
      _setLoading(false);
      return false;
    }
  }

  // ── Summary tiles ─────────────────────────────────────────────────

  Future<void> fetchSummary({String period = 'today'}) async {
    try {
      _summary = await _dashService.getSummary(period: period);
      notifyListeners();
    } catch (e) {
      debugPrint('[OnlineState] Summary fetch failed: $e');
    }
  }

  /// Set the online state without calling the API (e.g. from profile).
  void setOnlineStatus(bool online) {
    _isOnline = online;
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
}
