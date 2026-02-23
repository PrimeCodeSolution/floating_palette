import 'package:flutter_test/flutter_test.dart';

import 'package:floating_palette/src/bridge/event.dart';
import 'package:floating_palette/src/services/visibility_client.dart';
import 'package:floating_palette/src/testing/mock_native_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNativeBridge mock;
  late VisibilityClient client;

  setUp(() {
    mock = MockNativeBridge();
    mock.stubDefaults();
    client = VisibilityClient(mock);
  });

  tearDown(() {
    client.dispose();
    mock.reset();
  });

  // ════════════════════════════════════════════════════════════════════════════
  // show
  // ════════════════════════════════════════════════════════════════════════════

  group('show', () {
    test('sends correct service, command, windowId and default params', () async {
      await client.show('w1');

      expect(mock.sentCommands, hasLength(1));
      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('visibility'));
      expect(cmd.command, equals('show'));
      expect(cmd.windowId, equals('w1'));
      expect(cmd.params['animate'], isTrue);
      expect(cmd.params['focus'], isTrue);
    });

    test('passes custom animate and focus options', () async {
      await client.show('w1', animate: false, focus: false);

      final cmd = mock.sentCommands.first;
      expect(cmd.params['animate'], isFalse);
      expect(cmd.params['focus'], isFalse);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // hide
  // ════════════════════════════════════════════════════════════════════════════

  group('hide', () {
    test('sends correct params with default animate', () async {
      await client.hide('w1');

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('visibility'));
      expect(cmd.command, equals('hide'));
      expect(cmd.windowId, equals('w1'));
      expect(cmd.params['animate'], isTrue);
    });

    test('passes animate false', () async {
      await client.hide('w1', animate: false);

      final cmd = mock.sentCommands.first;
      expect(cmd.params['animate'], isFalse);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // setOpacity
  // ════════════════════════════════════════════════════════════════════════════

  group('setOpacity', () {
    test('sends correct params', () async {
      await client.setOpacity('w1', 0.5);

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('visibility'));
      expect(cmd.command, equals('setOpacity'));
      expect(cmd.windowId, equals('w1'));
      expect(cmd.params['opacity'], equals(0.5));
      expect(cmd.params['animate'], isFalse);
    });

    test('passes animation options', () async {
      await client.setOpacity('w1', 0.8, animate: true, durationMs: 150);

      final cmd = mock.sentCommands.first;
      expect(cmd.params['animate'], isTrue);
      expect(cmd.params['durationMs'], equals(150));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // isVisible
  // ════════════════════════════════════════════════════════════════════════════

  group('isVisible', () {
    test('parses true response', () async {
      mock.stubResponse('visibility', 'isVisible', true);

      final result = await client.isVisible('w1');

      expect(result, isTrue);
      expect(mock.wasCalledFor('visibility', 'isVisible', 'w1'), isTrue);
    });

    test('parses false response', () async {
      mock.stubResponse('visibility', 'isVisible', false);

      final result = await client.isVisible('w1');

      expect(result, isFalse);
    });

    test('returns false on null response', () async {
      final result = await client.isVisible('w1');

      expect(result, isFalse);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // getOpacity
  // ════════════════════════════════════════════════════════════════════════════

  group('getOpacity', () {
    test('parses double response', () async {
      mock.stubResponse('visibility', 'getOpacity', 0.75);

      final result = await client.getOpacity('w1');

      expect(result, equals(0.75));
    });

    test('returns 1.0 on null response', () async {
      final result = await client.getOpacity('w1');

      expect(result, equals(1.0));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // Events
  // ════════════════════════════════════════════════════════════════════════════

  group('onShown', () {
    test('fires callback when shown event received', () {
      var fired = false;
      client.onShown('w1', () => fired = true);

      mock.simulateEvent(const NativeEvent(
        service: 'visibility',
        event: 'shown',
        windowId: 'w1',
        data: {},
      ));

      expect(fired, isTrue);
    });

    test('ignores events for other windows', () {
      var fired = false;
      client.onShown('w1', () => fired = true);

      mock.simulateEvent(const NativeEvent(
        service: 'visibility',
        event: 'shown',
        windowId: 'w2',
        data: {},
      ));

      expect(fired, isFalse);
    });
  });

  group('onHidden', () {
    test('fires callback when hidden event received', () {
      var fired = false;
      client.onHidden('w1', () => fired = true);

      mock.simulateEvent(const NativeEvent(
        service: 'visibility',
        event: 'hidden',
        windowId: 'w1',
        data: {},
      ));

      expect(fired, isTrue);
    });
  });

  group('onShowStart', () {
    test('fires callback when showStart event received', () {
      var fired = false;
      client.onShowStart('w1', () => fired = true);

      mock.simulateEvent(const NativeEvent(
        service: 'visibility',
        event: 'showStart',
        windowId: 'w1',
        data: {},
      ));

      expect(fired, isTrue);
    });
  });

  group('onHideStart', () {
    test('fires callback when hideStart event received', () {
      var fired = false;
      client.onHideStart('w1', () => fired = true);

      mock.simulateEvent(const NativeEvent(
        service: 'visibility',
        event: 'hideStart',
        windowId: 'w1',
        data: {},
      ));

      expect(fired, isTrue);
    });
  });
}
