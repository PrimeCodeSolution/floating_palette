import 'dart:io' show Platform;
import 'dart:ui';

import '../config/palette_position.dart';

/// A rectangle in screen coordinates with anchor point helpers.
///
/// Automatically handles platform-specific coordinate systems:
/// - **macOS**: Y=0 at bottom of screen, Y increases upward
/// - **Windows**: Y=0 at top of screen, Y increases downward
///
/// The API is the same on both platforms - all conversions are handled internally.
///
/// ## Usage
///
/// ```dart
/// final editorRect = ScreenRect.fromBounds(await Palettes.editor.bounds);
///
/// // Get any anchor point (works the same on macOS and Windows)
/// final bottomLeft = editorRect.anchorPoint(Anchor.bottomLeft);
///
/// // Position slash menu below editor's bottom-left
/// Palettes.slashMenu.show(
///   position: PalettePosition(
///     target: Target.custom,
///     customPosition: bottomLeft.below(8), // 8px below (platform-aware)
///     anchor: Anchor.topLeft,
///   ),
/// );
/// ```
class ScreenRect {
  /// The underlying rectangle in native screen coordinates.
  ///
  /// On macOS: origin is bottom-left, Y increases upward.
  /// On Windows: origin is top-left, Y increases downward.
  final Rect native;

  /// Whether this is macOS coordinate system (Y=0 at bottom).
  final bool isMacOS;

  const ScreenRect(this.native, {required this.isMacOS});

  /// Create from palette bounds with automatic platform detection.
  ///
  /// Palette bounds come from native in the platform's coordinate system.
  factory ScreenRect.fromBounds(Rect bounds) {
    return ScreenRect(bounds, isMacOS: Platform.isMacOS);
  }

  /// Create with explicit platform specification (for testing).
  factory ScreenRect.fromBoundsWithPlatform(Rect bounds, {required bool isMacOS}) {
    return ScreenRect(bounds, isMacOS: isMacOS);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Visual Edge Accessors (platform-independent)
  // ════════════════════════════════════════════════════════════════════════════

  /// The leftmost X coordinate.
  double get left => native.left;

  /// The rightmost X coordinate.
  double get right => native.left + native.width;

  /// The Y coordinate of the visual top edge.
  ///
  /// On macOS: native.top + native.height (higher Y = higher on screen)
  /// On Windows: native.top
  double get visualTop => isMacOS ? native.top + native.height : native.top;

  /// The Y coordinate of the visual bottom edge.
  ///
  /// On macOS: native.top (lower Y = lower on screen)
  /// On Windows: native.top + native.height
  double get visualBottom => isMacOS ? native.top : native.top + native.height;

  /// Width of the rectangle.
  double get width => native.width;

  /// Height of the rectangle.
  double get height => native.height;

  /// Center X coordinate.
  double get centerX => native.left + native.width / 2;

  /// Center Y coordinate (visual center).
  double get centerY => isMacOS
      ? native.top + native.height / 2
      : native.top + native.height / 2;

  // ════════════════════════════════════════════════════════════════════════════
  // Anchor Points
  // ════════════════════════════════════════════════════════════════════════════

  /// Get the screen position of a specific anchor point.
  ///
  /// Returns an [Offset] representing the screen coordinates of the
  /// specified anchor point on this rectangle.
  Offset anchorPoint(Anchor anchor) {
    final x = switch (anchor) {
      Anchor.topLeft || Anchor.centerLeft || Anchor.bottomLeft => left,
      Anchor.topCenter || Anchor.center || Anchor.bottomCenter => centerX,
      Anchor.topRight || Anchor.centerRight || Anchor.bottomRight => right,
    };

    final y = switch (anchor) {
      Anchor.topLeft || Anchor.topCenter || Anchor.topRight => visualTop,
      Anchor.centerLeft || Anchor.center || Anchor.centerRight => centerY,
      Anchor.bottomLeft || Anchor.bottomCenter || Anchor.bottomRight =>
        visualBottom,
    };

    return Offset(x, y);
  }

  /// Top-left corner in screen coordinates.
  Offset get topLeft => anchorPoint(Anchor.topLeft);

  /// Top-center point in screen coordinates.
  Offset get topCenter => anchorPoint(Anchor.topCenter);

  /// Top-right corner in screen coordinates.
  Offset get topRight => anchorPoint(Anchor.topRight);

  /// Center-left point in screen coordinates.
  Offset get centerLeft => anchorPoint(Anchor.centerLeft);

  /// Center point in screen coordinates.
  Offset get center => anchorPoint(Anchor.center);

  /// Center-right point in screen coordinates.
  Offset get centerRight => anchorPoint(Anchor.centerRight);

  /// Bottom-left corner in screen coordinates.
  Offset get bottomLeft => anchorPoint(Anchor.bottomLeft);

  /// Bottom-center point in screen coordinates.
  Offset get bottomCenter => anchorPoint(Anchor.bottomCenter);

  /// Bottom-right corner in screen coordinates.
  Offset get bottomRight => anchorPoint(Anchor.bottomRight);

  // ════════════════════════════════════════════════════════════════════════════
  // Relative Positioning
  // ════════════════════════════════════════════════════════════════════════════

  /// Calculate position for placing another rectangle relative to this one.
  ///
  /// [theirAnchor] - Which point of THIS rectangle to align to.
  /// [myAnchor] - Which point of the OTHER rectangle should be at that position.
  /// [offset] - Additional offset to apply.
  ///
  /// Returns an [Offset] suitable for use with [PalettePosition.custom].
  ///
  /// ## Example
  ///
  /// Place a menu with its top-left at this rectangle's bottom-left (8px below):
  /// ```dart
  /// final targetPos = editorRect.positionFor(
  ///   theirAnchor: Anchor.bottomLeft,  // Align to editor's bottom-left
  ///   myAnchor: Anchor.topLeft,        // Menu's top-left goes there
  ///   offset: Offset(0, -8),           // 8px below (negative Y = down on macOS)
  /// );
  /// ```
  Offset positionFor({
    required Anchor theirAnchor,
    required Anchor myAnchor,
    Offset offset = Offset.zero,
  }) {
    // Get the point on THIS rectangle
    final targetPoint = anchorPoint(theirAnchor);

    // Apply offset
    // Note: On macOS, negative Y = down, positive Y = up
    return targetPoint + offset;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Local-to-Screen Conversion
  // ════════════════════════════════════════════════════════════════════════════

  /// Convert a local position (within this rectangle) to screen coordinates.
  ///
  /// [localPosition] - Position relative to top-left of the rectangle.
  ///                   (0, 0) is top-left, positive Y is down (Flutter convention).
  ///
  /// Returns screen coordinates in the native coordinate system.
  Offset localToScreen(Offset localPosition) {
    if (isMacOS) {
      // In macOS: origin is at bottom-left, Y increases upward
      // Flutter local: origin is at top-left, Y increases downward
      // So we need to flip Y
      return Offset(
        left + localPosition.dx,
        visualTop - localPosition.dy, // Subtract because local Y down = screen Y down
      );
    } else {
      // Windows: both have Y increasing downward
      return Offset(
        left + localPosition.dx,
        visualTop + localPosition.dy,
      );
    }
  }

  /// Convert screen coordinates to local position within this rectangle.
  ///
  /// Returns position relative to top-left of the rectangle,
  /// with positive Y going down (Flutter convention).
  Offset screenToLocal(Offset screenPosition) {
    if (isMacOS) {
      return Offset(
        screenPosition.dx - left,
        visualTop - screenPosition.dy, // Flip Y back
      );
    } else {
      return Offset(
        screenPosition.dx - left,
        screenPosition.dy - visualTop,
      );
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Platform-Aware Offset Helpers
  // ════════════════════════════════════════════════════════════════════════════

  /// Get an offset that moves DOWN by [pixels] in screen space.
  ///
  /// This abstracts away the platform coordinate differences:
  /// - macOS: negative Y = down
  /// - Windows: positive Y = down
  Offset offsetDown(double pixels) =>
      isMacOS ? Offset(0, -pixels) : Offset(0, pixels);

  /// Get an offset that moves UP by [pixels] in screen space.
  Offset offsetUp(double pixels) =>
      isMacOS ? Offset(0, pixels) : Offset(0, -pixels);

  /// Get an offset that moves RIGHT by [pixels] in screen space.
  Offset offsetRight(double pixels) => Offset(pixels, 0);

  /// Get an offset that moves LEFT by [pixels] in screen space.
  Offset offsetLeft(double pixels) => Offset(-pixels, 0);

  // ════════════════════════════════════════════════════════════════════════════
  // Available Space Calculations
  // ════════════════════════════════════════════════════════════════════════════

  /// Calculate available vertical space below a point to this rect's bottom edge.
  ///
  /// Useful for menus/popups to determine how many items can fit.
  /// Typically called on a screen work area rect.
  ///
  /// ```dart
  /// final workArea = primaryScreen.workArea.toScreenRect();
  /// final available = workArea.availableBelow(caretPosition);
  /// final maxItems = (available / itemHeight).floor();
  /// ```
  double availableBelow(Offset point) {
    // Distance from point to visual bottom of this rect
    if (isMacOS) {
      // macOS: point.dy is higher = visually higher, visualBottom is lower Y
      return point.dy - visualBottom;
    } else {
      // Windows: point.dy is lower = visually higher, visualBottom is higher Y
      return visualBottom - point.dy;
    }
  }

  /// Calculate available vertical space above a point to this rect's top edge.
  double availableAbove(Offset point) {
    if (isMacOS) {
      return visualTop - point.dy;
    } else {
      return point.dy - visualTop;
    }
  }

  /// Calculate available horizontal space to the right of a point.
  double availableRight(Offset point) => right - point.dx;

  /// Calculate available horizontal space to the left of a point.
  double availableLeft(Offset point) => point.dx - left;

  /// Calculate how many items of [itemHeight] fit in the available space below [point].
  ///
  /// [margin] - Safety margin from screen edge (default 16px)
  /// [padding] - Additional padding (e.g., ListView padding)
  ///
  /// Returns the number of full items that fit (no partial items).
  int itemsThatFitBelow(
    Offset point, {
    required double itemHeight,
    double margin = 16,
    double padding = 0,
  }) {
    final available = availableBelow(point) - margin - padding;
    return (available / itemHeight).floor().clamp(0, 999);
  }

  @override
  String toString() =>
      'ScreenRect(left: $left, visualTop: $visualTop, width: $width, height: $height, isMacOS: $isMacOS)';
}

/// Extension on [Rect] for quick conversion to [ScreenRect].
extension RectToScreenRect on Rect {
  /// Convert to a [ScreenRect] for anchor point access.
  ///
  /// Platform is detected automatically.
  ScreenRect toScreenRect() => ScreenRect.fromBounds(this);

  /// Convert to a [ScreenRect] with explicit platform specification.
  ScreenRect toScreenRectWithPlatform({required bool isMacOS}) =>
      ScreenRect.fromBoundsWithPlatform(this, isMacOS: isMacOS);
}

/// Extension on [Offset] for platform-aware directional offsets.
///
/// These helpers make it easy to create offsets that work correctly
/// on both macOS and Windows without thinking about coordinate systems.
extension ScreenOffset on Offset {
  /// Create a new offset moved DOWN by [pixels].
  ///
  /// Platform-aware: handles Y direction differences automatically.
  Offset below(double pixels, {bool? isMacOS}) {
    final mac = isMacOS ?? Platform.isMacOS;
    return mac ? Offset(dx, dy - pixels) : Offset(dx, dy + pixels);
  }

  /// Create a new offset moved UP by [pixels].
  Offset above(double pixels, {bool? isMacOS}) {
    final mac = isMacOS ?? Platform.isMacOS;
    return mac ? Offset(dx, dy + pixels) : Offset(dx, dy - pixels);
  }

  /// Create a new offset moved RIGHT by [pixels].
  Offset toTheRight(double pixels) => Offset(dx + pixels, dy);

  /// Create a new offset moved LEFT by [pixels].
  Offset toTheLeft(double pixels) => Offset(dx - pixels, dy);

  /// Create a new offset with both X and Y adjustments.
  ///
  /// [right] - pixels to move right (negative = left)
  /// [down] - pixels to move down (negative = up), platform-aware
  Offset shifted({double right = 0, double down = 0, bool? isMacOS}) {
    final mac = isMacOS ?? Platform.isMacOS;
    final yOffset = mac ? -down : down;
    return Offset(dx + right, dy + yOffset);
  }
}
