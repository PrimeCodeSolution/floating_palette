import 'dart:async';

import 'package:flutter/foundation.dart' show VoidCallback;

import '../bridge/command.dart';
import '../bridge/event.dart';
import '../bridge/native_bridge.dart';

/// A mock NativeBridge for testing.
///
/// Records all sent commands and allows stubbing responses.
///
/// Example:
/// ```dart
/// final mock = MockNativeBridge();
/// mock.stubResponse('window', 'create', 'window-123');
///
/// final host = PaletteHost.forTesting(bridge: mock);
///
/// // After some operations...
/// expect(mock.sentCommands, hasLength(1));
/// expect(mock.sentCommands.first.command, equals('create'));
/// ```
class MockNativeBridge implements NativeBridge {
  @override
  final Duration commandTimeout = const Duration(seconds: 5);

  /// All commands that have been sent.
  final List<NativeCommand> sentCommands = [];

  /// Stubbed responses keyed by 'service.command'.
  final Map<String, dynamic> stubbedResponses = {};

  /// Event callbacks by service name (for simulating events).
  final _eventCallbacks = <String, List<NativeEventCallback>>{};

  /// Global event callbacks.
  final _globalCallbacks = <NativeEventCallback>[];

  /// Stub a response for a service/command combination.
  ///
  /// ```dart
  /// mock.stubResponse('window', 'create', 'window-123');
  /// mock.stubResponse('visibility', 'isVisible', true);
  /// ```
  void stubResponse(String service, String command, dynamic response) {
    stubbedResponses['$service.$command'] = response;
  }

  /// Simulate an event from native.
  ///
  /// ```dart
  /// mock.simulateEvent(NativeEvent(
  ///   service: 'visibility',
  ///   event: 'shown',
  ///   windowId: 'my-palette',
  ///   data: {},
  /// ));
  /// ```
  void simulateEvent(NativeEvent event) {
    // Service-specific callbacks
    final callbacks = _eventCallbacks[event.service];
    if (callbacks != null) {
      for (final callback in callbacks) {
        callback(event);
      }
    }

    // Global callbacks
    for (final callback in _globalCallbacks) {
      callback(event);
    }
  }

  /// Clear all recorded commands and stubbed responses.
  void reset() {
    sentCommands.clear();
    stubbedResponses.clear();
    _commandListeners.clear();
    _windowCreateHandler = null;
  }

  /// Find commands by service and command name.
  List<NativeCommand> findCommands(String service, String command) {
    return sentCommands
        .where((c) => c.service == service && c.command == command)
        .toList();
  }

  /// Check if a command was sent.
  bool wasCalled(String service, String command) {
    return sentCommands.any((c) => c.service == service && c.command == command);
  }

  /// Check if a command was sent with specific window ID.
  bool wasCalledFor(String service, String command, String windowId) {
    return sentCommands.any(
      (c) => c.service == service && c.command == command && c.windowId == windowId,
    );
  }

  /// Get the last command sent to a service.
  NativeCommand? lastCommand(String service) {
    for (var i = sentCommands.length - 1; i >= 0; i--) {
      if (sentCommands[i].service == service) {
        return sentCommands[i];
      }
    }
    return null;
  }

  /// Get count of commands sent to a service/command.
  int callCount(String service, String command) {
    return sentCommands
        .where((c) => c.service == service && c.command == command)
        .length;
  }

  /// Simulate an event after a delay (for async testing).
  Future<void> simulateEventDelayed(
    NativeEvent event, {
    Duration delay = const Duration(milliseconds: 10),
  }) async {
    await Future.delayed(delay);
    simulateEvent(event);
  }

  /// Simulate a visibility change event.
  void simulateShown(String windowId) {
    simulateEvent(NativeEvent(
      service: 'visibility',
      event: 'shown',
      windowId: windowId,
      data: const {},
    ));
  }

  /// Simulate a visibility change event.
  void simulateHidden(String windowId) {
    simulateEvent(NativeEvent(
      service: 'visibility',
      event: 'hidden',
      windowId: windowId,
      data: const {},
    ));
  }

  /// Simulate window content ready event.
  void simulateContentReady(String windowId) {
    simulateEvent(NativeEvent(
      service: 'window',
      event: 'contentReady',
      windowId: windowId,
      data: const {},
    ));
  }

  /// Set up default stubs for common commands.
  ///
  /// Call this to have sensible defaults for:
  /// - host.getCapabilities
  /// - host.getProtocolVersion
  /// - host.getSnapshot
  /// - window.create
  /// - window.exists
  void stubDefaults() {
    // Protocol
    stubResponse('host', 'getProtocolVersion', {
      'version': 1,
      'minDartVersion': 1,
      'maxDartVersion': 1,
    });

    // Capabilities
    stubResponse('host', 'getCapabilities', {
      'blur': true,
      'transform': true,
      'globalHotkeys': true,
      'glassEffect': true,
      'multiMonitor': true,
      'contentSizing': true,
      'textSelection': true,
      'platform': 'test',
      'osVersion': 'test',
    });

    // Empty snapshot (no existing windows)
    stubResponse('host', 'getSnapshot', <Map<String, dynamic>>[]);

    // Window creation returns the window ID
    _windowCreateHandler = (command) => command.windowId ?? command.params['id'];
  }

  // Custom handler for window.create that returns the window ID
  dynamic Function(NativeCommand)? _windowCreateHandler;

  /// Register a callback to be notified when any command is sent.
  ///
  /// Useful for debugging or complex test scenarios.
  VoidCallback onCommand(void Function(NativeCommand) callback) {
    _commandListeners.add(callback);
    return () => _commandListeners.remove(callback);
  }

  final _commandListeners = <void Function(NativeCommand)>[];

  // ════════════════════════════════════════════════════════════════════════════
  // NativeBridge Implementation
  // ════════════════════════════════════════════════════════════════════════════

  @override
  Future<T?> send<T>(NativeCommand command) async {
    sentCommands.add(command);
    for (final listener in _commandListeners) {
      listener(command);
    }

    // Special handling for window.create
    if (command.service == 'window' && command.command == 'create' && _windowCreateHandler != null) {
      return _windowCreateHandler!(command) as T?;
    }

    final key = '${command.service}.${command.command}';
    return stubbedResponses[key] as T?;
  }

  @override
  Future<Map<String, dynamic>?> sendForMap(NativeCommand command) async {
    sentCommands.add(command);
    final key = '${command.service}.${command.command}';
    final response = stubbedResponses[key];
    if (response is Map) {
      return response.cast<String, dynamic>();
    }
    return null;
  }

  @override
  void sendFireAndForget(NativeCommand command) {
    sentCommands.add(command);
  }

  @override
  void subscribe(String service, NativeEventCallback callback) {
    _eventCallbacks.putIfAbsent(service, () => []).add(callback);
  }

  @override
  void unsubscribe(String service, NativeEventCallback callback) {
    _eventCallbacks[service]?.remove(callback);
  }

  @override
  void subscribeAll(NativeEventCallback callback) {
    _globalCallbacks.add(callback);
  }

  @override
  void unsubscribeAll(NativeEventCallback callback) {
    _globalCallbacks.remove(callback);
  }

  @override
  void dispose() {
    _eventCallbacks.clear();
    _globalCallbacks.clear();
  }
}
