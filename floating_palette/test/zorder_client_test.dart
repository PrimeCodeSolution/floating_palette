import 'package:flutter_test/flutter_test.dart';

import 'package:floating_palette/src/bridge/event.dart';
import 'package:floating_palette/src/services/zorder_client.dart';
import 'package:floating_palette/src/testing/mock_native_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNativeBridge mock;
  late ZOrderClient client;

  setUp(() {
    mock = MockNativeBridge();
    mock.stubDefaults();
    client = ZOrderClient(mock);
  });

  tearDown(() {
    client.dispose();
    mock.reset();
  });

  // ════════════════════════════════════════════════════════════════════════════
  // bringToFront
  // ════════════════════════════════════════════════════════════════════════════

  group('bringToFront', () {
    test('sends correct service, command and windowId', () async {
      await client.bringToFront('w1');

      expect(mock.sentCommands, hasLength(1));
      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('zorder'));
      expect(cmd.command, equals('bringToFront'));
      expect(cmd.windowId, equals('w1'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // sendToBack
  // ════════════════════════════════════════════════════════════════════════════

  group('sendToBack', () {
    test('sends correct command', () async {
      await client.sendToBack('w1');

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('zorder'));
      expect(cmd.command, equals('sendToBack'));
      expect(cmd.windowId, equals('w1'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // moveAbove
  // ════════════════════════════════════════════════════════════════════════════

  group('moveAbove', () {
    test('sends correct params with otherId', () async {
      await client.moveAbove('w1', 'w2');

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('zorder'));
      expect(cmd.command, equals('moveAbove'));
      expect(cmd.windowId, equals('w1'));
      expect(cmd.params['otherId'], equals('w2'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // moveBelow
  // ════════════════════════════════════════════════════════════════════════════

  group('moveBelow', () {
    test('sends correct params with otherId', () async {
      await client.moveBelow('w1', 'w2');

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('zorder'));
      expect(cmd.command, equals('moveBelow'));
      expect(cmd.windowId, equals('w1'));
      expect(cmd.params['otherId'], equals('w2'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // setZIndex
  // ════════════════════════════════════════════════════════════════════════════

  group('setZIndex', () {
    test('sends correct params with index', () async {
      await client.setZIndex('w1', 5);

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('zorder'));
      expect(cmd.command, equals('setZIndex'));
      expect(cmd.windowId, equals('w1'));
      expect(cmd.params['index'], equals(5));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // pin
  // ════════════════════════════════════════════════════════════════════════════

  group('pin', () {
    test('sends default pin level', () async {
      await client.pin('w1');

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('zorder'));
      expect(cmd.command, equals('pin'));
      expect(cmd.windowId, equals('w1'));
      expect(cmd.params['level'], equals('abovePalettes'));
    });

    test('sends custom pin level', () async {
      await client.pin('w1', level: PinLevel.aboveAll);

      final cmd = mock.sentCommands.first;
      expect(cmd.params['level'], equals('aboveAll'));
    });

    test('sends aboveApp pin level', () async {
      await client.pin('w1', level: PinLevel.aboveApp);

      final cmd = mock.sentCommands.first;
      expect(cmd.params['level'], equals('aboveApp'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // unpin
  // ════════════════════════════════════════════════════════════════════════════

  group('unpin', () {
    test('sends correct command', () async {
      await client.unpin('w1');

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('zorder'));
      expect(cmd.command, equals('unpin'));
      expect(cmd.windowId, equals('w1'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // getZIndex
  // ════════════════════════════════════════════════════════════════════════════

  group('getZIndex', () {
    test('parses int response', () async {
      mock.stubResponse('zorder', 'getZIndex', 3);

      final result = await client.getZIndex('w1');

      expect(result, equals(3));
      expect(mock.wasCalledFor('zorder', 'getZIndex', 'w1'), isTrue);
    });

    test('returns 0 on null response', () async {
      final result = await client.getZIndex('w1');

      expect(result, equals(0));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // isPinned
  // ════════════════════════════════════════════════════════════════════════════

  group('isPinned', () {
    test('parses true response', () async {
      mock.stubResponse('zorder', 'isPinned', true);

      final result = await client.isPinned('w1');

      expect(result, isTrue);
    });

    test('returns false on null response', () async {
      final result = await client.isPinned('w1');

      expect(result, isFalse);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // Events
  // ════════════════════════════════════════════════════════════════════════════

  group('onZOrderChanged', () {
    test('fires callback with parsed index', () {
      int? received;
      client.onZOrderChanged('w1', (index) => received = index);

      mock.simulateEvent(const NativeEvent(
        service: 'zorder',
        event: 'zOrderChanged',
        windowId: 'w1',
        data: {'index': 7},
      ));

      expect(received, equals(7));
    });

    test('ignores events for other windows', () {
      int? received;
      client.onZOrderChanged('w1', (index) => received = index);

      mock.simulateEvent(const NativeEvent(
        service: 'zorder',
        event: 'zOrderChanged',
        windowId: 'w2',
        data: {'index': 3},
      ));

      expect(received, isNull);
    });
  });
}
