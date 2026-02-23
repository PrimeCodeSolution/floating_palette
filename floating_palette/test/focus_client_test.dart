import 'package:flutter_test/flutter_test.dart';

import 'package:floating_palette/src/bridge/event.dart';
import 'package:floating_palette/src/config/palette_behavior.dart';
import 'package:floating_palette/src/services/focus_client.dart';
import 'package:floating_palette/src/testing/mock_native_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNativeBridge mock;
  late FocusClient client;

  setUp(() {
    mock = MockNativeBridge();
    mock.stubDefaults();
    client = FocusClient(mock);
  });

  tearDown(() {
    client.dispose();
    mock.reset();
  });

  // ════════════════════════════════════════════════════════════════════════════
  // focus
  // ════════════════════════════════════════════════════════════════════════════

  group('focus', () {
    test('sends correct service, command and windowId', () async {
      await client.focus('w1');

      expect(mock.sentCommands, hasLength(1));
      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('focus'));
      expect(cmd.command, equals('focus'));
      expect(cmd.windowId, equals('w1'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // unfocus
  // ════════════════════════════════════════════════════════════════════════════

  group('unfocus', () {
    test('sends correct command', () async {
      await client.unfocus('w1');

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('focus'));
      expect(cmd.command, equals('unfocus'));
      expect(cmd.windowId, equals('w1'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // setPolicy
  // ════════════════════════════════════════════════════════════════════════════

  group('setPolicy', () {
    test('sends policy name as param', () async {
      await client.setPolicy('w1', FocusPolicy.steal);

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('focus'));
      expect(cmd.command, equals('setPolicy'));
      expect(cmd.windowId, equals('w1'));
      expect(cmd.params['policy'], equals('steal'));
    });

    test('sends request policy', () async {
      await client.setPolicy('w1', FocusPolicy.request);

      final cmd = mock.sentCommands.first;
      expect(cmd.params['policy'], equals('request'));
    });

    test('sends none policy', () async {
      await client.setPolicy('w1', FocusPolicy.none);

      final cmd = mock.sentCommands.first;
      expect(cmd.params['policy'], equals('none'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // hasFocus (sends 'isFocused' command)
  // ════════════════════════════════════════════════════════════════════════════

  group('hasFocus', () {
    test('sends isFocused command (not hasFocus)', () async {
      mock.stubResponse('focus', 'isFocused', true);

      await client.hasFocus('w1');

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('focus'));
      expect(cmd.command, equals('isFocused'));
      expect(cmd.windowId, equals('w1'));
    });

    test('parses true response', () async {
      mock.stubResponse('focus', 'isFocused', true);

      final result = await client.hasFocus('w1');

      expect(result, isTrue);
    });

    test('returns false on null response', () async {
      final result = await client.hasFocus('w1');

      expect(result, isFalse);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // focusMainWindow
  // ════════════════════════════════════════════════════════════════════════════

  group('focusMainWindow', () {
    test('sends global command without windowId', () async {
      await client.focusMainWindow();

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('focus'));
      expect(cmd.command, equals('focusMainWindow'));
      expect(cmd.windowId, isNull);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // hideApp
  // ════════════════════════════════════════════════════════════════════════════

  group('hideApp', () {
    test('sends global command without windowId', () async {
      await client.hideApp();

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('focus'));
      expect(cmd.command, equals('hideApp'));
      expect(cmd.windowId, isNull);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // restoreFocus
  // ════════════════════════════════════════════════════════════════════════════

  group('restoreFocus', () {
    test('does nothing for FocusRestoreMode.none', () async {
      await client.restoreFocus(FocusRestoreMode.none);

      expect(mock.sentCommands, isEmpty);
    });

    test('calls focusMainWindow for mainWindow mode', () async {
      await client.restoreFocus(FocusRestoreMode.mainWindow);

      expect(mock.wasCalled('focus', 'focusMainWindow'), isTrue);
    });

    test('calls hideApp for previousApp mode', () async {
      await client.restoreFocus(FocusRestoreMode.previousApp);

      expect(mock.wasCalled('focus', 'hideApp'), isTrue);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // Events
  // ════════════════════════════════════════════════════════════════════════════

  group('onFocused', () {
    test('fires callback on focused event', () {
      var fired = false;
      client.onFocused('w1', () => fired = true);

      mock.simulateEvent(const NativeEvent(
        service: 'focus',
        event: 'focused',
        windowId: 'w1',
        data: {},
      ));

      expect(fired, isTrue);
    });

    test('ignores events for other windows', () {
      var fired = false;
      client.onFocused('w1', () => fired = true);

      mock.simulateEvent(const NativeEvent(
        service: 'focus',
        event: 'focused',
        windowId: 'w2',
        data: {},
      ));

      expect(fired, isFalse);
    });
  });

  group('onUnfocused', () {
    test('fires callback on unfocused event', () {
      var fired = false;
      client.onUnfocused('w1', () => fired = true);

      mock.simulateEvent(const NativeEvent(
        service: 'focus',
        event: 'unfocused',
        windowId: 'w1',
        data: {},
      ));

      expect(fired, isTrue);
    });
  });
}
