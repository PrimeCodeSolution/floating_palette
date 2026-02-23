import 'package:flutter_test/flutter_test.dart';

import 'package:floating_palette/src/bridge/event.dart';
import 'package:floating_palette/src/config/palette_appearance.dart';
import 'package:floating_palette/src/config/palette_size.dart';
import 'package:floating_palette/src/services/window_client.dart';
import 'package:floating_palette/src/testing/mock_native_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNativeBridge mock;
  late WindowClient client;

  setUp(() {
    mock = MockNativeBridge();
    mock.stubDefaults();
    client = WindowClient(mock);
  });

  tearDown(() {
    client.dispose();
    mock.reset();
  });

  // ════════════════════════════════════════════════════════════════════════════
  // create
  // ════════════════════════════════════════════════════════════════════════════

  group('create', () {
    test('sends correct service, command, windowId and params', () async {
      await client.create(
        'test-window',
        appearance: const PaletteAppearance(),
        size: const PaletteSize(width: 400, maxHeight: 300),
      );

      expect(mock.sentCommands, hasLength(1));
      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('window'));
      expect(cmd.command, equals('create'));
      expect(cmd.windowId, equals('test-window'));
      expect(cmd.params['id'], equals('test-window'));
      expect(cmd.params['entryPoint'], equals('paletteMain'));
      expect(cmd.params['cornerRadius'], equals(12.0));
      expect(cmd.params['shadow'], equals('medium'));
      expect(cmd.params['transparent'], isTrue);
      expect(cmd.params['keepAlive'], isFalse);
    });

    test('passes custom entryPoint', () async {
      await client.create(
        'w1',
        appearance: const PaletteAppearance(),
        size: const PaletteSize(width: 200),
        entryPoint: 'customEntry',
      );

      final cmd = mock.sentCommands.first;
      expect(cmd.params['entryPoint'], equals('customEntry'));
    });

    test('passes keepAlive true', () async {
      await client.create(
        'w1',
        appearance: const PaletteAppearance(),
        size: const PaletteSize(width: 200),
        keepAlive: true,
      );

      final cmd = mock.sentCommands.first;
      expect(cmd.params['keepAlive'], isTrue);
    });

    test('returns window ID from stub', () async {
      // stubDefaults sets up a handler that returns the windowId
      final result = await client.create(
        'my-id',
        appearance: const PaletteAppearance(),
        size: const PaletteSize(width: 200),
      );

      expect(result, equals('my-id'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // destroy
  // ════════════════════════════════════════════════════════════════════════════

  group('destroy', () {
    test('sends correct command', () async {
      await client.destroy('w1');

      expect(mock.sentCommands, hasLength(1));
      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('window'));
      expect(cmd.command, equals('destroy'));
      expect(cmd.windowId, equals('w1'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // exists
  // ════════════════════════════════════════════════════════════════════════════

  group('exists', () {
    test('parses true response', () async {
      mock.stubResponse('window', 'exists', true);

      final result = await client.exists('w1');

      expect(result, isTrue);
      expect(mock.wasCalledFor('window', 'exists', 'w1'), isTrue);
    });

    test('returns false on null response', () async {
      final result = await client.exists('w1');

      expect(result, isFalse);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // setEntryPoint
  // ════════════════════════════════════════════════════════════════════════════

  group('setEntryPoint', () {
    test('sends correct params', () async {
      await client.setEntryPoint('w1', 'myEntry');

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('window'));
      expect(cmd.command, equals('setEntryPoint'));
      expect(cmd.windowId, equals('w1'));
      expect(cmd.params['entryPoint'], equals('myEntry'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // Events
  // ════════════════════════════════════════════════════════════════════════════

  group('onCreated', () {
    test('fires callback on created event', () {
      var fired = false;
      client.onCreated('w1', () => fired = true);

      mock.simulateEvent(const NativeEvent(
        service: 'window',
        event: 'created',
        windowId: 'w1',
        data: {},
      ));

      expect(fired, isTrue);
    });

    test('ignores events for other windows', () {
      var fired = false;
      client.onCreated('w1', () => fired = true);

      mock.simulateEvent(const NativeEvent(
        service: 'window',
        event: 'created',
        windowId: 'w2',
        data: {},
      ));

      expect(fired, isFalse);
    });
  });

  group('onDestroyed', () {
    test('fires callback on destroyed event', () {
      var fired = false;
      client.onDestroyed('w1', () => fired = true);

      mock.simulateEvent(const NativeEvent(
        service: 'window',
        event: 'destroyed',
        windowId: 'w1',
        data: {},
      ));

      expect(fired, isTrue);
    });
  });

  group('onContentReady', () {
    test('fires callback on contentReady event', () {
      var fired = false;
      client.onContentReady('w1', () => fired = true);

      mock.simulateEvent(const NativeEvent(
        service: 'window',
        event: 'contentReady',
        windowId: 'w1',
        data: {},
      ));

      expect(fired, isTrue);
    });
  });
}
