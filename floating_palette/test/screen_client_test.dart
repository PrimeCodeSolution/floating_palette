import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:floating_palette/src/bridge/event.dart';
import 'package:floating_palette/src/services/screen_client.dart';
import 'package:floating_palette/src/testing/mock_native_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNativeBridge mock;
  late ScreenClient client;

  setUp(() {
    mock = MockNativeBridge();
    mock.stubDefaults();
    client = ScreenClient(mock);
  });

  tearDown(() {
    client.dispose();
    mock.reset();
  });

  // ════════════════════════════════════════════════════════════════════════════
  // getScreens
  // ════════════════════════════════════════════════════════════════════════════

  group('getScreens', () {
    test('parses list of ScreenInfo from response', () async {
      mock.stubResponse('screen', 'getScreens', [
        {
          'id': 0,
          'frame': {'x': 0.0, 'y': 0.0, 'width': 1920.0, 'height': 1080.0},
          'visibleFrame': {'x': 0.0, 'y': 25.0, 'width': 1920.0, 'height': 1055.0},
          'scaleFactor': 2.0,
          'isPrimary': true,
        },
        {
          'id': 1,
          'frame': {'x': 1920.0, 'y': 0.0, 'width': 2560.0, 'height': 1440.0},
          'visibleFrame': {'x': 1920.0, 'y': 25.0, 'width': 2560.0, 'height': 1415.0},
          'scaleFactor': 1.0,
          'isPrimary': false,
        },
      ]);

      final screens = await client.getScreens();

      expect(screens, hasLength(2));
      expect(screens[0].index, equals(0));
      expect(screens[0].bounds, equals(const Rect.fromLTWH(0, 0, 1920, 1080)));
      expect(screens[0].workArea, equals(const Rect.fromLTWH(0, 25, 1920, 1055)));
      expect(screens[0].scaleFactor, equals(2.0));
      expect(screens[0].isPrimary, isTrue);

      expect(screens[1].index, equals(1));
      expect(screens[1].bounds, equals(const Rect.fromLTWH(1920, 0, 2560, 1440)));
      expect(screens[1].isPrimary, isFalse);
    });

    test('returns empty list on null response', () async {
      final screens = await client.getScreens();

      expect(screens, isEmpty);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // getWindowScreen
  // ════════════════════════════════════════════════════════════════════════════

  group('getWindowScreen', () {
    test('parses int response', () async {
      mock.stubResponse('screen', 'getWindowScreen', 1);

      final result = await client.getWindowScreen('w1');

      expect(result, equals(1));
      expect(mock.wasCalledFor('screen', 'getWindowScreen', 'w1'), isTrue);
    });

    test('returns 0 on null response', () async {
      final result = await client.getWindowScreen('w1');

      expect(result, equals(0));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // moveToScreen
  // ════════════════════════════════════════════════════════════════════════════

  group('moveToScreen', () {
    test('sends correct params', () async {
      await client.moveToScreen('w1', 1);

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('screen'));
      expect(cmd.command, equals('moveToScreen'));
      expect(cmd.windowId, equals('w1'));
      expect(cmd.params['screenIndex'], equals(1));
      expect(cmd.params['animate'], isFalse);
    });

    test('passes animation options', () async {
      await client.moveToScreen('w1', 0, animate: true, durationMs: 300);

      final cmd = mock.sentCommands.first;
      expect(cmd.params['animate'], isTrue);
      expect(cmd.params['durationMs'], equals(300));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // getCursorPosition
  // ════════════════════════════════════════════════════════════════════════════

  group('getCursorPosition', () {
    test('parses response into Offset', () async {
      mock.stubResponse('screen', 'getCursorPosition', {'x': 500.0, 'y': 300.0});

      final result = await client.getCursorPosition();

      expect(result, equals(const Offset(500, 300)));
    });

    test('returns Offset.zero on null response', () async {
      final result = await client.getCursorPosition();

      expect(result, equals(Offset.zero));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // getCursorScreen
  // ════════════════════════════════════════════════════════════════════════════

  group('getCursorScreen', () {
    test('parses int response', () async {
      mock.stubResponse('screen', 'getCursorScreen', 2);

      final result = await client.getCursorScreen();

      expect(result, equals(2));
    });

    test('returns 0 on null response', () async {
      final result = await client.getCursorScreen();

      expect(result, equals(0));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // getCurrentScreen
  // ════════════════════════════════════════════════════════════════════════════

  group('getCurrentScreen', () {
    test('parses response into ScreenInfo', () async {
      mock.stubResponse('screen', 'getCurrentScreen', {
        'id': 0,
        'frame': {'x': 0.0, 'y': 0.0, 'width': 1920.0, 'height': 1080.0},
        'visibleFrame': {'x': 0.0, 'y': 25.0, 'width': 1920.0, 'height': 1055.0},
        'scaleFactor': 2.0,
        'isPrimary': true,
      });

      final result = await client.getCurrentScreen('w1');

      expect(result, isNotNull);
      expect(result!.index, equals(0));
      expect(result.bounds, equals(const Rect.fromLTWH(0, 0, 1920, 1080)));
      expect(result.workArea, equals(const Rect.fromLTWH(0, 25, 1920, 1055)));
      expect(result.scaleFactor, equals(2.0));
      expect(result.isPrimary, isTrue);
    });

    test('returns null on null response', () async {
      final result = await client.getCurrentScreen('w1');

      expect(result, isNull);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // getActiveAppBounds
  // ════════════════════════════════════════════════════════════════════════════

  group('getActiveAppBounds', () {
    test('parses response into ActiveAppInfo', () async {
      mock.stubResponse('screen', 'getActiveAppBounds', {
        'x': 100.0,
        'y': 50.0,
        'width': 800.0,
        'height': 600.0,
        'appName': 'Xcode',
      });

      final result = await client.getActiveAppBounds();

      expect(result, isNotNull);
      expect(result!.bounds, equals(const Rect.fromLTWH(100, 50, 800, 600)));
      expect(result.appName, equals('Xcode'));
    });

    test('returns null on null response', () async {
      final result = await client.getActiveAppBounds();

      expect(result, isNull);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // Events
  // ════════════════════════════════════════════════════════════════════════════

  group('onScreensChanged', () {
    test('fires callback with parsed ScreenInfo list', () {
      List<ScreenInfo>? received;
      client.onScreensChanged((screens) => received = screens);

      mock.simulateEvent(NativeEvent(
        service: 'screen',
        event: 'screensChanged',
        data: {
          'screens': [
            {
              'id': 0,
              'frame': {'x': 0.0, 'y': 0.0, 'width': 1920.0, 'height': 1080.0},
              'visibleFrame': {'x': 0.0, 'y': 25.0, 'width': 1920.0, 'height': 1055.0},
              'scaleFactor': 2.0,
              'isPrimary': true,
            },
          ],
        },
      ));

      expect(received, isNotNull);
      expect(received, hasLength(1));
      expect(received![0].index, equals(0));
      expect(received![0].isPrimary, isTrue);
    });

    test('fires callback with empty list when no screens data', () {
      List<ScreenInfo>? received;
      client.onScreensChanged((screens) => received = screens);

      mock.simulateEvent(const NativeEvent(
        service: 'screen',
        event: 'screensChanged',
        data: {},
      ));

      expect(received, isNotNull);
      expect(received, isEmpty);
    });
  });

  group('onWindowScreenChanged', () {
    test('fires callback with parsed screen index', () {
      int? received;
      client.onWindowScreenChanged('w1', (index) => received = index);

      mock.simulateEvent(const NativeEvent(
        service: 'screen',
        event: 'screenChanged',
        windowId: 'w1',
        data: {'screenIndex': 2},
      ));

      expect(received, equals(2));
    });

    test('ignores events for other windows', () {
      int? received;
      client.onWindowScreenChanged('w1', (index) => received = index);

      mock.simulateEvent(const NativeEvent(
        service: 'screen',
        event: 'screenChanged',
        windowId: 'w2',
        data: {'screenIndex': 1},
      ));

      expect(received, isNull);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // ScreenInfo.fromMap
  // ════════════════════════════════════════════════════════════════════════════

  group('ScreenInfo.fromMap', () {
    test('parses nested frame and visibleFrame objects', () {
      final info = ScreenInfo.fromMap({
        'id': 2,
        'frame': {'x': 100.0, 'y': 0.0, 'width': 2560.0, 'height': 1440.0},
        'visibleFrame': {'x': 100.0, 'y': 38.0, 'width': 2560.0, 'height': 1402.0},
        'scaleFactor': 2.0,
        'isPrimary': false,
      });

      expect(info.index, equals(2));
      expect(info.bounds, equals(const Rect.fromLTWH(100, 0, 2560, 1440)));
      expect(info.workArea, equals(const Rect.fromLTWH(100, 38, 2560, 1402)));
      expect(info.scaleFactor, equals(2.0));
      expect(info.isPrimary, isFalse);
    });

    test('handles missing frame data gracefully', () {
      final info = ScreenInfo.fromMap({
        'id': 0,
      });

      expect(info.index, equals(0));
      expect(info.bounds, equals(Rect.zero));
      expect(info.workArea, equals(Rect.zero));
      expect(info.scaleFactor, equals(1.0));
      expect(info.isPrimary, isFalse);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // ActiveAppInfo.fromMap
  // ════════════════════════════════════════════════════════════════════════════

  group('ActiveAppInfo.fromMap', () {
    test('parses bounds and appName', () {
      final info = ActiveAppInfo.fromMap({
        'x': 50.0,
        'y': 100.0,
        'width': 1200.0,
        'height': 800.0,
        'appName': 'Safari',
      });

      expect(info.bounds, equals(const Rect.fromLTWH(50, 100, 1200, 800)));
      expect(info.appName, equals('Safari'));
    });

    test('handles missing fields with defaults', () {
      final info = ActiveAppInfo.fromMap({});

      expect(info.bounds, equals(Rect.zero));
      expect(info.appName, equals(''));
    });
  });
}
