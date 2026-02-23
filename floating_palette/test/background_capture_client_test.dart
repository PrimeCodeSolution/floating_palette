import 'package:flutter/painting.dart' show EdgeInsets;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:floating_palette/src/services/background_capture_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BackgroundCaptureClient client;
  final channel = const MethodChannel('floating_palette/self');

  setUp(() {
    client = BackgroundCaptureClient();
  });

  tearDown(() {
    client.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  // ════════════════════════════════════════════════════════════════════════════
  // checkPermission
  // ════════════════════════════════════════════════════════════════════════════

  group('checkPermission', () {
    test('returns granted', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'backgroundCapture.checkPermission') {
          return 'granted';
        }
        return null;
      });

      final result = await client.checkPermission();

      expect(result, equals(BackgroundCapturePermission.granted));
    });

    test('returns denied', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'backgroundCapture.checkPermission') {
          return 'denied';
        }
        return null;
      });

      final result = await client.checkPermission();

      expect(result, equals(BackgroundCapturePermission.denied));
    });

    test('returns restricted', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'backgroundCapture.checkPermission') {
          return 'restricted';
        }
        return null;
      });

      final result = await client.checkPermission();

      expect(result, equals(BackgroundCapturePermission.restricted));
    });

    test('returns notDetermined for unknown value', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'backgroundCapture.checkPermission') {
          return 'something_else';
        }
        return null;
      });

      final result = await client.checkPermission();

      expect(result, equals(BackgroundCapturePermission.notDetermined));
    });

    test('returns notDetermined on PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'backgroundCapture.checkPermission') {
          throw PlatformException(code: 'ERROR', message: 'test error');
        }
        return null;
      });

      final result = await client.checkPermission();

      expect(result, equals(BackgroundCapturePermission.notDetermined));
    });

    test('emits error event on PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'backgroundCapture.checkPermission') {
          throw PlatformException(code: 'ERROR', message: 'test error');
        }
        return null;
      });

      final events = <BackgroundCaptureEvent>[];
      client.events.listen(events.add);

      await client.checkPermission();
      await Future<void>.delayed(Duration.zero); // Let broadcast stream deliver

      expect(events, hasLength(1));
      expect(events.first.type, equals('error'));
      expect(events.first.data['error'], equals('test error'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // requestPermission
  // ════════════════════════════════════════════════════════════════════════════

  group('requestPermission', () {
    test('invokes correct method', () async {
      String? invokedMethod;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        invokedMethod = call.method;
        return null;
      });

      await client.requestPermission();

      expect(invokedMethod, equals('backgroundCapture.requestPermission'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // startCapture
  // ════════════════════════════════════════════════════════════════════════════

  group('startCapture', () {
    test('returns texture ID on success', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'backgroundCapture.start') {
          return 42;
        }
        return null;
      });

      final result = await client.startCapture();

      expect(result, equals(42));
    });

    test('passes config params', () async {
      Map<dynamic, dynamic>? receivedArgs;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'backgroundCapture.start') {
          receivedArgs = call.arguments as Map<dynamic, dynamic>?;
          return 1;
        }
        return null;
      });

      await client.startCapture(
        config: const BackgroundCaptureConfig(
          frameRate: 60,
          pixelRatio: 0.5,
          excludeSelf: false,
          capturePadding: EdgeInsets.all(10),
        ),
      );

      expect(receivedArgs, isNotNull);
      expect(receivedArgs!['frameRate'], equals(60));
      expect(receivedArgs!['pixelRatio'], equals(0.5));
      expect(receivedArgs!['excludeSelf'], isFalse);
      expect(receivedArgs!['paddingTop'], equals(10.0));
      expect(receivedArgs!['paddingRight'], equals(10.0));
      expect(receivedArgs!['paddingBottom'], equals(10.0));
      expect(receivedArgs!['paddingLeft'], equals(10.0));
    });

    test('emits started event on success', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'backgroundCapture.start') {
          return 99;
        }
        return null;
      });

      final events = <BackgroundCaptureEvent>[];
      client.events.listen(events.add);

      await client.startCapture();
      await Future<void>.delayed(Duration.zero); // Let broadcast stream deliver

      expect(events, hasLength(1));
      expect(events.first.type, equals('started'));
      expect(events.first.data['textureId'], equals(99));
    });

    test('returns null on PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'backgroundCapture.start') {
          throw PlatformException(code: 'ERROR', message: 'capture failed');
        }
        return null;
      });

      final result = await client.startCapture();

      expect(result, isNull);
    });

    test('emits error event on PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'backgroundCapture.start') {
          throw PlatformException(code: 'ERROR', message: 'capture failed');
        }
        return null;
      });

      final events = <BackgroundCaptureEvent>[];
      client.events.listen(events.add);

      await client.startCapture();
      await Future<void>.delayed(Duration.zero); // Let broadcast stream deliver

      expect(events, hasLength(1));
      expect(events.first.type, equals('error'));
      expect(events.first.data['error'], equals('capture failed'));
    });

    test('returns null when no texture ID returned', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'backgroundCapture.start') {
          return null;
        }
        return null;
      });

      final result = await client.startCapture();

      expect(result, isNull);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // stopCapture
  // ════════════════════════════════════════════════════════════════════════════

  group('stopCapture', () {
    test('invokes correct method', () async {
      String? invokedMethod;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        invokedMethod = call.method;
        return null;
      });

      await client.stopCapture();

      expect(invokedMethod, equals('backgroundCapture.stop'));
    });

    test('emits stopped event on success', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        return null;
      });

      final events = <BackgroundCaptureEvent>[];
      client.events.listen(events.add);

      await client.stopCapture();
      await Future<void>.delayed(Duration.zero); // Let broadcast stream deliver

      expect(events, hasLength(1));
      expect(events.first.type, equals('stopped'));
    });

    test('emits error event on PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'backgroundCapture.stop') {
          throw PlatformException(code: 'ERROR', message: 'stop failed');
        }
        return null;
      });

      final events = <BackgroundCaptureEvent>[];
      client.events.listen(events.add);

      await client.stopCapture();
      await Future<void>.delayed(Duration.zero); // Let broadcast stream deliver

      expect(events, hasLength(1));
      expect(events.first.type, equals('error'));
      expect(events.first.data['error'], equals('stop failed'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // getTextureId
  // ════════════════════════════════════════════════════════════════════════════

  group('getTextureId', () {
    test('returns texture ID', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'backgroundCapture.getTextureId') {
          return 7;
        }
        return null;
      });

      final result = await client.getTextureId();

      expect(result, equals(7));
    });

    test('returns null when no capture active', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        return null;
      });

      final result = await client.getTextureId();

      expect(result, isNull);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // events stream
  // ════════════════════════════════════════════════════════════════════════════

  group('events stream', () {
    test('is a broadcast stream', () {
      // Should be able to listen multiple times without error
      client.events.listen((_) {});
      client.events.listen((_) {});
    });
  });
}
