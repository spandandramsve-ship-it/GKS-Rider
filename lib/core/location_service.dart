import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../core/api_client.dart';
import '../core/socket_service.dart';

/// Wraps [Geolocator] for GPS access, periodic REST location posts,
/// and socket location emits during delivery.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  Timer? _trackingTimer;
  bool get isTracking => _trackingTimer != null;

  // ── Permissions ─────────────────────────────────────────────────────

  /// Requests location permission. Returns `true` if granted.
  Future<bool> ensurePermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[Location] Location services disabled');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('[Location] Permission denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('[Location] Permission permanently denied');
      return false;
    }

    return true;
  }

  // ── Single position ────────────────────────────────────────────────

  Future<Position?> getCurrentPosition() async {
    final ok = await ensurePermission();
    if (!ok) return null;
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // ── Go online: single POST to /rider/auth/location ─────────────────

  /// Posts the current location to go online. Returns `true` on success.
  Future<bool> postGoOnline() async {
    final pos = await getCurrentPosition();
    if (pos == null) return false;

    try {
      await ApiClient.instance.dio.post(
        '/rider/auth/location',
        data: {'lat': pos.latitude, 'lng': pos.longitude},
      );
      return true;
    } catch (e) {
      debugPrint('[Location] go-online failed: $e');
      return false;
    }
  }

  // ── Periodic tracking (pickup → delivery) ──────────────────────────

  /// Starts emitting location via socket every [intervalSeconds] seconds.
  /// Also posts to REST periodically to keep the rider visible.
  void startTracking({int intervalSeconds = 12}) {
    stopTracking();
    _trackingTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) => _emitLocation(),
    );
    // Fire immediately too.
    _emitLocation();
  }

  void stopTracking() {
    _trackingTimer?.cancel();
    _trackingTimer = null;
  }

  Future<void> _emitLocation() async {
    try {
      final pos = await getCurrentPosition();
      if (pos != null) {
        SocketService.instance.emitLocation(pos.latitude, pos.longitude);
      }
    } catch (e) {
      debugPrint('[Location] emit failed: $e');
    }
  }
}
