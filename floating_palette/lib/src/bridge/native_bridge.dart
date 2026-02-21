import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';

import 'command.dart';
import 'event.dart';

/// Callback for native events.
typedef NativeEventCallback = void Function(NativeEvent event);

/// Single bridge to native layer.
///
/// All communication with native goes through this class.
/// Services use this to send commands and receive events.
class NativeBridge {
  final MethodChannel _channel;

  /// Timeout for commands sent to native.
  ///
  /// If native doesn't respond within this duration, a [NativeBridgeException]
  /// with code `'TIMEOUT'` is thrown.
  final Duration commandTimeout;

  /// Create a new NativeBridge.
  ///
  /// In most cases, you should use [PaletteHost.bridge] instead of
  /// creating your own instance.
  NativeBridge({
    String channelName = 'floating_palette',
    this.commandTimeout = const Duration(seconds: 5),
  }) : _channel = MethodChannel(channelName) {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  /// Event callbacks by service name.
  final _eventCallbacks = <String, List<NativeEventCallback>>{};

  /// Global event callbacks (receive all events).
  final _globalCallbacks = <NativeEventCallback>[];

  // ════════════════════════════════════════════════════════════════════════
  // Commands
  // ════════════════════════════════════════════════════════════════════════

  /// Send a command to native.
  Future<T?> send<T>(NativeCommand command) async {
    try {
      final result = await _channel.invokeMethod<T>(
        'command',
        command.toMap(),
      ).timeout(commandTimeout);
      return result;
    } on TimeoutException catch (e, stackTrace) {
      Error.throwWithStackTrace(
        NativeBridgeException(
          command: command,
          message: 'Command timed out after ${commandTimeout.inSeconds}s',
          code: 'TIMEOUT',
          originalException: e,
        ),
        stackTrace,
      );
    } on PlatformException catch (e, stackTrace) {
      Error.throwWithStackTrace(
        NativeBridgeException(
          command: command,
          message: e.message ?? 'Unknown error',
          code: e.code,
          originalException: e,
        ),
        stackTrace,
      );
    }
  }

  /// Send a command and expect a Map result.
  Future<Map<String, dynamic>?> sendForMap(NativeCommand command) async {
    final result = await send<Map<dynamic, dynamic>>(command);
    return result?.cast<String, dynamic>();
  }

  /// Send a command, fire and forget (no result expected).
  void sendFireAndForget(NativeCommand command) {
    _channel.invokeMethod<void>('command', command.toMap());
  }

  // ════════════════════════════════════════════════════════════════════════
  // Events
  // ════════════════════════════════════════════════════════════════════════

  /// Subscribe to events from a specific service.
  void subscribe(String service, NativeEventCallback callback) {
    _eventCallbacks.putIfAbsent(service, () => []).add(callback);
  }

  /// Unsubscribe from events.
  void unsubscribe(String service, NativeEventCallback callback) {
    _eventCallbacks[service]?.remove(callback);
  }

  /// Subscribe to all events (global listener).
  void subscribeAll(NativeEventCallback callback) {
    _globalCallbacks.add(callback);
  }

  /// Unsubscribe from all events.
  void unsubscribeAll(NativeEventCallback callback) {
    _globalCallbacks.remove(callback);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'event') {
      final event = NativeEvent.fromMap(
        Map<String, dynamic>.from(call.arguments as Map),
      );
      _dispatchEvent(event);
    }
    return null;
  }

  void _dispatchEvent(NativeEvent event) {
    // Service-specific callbacks
    final callbacks = _eventCallbacks[event.service];
    if (callbacks != null) {
      for (final callback in callbacks) {
        try {
          callback(event);
        } catch (e, s) {
          debugPrint('[NativeBridge] Error in ${event.service} event handler: $e\n$s');
        }
      }
    }

    // Global callbacks
    for (final callback in _globalCallbacks) {
      try {
        callback(event);
      } catch (e, s) {
        debugPrint('[NativeBridge] Error in global event handler: $e\n$s');
      }
    }
  }

  /// Dispose resources.
  ///
  /// Clears all callbacks and removes the method call handler.
  void dispose() {
    _eventCallbacks.clear();
    _globalCallbacks.clear();
    _channel.setMethodCallHandler(null);
  }
}

/// Exception thrown when a native command fails.
class NativeBridgeException implements Exception {
  final NativeCommand command;
  final String message;
  final String? code;
  final Object? originalException;

  const NativeBridgeException({
    required this.command,
    required this.message,
    this.code,
    this.originalException,
  });

  @override
  String toString() {
    final windowPart =
        command.windowId != null ? ' [${command.windowId}]' : '';
    final codePart = code != null ? ' [$code]' : '';
    return 'NativeBridgeException:$windowPart ${command.service}.${command.command}$codePart failed: $message';
  }
}
