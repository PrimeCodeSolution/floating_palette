import 'dart:ui' show Color;

/// Configuration for an animated gradient border around a palette.
///
/// Used with [PaletteScaffold.border] to add a rotating gradient border
/// that expands the window size (doesn't shrink content).
///
/// ```dart
/// PaletteScaffold(
///   border: GradientBorder(width: 8.0),
///   child: MyContent(),
/// )
/// ```
class GradientBorder {
  /// Width of the border stroke in logical pixels.
  final double width;

  /// Colors for the gradient animation.
  ///
  /// Should include at least 3 colors. The last color should match
  /// the first for a seamless loop effect.
  final List<Color> colors;

  /// Duration for one complete rotation of the gradient.
  final Duration animationDuration;

  /// Corner radius for the border.
  ///
  /// If null, uses the scaffold's [cornerRadius].
  final double? cornerRadius;

  const GradientBorder({
    this.width = 4.0,
    this.colors = const [
      Color(0xFF6366F1), // Indigo
      Color(0xFF8B5CF6), // Violet
      Color(0xFFEC4899), // Pink
      Color(0xFF6366F1), // Back to indigo (seamless loop)
    ],
    this.animationDuration = const Duration(seconds: 3),
    this.cornerRadius,
  });

  /// Subtle indigo border - thin and elegant.
  const GradientBorder.subtle()
      : width = 2.0,
        colors = const [
          Color(0xFF6366F1),
          Color(0xFF818CF8),
          Color(0xFF6366F1),
        ],
        animationDuration = const Duration(seconds: 4),
        cornerRadius = null;

  /// Vibrant rainbow border - bold and eye-catching.
  const GradientBorder.vibrant()
      : width = 6.0,
        colors = const [
          Color(0xFFEF4444), // Red
          Color(0xFFF59E0B), // Amber
          Color(0xFF10B981), // Emerald
          Color(0xFF3B82F6), // Blue
          Color(0xFF8B5CF6), // Violet
          Color(0xFFEF4444), // Back to red
        ],
        animationDuration = const Duration(seconds: 2),
        cornerRadius = null;

  /// Creates a copy with the specified fields replaced.
  GradientBorder copyWith({
    double? width,
    List<Color>? colors,
    Duration? animationDuration,
    double? cornerRadius,
  }) {
    return GradientBorder(
      width: width ?? this.width,
      colors: colors ?? this.colors,
      animationDuration: animationDuration ?? this.animationDuration,
      cornerRadius: cornerRadius ?? this.cornerRadius,
    );
  }
}
