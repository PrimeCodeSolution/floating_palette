import 'package:flutter_test/flutter_test.dart';

import 'package:floating_palette/src/bridge/event.dart';
import 'package:floating_palette/src/services/animation_client.dart';
import 'package:floating_palette/src/testing/mock_native_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNativeBridge mock;
  late AnimationClient client;

  setUp(() {
    mock = MockNativeBridge();
    mock.stubDefaults();
    client = AnimationClient(mock);
  });

  tearDown(() {
    client.dispose();
    mock.reset();
  });

  // ════════════════════════════════════════════════════════════════════════════
  // animate
  // ════════════════════════════════════════════════════════════════════════════

  group('animate', () {
    test('sends correct service, command, windowId and params', () async {
      await client.animate(
        'w1',
        property: AnimatableProperty.opacity,
        from: 0.0,
        to: 1.0,
        durationMs: 300,
      );

      expect(mock.sentCommands, hasLength(1));
      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('animation'));
      expect(cmd.command, equals('animate'));
      expect(cmd.windowId, equals('w1'));
      expect(cmd.params['property'], equals('opacity'));
      expect(cmd.params['from'], equals(0.0));
      expect(cmd.params['to'], equals(1.0));
      expect(cmd.params['durationMs'], equals(300));
      expect(cmd.params['curve'], equals('easeOut'));
      expect(cmd.params['repeat'], equals(1));
      expect(cmd.params['autoReverse'], isFalse);
    });

    test('passes custom curve, repeat, autoReverse', () async {
      await client.animate(
        'w1',
        property: AnimatableProperty.scale,
        from: 1.0,
        to: 2.0,
        durationMs: 500,
        curve: 'linear',
        repeat: 3,
        autoReverse: true,
      );

      final cmd = mock.sentCommands.first;
      expect(cmd.params['property'], equals('scale'));
      expect(cmd.params['curve'], equals('linear'));
      expect(cmd.params['repeat'], equals(3));
      expect(cmd.params['autoReverse'], isTrue);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // animateMultiple
  // ════════════════════════════════════════════════════════════════════════════

  group('animateMultiple', () {
    test('sends animations list', () async {
      await client.animateMultiple(
        'w1',
        animations: [
          const PropertyAnimation(
            property: AnimatableProperty.x,
            from: 0,
            to: 100,
          ),
          const PropertyAnimation(
            property: AnimatableProperty.y,
            from: 0,
            to: 200,
          ),
        ],
        durationMs: 400,
      );

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('animation'));
      expect(cmd.command, equals('animateMultiple'));
      expect(cmd.windowId, equals('w1'));
      expect(cmd.params['durationMs'], equals(400));
      expect(cmd.params['curve'], equals('easeOut'));

      final animations = cmd.params['animations'] as List<dynamic>;
      expect(animations, hasLength(2));
      expect(animations[0]['property'], equals('x'));
      expect(animations[0]['from'], equals(0.0));
      expect(animations[0]['to'], equals(100.0));
      expect(animations[1]['property'], equals('y'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // stop
  // ════════════════════════════════════════════════════════════════════════════

  group('stop', () {
    test('sends correct params', () async {
      await client.stop('w1', AnimatableProperty.rotation);

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('animation'));
      expect(cmd.command, equals('stop'));
      expect(cmd.windowId, equals('w1'));
      expect(cmd.params['property'], equals('rotation'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // stopAll
  // ════════════════════════════════════════════════════════════════════════════

  group('stopAll', () {
    test('sends correct command with no extra params', () async {
      await client.stopAll('w1');

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('animation'));
      expect(cmd.command, equals('stopAll'));
      expect(cmd.windowId, equals('w1'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // isAnimating
  // ════════════════════════════════════════════════════════════════════════════

  group('isAnimating', () {
    test('parses true response', () async {
      mock.stubResponse('animation', 'isAnimating', true);

      final result = await client.isAnimating('w1', AnimatableProperty.x);

      expect(result, isTrue);
      expect(mock.wasCalledFor('animation', 'isAnimating', 'w1'), isTrue);
    });

    test('returns false on null response', () async {
      final result = await client.isAnimating('w1', AnimatableProperty.opacity);

      expect(result, isFalse);
    });

    test('sends property name in params', () async {
      await client.isAnimating('w1', AnimatableProperty.height);

      final cmd = mock.sentCommands.first;
      expect(cmd.params['property'], equals('height'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // Events
  // ════════════════════════════════════════════════════════════════════════════

  group('onCompleted', () {
    test('fires callback when matching property completes', () {
      var fired = false;
      client.onCompleted('w1', AnimatableProperty.opacity, () => fired = true);

      mock.simulateEvent(const NativeEvent(
        service: 'animation',
        event: 'complete',
        windowId: 'w1',
        data: {'property': 'opacity'},
      ));

      expect(fired, isTrue);
    });

    test('does not fire for different property', () {
      var fired = false;
      client.onCompleted('w1', AnimatableProperty.opacity, () => fired = true);

      mock.simulateEvent(const NativeEvent(
        service: 'animation',
        event: 'complete',
        windowId: 'w1',
        data: {'property': 'scale'},
      ));

      expect(fired, isFalse);
    });

    test('ignores events for other windows', () {
      var fired = false;
      client.onCompleted('w1', AnimatableProperty.x, () => fired = true);

      mock.simulateEvent(const NativeEvent(
        service: 'animation',
        event: 'complete',
        windowId: 'w2',
        data: {'property': 'x'},
      ));

      expect(fired, isFalse);
    });
  });

  group('onAnyCompleted', () {
    test('fires callback with parsed property', () {
      AnimatableProperty? received;
      client.onAnyCompleted('w1', (prop) => received = prop);

      mock.simulateEvent(const NativeEvent(
        service: 'animation',
        event: 'complete',
        windowId: 'w1',
        data: {'property': 'rotation'},
      ));

      expect(received, equals(AnimatableProperty.rotation));
    });

    test('does not fire when property name is null', () {
      AnimatableProperty? received;
      client.onAnyCompleted('w1', (prop) => received = prop);

      mock.simulateEvent(const NativeEvent(
        service: 'animation',
        event: 'complete',
        windowId: 'w1',
        data: {},
      ));

      expect(received, isNull);
    });
  });
}
