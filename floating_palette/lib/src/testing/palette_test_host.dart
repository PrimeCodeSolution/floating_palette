import '../bridge/event.dart';
import '../config/config.dart';
import '../controller/palette_controller.dart';
import '../core/capabilities.dart';
import '../core/palette_host.dart';
import 'mock_native_bridge.dart';

/// Test helper for isolated palette testing.
///
/// Provides easy setup and teardown with mock bridge:
///
/// ```dart
/// late PaletteTestHost testHost;
///
/// setUp(() async {
///   testHost = await PaletteTestHost.create();
/// });
///
/// tearDown(() async {
///   await testHost.dispose();
/// });
///
/// test('shows palette', () async {
///   final controller = testHost.createController('test-palette');
///
///   await controller.show();
///
///   expect(testHost.mock.wasCalled('visibility', 'show'), isTrue);
/// });
/// ```
class PaletteTestHost {
  /// The mock bridge for verifying commands and simulating events.
  final MockNativeBridge mock;

  /// The palette host instance.
  final PaletteHost host;

  PaletteTestHost._(this.mock, this.host);

  /// Create a new test host with default stubs.
  ///
  /// Sets up common stubs for:
  /// - Protocol version
  /// - Capabilities
  /// - Empty window snapshot
  static Future<PaletteTestHost> create({
    Capabilities? capabilities,
  }) async {
    // Reset any existing instance
    PaletteHost.reset();

    final mock = MockNativeBridge();
    mock.stubDefaults();

    final host = PaletteHost.forTesting(
      bridge: mock,
      capabilities: capabilities ?? const Capabilities.all(),
    );

    return PaletteTestHost._(mock, host);
  }

  /// Create a palette controller for testing.
  ///
  /// ```dart
  /// final controller = testHost.createController('my-palette');
  /// await controller.show();
  /// ```
  PaletteController<T> createController<T>(
    String id, {
    PaletteConfig? config,
  }) {
    return host.palette<T>(id, config: config);
  }

  /// Get an existing controller.
  PaletteController? getController(String id) => host.getController(id);

  /// Simulate a native event.
  ///
  /// ```dart
  /// testHost.simulateEvent(NativeEvent(
  ///   service: 'visibility',
  ///   event: 'shown',
  ///   windowId: 'my-palette',
  ///   data: {},
  /// ));
  /// ```
  void simulateEvent(NativeEvent event) => mock.simulateEvent(event);

  /// Simulate palette becoming visible.
  void simulateShown(String paletteId) => mock.simulateShown(paletteId);

  /// Simulate palette becoming hidden.
  void simulateHidden(String paletteId) => mock.simulateHidden(paletteId);

  /// Simulate window content ready.
  void simulateContentReady(String paletteId) =>
      mock.simulateContentReady(paletteId);

  /// Verify a command was sent.
  ///
  /// ```dart
  /// testHost.verifyCommand('visibility', 'show', windowId: 'my-palette');
  /// ```
  void verifyCommand(
    String service,
    String command, {
    String? windowId,
  }) {
    if (windowId != null) {
      if (!mock.wasCalledFor(service, command, windowId)) {
        throw TestFailure(
          'Expected command $service.$command for $windowId, '
          'but it was not called.\n'
          'Sent commands: ${mock.sentCommands.map((c) => '${c.service}.${c.command}(${c.windowId})').join(', ')}',
        );
      }
    } else {
      if (!mock.wasCalled(service, command)) {
        throw TestFailure(
          'Expected command $service.$command, but it was not called.\n'
          'Sent commands: ${mock.sentCommands.map((c) => '${c.service}.${c.command}').join(', ')}',
        );
      }
    }
  }

  /// Verify a command was NOT sent.
  void verifyNoCommand(String service, String command) {
    if (mock.wasCalled(service, command)) {
      throw TestFailure(
        'Expected command $service.$command NOT to be called, but it was.',
      );
    }
  }

  /// Clear all recorded commands (but keep stubs).
  void clearCommands() => mock.sentCommands.clear();

  /// Reset mock completely (commands and stubs).
  void resetMock() => mock.reset();

  /// Dispose the test host.
  ///
  /// Always call this in tearDown to clean up.
  Future<void> dispose() async {
    await host.dispose();
    PaletteHost.reset();
  }
}

/// Exception thrown when test verification fails.
class TestFailure implements Exception {
  final String message;
  TestFailure(this.message);

  @override
  String toString() => 'TestFailure: $message';
}
