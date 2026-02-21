import 'package:flutter/material.dart';

/// Floating Palette brand colors.
abstract final class FPColors {
  // Primary
  static const primary = Color(0xFF00D9FF);
  static const primaryDark = Color(0xFF00A8CC);

  // Secondary
  static const secondary = Color(0xFFA78BFA);
  static const secondaryDark = Color(0xFF7C5CC7);

  // Surfaces
  static const surface = Color(0xFF0F0F13);
  static const surfaceElevated = Color(0xFF1A1A21);
  static const surfaceSubtle = Color(0xFF252530);

  // Text
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFA0A0B0);

  // Semantic
  static const success = Color(0xFF34D399);
  static const warning = Color(0xFFFBBF24);
  static const error = Color(0xFFF87171);
}

/// Standard spacing values.
abstract final class FPSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

/// Theme factory.
abstract final class FPTheme {
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: FPColors.surface,
        colorScheme: const ColorScheme.dark(
          primary: FPColors.primary,
          secondary: FPColors.secondary,
          surface: FPColors.surfaceElevated,
        ),
        cardTheme: CardThemeData(
          color: FPColors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: FPColors.surface,
          foregroundColor: FPColors.textPrimary,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: FPColors.primary,
            foregroundColor: FPColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            color: FPColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
          headlineMedium: TextStyle(
            color: FPColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: TextStyle(color: FPColors.textPrimary),
          bodyMedium: TextStyle(color: FPColors.textSecondary),
        ),
      );
}

/// Simple logo widget for Floating Palette.
class FPLogo extends StatelessWidget {
  final double size;
  final Color? color;

  const FPLogo({
    super.key,
    this.size = 48,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final logoColor = color ?? FPColors.primary;

    // Frame dimensions (landscape ratio like in the image)
    final frameWidth = size;
    final frameHeight = size * 0.7;
    final frameRadius = size * 0.2; // More rounded corners
    final frameStroke = size * 0.06; // Thicker stroke

    // Panel dimensions (smaller, more rounded)
    final panelWidth = size * 0.55;
    final panelHeight = size * 0.42;
    final panelRadius = size * 0.12; // Very rounded corners

    // 50% overlap positioning
    final overlapX = panelWidth * 0.45;
    final overlapY = panelHeight * 0.45;

    return SizedBox(
      width: frameWidth + overlapX,
      height: frameHeight + overlapY,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Outer frame with glow
          Container(
            width: frameWidth,
            height: frameHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(frameRadius),
              border: Border.all(color: logoColor, width: frameStroke),
              boxShadow: [
                // Outer glow
                BoxShadow(
                  color: logoColor.withValues(alpha: 0.4),
                  blurRadius: size * 0.15,
                  spreadRadius: size * 0.02,
                ),
              ],
            ),
          ),
          // Floating glass panel (50% in, 50% out)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: panelWidth,
              height: panelHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(panelRadius),
                // Glass effect gradient
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    logoColor.withValues(alpha: 0.6),
                    logoColor.withValues(alpha: 0.25),
                    logoColor.withValues(alpha: 0.4),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                border: Border.all(
                  color: logoColor.withValues(alpha: 0.7),
                  width: frameStroke * 0.5,
                ),
                boxShadow: [
                  // Outer glow
                  BoxShadow(
                    color: logoColor.withValues(alpha: 0.5),
                    blurRadius: size * 0.2,
                    spreadRadius: size * 0.02,
                  ),
                  // Inner subtle shadow for depth
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.1),
                    blurRadius: size * 0.05,
                    offset: Offset(-size * 0.02, -size * 0.02),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
