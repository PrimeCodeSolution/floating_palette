import 'package:flutter_test/flutter_test.dart';

import 'package:floating_palette/src/testing/palette_test_host.dart';
import 'package:floating_palette/src/controller/effects_helper.dart';
import 'package:floating_palette/src/services/animation_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PaletteTestHost testHost;
  late EffectsHelper effects;

  setUp(() async {
    testHost = await PaletteTestHost.create();
    // Create a controller to get a properly-wired AnimationClient
    // but test effects through EffectsHelper directly
    effects = EffectsHelper(AnimationClient(testHost.host.bridge));
  });

  tearDown(() async {
    await testHost.dispose();
  });

  group('shake', () {
    test('horizontal sends AnimatableProperty.x', () async {
      await effects.shake('test', direction: ShakeDirection.horizontal);

      final cmd = testHost.mock.findCommands('animation', 'animate').last;
      expect(cmd.params['property'], 'x');
      expect(cmd.params['from'], -10);
      expect(cmd.params['to'], 10);
    });

    test('vertical sends AnimatableProperty.y', () async {
      await effects.shake('test', direction: ShakeDirection.vertical);

      final cmd = testHost.mock.findCommands('animation', 'animate').last;
      expect(cmd.params['property'], 'y');
      expect(cmd.params['from'], -10);
      expect(cmd.params['to'], 10);
    });

    test('rotate sends AnimatableProperty.rotation with ±0.05', () async {
      await effects.shake('test', direction: ShakeDirection.rotate);

      final cmd = testHost.mock.findCommands('animation', 'animate').last;
      expect(cmd.params['property'], 'rotation');
      expect(cmd.params['from'], -0.05);
      expect(cmd.params['to'], 0.05);
    });

    test('.random resolves to one of {x, y, rotation}', () async {
      // Run multiple times to exercise randomness
      final properties = <String>{};
      for (var i = 0; i < 50; i++) {
        testHost.clearCommands();
        await effects.shake('test', direction: ShakeDirection.random);
        final cmd = testHost.mock.findCommands('animation', 'animate').last;
        properties.add(cmd.params['property'] as String);
      }

      // Should only produce valid properties
      expect(properties, everyElement(isIn(['x', 'y', 'rotation'])));
      // With 50 iterations, the probability of NOT hitting at least 2 of 3 is negligible
      expect(properties.length, greaterThanOrEqualTo(2));
    });

    test('.random resolving to rotation uses ±0.05, not ±intensity', () async {
      // Run until we get a rotation result
      String? property;
      double? from;
      double? to;

      for (var i = 0; i < 100; i++) {
        testHost.clearCommands();
        await effects.shake('test', direction: ShakeDirection.random, intensity: 10);
        final cmd = testHost.mock.findCommands('animation', 'animate').last;
        if (cmd.params['property'] == 'rotation') {
          property = cmd.params['property'] as String;
          from = (cmd.params['from'] as num).toDouble();
          to = (cmd.params['to'] as num).toDouble();
          break;
        }
      }

      expect(property, 'rotation');
      expect(from, -0.05);
      expect(to, 0.05);
    });

    test('respects custom intensity and count', () async {
      await effects.shake(
        'test',
        direction: ShakeDirection.horizontal,
        intensity: 20,
        count: 5,
        duration: const Duration(milliseconds: 500),
      );

      final cmd = testHost.mock.findCommands('animation', 'animate').last;
      expect(cmd.params['from'], -20);
      expect(cmd.params['to'], 20);
      expect(cmd.params['repeat'], 5);
      expect(cmd.params['durationMs'], 100); // 500 / 5
      expect(cmd.params['autoReverse'], true);
    });
  });

  group('pulse', () {
    test('sends scale animation', () async {
      await effects.pulse('test', maxScale: 1.2);

      final cmd = testHost.mock.findCommands('animation', 'animate').last;
      expect(cmd.params['property'], 'scale');
      expect(cmd.params['from'], 1.0);
      expect(cmd.params['to'], 1.2);
      expect(cmd.params['autoReverse'], true);
    });

    test('respects count and duration', () async {
      await effects.pulse(
        'test',
        count: 3,
        duration: const Duration(milliseconds: 600),
      );

      final cmd = testHost.mock.findCommands('animation', 'animate').last;
      expect(cmd.params['repeat'], 3);
      expect(cmd.params['durationMs'], 200); // 600 / 3
    });
  });

  group('bounce', () {
    test('sends y animation with negative height', () async {
      await effects.bounce('test', height: 30);

      final cmd = testHost.mock.findCommands('animation', 'animate').last;
      expect(cmd.params['property'], 'y');
      expect(cmd.params['from'], 0);
      expect(cmd.params['to'], -30);
      expect(cmd.params['curve'], 'easeOut');
      expect(cmd.params['autoReverse'], true);
    });
  });
}
