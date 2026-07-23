import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../core/api_client.dart';
import '../core/socket_service.dart';

/// Wraps [Geolocator] for GPS access, a background-safe position stream,
/// and socket location emits during delivery.
///
/// Tracking runs via [Geolocator.getPositionStream] rather than a plain
/// `Timer`, because a Dart timer is frozen by the OS soon after the app is
/// backgrounded (Doze mode on Android, ~30s suspension on iOS). The position
/// stream is backed by a real Android foreground service (persistent
/// notification) and iOS background location updates, both of which keep
/// the process — and therefore the socket connection — alive during a
/// delivery.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  StreamSubscription<Position>? _positionSub;
  DateTime? _lastEmitAt;
  int _minEmitIntervalSeconds = 12;

  bool get isTracking => _positionSub != null;

  // ── Permissions ─────────────────────────────────────────────────────

  /// Requests location permission, escalating to background ("Always")
  /// access — required for tracking to keep working once the app is
  /// backgrounded during a delivery. Returns `true` if at least
  /// foreground access is granted.
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

    // Escalate while-in-use → always, so background tracking keeps working.
    if (permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.always) {
        debugPrint(
          '[Location] Background ("Always") permission not granted — '
          'tracking may stop once the app is backgrounded.',
        );
      }
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

  // ── Continuous tracking (pickup → delivery) ─────────────────────────

  /// Starts emitting location via socket, at most every [intervalSeconds]
  /// seconds, backed by a real Android foreground service / iOS background
  /// location session so it keeps running while the app is backgrounded.
  Future<void> startTracking({int intervalSeconds = 12}) async {
    stopTracking();

    final ok = await ensurePermission();
    if (!ok) {
      debugPrint('[Location] startTracking aborted — permission not granted');
      return;
    }

    _minEmitIntervalSeconds = intervalSeconds;
    _lastEmitAt = null;

    _positionSub = Geolocator.getPositionStream(
      locationSettings: _buildLocationSettings(intervalSeconds),
    ).listen(
      _onPosition,
      onError: (Object e) => debugPrint('[Location] stream error: $e'),
    );
  }

  void stopTracking() {
    _positionSub?.cancel();
    _positionSub = null;
    _lastEmitAt = null;
  }

  void _onPosition(Position pos) {
    final now = DateTime.now();
    if (_lastEmitAt != null &&
        now.difference(_lastEmitAt!).inSeconds < _minEmitIntervalSeconds) {
      return;
    }
    _lastEmitAt = now;
    SocketService.instance.emitLocation(pos.latitude, pos.longitude);
  }

  LocationSettings _buildLocationSettings(int intervalSeconds) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: Duration(seconds: intervalSeconds),
        // Runs as a real foreground service with a persistent notification
        // so Doze/App Standby don't freeze tracking while backgrounded.
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Delivery in progress',
          notificationText: 'GKS Rider is sharing your live location',
          enableWakeLock: true,
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.otherNavigation,
        distanceFilter: 10,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }
    return LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
  }
}
