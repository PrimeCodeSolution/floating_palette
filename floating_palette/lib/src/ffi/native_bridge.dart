import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'ffi_bindings.g.dart';

/// High-level Dart API for synchronous FFI calls.
///
/// Wraps the generated [FFIBindings] with a more ergonomic interface,
/// handling pointer allocation/deallocation automatically.
///
/// This is different from [NativeBridge] in the bridge module which uses
/// async MethodChannel. This class provides synchronous calls for
/// time-critical operations like window resizing during layout.
///
/// Usage:
/// ```dart
/// final bridge = SyncNativeBridge.instance;
///
/// // Get cursor position synchronously
/// final cursor = bridge.getCursorPosition();
/// print('Cursor at: ${cursor.x}, ${cursor.y}');
///
/// // Resize window synchronously (for SizeReporter)
/// bridge.resizeWindow('my-palette', 400, 300);
/// ```
class SyncNativeBridge {
  static SyncNativeBridge? _instance;

  /// Singleton instance of the native bridge.
  static SyncNativeBridge get instance {
    _instance ??= SyncNativeBridge._();
    return _instance!;
  }

  late final FFIBindings _bindings;
  bool _initialized = false;

  SyncNativeBridge._() {
    _initialize();
  }

  void _initialize() {
    if (_initialized) return;

    // Unsupported platform - leave _initialized = false
    if (!Platform.isMacOS && !Platform.isWindows) {
      return;
    }

    try {
      final DynamicLibrary lib;
      if (Platform.isMacOS) {
        // On macOS, symbols are in the process itself (Flutter plugin)
        lib = DynamicLibrary.process();
      } else {
        // On Windows, load the DLL
        lib = DynamicLibrary.open('floating_palette_plugin.dll');
      }

      _bindings = FFIBindings(lib);
      _initialized = true;
    } catch (e) {
      // FFI not available (e.g., running in test environment)
      _initialized = false;
      rethrow;
    }
  }

  /// Whether the native bridge is available.
  bool get isAvailable => _initialized;

  // ═══════════════════════════════════════════════════════════════════════════
  // WINDOW SIZING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Resize a palette window synchronously.
  ///
  /// This is the critical FFI call used by [SizeReporter] to resize
  /// the native window in the same frame as content measurement,
  /// avoiding flicker.
  void resizeWindow(String windowId, double width, double height) {
    final idPtr = windowId.toNativeUtf8().cast<Char>();
    try {
      _bindings.ResizeWindow(idPtr, width, height);
    } finally {
      calloc.free(idPtr);
    }
  }

  /// Get the current frame of a palette window.
  ///
  /// Returns null if the window doesn't exist.
  NativeRect? getWindowFrame(String windowId) {
    final idPtr = windowId.toNativeUtf8().cast<Char>();
    final x = calloc<Double>();
    final y = calloc<Double>();
    final w = calloc<Double>();
    final h = calloc<Double>();

    try {
      final exists = _bindings.GetWindowFrame(idPtr, x, y, w, h);
      if (!exists) return null;
      return NativeRect(x.value, y.value, w.value, h.value);
    } finally {
      calloc.free(idPtr);
      calloc.free(x);
      calloc.free(y);
      calloc.free(w);
      calloc.free(h);
    }
  }

  /// Check if a palette window is currently visible.
  ///
  /// Returns false if the window doesn't exist or isn't visible.
  bool isWindowVisible(String windowId) {
    final idPtr = windowId.toNativeUtf8().cast<Char>();
    try {
      return _bindings.IsWindowVisible(idPtr);
    } finally {
      calloc.free(idPtr);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CURSOR POSITION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get the current cursor position in screen coordinates.
  ///
  /// Used for `.nearCursor()` positioning to get exact position
  /// at the moment of showing a palette.
  Point getCursorPosition() {
    final x = calloc<Double>();
    final y = calloc<Double>();

    try {
      _bindings.GetCursorPosition(x, y);
      return Point(x.value, y.value);
    } finally {
      calloc.free(x);
      calloc.free(y);
    }
  }

  /// Get the screen index where the cursor is located.
  ///
  /// Returns -1 if unable to determine.
  int getCursorScreen() {
    return _bindings.GetCursorScreen();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SCREEN INFO
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get the number of connected screens.
  int getScreenCount() {
    return _bindings.GetScreenCount();
  }

  /// Get the full bounds of a screen (including menu bar, dock).
  ///
  /// Returns null if screen index is invalid.
  NativeRect? getScreenBounds(int screenIndex) {
    final x = calloc<Double>();
    final y = calloc<Double>();
    final w = calloc<Double>();
    final h = calloc<Double>();

    try {
      final exists = _bindings.GetScreenBounds(screenIndex, x, y, w, h);
      if (!exists) return null;
      return NativeRect(x.value, y.value, w.value, h.value);
    } finally {
      calloc.free(x);
      calloc.free(y);
      calloc.free(w);
      calloc.free(h);
    }
  }

  /// Get the visible bounds of a screen (excluding menu bar, dock, taskbar).
  ///
  /// Use this for constraining palette positions.
  /// Returns null if screen index is invalid.
  NativeRect? getScreenVisibleBounds(int screenIndex) {
    final x = calloc<Double>();
    final y = calloc<Double>();
    final w = calloc<Double>();
    final h = calloc<Double>();

    try {
      final exists = _bindings.GetScreenVisibleBounds(screenIndex, x, y, w, h);
      if (!exists) return null;
      return NativeRect(x.value, y.value, w.value, h.value);
    } finally {
      calloc.free(x);
      calloc.free(y);
      calloc.free(w);
      calloc.free(h);
    }
  }

  /// Get the scale factor of a screen.
  ///
  /// Returns 1.0 for standard displays, 2.0 for Retina/HiDPI.
  double getScreenScaleFactor(int screenIndex) {
    return _bindings.GetScreenScaleFactor(screenIndex);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACTIVE APPLICATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get the bounds of the frontmost application window.
  ///
  /// Useful for positioning palettes relative to the host app.
  /// Returns null if no active window found.
  NativeRect? getActiveAppBounds() {
    final x = calloc<Double>();
    final y = calloc<Double>();
    final w = calloc<Double>();
    final h = calloc<Double>();

    try {
      final found = _bindings.GetActiveAppBounds(x, y, w, h);
      if (!found) return null;
      return NativeRect(x.value, y.value, w.value, h.value);
    } finally {
      calloc.free(x);
      calloc.free(y);
      calloc.free(w);
      calloc.free(h);
    }
  }

  /// Get the bundle identifier of the active application.
  ///
  /// On macOS: returns bundle ID like "com.apple.Safari"
  /// On Windows: returns process name like "notepad.exe"
  /// Returns null if not found.
  String? getActiveAppIdentifier() {
    const bufferSize = 256;
    final buffer = calloc<Char>(bufferSize);

    try {
      final length = _bindings.GetActiveAppIdentifier(buffer, bufferSize);
      if (length == 0) return null;
      return buffer.cast<Utf8>().toDartString(length: length);
    } finally {
      calloc.free(buffer);
    }
  }
}

/// A simple point with x and y coordinates.
class Point {
  final double x;
  final double y;

  const Point(this.x, this.y);

  @override
  String toString() => 'Point($x, $y)';
}

/// A simple rectangle with position and size for FFI operations.
///
/// Named `NativeRect` to avoid conflicts with `dart:ui`'s `Rect`.
class NativeRect {
  final double x;
  final double y;
  final double width;
  final double height;

  const NativeRect(this.x, this.y, this.width, this.height);

  double get left => x;
  double get top => y;
  double get right => x + width;
  double get bottom => y + height;

  @override
  String toString() => 'NativeRect($x, $y, $width, $height)';
}
