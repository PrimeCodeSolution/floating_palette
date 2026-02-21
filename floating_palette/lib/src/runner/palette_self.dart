import 'dart:io' show Platform;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../positioning/screen_rect.dart';

/// Query methods for a palette to get information about itself.
///
/// Since each palette runs in its own Flutter engine, it needs a way to
/// query its own window properties (bounds, position, etc.) for coordinate
/// conversion.
///
/// Platform differences are handled automatically - the same code works
/// on both macOS and Windows.
///
/// ## Usage
///
/// ```dart
/// class _EditorPaletteState extends State<EditorPalette> {
///   Future<void> _reportCaretPosition(Offset localCaret) async {
///     // Convert local caret position to screen coordinates
///     // Platform coordinate system is handled automatically
///     final screenCaret = await PaletteSelf.localToScreen(localCaret);
///
///     // Send to host
///     PaletteMessenger.send('caret-position', {
///       'x': screenCaret.dx,
///       'y': screenCaret.dy,
///     });
///   }
/// }
/// ```
class PaletteSelf {
  static const _channel = MethodChannel('floating_palette/self');

  /// Callbacks for focus events.
  static final List<void Function()> _focusGainedCallbacks = [];
  static final List<void Function()> _focusLostCallbacks = [];
  static bool _handlerRegistered = false;

  /// Initialize focus handling for this palette.
  /// Called automatically during palette engine initialization.
  /// This ensures lifecycle state is properly managed for all palettes.
  static void initFocusHandling() {
    _ensureHandlerRegistered();
    _installLifecycleOverride();
  }

  /// Register a callback for when this palette gains focus.
  static void onFocusGained(void Function() callback) {
    _ensureHandlerRegistered();
    _focusGainedCallbacks.add(callback);
  }

  /// Register a callback for when this palette loses focus.
  static void onFocusLost(void Function() callback) {
    _ensureHandlerRegistered();
    _focusLostCallbacks.add(callback);
  }

  /// Remove a focus gained callback.
  static void removeFocusGainedCallback(void Function() callback) {
    _focusGainedCallbacks.remove(callback);
  }

  /// Remove a focus lost callback.
  static void removeFocusLostCallback(void Function() callback) {
    _focusLostCallbacks.remove(callback);
  }

  static void _ensureHandlerRegistered() {
    if (_handlerRegistered) return;
    _handlerRegistered = true;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onFocusGained':
          for (final callback in List.from(_focusGainedCallbacks)) {
            callback();
          }
        case 'onFocusLost':
          for (final callback in List.from(_focusLostCallbacks)) {
            callback();
          }
      }
      return null;
    });
  }

  static bool _lifecycleOverrideInstalled = false;

  /// Replace the default `flutter/lifecycle` handler to prevent the engine
  /// from freezing palette rendering when the app loses focus.
  ///
  /// Flutter's macOS embedder sends `hidden`/`paused` on the
  /// `flutter/lifecycle` channel when the app deactivates, which causes
  /// `SchedulerBinding` to disable frame scheduling. Since palettes are
  /// independent floating panels, they must keep rendering regardless.
  ///
  /// This intercepts the channel and swallows `hidden`/`paused` states,
  /// only forwarding `resumed`/`inactive` (both keep frames enabled).
  static void _installLifecycleOverride() {
    if (_lifecycleOverrideInstalled) return;
    _lifecycleOverrideInstalled = true;

    ServicesBinding.instance.defaultBinaryMessenger
        .setMessageHandler('flutter/lifecycle', (data) async {
      if (data == null) return null;

      final stateStr = const StringCodec().decodeMessage(data);
      if (stateStr == null) return null;

      // Parse "AppLifecycleState.hidden" → AppLifecycleState.hidden
      final state = AppLifecycleState.values.firstWhere(
        (s) => s.toString() == stateStr,
        orElse: () => AppLifecycleState.resumed,
      );

      switch (state) {
        case AppLifecycleState.hidden:
        case AppLifecycleState.paused:
        case AppLifecycleState.detached:
          // Swallow — don't let the engine disable frame scheduling
          return null;
        case AppLifecycleState.resumed:
        case AppLifecycleState.inactive:
          // Forward — both keep frames enabled
          SchedulerBinding.instance.handleAppLifecycleStateChanged(state); // ignore: invalid_use_of_protected_member
          return null;
      }
    });
  }

  /// Whether we're on macOS (affects coordinate calculations).
  static bool get isMacOS => Platform.isMacOS;

  /// Get this palette's window bounds in screen coordinates.
  ///
  /// Returns the window's position and size in native screen coordinates.
  /// On macOS, Y=0 is at the bottom of the screen.
  static Future<Rect> get bounds async {
    final result = await _channel.invokeMapMethod<String, dynamic>('getBounds');
    if (result == null) return Rect.zero;
    return Rect.fromLTWH(
      (result['x'] as num).toDouble(),
      (result['y'] as num).toDouble(),
      (result['width'] as num).toDouble(),
      (result['height'] as num).toDouble(),
    );
  }

  /// Get this palette's window bounds as a [ScreenRect].
  ///
  /// Convenience method that wraps [bounds] in a [ScreenRect] for
  /// anchor point access and coordinate conversion.
  static Future<ScreenRect> get screenRect async {
    final b = await bounds;
    return ScreenRect.fromBounds(b);
  }

  /// Get this palette's window position.
  static Future<Offset> get position async {
    final result =
        await _channel.invokeMapMethod<String, dynamic>('getPosition');
    if (result == null) return Offset.zero;
    return Offset(
      (result['x'] as num).toDouble(),
      (result['y'] as num).toDouble(),
    );
  }

  /// Get this palette's window size.
  static Future<Size> get size async {
    final result = await _channel.invokeMapMethod<String, dynamic>('getSize');
    if (result == null) return Size.zero;
    return Size(
      (result['width'] as num).toDouble(),
      (result['height'] as num).toDouble(),
    );
  }

  /// Get a specific anchor point's screen position for this palette.
  ///
  /// ```dart
  /// final myBottomLeft = await PaletteSelf.getAnchorPoint(Anchor.bottomLeft);
  /// ```
  static Future<Offset> getAnchorPoint(dynamic anchor) async {
    final rect = await screenRect;
    // Import Anchor from config to avoid circular dependency
    // For now, accept the anchor enum value directly
    return rect.anchorPoint(anchor);
  }

  /// Convert a local position within this palette to screen coordinates.
  ///
  /// [localPosition] - Position relative to top-left of the palette window.
  ///                   (0, 0) is top-left, positive Y is down.
  ///
  /// Returns screen coordinates in the native coordinate system.
  static Future<Offset> localToScreen(Offset localPosition) async {
    final rect = await screenRect;
    return rect.localToScreen(localPosition);
  }

  /// Get this palette's size configuration.
  ///
  /// Returns the size constraints (minHeight, maxHeight, width, etc.)
  /// that were set when the palette was configured.
  static Future<PaletteSizeConfig> get sizeConfig async {
    final result = await _channel.invokeMapMethod<String, dynamic>('getSizeConfig');
    if (result == null) return const PaletteSizeConfig();
    return PaletteSizeConfig(
      width: (result['width'] as num?)?.toDouble() ?? 400,
      minHeight: (result['minHeight'] as num?)?.toDouble() ?? 100,
      maxHeight: (result['maxHeight'] as num?)?.toDouble() ?? 600,
      minWidth: (result['minWidth'] as num?)?.toDouble() ?? 200,
      resizable: result['resizable'] as bool? ?? false,
    );
  }
}

/// Size configuration for a palette, queryable at runtime.
class PaletteSizeConfig {
  final double width;
  final double minWidth;
  final double minHeight;
  final double maxHeight;
  final bool resizable;

  const PaletteSizeConfig({
    this.width = 400,
    this.minWidth = 200,
    this.minHeight = 100,
    this.maxHeight = 600,
    this.resizable = false,
  });
}
