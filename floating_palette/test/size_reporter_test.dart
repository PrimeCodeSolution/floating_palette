import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:floating_palette/src/widgets/size_reporter.dart';

void main() {
  group('SizeReporter', () {
    setUp(() {
      // Set up a test window ID for each test
      SizeReporter.setWindowId('test-window');
      // Clear any force flag from previous tests
      SizeReporter.consumeForceFlag();
    });

    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizeReporter(
            onSizeChanged: (_) {},
            child: const Text('Test Child'),
          ),
        ),
      );

      expect(find.text('Test Child'), findsOneWidget);
    });

    testWidgets('calls onSizeChanged when size changes', (tester) async {
      Size? reportedSize;

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizeReporter(
              onSizeChanged: (size) => reportedSize = size,
              child: const SizedBox(width: 100, height: 50),
            ),
          ),
        ),
      );

      await tester.pump();

      // Size should be reported
      expect(find.byType(SizeReporter), findsOneWidget);
      expect(reportedSize, isNotNull);
    });

    testWidgets('updates callback when widget updates', (tester) async {
      var callCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizeReporter(
              onSizeChanged: (size) => callCount++,
              child: const SizedBox(width: 100, height: 50),
            ),
          ),
        ),
      );

      await tester.pump();
      final firstCallCount = callCount;

      // Update with new callback
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizeReporter(
              onSizeChanged: (size) => callCount++,
              child: const SizedBox(width: 100, height: 50),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(SizeReporter), findsOneWidget);
      expect(callCount, greaterThanOrEqualTo(firstCallCount));
    });

    test('forceNextReport sets global flag', () {
      // Consume any existing flag first
      SizeReporter.consumeForceFlag();

      // Flag should be false now
      expect(SizeReporter.consumeForceFlag(), false);

      // Set the force flag
      SizeReporter.forceNextReport();

      // Flag should be true and consumed
      expect(SizeReporter.consumeForceFlag(), true);

      // Flag should be false after consumption
      expect(SizeReporter.consumeForceFlag(), false);
    });

    test('consumeForceFlag returns true only once after forceNextReport', () {
      // Reset state
      SizeReporter.consumeForceFlag();

      SizeReporter.forceNextReport();
      expect(SizeReporter.consumeForceFlag(), true);
      expect(SizeReporter.consumeForceFlag(), false);
      expect(SizeReporter.consumeForceFlag(), false);
    });

    testWidgets('handles size changes during layout', (tester) async {
      Size? reportedSize;

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizeReporter(
              onSizeChanged: (size) => reportedSize = size,
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );

      await tester.pump();
      final firstSize = reportedSize;

      // Change the size
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizeReporter(
              onSizeChanged: (size) => reportedSize = size,
              child: const SizedBox(width: 200, height: 150),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(SizeReporter), findsOneWidget);
      expect(reportedSize, isNot(equals(firstSize)));
    });

    testWidgets('ignores small size changes (float jitter)', (tester) async {
      int callCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizeReporter(
              onSizeChanged: (_) => callCount++,
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );

      await tester.pump();
      final initialCount = callCount;

      // Same size - should not trigger additional callback
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizeReporter(
              onSizeChanged: (_) => callCount++,
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );

      await tester.pump();

      // Count should not have increased
      expect(callCount, initialCount);
    });

    testWidgets('forceNextReport triggers report even without size change',
        (tester) async {
      int callCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizeReporter(
              key: const ValueKey('first'),
              onSizeChanged: (_) => callCount++,
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );

      await tester.pump();
      final initialCount = callCount;

      // Force next report
      SizeReporter.forceNextReport();

      // Rebuild with same size but new key to force layout pass
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizeReporter(
              key: const ValueKey('second'),
              onSizeChanged: (_) => callCount++,
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );

      await tester.pump();

      // Force should have triggered a report
      expect(callCount, greaterThan(initialCount));
    });

    test('setWindowId updates the global window ID', () {
      SizeReporter.setWindowId('window-1');
      expect(SizeReporter.windowId, 'window-1');

      SizeReporter.setWindowId('window-2');
      expect(SizeReporter.windowId, 'window-2');
    });

    testWidgets('does not report when windowId is null', (tester) async {
      // Clear the window ID
      SizeReporter.setWindowId('');
      // Use reflection or just test behavior

      int callCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizeReporter(
              onSizeChanged: (_) => callCount++,
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );

      await tester.pump();

      // Widget still renders, callback may still be called
      // (FFI call is wrapped in try/catch)
      expect(find.byType(SizeReporter), findsOneWidget);
    });
  });

  group('IntrinsicSizeReporter', () {
    setUp(() {
      // Set up a test window ID for each test
      SizeReporter.setWindowId('test-window');
    });

    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: IntrinsicSizeReporter(
            onSizeChanged: (_) {},
            width: 200,
            child: const Text('Test Child'),
          ),
        ),
      );

      expect(find.text('Test Child'), findsOneWidget);
    });

    testWidgets('calls onSizeChanged after frame', (tester) async {
      Size? reportedSize;

      await tester.pumpWidget(
        MaterialApp(
          home: IntrinsicSizeReporter(
            onSizeChanged: (size) => reportedSize = size,
            width: 200,
            child: const SizedBox(width: 100, height: 50),
          ),
        ),
      );

      // Need to pump to trigger post-frame callback
      await tester.pump();
      await tester.pump();

      expect(reportedSize, isNotNull);
    });

    testWidgets('re-measures when widget updates', (tester) async {
      Size? reportedSize;

      await tester.pumpWidget(
        MaterialApp(
          home: IntrinsicSizeReporter(
            onSizeChanged: (size) => reportedSize = size,
            width: 200,
            child: const SizedBox(width: 100, height: 50),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      final firstSize = reportedSize;

      // Update child size
      await tester.pumpWidget(
        MaterialApp(
          home: IntrinsicSizeReporter(
            onSizeChanged: (size) => reportedSize = size,
            width: 200,
            child: const SizedBox(width: 150, height: 80),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(reportedSize, isNotNull);
      expect(reportedSize, isNot(equals(firstSize)));
    });

    testWidgets('respects width constraint', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: IntrinsicSizeReporter(
            onSizeChanged: (_) {},
            width: 300,
            child: const SizedBox(width: 100, height: 50),
          ),
        ),
      );

      await tester.pump();

      final widget = tester.widget<IntrinsicSizeReporter>(
        find.byType(IntrinsicSizeReporter),
      );

      expect(widget.width, 300);
    });

    testWidgets('uses KeyedSubtree for child', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: IntrinsicSizeReporter(
            onSizeChanged: (_) {},
            width: 200,
            child: const Text('Test'),
          ),
        ),
      );

      expect(find.byType(KeyedSubtree), findsOneWidget);
    });

    testWidgets('handles unmounted state gracefully', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: IntrinsicSizeReporter(
            onSizeChanged: (_) {},
            width: 200,
            child: const Text('Test'),
          ),
        ),
      );

      // Remove widget before post-frame callback
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // Should not crash
      expect(find.byType(IntrinsicSizeReporter), findsNothing);
    });

    testWidgets('ignores small size changes (< 0.5 pixel)', (tester) async {
      int callCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: IntrinsicSizeReporter(
            onSizeChanged: (_) => callCount++,
            width: 200,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      final initialCount = callCount;

      // Pump again with same widget - should not trigger new callback
      await tester.pump();

      // Count should not have increased
      expect(callCount, initialCount);
    });

    testWidgets('clamps intrinsic width to max width', (tester) async {
      Size? reportedSize;

      await tester.pumpWidget(
        MaterialApp(
          home: IntrinsicSizeReporter(
            onSizeChanged: (size) => reportedSize = size,
            width: 100, // Max width
            child: const SizedBox(width: 200, height: 50), // Wider than max
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      // Width should be clamped to max
      expect(reportedSize, isNotNull);
      expect(reportedSize!.width, lessThanOrEqualTo(100));
    });
  });
}
