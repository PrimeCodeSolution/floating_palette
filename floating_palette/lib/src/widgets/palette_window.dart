import 'package:flutter/services.dart';

import 'size_reporter.dart';

/// Utility for palettes to control their own window.
///
/// Since each palette runs in its own Flutter engine, this provides
/// access to window operations like dragging, resizing, and hiding.
///
/// Usage:
/// ```dart
/// GestureDetector(
///   onPanStart: (_) => PaletteWindow.startDrag(),
///   child: MyHeader(),
/// )
/// ```
class PaletteWindow {
  // Use the 'self' channel which is set up on each palette engine
  static const _channel = MethodChannel('floating_palette/self');

  PaletteWindow._();

  /// Get the current palette/window ID for this engine.
  ///
  /// Returns null if the window ID hasn't been set yet.
  /// The ID is set by the palette runner during initialization.
  static String? get currentId => SizeReporter.windowId;

  /// Start native window dragging.
  ///
  /// Call this on pan/drag start (e.g., from a header drag handle)
  /// to initiate native window dragging.
  static Future<void> startDrag() async {
    await _channel.invokeMethod('startDrag');
  }

  /// Set the window size.
  ///
  /// Use this to dynamically resize the palette window (e.g., when
  /// showing/hiding results in a search palette).
  static Future<void> setSize(double width, double height) async {
    await _channel.invokeMethod('setSize', {
      'width': width,
      'height': height,
    });
  }

  /// Hide this palette window.
  ///
  /// Use this when the user completes an action (e.g., selecting
  /// a search result) and the palette should close.
  static Future<void> hide() async {
    await _channel.invokeMethod('hide');
  }

  /// Get the icon for a macOS application.
  ///
  /// Returns PNG bytes of the app icon, or null if not available.
  /// [appPath] should be the full path to the .app bundle.
  static Future<Uint8List?> getAppIcon(String appPath) async {
    final result = await _channel.invokeMethod<Uint8List>('getAppIcon', {
      'path': appPath,
    });
    return result;
  }
}
