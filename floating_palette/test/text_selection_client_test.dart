import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:floating_palette/src/bridge/event.dart';
import 'package:floating_palette/src/services/text_selection.dart';
import 'package:floating_palette/src/services/text_selection_client.dart';
import 'package:floating_palette/src/testing/mock_native_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNativeBridge mock;
  late TextSelectionClient client;

  setUp(() {
    mock = MockNativeBridge();
    mock.stubDefaults();
    client = TextSelectionClient(mock);
  });

  tearDown(() {
    client.dispose();
    mock.reset();
  });

  // ════════════════════════════════════════════════════════════════════════════
  // checkPermission
  // ════════════════════════════════════════════════════════════════════════════

  group('checkPermission', () {
    test('returns true when granted', () async {
      mock.stubResponse('textSelection', 'checkPermission', {'granted': true});

      final granted = await client.checkPermission();

      expect(granted, isTrue);
      expect(mock.wasCalled('textSelection', 'checkPermission'), isTrue);
    });

    test('returns false when denied', () async {
      mock.stubResponse('textSelection', 'checkPermission', {'granted': false});

      final granted = await client.checkPermission();

      expect(granted, isFalse);
    });

    test('returns false on null response', () async {
      final granted = await client.checkPermission();

      expect(granted, isFalse);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // requestPermission
  // ════════════════════════════════════════════════════════════════════════════

  group('requestPermission', () {
    test('sends correct command', () async {
      await client.requestPermission();

      expect(mock.wasCalled('textSelection', 'requestPermission'), isTrue);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // getSelection
  // ════════════════════════════════════════════════════════════════════════════

  group('getSelection', () {
    test('parses response into SelectedText', () async {
      mock.stubResponse('textSelection', 'getSelection', {
        'text': 'Hello World',
        'x': 120.0,
        'y': 340.0,
        'width': 85.0,
        'height': 16.0,
        'appBundleId': 'com.google.Chrome',
        'appName': 'Google Chrome',
      });

      final selection = await client.getSelection();

      expect(selection, isNotNull);
      expect(selection!.text, equals('Hello World'));
      expect(selection.bounds, equals(const Rect.fromLTWH(120, 340, 85, 16)));
      expect(selection.appBundleId, equals('com.google.Chrome'));
      expect(selection.appName, equals('Google Chrome'));
    });

    test('returns null on null response', () async {
      final selection = await client.getSelection();

      expect(selection, isNull);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // startMonitoring / stopMonitoring
  // ════════════════════════════════════════════════════════════════════════════

  group('startMonitoring', () {
    test('sends correct command', () async {
      await client.startMonitoring();

      expect(mock.wasCalled('textSelection', 'startMonitoring'), isTrue);
    });
  });

  group('stopMonitoring', () {
    test('sends correct command', () async {
      await client.stopMonitoring();

      expect(mock.wasCalled('textSelection', 'stopMonitoring'), isTrue);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // Events
  // ════════════════════════════════════════════════════════════════════════════

  group('onSelectionChanged', () {
    test('fires callback with parsed SelectedText', () {
      SelectedText? received;
      client.onSelectionChanged((selection) => received = selection);

      mock.simulateEvent(const NativeEvent(
        service: 'textSelection',
        event: 'selectionChanged',
        data: {
          'text': 'selected text',
          'x': 100.0,
          'y': 200.0,
          'width': 150.0,
          'height': 20.0,
          'appBundleId': 'com.apple.Safari',
          'appName': 'Safari',
        },
      ));

      expect(received, isNotNull);
      expect(received!.text, equals('selected text'));
      expect(received!.bounds, equals(const Rect.fromLTWH(100, 200, 150, 20)));
      expect(received!.appBundleId, equals('com.apple.Safari'));
      expect(received!.appName, equals('Safari'));
    });
  });

  group('onSelectionCleared', () {
    test('fires callback', () {
      var cleared = false;
      client.onSelectionCleared(() => cleared = true);

      mock.simulateEvent(const NativeEvent(
        service: 'textSelection',
        event: 'selectionCleared',
        data: {},
      ));

      expect(cleared, isTrue);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // SelectedText.fromMap
  // ════════════════════════════════════════════════════════════════════════════

  group('SelectedText.fromMap', () {
    test('parses all fields', () {
      final selection = SelectedText.fromMap({
        'text': 'test',
        'x': 10.0,
        'y': 20.0,
        'width': 100.0,
        'height': 14.0,
        'appBundleId': 'com.example.app',
        'appName': 'Example',
      });

      expect(selection.text, equals('test'));
      expect(selection.bounds, equals(const Rect.fromLTWH(10, 20, 100, 14)));
      expect(selection.appBundleId, equals('com.example.app'));
      expect(selection.appName, equals('Example'));
    });

    test('handles missing fields with defaults', () {
      final selection = SelectedText.fromMap({});

      expect(selection.text, equals(''));
      expect(selection.bounds, equals(Rect.zero));
      expect(selection.appBundleId, equals(''));
      expect(selection.appName, equals(''));
    });

    test('handles missing bounds gracefully', () {
      final selection = SelectedText.fromMap({
        'text': 'no bounds',
        'appBundleId': 'com.app',
        'appName': 'App',
      });

      expect(selection.text, equals('no bounds'));
      expect(selection.bounds, equals(Rect.zero));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // dispose
  // ════════════════════════════════════════════════════════════════════════════

  group('dispose', () {
    test('cleans up event subscriptions', () {
      SelectedText? received;
      client.onSelectionChanged((selection) => received = selection);

      client.dispose();

      mock.simulateEvent(const NativeEvent(
        service: 'textSelection',
        event: 'selectionChanged',
        data: {
          'text': 'after dispose',
          'x': 0.0,
          'y': 0.0,
          'width': 0.0,
          'height': 0.0,
          'appBundleId': '',
          'appName': '',
        },
      ));

      expect(received, isNull);
    });
  });
}
