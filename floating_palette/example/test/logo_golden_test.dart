import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/theme/brand.dart';

void main() {
  testWidgets('FPLogo golden test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Center(
          child: Container(
            color: const Color(0xFF1A1A2E), // Dark background
            padding: const EdgeInsets.all(24),
            child: const FPLogo(size: 128), // Larger size for better quality
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(FPLogo),
      matchesGoldenFile('goldens/fp_logo.png'),
    );
  });

  testWidgets('FPLogo white golden test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Center(
          child: Container(
            color: Colors.transparent,
            padding: const EdgeInsets.all(24),
            child: const FPLogo(size: 128, color: Colors.white),
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(FPLogo),
      matchesGoldenFile('goldens/fp_logo_white.png'),
    );
  });
}
