import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/env.dart';

const _jsonPrinter = JsonEncoder.withIndent('  ');

/// Pretty-prints [data] for logging; falls back to `toString()` for
/// anything that isn't directly JSON-encodable.
String _prettyPayload(dynamic data) {
  if (data == null) return 'null';
  try {
    return _jsonPrinter.convert(data);
  } catch (_) {
    return data.toString();
  }
}

/// Manages the socket.io connection for realtime events.
///
/// - Connects to the host root (not /api/v1).
/// - Passes JWT via `auth.token` on handshake.
/// - Listens for `order:assigned` and `order:status`.
/// - Emits `rider:location` for live tracking.
///
/// Every inbound/outbound event is logged via `debugPrint` with its
/// full payload for debugging.
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
      debugPrint('[Socket] 🔌 connect (id: ${_socket?.id})');
    });

    _socket!.on('order:assigned', (data) {
      debugPrint('[Socket] 📥 order:assigned payload: ${_prettyPayload(data)}');
      if (data is Map<String, dynamic>) {
        _orderAssignedController.add(data);
      } else if (data is Map) {
        _orderAssignedController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('order:status', (data) {
      debugPrint('[Socket] 📥 order:status payload: ${_prettyPayload(data)}');
      if (data is Map<String, dynamic>) {
        _orderStatusController.add(data);
      } else if (data is Map) {
        _orderStatusController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.onConnectError((data) {
      debugPrint('[Socket] ❌ connect_error: ${_prettyPayload(data)}');
      // Auth failure on handshake — treat as 401.
      final msg = data?.toString() ?? '';
      if (msg.contains('auth') ||
          msg.contains('unauthorized') ||
          msg.contains('jwt')) {
        _authErrorController.add(null);
      }
    });

    _socket!.onError((data) {
      debugPrint('[Socket] ❌ error: ${_prettyPayload(data)}');
    });

    _socket!.onDisconnect((reason) {
      debugPrint('[Socket] 🔌 disconnect: ${_prettyPayload(reason)}');
    });

    _socket!.onReconnect((data) {
      debugPrint('[Socket] 🔁 reconnect: ${_prettyPayload(data)}');
    });

    _socket!.onReconnectAttempt((data) {
      debugPrint('[Socket] 🔁 reconnect_attempt: ${_prettyPayload(data)}');
    });

    _socket!.onReconnectError((data) {
      debugPrint('[Socket] ❌ reconnect_error: ${_prettyPayload(data)}');
    });

    _socket!.onReconnectFailed((data) {
      debugPrint('[Socket] ❌ reconnect_failed: ${_prettyPayload(data)}');
    });

    _socket!.connect();
  }

  // ── Emit rider location ─────────────────────────────────────────────

  void emitLocation(double lat, double lng) {
    final payload = {'lat': lat, 'lng': lng};
    debugPrint('[Socket] 📤 rider:location payload: ${_prettyPayload(payload)}');
    _socket?.emit('rider:location', payload);
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
