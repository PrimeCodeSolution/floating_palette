import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show MissingPluginException;

import '../bridge/command.dart';
import '../bridge/native_bridge.dart';
import '../config/config.dart';
import '../controller/palette_controller.dart';
import '../input/input_manager.dart';
import '../services/focus_client.dart';
import '../services/screen_client.dart';
import '../services/snap_client.dart';
import 'capabilities.dart';
import 'palette_registry.dart';
import 'protocol.dart';

/// Central dependency injection container for floating palettes.
///
/// PaletteHost is the single point of initialization that creates and owns
/// all the shared infrastructure: NativeBridge, InputManager, etc.
///
/// Usage:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await PaletteHost.initialize();
///   runApp(MyApp());
/// }
/// ```
class PaletteHost {
  static PaletteHost? _instance;

  /// Get the initialized instance.
  ///
  /// Throws if [initialize] hasn't been called.
  static PaletteHost get instance => _instance ??
      (throw StateError(
          'PaletteHost not initialized. Call PaletteHost.initialize() first.'));

  /// Check if the host has been initialized.
  static bool get isInitialized => _instance != null;

  /// The native bridge for communicating with the platform.
  final NativeBridge bridge;

  /// The input manager for handling keyboard/pointer input.
  final InputManager inputManager;

  /// The registry for palette widget builders.
  final PaletteRegistry registry;

  /// Platform capabilities.
  final Capabilities capabilities;

  /// Controllers created by this host.
  final Map<String, PaletteController> _controllers = {};

  PaletteHost._({
    required this.bridge,
    required this.inputManager,
    required this.registry,
    required this.capabilities,
  });

  /// Initialize the palette host.
  ///
  /// This should be called once at app startup, before using any palettes.
  /// Creates the NativeBridge, InputManager, and fetches capabilities.
  ///
  /// Throws [ProtocolMismatchError] if the native plugin version is incompatible.
  static Future<PaletteHost> initialize() async {
    if (_instance != null) return _instance!;

    final bridge = NativeBridge();

    // Verify protocol compatibility
    try {
      await Protocol.handshake(bridge);
    } on ProtocolMismatchError {
      bridge.dispose();
      rethrow;
    } on MissingPluginException {
      // Legacy native plugin without handshake support - continue
      debugPrint('[PaletteHost] Protocol handshake not supported (legacy native), continuing');
    }

    final inputManager = InputManager(bridge);
    final registry = PaletteRegistry();
    final capabilities = await Capabilities.fetch(bridge);

    _instance = PaletteHost._(
      bridge: bridge,
      inputManager: inputManager,
      registry: registry,
      capabilities: capabilities,
    );

    return _instance!;
  }

  /// Create a PaletteHost for testing with custom dependencies.
  ///
  /// **Important:** You must provide a mock bridge to avoid hitting native code.
  /// Use [MockNativeBridge] from the testing package.
  ///
  /// ```dart
  /// import 'package:floating_palette/src/testing/testing.dart';
  ///
  /// final mock = MockNativeBridge()..stubDefaults();
  /// final host = PaletteHost.forTesting(bridge: mock);
  /// ```
  ///
  /// Throws [ArgumentError] if no bridge is provided, to prevent accidentally
  /// using real native code in tests.
  static PaletteHost forTesting({
    required NativeBridge bridge,
    InputManager? inputManager,
    PaletteRegistry? registry,
    Capabilities? capabilities,
  }) {
    final testInputManager = inputManager ?? InputManager(bridge);

    _instance = PaletteHost._(
      bridge: bridge,
      inputManager: testInputManager,
      registry: registry ?? PaletteRegistry(),
      capabilities: capabilities ?? const Capabilities.all(),
    );

    return _instance!;
  }

  /// Reset the singleton instance (for testing).
  static void reset() {
    _instance?.dispose();
    _instance = null;
  }

  /// Get or create a palette controller.
  ///
  /// Controllers are cached by ID. Subsequent calls with the same ID
  /// return the existing controller.
  PaletteController<T> palette<T>(String id, {PaletteConfig? config}) {
    return _controllers.putIfAbsent(
      id,
      () => PaletteController<T>(
        id: id,
        host: this,
        config: config,
      ),
    ) as PaletteController<T>;
  }

  /// Get an existing controller by ID.
  PaletteController? getController(String id) => _controllers[id];

  /// Get all registered controllers.
  Iterable<PaletteController> get controllers => _controllers.values;

  // ════════════════════════════════════════════════════════════════════════════
  // Hot Restart Recovery
  // ════════════════════════════════════════════════════════════════════════════

  /// Recover state after a hot restart.
  ///
  /// Native windows survive hot restart but Dart state resets. This method:
  /// 1. Fetches snapshot of all existing native windows
  /// 2. Syncs registered controllers with their native window state
  /// 3. Destroys orphan windows (native windows without Dart controllers)
  ///
  /// **Important:** Call this AFTER registering controllers with [palette].
  /// The generated `Palettes.init()` handles this automatically.
  ///
  /// ```dart
  /// // Manual usage (if not using code generation):
  /// await PaletteHost.initialize();
  /// host.palette('menu', config: menuConfig);  // Register first
  /// host.palette('tooltip', config: tooltipConfig);
  /// await host.recover();  // Then recover
  /// ```
  Future<void> recover() async {
    try {
      final snapshot = await bridge.send<List<dynamic>>(const NativeCommand(
        service: 'host',
        command: 'getSnapshot',
      ));

      if (snapshot == null || snapshot.isEmpty) return;

      for (final entry in snapshot) {
        final data = entry as Map<dynamic, dynamic>;
        final id = data['id'] as String;
        final visible = data['visible'] as bool? ?? false;
        final focused = data['focused'] as bool? ?? false;
        final bounds = Rect.fromLTWH(
          (data['x'] as num?)?.toDouble() ?? 0,
          (data['y'] as num?)?.toDouble() ?? 0,
          (data['width'] as num?)?.toDouble() ?? 0,
          (data['height'] as num?)?.toDouble() ?? 0,
        );

        final controller = _controllers[id];
        if (controller != null) {
          // Sync Dart state with native window
          controller.syncFromNative(
            visible: visible,
            bounds: bounds,
            focused: focused,
          );
          debugPrint('[PaletteHost] Recovered palette: $id (visible: $visible)');
        } else {
          // Orphan window - destroy it
          debugPrint('[PaletteHost] Destroying orphan window: $id');
          await bridge.send(NativeCommand(
            service: 'window',
            command: 'destroy',
            windowId: id,
          ));
        }
      }
    } catch (e) {
      debugPrint('[PaletteHost] Recovery failed: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Convenience Methods (wraps service clients for simple API)
  // ════════════════════════════════════════════════════════════════════════════

  FocusClient? _focusClient;
  ScreenClient? _screenClient;
  SnapClient? _snapClient;

  /// Get the snap client for palette-to-palette snapping.
  SnapClient get snapClient => _snapClient ??= SnapClient(bridge);

  /// Activate the main app window (return keyboard focus to main app).
  ///
  /// Call this after showing a palette that doesn't need keyboard input
  /// to ensure hotkeys in the main app continue to work.
  Future<void> focusMainWindow() {
    _focusClient ??= FocusClient(bridge);
    return _focusClient!.focusMainWindow();
  }

  /// Get bounds of the currently active (frontmost) application window.
  ///
  /// Useful for positioning palettes relative to the user's active app,
  /// similar to how macOS Spotlight appears near the active window.
  Future<ActiveAppInfo?> getActiveAppBounds() {
    _screenClient ??= ScreenClient(bridge);
    return _screenClient!.getActiveAppBounds();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Disposal
  // ════════════════════════════════════════════════════════════════════════════

  /// Dispose all resources and clear the singleton instance.
  ///
  /// After calling dispose, [isInitialized] returns false and you must call
  /// [initialize] again before using palettes.
  Future<void> dispose() async {
    // Dispose all controllers
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();

    // Dispose input manager
    inputManager.dispose();

    // Dispose bridge
    bridge.dispose();

    // Clear singleton to prevent accessing disposed instance
    _instance = null;
  }
}
