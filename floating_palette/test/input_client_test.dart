import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:floating_palette/src/bridge/event.dart';
import 'package:floating_palette/src/services/input_client.dart';
import 'package:floating_palette/src/testing/mock_native_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNativeBridge mock;
  late InputClient client;

  setUp(() {
    mock = MockNativeBridge();
    mock.stubDefaults();
    client = InputClient(mock);
  });

  tearDown(() {
    client.dispose();
    mock.reset();
  });

  // ════════════════════════════════════════════════════════════════════════════
  // captureKeyboard
  // ════════════════════════════════════════════════════════════════════════════

  group('captureKeyboard', () {
    test('sends correct service, command, windowId and allKeys flag', () async {
      await client.captureKeyboard('w1', allKeys: true);

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('input'));
      expect(cmd.command, equals('captureKeyboard'));
      expect(cmd.windowId, equals('w1'));
      expect(cmd.params['allKeys'], isTrue);
    });

    test('sends specific key IDs', () async {
      await client.captureKeyboard(
        'w1',
        keys: {LogicalKeyboardKey.escape, LogicalKeyboardKey.enter},
      );

      final cmd = mock.sentCommands.first;
      final keyIds = cmd.params['keys'] as List;
      expect(keyIds, contains(LogicalKeyboardKey.escape.keyId));
      expect(keyIds, contains(LogicalKeyboardKey.enter.keyId));
    });

    test('sends without keys param when keys is null', () async {
      await client.captureKeyboard('w1');

      final cmd = mock.sentCommands.first;
      expect(cmd.params.containsKey('keys'), isFalse);
      expect(cmd.params['allKeys'], isFalse);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // releaseKeyboard
  // ════════════════════════════════════════════════════════════════════════════

  group('releaseKeyboard', () {
    test('sends correct command', () async {
      await client.releaseKeyboard('w1');

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('input'));
      expect(cmd.command, equals('releaseKeyboard'));
      expect(cmd.windowId, equals('w1'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // capturePointer
  // ════════════════════════════════════════════════════════════════════════════

  group('capturePointer', () {
    test('sends correct command', () async {
      await client.capturePointer('w1');

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('input'));
      expect(cmd.command, equals('capturePointer'));
      expect(cmd.windowId, equals('w1'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // releasePointer
  // ════════════════════════════════════════════════════════════════════════════

  group('releasePointer', () {
    test('sends correct command', () async {
      await client.releasePointer('w1');

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('input'));
      expect(cmd.command, equals('releasePointer'));
      expect(cmd.windowId, equals('w1'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // setCursor
  // ════════════════════════════════════════════════════════════════════════════

  group('setCursor', () {
    test('sends cursor kind as param', () async {
      await client.setCursor('w1', SystemMouseCursors.click);

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('input'));
      expect(cmd.command, equals('setCursor'));
      expect(cmd.windowId, equals('w1'));
      expect(cmd.params['cursor'], equals(SystemMouseCursors.click.kind));
    });

    test('sends text cursor kind', () async {
      await client.setCursor('w1', SystemMouseCursors.text);

      final cmd = mock.sentCommands.first;
      expect(cmd.params['cursor'], equals(SystemMouseCursors.text.kind));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // resetCursor
  // ════════════════════════════════════════════════════════════════════════════

  group('resetCursor', () {
    test('sends correct command', () async {
      await client.resetCursor('w1');

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('input'));
      expect(cmd.command, equals('resetCursor'));
      expect(cmd.windowId, equals('w1'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // setPassthrough
  // ════════════════════════════════════════════════════════════════════════════

  group('setPassthrough', () {
    test('sends enabled param', () async {
      await client.setPassthrough('w1');

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('input'));
      expect(cmd.command, equals('setPassthrough'));
      expect(cmd.windowId, equals('w1'));
      expect(cmd.params['enabled'], isTrue);
    });

    test('sends disabled', () async {
      await client.setPassthrough('w1', enabled: false);

      final cmd = mock.sentCommands.first;
      expect(cmd.params['enabled'], isFalse);
    });

    test('sends regions as rect maps', () async {
      await client.setPassthrough(
        'w1',
        regions: [
          const Rect.fromLTWH(0, 0, 100, 50),
          const Rect.fromLTWH(200, 100, 150, 75),
        ],
      );

      final cmd = mock.sentCommands.first;
      final regions = cmd.params['regions'] as List;
      expect(regions, hasLength(2));
      expect(regions[0]['x'], equals(0.0));
      expect(regions[0]['y'], equals(0.0));
      expect(regions[0]['width'], equals(100.0));
      expect(regions[0]['height'], equals(50.0));
      expect(regions[1]['x'], equals(200.0));
    });

    test('omits regions when null', () async {
      await client.setPassthrough('w1');

      final cmd = mock.sentCommands.first;
      expect(cmd.params.containsKey('regions'), isFalse);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // Events
  // ════════════════════════════════════════════════════════════════════════════

  group('onKeyDown', () {
    test('fires callback with parsed key and modifiers', () {
      LogicalKeyboardKey? receivedKey;
      Set<LogicalKeyboardKey>? receivedModifiers;
      client.onKeyDown('w1', (key, modifiers) {
        receivedKey = key;
        receivedModifiers = modifiers;
      });

      mock.simulateEvent(NativeEvent(
        service: 'input',
        event: 'keyDown',
        windowId: 'w1',
        data: {
          'keyId': LogicalKeyboardKey.keyA.keyId,
          'modifiers': [LogicalKeyboardKey.meta.keyId],
        },
      ));

      expect(receivedKey, isNotNull);
      expect(receivedKey!.keyId, equals(LogicalKeyboardKey.keyA.keyId));
      expect(receivedModifiers, hasLength(1));
      expect(receivedModifiers!.first.keyId, equals(LogicalKeyboardKey.meta.keyId));
    });

    test('handles empty modifiers', () {
      Set<LogicalKeyboardKey>? receivedModifiers;
      client.onKeyDown('w1', (key, modifiers) {
        receivedModifiers = modifiers;
      });

      mock.simulateEvent(NativeEvent(
        service: 'input',
        event: 'keyDown',
        windowId: 'w1',
        data: {
          'keyId': LogicalKeyboardKey.escape.keyId,
        },
      ));

      expect(receivedModifiers, isEmpty);
    });

    test('ignores events for other windows', () {
      var fired = false;
      client.onKeyDown('w1', (_, _) => fired = true);

      mock.simulateEvent(NativeEvent(
        service: 'input',
        event: 'keyDown',
        windowId: 'w2',
        data: {'keyId': LogicalKeyboardKey.keyA.keyId},
      ));

      expect(fired, isFalse);
    });
  });

  group('onKeyUp', () {
    test('fires callback with parsed key', () {
      LogicalKeyboardKey? receivedKey;
      client.onKeyUp('w1', (key) => receivedKey = key);

      mock.simulateEvent(NativeEvent(
        service: 'input',
        event: 'keyUp',
        windowId: 'w1',
        data: {'keyId': LogicalKeyboardKey.keyB.keyId},
      ));

      expect(receivedKey, isNotNull);
      expect(receivedKey!.keyId, equals(LogicalKeyboardKey.keyB.keyId));
    });
  });

  group('onClickOutside', () {
    test('fires callback with parsed Offset', () {
      Offset? received;
      client.onClickOutside('w1', (pos) => received = pos);

      mock.simulateEvent(const NativeEvent(
        service: 'input',
        event: 'clickOutside',
        windowId: 'w1',
        data: {'x': 300.0, 'y': 450.0},
      ));

      expect(received, equals(const Offset(300, 450)));
    });
  });

  group('onPointerEnter', () {
    test('fires callback', () {
      var fired = false;
      client.onPointerEnter('w1', () => fired = true);

      mock.simulateEvent(const NativeEvent(
        service: 'input',
        event: 'pointerEnter',
        windowId: 'w1',
        data: {},
      ));

      expect(fired, isTrue);
    });
  });

  group('onPointerExit', () {
    test('fires callback', () {
      var fired = false;
      client.onPointerExit('w1', () => fired = true);

      mock.simulateEvent(const NativeEvent(
        service: 'input',
        event: 'pointerExit',
        windowId: 'w1',
        data: {},
      ));

      expect(fired, isTrue);
    });
  });
}
