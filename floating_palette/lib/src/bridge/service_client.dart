import 'dart:async';

import 'command.dart';
import 'event.dart';
import 'native_bridge.dart';

/// Base class for service clients.
///
/// Each service client wraps a specific native service,
/// providing a typed Dart API for its commands and events.
abstract class ServiceClient {
  /// The native bridge.
  final NativeBridge _bridge;

  /// Create a service client with the given bridge.
  ServiceClient(this._bridge);

  /// Protected access to bridge for subclasses that need direct bridge access.
  NativeBridge get bridge => _bridge;

  /// The service name (must match native side).
  String get serviceName;

  /// Event subscriptions for cleanup.
  final _subscriptions = <NativeEventCallback>[];

  /// Send a command to this service.
  Future<T?> send<T>(String command, {String? windowId, Map<String, dynamic>? params}) {
    return _bridge.send<T>(NativeCommand(
      service: serviceName,
      command: command,
      windowId: windowId,
      params: params ?? const {},
    ));
  }

  /// Send a command expecting a Map result.
  Future<Map<String, dynamic>?> sendForMap(
    String command, {
    String? windowId,
    Map<String, dynamic>? params,
  }) {
    return _bridge.sendForMap(NativeCommand(
      service: serviceName,
      command: command,
      windowId: windowId,
      params: params ?? const {},
    ));
  }

  /// Send a command, fire and forget.
  void sendFireAndForget(String command, {String? windowId, Map<String, dynamic>? params}) {
    _bridge.sendFireAndForget(NativeCommand(
      service: serviceName,
      command: command,
      windowId: windowId,
      params: params ?? const {},
    ));
  }

  /// Subscribe to events from this service.
  void onEvent(String eventName, void Function(NativeEvent) callback) {
    void handler(NativeEvent event) {
      if (event.event == eventName) {
        callback(event);
      }
    }

    _subscriptions.add(handler);
    _bridge.subscribe(serviceName, handler);
  }

  /// Subscribe to events for a specific window.
  void onWindowEvent(
    String windowId,
    String eventName,
    void Function(NativeEvent) callback,
  ) {
    void handler(NativeEvent event) {
      if (event.event == eventName && event.windowId == windowId) {
        callback(event);
      }
    }

    _subscriptions.add(handler);
    _bridge.subscribe(serviceName, handler);
  }

  /// Clean up all subscriptions.
  void dispose() {
    for (final sub in _subscriptions) {
      _bridge.unsubscribe(serviceName, sub);
    }
    _subscriptions.clear();
  }
}
