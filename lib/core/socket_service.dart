import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/env.dart';

/// Manages the socket.io connection for realtime events.
///
/// - Connects to the host root (not /api/v1).
/// - Passes JWT via `auth.token` on handshake.
/// - Listens for `order:assigned` and `order:status`.
/// - Emits `rider:location` for live tracking.
class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  io.Socket? _socket;
  bool get isConnected => _socket?.connected ?? false;

  // ── Streams exposed to the state layer ──────────────────────────────

  final _orderAssignedController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onOrderAssigned =>
      _orderAssignedController.stream;

  final _orderStatusController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onOrderStatus =>
      _orderStatusController.stream;

  /// Fired on auth failure during handshake — treat like a 401.
  final _authErrorController = StreamController<void>.broadcast();
  Stream<void> get onAuthError => _authErrorController.stream;

  // ── Connect ────────────────────────────────────────────────────────

  void connect(String jwt) {
    if (_socket != null) {
      _socket!.dispose();
    }

    _socket = io.io(
      Env.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': jwt})
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionAttempts(double.maxFinite.toInt())
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('[Socket] Connected');
    });

    _socket!.on('order:assigned', (data) {
      debugPrint('[Socket] order:assigned received');
      if (data is Map<String, dynamic>) {
        _orderAssignedController.add(data);
      } else if (data is Map) {
        _orderAssignedController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('order:status', (data) {
      debugPrint('[Socket] order:status received');
      if (data is Map<String, dynamic>) {
        _orderStatusController.add(data);
      } else if (data is Map) {
        _orderStatusController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.onConnectError((data) {
      debugPrint('[Socket] connect_error: $data');
      // Auth failure on handshake — treat as 401.
      final msg = data?.toString() ?? '';
      if (msg.contains('auth') ||
          msg.contains('unauthorized') ||
          msg.contains('jwt')) {
        _authErrorController.add(null);
      }
    });

    _socket!.onDisconnect((_) {
      debugPrint('[Socket] Disconnected');
    });

    _socket!.onReconnect((_) {
      debugPrint('[Socket] Reconnected');
    });

    _socket!.connect();
  }

  // ── Emit rider location ─────────────────────────────────────────────

  void emitLocation(double lat, double lng) {
    _socket?.emit('rider:location', {'lat': lat, 'lng': lng});
  }

  // ── Disconnect ──────────────────────────────────────────────────────

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  // ── Dispose (app shutdown) ──────────────────────────────────────────

  void dispose() {
    disconnect();
    _orderAssignedController.close();
    _orderStatusController.close();
    _authErrorController.close();
  }
}
