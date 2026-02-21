import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../widgets/size_reporter.dart';
import 'palette.dart';
import 'palette_self.dart';

/// Key event data received from native.
class PaletteKeyEvent {
  final LogicalKeyboardKey key;
  final Set<LogicalKeyboardKey> modifiers;
  final bool isDown;

  PaletteKeyEvent({
    required this.key,
    required this.modifiers,
    required this.isDown,
  });
}

/// Provides access to key events routed to this palette.
///
/// This is a singleton since each palette runs in its own Flutter engine.
/// Use this within palette widgets to receive key events that were
/// captured for this palette by the main app.
class PaletteKeyReceiver {
  static final PaletteKeyReceiver _instance = PaletteKeyReceiver._();
  static PaletteKeyReceiver get instance => _instance;

  PaletteKeyReceiver._();

  final _keyController = StreamController<PaletteKeyEvent>.broadcast();

  /// Stream of key events routed to this palette.
  Stream<PaletteKeyEvent> get keyStream => _keyController.stream;

  /// Stream of keyDown events only.
  Stream<PaletteKeyEvent> get keyDownStream =>
      _keyController.stream.where((e) => e.isDown);

  /// Handle a key event from native.
  void _handleKeyDown(int keyId, List<int> modifierIds) {
    debugPrint('[PaletteKeyReceiver] _handleKeyDown: keyId=0x${keyId.toRadixString(16)}');
    final event = PaletteKeyEvent(
      key: LogicalKeyboardKey(keyId),
      modifiers: modifierIds.map((id) => LogicalKeyboardKey(id)).toSet(),
      isDown: true,
    );
    debugPrint('[PaletteKeyReceiver] Broadcasting event to ${_keyController.hasListener ? "listeners" : "NO LISTENERS"}');
    _keyController.add(event);
  }

  void _handleKeyUp(int keyId) {
    debugPrint('[PaletteKeyReceiver] _handleKeyUp: keyId=0x${keyId.toRadixString(16)}');
    _keyController.add(PaletteKeyEvent(
      key: LogicalKeyboardKey(keyId),
      modifiers: {},
      isDown: false,
    ));
  }

  void dispose() {
    _keyController.close();
  }
}

/// Method channel for palette entry point communication.
const _entryChannel = MethodChannel('floating_palette/entry');

/// Initialize palette engine with generated builders.
///
/// This is called from the generated `paletteMain()` entry point.
/// It gets the palette ID from native and runs the appropriate widget.
///
/// [registerEvents] - Optional callback to register event types for typed
/// event handling in palette widgets via `Palette.on<T>()`. The generator
/// passes `_registerAllEvents` automatically if events are defined.
void initPaletteEngine(
  Map<String, Widget Function()> builders, {
  void Function()? registerEvents,
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register events for typed event handling (Palette.on<T>())
  registerEvents?.call();

  // Set up listener for native commands (forceResize on re-show)
  _setupEntryChannelListener();

  // Initialize focus handling (fixes lifecycle state for all palettes)
  PaletteSelf.initFocusHandling();

  // Get palette ID from native
  final paletteId = await _entryChannel.invokeMethod<String>('getPaletteId');

  if (paletteId == null) {
    runApp(const _ErrorWidget('No palette ID received from native'));
    return;
  }

  // Set the global window ID for SizeReporter
  // Since each palette runs in its own Flutter engine (one window per engine),
  // we use a static window ID instead of passing it to every widget.
  SizeReporter.setWindowId(paletteId);

  // Initialize PaletteContext so Palette.* API works
  PaletteContext.init(paletteId);

  final builder = builders[paletteId];
  if (builder == null) {
    runApp(_ErrorWidget('No builder for palette: $paletteId'));
    return;
  }

  runApp(builder());
}

/// Registry for palette entry points.
///
/// Maps entry point names to widget builders.
/// When native creates a window with `entryPoint: "myPalette"`,
/// the corresponding builder is used to create the widget.
class PaletteRegistry {
  static final _builders = <String, WidgetBuilder>{};
  static Widget Function(Widget child)? _wrapper;

  /// Register a palette builder.
  ///
  /// The [name] should match the entry point name passed to create().
  /// The [builder] creates the widget to display.
  static void register(String name, WidgetBuilder builder) {
    _builders[name] = builder;
  }

  /// Set a global wrapper for all palettes.
  ///
  /// Useful for providing state management (GetIt, Provider, etc.).
  static void setWrapper(Widget Function(Widget child) wrapper) {
    _wrapper = wrapper;
  }

  /// Get the builder for a palette.
  static WidgetBuilder? getBuilder(String name) => _builders[name];

  /// Get the wrapper.
  static Widget Function(Widget child)? get wrapper => _wrapper;

  /// Clear all registrations.
  static void clear() {
    _builders.clear();
    _wrapper = null;
  }
}

/// Run a palette entry point.
///
/// Call this from your entry point function:
///
/// ```dart
/// @pragma('vm:entry-point')
/// void myPaletteMain() => runPalette('myPalette');
/// ```
///
/// Or with a direct builder:
///
/// ```dart
/// @pragma('vm:entry-point')
/// void myPaletteMain() => runPaletteApp('myPalette', MyPaletteWidget());
/// ```
void runPalette(String name) {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up listener for native commands (forceResize on re-show)
  _setupEntryChannelListener();

  // Initialize focus handling (fixes lifecycle state for all palettes)
  PaletteSelf.initFocusHandling();

  // Set the window ID for SizeReporter (same as palette name)
  SizeReporter.setWindowId(name);

  // Initialize PaletteContext so Palette.* API works
  PaletteContext.init(name);

  final builder = PaletteRegistry.getBuilder(name);
  if (builder == null) {
    runApp(_ErrorWidget('No builder registered for palette: $name'));
    return;
  }

  Widget app = Builder(builder: builder);

  final wrapper = PaletteRegistry.wrapper;
  if (wrapper != null) {
    app = wrapper(app);
  }

  runApp(app);
}

/// Run a palette with a direct widget.
///
/// The [windowId] is used for SizeReporter to resize the native window.
/// It should match the ID passed to `PaletteController.create()`.
void runPaletteApp(String windowId, Widget child) {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up listener for native commands (forceResize on re-show)
  _setupEntryChannelListener();

  // Initialize focus handling (fixes lifecycle state for all palettes)
  PaletteSelf.initFocusHandling();

  // Set the window ID for SizeReporter
  SizeReporter.setWindowId(windowId);

  // Initialize PaletteContext so Palette.* API works
  PaletteContext.init(windowId);

  Widget app = child;

  final wrapper = PaletteRegistry.wrapper;
  if (wrapper != null) {
    app = wrapper(app);
  }

  runApp(app);
}

/// Set up the entry channel listener for native commands.
void _setupEntryChannelListener() {
  _entryChannel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'forceResize':
        // Native is telling us to re-report our size (e.g., on re-show)
        SizeReporter.forceNextReport();
        // Trigger a rebuild to run SizeReporter's layout
        WidgetsBinding.instance.scheduleForcedFrame();
        break;

      case 'keyDown':
        // Key event routed from native InputService
        debugPrint('[PaletteRunner] Received keyDown from native');
        final args = call.arguments as Map<Object?, Object?>?;
        debugPrint('[PaletteRunner] args=$args');
        if (args != null) {
          final keyId = args['keyId'] as int?;
          final modifiers = (args['modifiers'] as List?)?.cast<int>() ?? [];
          debugPrint('[PaletteRunner] keyId=0x${keyId?.toRadixString(16)}, modifiers=$modifiers');
          if (keyId != null) {
            PaletteKeyReceiver.instance._handleKeyDown(keyId, modifiers);
          }
        }
        break;

      case 'keyUp':
        debugPrint('[PaletteRunner] Received keyUp from native');
        final args = call.arguments as Map<Object?, Object?>?;
        if (args != null) {
          final keyId = args['keyId'] as int?;
          debugPrint('[PaletteRunner] keyId=0x${keyId?.toRadixString(16)}');
          if (keyId != null) {
            PaletteKeyReceiver.instance._handleKeyUp(keyId);
          }
        }
        break;
    }
    return null;
  });
}

class _ErrorWidget extends StatelessWidget {
  final String message;

  const _ErrorWidget(this.message);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: const Color(0xFFFF0000),
        child: Center(
          child: Text(
            message,
            style: const TextStyle(color: Color(0xFFFFFFFF)),
          ),
        ),
      ),
    );
  }
}
