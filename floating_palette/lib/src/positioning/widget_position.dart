import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';

import 'screen_rect.dart';
import '../config/palette_position.dart';

/// Utility for finding widget positions in screen coordinates.
///
/// Since palettes run in separate Flutter engines, each palette has its own
/// coordinate system. This class helps convert local widget positions to
/// screen coordinates that can be used for positioning other palettes.
///
/// Platform differences (macOS vs Windows coordinate systems) are handled
/// automatically.
///
/// ## Usage in a Palette
///
/// ```dart
/// class EditorPalette extends StatefulWidget {
///   @override
///   State<EditorPalette> createState() => _EditorPaletteState();
/// }
///
/// class _EditorPaletteState extends State<EditorPalette> {
///   final _textFieldKey = GlobalKey();
///   final _positionHelper = WidgetPosition();
///
///   void _onSlashTyped() async {
///     // Set window bounds first
///     _positionHelper.windowBounds = await PaletteSelf.screenRect;
///
///     // Get text field's screen position
///     final textFieldRect = _positionHelper.getWidgetRect(_textFieldKey);
///     if (textFieldRect != null) {
///       // Send position to host for slash menu placement
///       PaletteMessenger.send('show-slash-menu', {
///         'x': textFieldRect.bottomLeft.dx,
///         'y': textFieldRect.bottomLeft.dy,
///       });
///     }
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return TextField(key: _textFieldKey, ...);
///   }
/// }
/// ```
class WidgetPosition {
  /// The palette's window bounds in screen coordinates.
  ///
  /// This must be set before converting local positions to screen coordinates.
  /// Typically set by querying the palette's own window bounds.
  ScreenRect? windowBounds;

  /// Whether we're on macOS (affects coordinate conversion).
  /// Detected automatically from platform.
  final bool isMacOS;

  WidgetPosition({bool? isMacOS}) : isMacOS = isMacOS ?? Platform.isMacOS;

  /// Get a widget's local bounds (relative to the Flutter view).
  ///
  /// Returns null if the widget is not mounted or has no render box.
  Rect? getLocalRect(GlobalKey key) {
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return null;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    return Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
  }

  /// Get a widget's bounds in screen coordinates.
  ///
  /// [key] - GlobalKey attached to the widget.
  /// [windowBounds] - Optional override for the palette's window bounds.
  ///
  /// Returns null if the widget is not mounted or window bounds are not set.
  ScreenRect? getWidgetRect(GlobalKey key, {ScreenRect? windowBounds}) {
    final bounds = windowBounds ?? this.windowBounds;
    if (bounds == null) return null;

    final localRect = getLocalRect(key);
    if (localRect == null) return null;

    // Convert the local rect's origin to screen coordinates
    final screenOrigin = bounds.localToScreen(localRect.topLeft);

    // Create a new rect at screen position
    // Note: The rect dimensions stay the same, just the position changes
    if (isMacOS) {
      // On macOS, we need to account for the coordinate flip
      // Screen origin is at the top-left of the widget visually
      return ScreenRect(
        Rect.fromLTWH(
          screenOrigin.dx,
          screenOrigin.dy - localRect.height, // Adjust for macOS Y flip
          localRect.width,
          localRect.height,
        ),
        isMacOS: true,
      );
    } else {
      return ScreenRect(
        Rect.fromLTWH(
          screenOrigin.dx,
          screenOrigin.dy,
          localRect.width,
          localRect.height,
        ),
        isMacOS: false,
      );
    }
  }

  /// Get a specific anchor point of a widget in screen coordinates.
  ///
  /// [key] - GlobalKey attached to the widget.
  /// [anchor] - Which anchor point to get.
  /// [windowBounds] - Optional override for the palette's window bounds.
  ///
  /// Returns null if the widget is not mounted or window bounds are not set.
  Offset? getWidgetAnchor(
    GlobalKey key,
    Anchor anchor, {
    ScreenRect? windowBounds,
  }) {
    final rect = getWidgetRect(key, windowBounds: windowBounds);
    return rect?.anchorPoint(anchor);
  }

  /// Get the screen position of a point within a widget.
  ///
  /// [key] - GlobalKey attached to the widget.
  /// [localOffset] - Position within the widget (0,0 = top-left).
  /// [windowBounds] - Optional override for the palette's window bounds.
  ///
  /// Useful for getting the position of a text caret within a text field.
  Offset? getPointInWidget(
    GlobalKey key,
    Offset localOffset, {
    ScreenRect? windowBounds,
  }) {
    final bounds = windowBounds ?? this.windowBounds;
    if (bounds == null) return null;

    final widgetLocalRect = getLocalRect(key);
    if (widgetLocalRect == null) return null;

    // The point in palette-local coordinates
    final pointInPalette = widgetLocalRect.topLeft + localOffset;

    // Convert to screen coordinates
    return bounds.localToScreen(pointInPalette);
  }
}

/// Mixin for StatefulWidget that need to report positions to host.
///
/// Provides convenient access to window bounds and position helpers.
///
/// ## Usage
///
/// ```dart
/// class _MyPaletteState extends State<MyPalette> with PalettePositionMixin {
///   final _widgetKey = GlobalKey();
///
///   void _reportPosition() {
///     final pos = getWidgetScreenPosition(_widgetKey, Anchor.bottomLeft);
///     if (pos != null) {
///       PaletteMessenger.send('widget-position', {'x': pos.dx, 'y': pos.dy});
///     }
///   }
/// }
/// ```
mixin PalettePositionMixin<T extends StatefulWidget> on State<T> {
  final _positionHelper = WidgetPosition();

  /// Set the palette's window bounds for coordinate conversion.
  ///
  /// Call this after getting the palette's bounds from native.
  void setWindowBounds(Rect bounds) {
    _positionHelper.windowBounds = ScreenRect.fromBounds(bounds);
  }

  /// Get a widget's screen rectangle.
  ScreenRect? getWidgetScreenRect(GlobalKey key) {
    return _positionHelper.getWidgetRect(key);
  }

  /// Get a widget's anchor point in screen coordinates.
  Offset? getWidgetScreenPosition(GlobalKey key, Anchor anchor) {
    return _positionHelper.getWidgetAnchor(key, anchor);
  }

  /// Get a specific point within a widget in screen coordinates.
  Offset? getPointInWidgetScreen(GlobalKey key, Offset localOffset) {
    return _positionHelper.getPointInWidget(key, localOffset);
  }
}
