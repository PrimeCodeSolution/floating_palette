import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:floating_palette/src/bridge/event.dart';
import 'package:floating_palette/src/services/frame_client.dart';
import 'package:floating_palette/src/testing/mock_native_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNativeBridge mock;
  late FrameClient client;

  setUp(() {
    mock = MockNativeBridge();
    mock.stubDefaults();
    client = FrameClient(mock);
  });

  tearDown(() {
    client.dispose();
    mock.reset();
  });

  // ════════════════════════════════════════════════════════════════════════════
  // setPosition
  // ════════════════════════════════════════════════════════════════════════════

  group('setPosition', () {
    test('sends correct service, command, windowId and params', () async {
      await client.setPosition('w1', const Offset(100, 200));

      expect(mock.sentCommands, hasLength(1));
      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('frame'));
      expect(cmd.command, equals('setPosition'));
      expect(cmd.windowId, equals('w1'));
      expect(cmd.params['x'], equals(100.0));
      expect(cmd.params['y'], equals(200.0));
      expect(cmd.params['animate'], isFalse);
    });

    test('passes anchor when provided', () async {
      await client.setPosition('w1', const Offset(50, 75), anchor: 'center');

      final cmd = mock.sentCommands.first;
      expect(cmd.params['anchor'], equals('center'));
    });

    test('passes animation options', () async {
      await client.setPosition(
        'w1',
        const Offset(10, 20),
        animate: true,
        durationMs: 300,
        curve: 'easeIn',
      );

      final cmd = mock.sentCommands.first;
      expect(cmd.params['animate'], isTrue);
      expect(cmd.params['durationMs'], equals(300));
      expect(cmd.params['curve'], equals('easeIn'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // setSize
  // ════════════════════════════════════════════════════════════════════════════

  group('setSize', () {
    test('sends correct params', () async {
      await client.setSize('w1', const Size(400, 300));

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('frame'));
      expect(cmd.command, equals('setSize'));
      expect(cmd.windowId, equals('w1'));
      expect(cmd.params['width'], equals(400.0));
      expect(cmd.params['height'], equals(300.0));
      expect(cmd.params['animate'], isFalse);
    });

    test('passes animation options', () async {
      await client.setSize(
        'w1',
        const Size(500, 400),
        animate: true,
        durationMs: 200,
        curve: 'easeOut',
      );

      final cmd = mock.sentCommands.first;
      expect(cmd.params['animate'], isTrue);
      expect(cmd.params['durationMs'], equals(200));
      expect(cmd.params['curve'], equals('easeOut'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // setBounds
  // ════════════════════════════════════════════════════════════════════════════

  group('setBounds', () {
    test('sends correct params from Rect', () async {
      await client.setBounds('w1', const Rect.fromLTWH(10, 20, 300, 200));

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('frame'));
      expect(cmd.command, equals('setBounds'));
      expect(cmd.windowId, equals('w1'));
      expect(cmd.params['x'], equals(10.0));
      expect(cmd.params['y'], equals(20.0));
      expect(cmd.params['width'], equals(300.0));
      expect(cmd.params['height'], equals(200.0));
    });

    test('passes animation options', () async {
      await client.setBounds(
        'w1',
        const Rect.fromLTWH(0, 0, 100, 100),
        animate: true,
        durationMs: 500,
      );

      final cmd = mock.sentCommands.first;
      expect(cmd.params['animate'], isTrue);
      expect(cmd.params['durationMs'], equals(500));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // getPosition
  // ════════════════════════════════════════════════════════════════════════════

  group('getPosition', () {
    test('parses response into Offset', () async {
      mock.stubResponse('frame', 'getPosition', {'x': 150.0, 'y': 250.0});

      final result = await client.getPosition('w1');

      expect(result, equals(const Offset(150, 250)));
      expect(mock.wasCalledFor('frame', 'getPosition', 'w1'), isTrue);
    });

    test('returns Offset.zero on null response', () async {
      // No stub => null response
      final result = await client.getPosition('w1');

      expect(result, equals(Offset.zero));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // getSize
  // ════════════════════════════════════════════════════════════════════════════

  group('getSize', () {
    test('parses response into Size', () async {
      mock.stubResponse('frame', 'getSize', {'width': 800.0, 'height': 600.0});

      final result = await client.getSize('w1');

      expect(result, equals(const Size(800, 600)));
    });

    test('returns Size.zero on null response', () async {
      final result = await client.getSize('w1');

      expect(result, equals(Size.zero));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // getBounds
  // ════════════════════════════════════════════════════════════════════════════

  group('getBounds', () {
    test('parses response into Rect', () async {
      mock.stubResponse('frame', 'getBounds', {
        'x': 10.0,
        'y': 20.0,
        'width': 300.0,
        'height': 200.0,
      });

      final result = await client.getBounds('w1');

      expect(result, equals(const Rect.fromLTWH(10, 20, 300, 200)));
    });

    test('returns Rect.zero on null response', () async {
      final result = await client.getBounds('w1');

      expect(result, equals(Rect.zero));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // setDraggable
  // ════════════════════════════════════════════════════════════════════════════

  group('setDraggable', () {
    test('sends draggable true', () async {
      await client.setDraggable('w1', draggable: true);

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('frame'));
      expect(cmd.command, equals('setDraggable'));
      expect(cmd.windowId, equals('w1'));
      expect(cmd.params['draggable'], isTrue);
    });

    test('sends draggable false', () async {
      await client.setDraggable('w1', draggable: false);

      final cmd = mock.sentCommands.first;
      expect(cmd.params['draggable'], isFalse);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // Events
  // ════════════════════════════════════════════════════════════════════════════

  group('onMoved', () {
    test('fires callback with parsed Offset', () {
      Offset? received;
      client.onMoved('w1', (pos) => received = pos);

      mock.simulateEvent(const NativeEvent(
        service: 'frame',
        event: 'moved',
        windowId: 'w1',
        data: {'x': 42.0, 'y': 84.0},
      ));

      expect(received, equals(const Offset(42, 84)));
    });

    test('ignores events for other windows', () {
      Offset? received;
      client.onMoved('w1', (pos) => received = pos);

      mock.simulateEvent(const NativeEvent(
        service: 'frame',
        event: 'moved',
        windowId: 'w2',
        data: {'x': 10.0, 'y': 20.0},
      ));

      expect(received, isNull);
    });
  });

  group('onResized', () {
    test('fires callback with parsed Size', () {
      Size? received;
      client.onResized('w1', (size) => received = size);

      mock.simulateEvent(const NativeEvent(
        service: 'frame',
        event: 'resized',
        windowId: 'w1',
        data: {'width': 640.0, 'height': 480.0},
      ));

      expect(received, equals(const Size(640, 480)));
    });

    test('ignores events for other windows', () {
      Size? received;
      client.onResized('w1', (size) => received = size);

      mock.simulateEvent(const NativeEvent(
        service: 'frame',
        event: 'resized',
        windowId: 'other',
        data: {'width': 100.0, 'height': 100.0},
      ));

      expect(received, isNull);
    });
  });
}
