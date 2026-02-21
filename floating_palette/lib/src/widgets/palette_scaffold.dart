import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../config/palette_border.dart' show GradientBorder;
import 'size_reporter.dart';

/// A scaffold widget for palette content.
///
/// This is the root widget for all palette content. It handles:
/// - Automatic window sizing when `resizable: false` (via [SizeReporter])
/// - Background color/decoration
/// - Animated gradient border (via [border])
/// - Optional padding
///
/// ## Usage
///
/// ```dart
/// @FloatingPalette('my_palette')
/// Widget myPalette(BuildContext context, MyArgs args) {
///   return PaletteScaffold(
///     backgroundColor: Colors.white,
///     border: GradientBorder(width: 8.0),
///     child: Column(
///       mainAxisSize: MainAxisSize.min,
///       children: [
///         Text('Hello ${args.name}'),
///         ElevatedButton(
///           onPressed: () => PaletteController.hide('my_palette'),
///           child: Text('Close'),
///         ),
///       ],
///     ),
///   );
/// }
/// ```
///
/// ## Sizing Behavior
///
/// By default (`resizable: false`), the palette window will automatically
/// resize to fit the content. The [SizeReporter] measures the child's size
/// during layout and calls native FFI to resize the window synchronously,
/// avoiding flicker.
///
/// When `resizable: true`, the native window is user-resizable and the
/// scaffold does not control window sizing.
///
/// ## Border Behavior
///
/// When [border] is set, the animated gradient border is added INSIDE the
/// sizing measurement. This means the border EXPANDS the window size rather
/// than shrinking the content. A 400x400 content with a 10px border results
/// in a 420x420 window (content stays 400x400).
class PaletteScaffold extends StatelessWidget {
  /// The child widget to display in the palette.
  final Widget child;

  /// Whether the palette is resizable by the user.
  ///
  /// When `false` (default), the window size is controlled by the content.
  /// When `true`, the window is resizable by the user and the scaffold
  /// does not control sizing.
  final bool resizable;

  /// Background color of the palette.
  final Color? backgroundColor;

  /// Decoration for the palette background.
  ///
  /// If provided, [backgroundColor] is ignored.
  final BoxDecoration? decoration;

  /// Corner radius for the palette window.
  ///
  /// Defaults to 12. Set to 0 for sharp corners.
  /// This is handled by Flutter's ClipRRect to ensure proper transparency
  /// at corners (native masking causes black corners due to Metal layer).
  final double cornerRadius;

  /// Padding around the content.
  final EdgeInsetsGeometry? padding;

  /// Animated gradient border around the palette.
  ///
  /// When set, the border expands the window size (doesn't shrink content).
  /// The border is measured as part of the content for proper sizing.
  final GradientBorder? border;

  /// Transparent padding outside the decoration that expands the window.
  ///
  /// Use this to reserve space for overlay content (tooltips, dropdowns)
  /// that renders beyond the visible palette bounds. The extra space is
  /// fully transparent and non-interactive (hit-tests pass through).
  ///
  /// Example: `overflowPadding: EdgeInsets.only(bottom: 32)` reserves
  /// 32px below the palette for tooltips.
  final EdgeInsetsGeometry? overflowPadding;

  /// Called when the content size changes.
  ///
  /// Only called when `resizable: false`.
  final void Function(Size size)? onSizeChanged;

  const PaletteScaffold({
    super.key,
    required this.child,
    this.resizable = false,
    this.backgroundColor,
    this.decoration,
    this.cornerRadius = 12,
    this.padding,
    this.border,
    this.overflowPadding,
    this.onSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = child;

    // Apply padding if provided
    if (padding != null) {
      content = Padding(
        padding: padding!,
        child: content,
      );
    }

    // Apply background with corner radius
    // Use ClipRRect to handle corners in Flutter (avoids native Metal layer issues)
    BorderRadius? clipRadius;

    if (decoration != null) {
      // Use provided decoration as-is
      content = Container(
        decoration: decoration,
        child: content,
      );
      // Extract border radius from decoration for clipping
      clipRadius = decoration!.borderRadius as BorderRadius?;
    } else if (backgroundColor != null) {
      // Create decoration with corner radius
      content = Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(cornerRadius),
        ),
        child: content,
      );
      clipRadius = BorderRadius.circular(cornerRadius);
    }

    // Apply corner clipping to ensure transparent corners
    // Use the same radius as the decoration for consistency
    final effectiveClipRadius = clipRadius ?? BorderRadius.circular(cornerRadius);
    if (cornerRadius > 0 || clipRadius != null) {
      content = ClipRRect(
        borderRadius: effectiveClipRadius,
        child: content,
      );
    }

    // Apply border BEFORE SizeReporter so it's included in sizing
    // This makes the border EXPAND the window rather than shrink content
    if (border != null) {
      content = _AnimatedBorderWrapper(
        border: border!,
        cornerRadius: border!.cornerRadius ?? cornerRadius,
        child: content,
      );
    }

    // Apply overflow padding outside decoration/clip for overlay content (tooltips)
    // This expands the window without affecting the visual content area
    if (overflowPadding != null) {
      content = Padding(
        padding: overflowPadding!,
        child: content,
      );
    }

    // Wrap with SizeReporter if not resizable
    // SizeReporter uses the static windowId set by the palette runner
    // Border is now INSIDE this measurement, so window = content + border
    if (!resizable) {
      content = SizeReporter(
        onSizeChanged: onSizeChanged,
        child: content,
      );
    } else {
      // When resizable, expand to fill available window space
      content = SizedBox.expand(child: content);
    }

    // Use Material for ink effects and default styling
    return Material(
      type: MaterialType.transparency,
      child: content,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Internal Animated Border Widget
// ════════════════════════════════════════════════════════════════════════════

/// Internal widget that wraps content with an animated gradient border.
///
/// This is intentionally private - users should use [PaletteScaffold.border].
class _AnimatedBorderWrapper extends StatefulWidget {
  final GradientBorder border;
  final double cornerRadius;
  final Widget child;

  const _AnimatedBorderWrapper({
    required this.border,
    required this.cornerRadius,
    required this.child,
  });

  @override
  State<_AnimatedBorderWrapper> createState() => _AnimatedBorderWrapperState();
}

class _AnimatedBorderWrapperState extends State<_AnimatedBorderWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.border.animationDuration,
    )..repeat();
  }

  @override
  void didUpdateWidget(_AnimatedBorderWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update duration if changed
    if (widget.border.animationDuration != oldWidget.border.animationDuration) {
      _controller.duration = widget.border.animationDuration;
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderWidth = widget.border.width;
    final halfBorder = borderWidth / 2;

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        // Child with padding to make room for full border width
        // Border stroke extends from 0 to borderWidth, so content starts at borderWidth
        Padding(
          padding: EdgeInsets.all(borderWidth),
          child: widget.child,
        ),
        // Border overlay (drawn at edges)
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: _GradientBorderPainter(
                    progress: _controller.value,
                    borderWidth: borderWidth,
                    borderRadius: widget.cornerRadius + halfBorder,
                    colors: widget.border.colors,
                    inset: halfBorder,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter for the rotating gradient border.
class _GradientBorderPainter extends CustomPainter {
  final double progress;
  final double borderWidth;
  final double borderRadius;
  final List<Color> colors;
  final double inset;

  _GradientBorderPainter({
    required this.progress,
    required this.borderWidth,
    required this.borderRadius,
    required this.colors,
    this.inset = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw border inset by the specified amount
    // This ensures the stroke is fully visible within bounds
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );

    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(borderRadius),
    );

    // Create sweep gradient with rotation based on progress
    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: math.pi * 2,
      colors: colors,
      transform: GradientRotation(progress * math.pi * 2),
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_GradientBorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.colors != colors ||
        oldDelegate.inset != inset;
  }
}
