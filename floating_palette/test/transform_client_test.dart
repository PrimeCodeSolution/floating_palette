import 'dart:math' show pi;

import 'package:flutter/painting.dart' show Alignment;
import 'package:flutter_test/flutter_test.dart';

import 'package:floating_palette/src/services/transform_client.dart';
import 'package:floating_palette/src/testing/mock_native_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNativeBridge mock;
  late TransformClient client;

  setUp(() {
    mock = MockNativeBridge();
    mock.stubDefaults();
    client = TransformClient(mock);
  });

  tearDown(() {
    client.dispose();
    mock.reset();
  });

  // ════════════════════════════════════════════════════════════════════════════
  // setScale
  // ════════════════════════════════════════════════════════════════════════════

  group('setScale', () {
    test('sends correct service, command, windowId and params', () async {
      await client.setScale('w1', 2.0);

      expect(mock.sentCommands, hasLength(1));
      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('transform'));
      expect(cmd.command, equals('setScale'));
      expect(cmd.windowId, equals('w1'));
      expect(cmd.params['scale'], equals(2.0));
      expect(cmd.params['anchorX'], equals(0.0)); // Alignment.center
      expect(cmd.params['anchorY'], equals(0.0));
      expect(cmd.params['animate'], isFalse);
    });

    test('passes custom anchor', () async {
      await client.setScale('w1', 1.5, anchor: Alignment.topLeft);

      final cmd = mock.sentCommands.first;
      expect(cmd.params['anchorX'], equals(-1.0));
      expect(cmd.params['anchorY'], equals(-1.0));
    });

    test('passes animation options', () async {
      await client.setScale(
        'w1',
        0.5,
        animate: true,
        durationMs: 200,
        curve: 'easeInOut',
      );

      final cmd = mock.sentCommands.first;
      expect(cmd.params['animate'], isTrue);
      expect(cmd.params['durationMs'], equals(200));
      expect(cmd.params['curve'], equals('easeInOut'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // setRotation
  // ════════════════════════════════════════════════════════════════════════════

  group('setRotation', () {
    test('converts radians to degrees', () async {
      await client.setRotation('w1', pi); // 180 degrees

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('transform'));
      expect(cmd.command, equals('setRotation'));
      expect(cmd.windowId, equals('w1'));
      expect(cmd.params['degrees'], closeTo(180.0, 0.001));
    });

    test('converts pi/2 to 90 degrees', () async {
      await client.setRotation('w1', pi / 2);

      final cmd = mock.sentCommands.first;
      expect(cmd.params['degrees'], closeTo(90.0, 0.001));
    });

    test('converts 0 to 0 degrees', () async {
      await client.setRotation('w1', 0);

      final cmd = mock.sentCommands.first;
      expect(cmd.params['degrees'], equals(0.0));
    });

    test('passes anchor and animation options', () async {
      await client.setRotation(
        'w1',
        pi / 4,
        anchor: Alignment.bottomRight,
        animate: true,
        durationMs: 300,
        curve: 'linear',
      );

      final cmd = mock.sentCommands.first;
      expect(cmd.params['degrees'], closeTo(45.0, 0.001));
      expect(cmd.params['anchorX'], equals(1.0));
      expect(cmd.params['anchorY'], equals(1.0));
      expect(cmd.params['animate'], isTrue);
      expect(cmd.params['durationMs'], equals(300));
      expect(cmd.params['curve'], equals('linear'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // setFlip
  // ════════════════════════════════════════════════════════════════════════════

  group('setFlip', () {
    test('sends correct params with defaults', () async {
      await client.setFlip('w1');

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('transform'));
      expect(cmd.command, equals('setFlip'));
      expect(cmd.windowId, equals('w1'));
      expect(cmd.params['horizontal'], isFalse);
      expect(cmd.params['vertical'], isFalse);
      expect(cmd.params['animate'], isFalse);
    });

    test('sends horizontal flip', () async {
      await client.setFlip('w1', horizontal: true);

      final cmd = mock.sentCommands.first;
      expect(cmd.params['horizontal'], isTrue);
      expect(cmd.params['vertical'], isFalse);
    });

    test('sends vertical flip with animation', () async {
      await client.setFlip(
        'w1',
        vertical: true,
        animate: true,
        durationMs: 400,
      );

      final cmd = mock.sentCommands.first;
      expect(cmd.params['vertical'], isTrue);
      expect(cmd.params['animate'], isTrue);
      expect(cmd.params['durationMs'], equals(400));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // reset
  // ════════════════════════════════════════════════════════════════════════════

  group('reset', () {
    test('sends correct command', () async {
      await client.reset('w1');

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('transform'));
      expect(cmd.command, equals('reset'));
      expect(cmd.windowId, equals('w1'));
      expect(cmd.params['animate'], isFalse);
    });

    test('passes animation options', () async {
      await client.reset('w1', animate: true, durationMs: 250);

      final cmd = mock.sentCommands.first;
      expect(cmd.params['animate'], isTrue);
      expect(cmd.params['durationMs'], equals(250));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // getScale
  // ════════════════════════════════════════════════════════════════════════════

  group('getScale', () {
    test('parses double response', () async {
      mock.stubResponse('transform', 'getScale', 2.5);

      final result = await client.getScale('w1');

      expect(result, equals(2.5));
    });

    test('returns 1.0 on null response', () async {
      final result = await client.getScale('w1');

      expect(result, equals(1.0));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // getRotation
  // ════════════════════════════════════════════════════════════════════════════

  group('getRotation', () {
    test('parses double response', () async {
      mock.stubResponse('transform', 'getRotation', 45.0);

      final result = await client.getRotation('w1');

      expect(result, equals(45.0));
    });

    test('returns 0.0 on null response', () async {
      final result = await client.getRotation('w1');

      expect(result, equals(0.0));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // getFlip
  // ════════════════════════════════════════════════════════════════════════════

  group('getFlip', () {
    test('parses response into record', () async {
      mock.stubResponse('transform', 'getFlip', {
        'horizontal': true,
        'vertical': false,
      });

      final result = await client.getFlip('w1');

      expect(result.horizontal, isTrue);
      expect(result.vertical, isFalse);
    });

    test('returns (false, false) on null response', () async {
      final result = await client.getFlip('w1');

      expect(result.horizontal, isFalse);
      expect(result.vertical, isFalse);
    });
  });
}
