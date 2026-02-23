import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:floating_palette/src/config/palette_appearance.dart';
import 'package:floating_palette/src/services/appearance_client.dart';
import 'package:floating_palette/src/testing/mock_native_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNativeBridge mock;
  late AppearanceClient client;

  setUp(() {
    mock = MockNativeBridge();
    mock.stubDefaults();
    client = AppearanceClient(mock);
  });

  tearDown(() {
    client.dispose();
    mock.reset();
  });

  // ════════════════════════════════════════════════════════════════════════════
  // setCornerRadius
  // ════════════════════════════════════════════════════════════════════════════

  group('setCornerRadius', () {
    test('sends correct service, command, windowId and params', () async {
      await client.setCornerRadius('w1', 16.0);

      expect(mock.sentCommands, hasLength(1));
      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('appearance'));
      expect(cmd.command, equals('setCornerRadius'));
      expect(cmd.windowId, equals('w1'));
      expect(cmd.params['radius'], equals(16.0));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // setShadow
  // ════════════════════════════════════════════════════════════════════════════

  group('setShadow', () {
    test('sends shadow name', () async {
      await client.setShadow('w1', PaletteShadow.large);

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('appearance'));
      expect(cmd.command, equals('setShadow'));
      expect(cmd.windowId, equals('w1'));
      expect(cmd.params['shadow'], equals('large'));
    });

    test('sends none shadow', () async {
      await client.setShadow('w1', PaletteShadow.none);

      final cmd = mock.sentCommands.first;
      expect(cmd.params['shadow'], equals('none'));
    });

    test('sends small shadow', () async {
      await client.setShadow('w1', PaletteShadow.small);

      final cmd = mock.sentCommands.first;
      expect(cmd.params['shadow'], equals('small'));
    });

    test('sends medium shadow', () async {
      await client.setShadow('w1', PaletteShadow.medium);

      final cmd = mock.sentCommands.first;
      expect(cmd.params['shadow'], equals('medium'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // setBackgroundColor
  // ════════════════════════════════════════════════════════════════════════════

  group('setBackgroundColor', () {
    test('sends color as ARGB32 integer', () async {
      await client.setBackgroundColor('w1', const Color(0xFF00FF00));

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('appearance'));
      expect(cmd.command, equals('setBackgroundColor'));
      expect(cmd.windowId, equals('w1'));
      expect(cmd.params['color'], equals(const Color(0xFF00FF00).toARGB32()));
    });

    test('sends null color', () async {
      await client.setBackgroundColor('w1', null);

      final cmd = mock.sentCommands.first;
      expect(cmd.params['color'], isNull);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // setTransparent
  // ════════════════════════════════════════════════════════════════════════════

  group('setTransparent', () {
    test('sends transparent true', () async {
      await client.setTransparent('w1', true);

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('appearance'));
      expect(cmd.command, equals('setTransparent'));
      expect(cmd.windowId, equals('w1'));
      expect(cmd.params['transparent'], isTrue);
    });

    test('sends transparent false', () async {
      await client.setTransparent('w1', false);

      final cmd = mock.sentCommands.first;
      expect(cmd.params['transparent'], isFalse);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // setBlur
  // ════════════════════════════════════════════════════════════════════════════

  group('setBlur', () {
    test('sends default params', () async {
      await client.setBlur('w1');

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('appearance'));
      expect(cmd.command, equals('setBlur'));
      expect(cmd.windowId, equals('w1'));
      expect(cmd.params['enabled'], isTrue);
      expect(cmd.params['material'], equals('hudWindow'));
    });

    test('sends disabled blur', () async {
      await client.setBlur('w1', enabled: false);

      final cmd = mock.sentCommands.first;
      expect(cmd.params['enabled'], isFalse);
    });

    test('sends custom material', () async {
      await client.setBlur('w1', material: 'sidebar');

      final cmd = mock.sentCommands.first;
      expect(cmd.params['material'], equals('sidebar'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // applyAppearance
  // ════════════════════════════════════════════════════════════════════════════

  group('applyAppearance', () {
    test('sends full appearance config', () async {
      await client.applyAppearance('w1', const PaletteAppearance(
        cornerRadius: 20,
        shadow: PaletteShadow.large,
        transparent: true,
      ));

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('appearance'));
      expect(cmd.command, equals('applyAppearance'));
      expect(cmd.windowId, equals('w1'));
      expect(cmd.params['cornerRadius'], equals(20.0));
      expect(cmd.params['shadow'], equals('large'));
      expect(cmd.params['transparent'], isTrue);
    });

    test('includes backgroundColor when set', () async {
      await client.applyAppearance('w1', const PaletteAppearance(
        backgroundColor: Color(0xFFFF0000),
      ));

      final cmd = mock.sentCommands.first;
      expect(cmd.params['backgroundColor'], equals(const Color(0xFFFF0000).toARGB32()));
    });

    test('omits backgroundColor when null', () async {
      await client.applyAppearance('w1', const PaletteAppearance());

      final cmd = mock.sentCommands.first;
      expect(cmd.params.containsKey('backgroundColor'), isFalse);
    });
  });
}
