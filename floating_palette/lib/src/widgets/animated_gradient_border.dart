import 'dart:math' as math;
import 'package:flutter/material.dart';

/// An animated gradient border that flows around its child like LED strips.
///
/// The gradient rotates continuously, creating a flowing light effect.
/// Customize [colors] to achieve any visual style you want.
///
/// The border is drawn as an overlay and does NOT add padding to the child.
/// Use [enabled] to show/hide the border without affecting layout.
///
/// Example:
/// ```dart
/// AnimatedGradientBorder(
///   enabled: isLoading,
///   borderRadius: 16.0,
///   child: MyContent(),
/// )
/// ```
class AnimatedGradientBorder extends StatefulWidget {
  /// The child widget to wrap with the animated border.
  final Widget child;

  /// Whether the border is visible and animating.
  ///
  /// When false, the border is hidden but layout remains unchanged.
  final bool enabled;

  /// Width of the border stroke in logical pixels.
  final double borderWidth;

  /// Border radius for the rounded corners.
  final double borderRadius;

  /// Colors for the gradient animation.
  ///
  /// Should include at least 3 colors. The last color should match
  /// the first for a seamless loop effect.
  final List<Color> colors;

  /// Duration for one complete rotation of the gradient.
  final Duration animationDuration;

  const AnimatedGradientBorder({
    super.key,
    required this.child,
    this.enabled = true,
    this.borderWidth = 4.0,
    this.borderRadius = 16.0,
    this.colors = const [
      Color(0xFF6366F1), // Indigo
      Color(0xFF8B5CF6), // Violet
      Color(0xFFEC4899), // Pink
      Color(0xFF6366F1), // Back to indigo (seamless loop)
    ],
    this.animationDuration = const Duration(seconds: 3),
  });

  @override
  State<AnimatedGradientBorder> createState() => _AnimatedGradientBorderState();
}

class _AnimatedGradientBorderState extends State<AnimatedGradientBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    if (widget.enabled) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(AnimatedGradientBorder oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update duration if changed
    if (widget.animationDuration != oldWidget.animationDuration) {
      _controller.duration = widget.animationDuration;
      if (widget.enabled) {
        _controller.repeat();
      }
    }

    // Start/stop animation based on enabled state
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use Stack to overlay border on top of child (no padding added)
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Child without any padding - border is purely an overlay
        widget.child,
        // Border overlay (only when enabled)
        if (widget.enabled)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return CustomPaint(
                    size: Size.infinite,
                    painter: _GradientBorderPainter(
                      progress: _controller.value,
                      borderWidth: widget.borderWidth,
                      borderRadius: widget.borderRadius,
                      colors: widget.colors,
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

class _GradientBorderPainter extends CustomPainter {
  final double progress;
  final double borderWidth;
  final double borderRadius;
  final List<Color> colors;

  _GradientBorderPainter({
    required this.progress,
    required this.borderWidth,
    required this.borderRadius,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw border inset by half stroke width so it's fully visible
    final halfStroke = borderWidth / 2;
    final rect = Rect.fromLTWH(
      halfStroke,
      halfStroke,
      size.width - borderWidth,
      size.height - borderWidth,
    );

    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(borderRadius - halfStroke),
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
        oldDelegate.colors != colors;
  }
}
