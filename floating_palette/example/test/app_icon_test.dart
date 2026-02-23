import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/theme/brand.dart';

/// Generates macOS app icons at all required sizes.
/// Run with: flutter test test/app_icon_test.dart --update-goldens
void main() {
  // macOS requires these sizes
  final sizes = [16, 32, 64, 128, 256, 512, 1024];

  for (final size in sizes) {
    testWidgets('App icon ${size}x$size', (WidgetTester tester) async {
      // Set the surface size to match the icon size exactly
      await tester.binding.setSurfaceSize(Size(size.toDouble(), size.toDouble()));

      // Calculate logo size to fit nicely with padding
      final logoSize = size * 0.55;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 1.0),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox(
                width: size.toDouble(),
                height: size.toDouble(),
                child: Container(
                  decoration: BoxDecoration(
                    // macOS Big Sur style rounded rectangle
                    borderRadius: BorderRadius.circular(size * 0.22),
                    // Dark gradient background
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1E2140),
                        Color(0xFF0D0F1A),
                      ],
                    ),
                    // Subtle border
                    border: Border.all(
                      color: const Color(0xFF00D9FF).withValues(alpha: 0.15),
                      width: (size * 0.01).clamp(0.5, 2.0),
                    ),
                  ),
                  child: Center(
                    child: FPLogo(size: logoSize),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(SizedBox).first,
        matchesGoldenFile('goldens/app_icon_$size.png'),
      );

      // Reset surface size
      await tester.binding.setSurfaceSize(null);
    });
  }
}
