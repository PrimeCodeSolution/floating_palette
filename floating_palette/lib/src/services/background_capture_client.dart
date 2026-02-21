import 'dart:async';

import 'package:flutter/painting.dart' show EdgeInsets;
import 'package:flutter/services.dart';

/// Permission status for screen recording.
enum BackgroundCapturePermission {
  /// Permission has been granted.
  granted,

  /// Permission has been denied.
  denied,

  /// Permission has not been determined yet.
  notDetermined,

  /// Permission is restricted (e.g., by MDM).
  restricted,
}

/// Configuration for background capture.
class BackgroundCaptureConfig {
  /// Target frame rate in frames per second.
  /// Higher values provide smoother updates but use more resources.
  /// Default: 30 fps. Maximum: 60 fps.
  final int frameRate;

  /// Pixel ratio relative to window size.
  /// 1.0 = native resolution, 0.5 = half resolution (better performance).
  /// Default: 1.0.
  final double pixelRatio;

  /// Whether to exclude the palette window itself from capture.
  /// Default: true.
  final bool excludeSelf;

  /// Extra padding around the window to capture.
  /// Useful for effects that extend beyond the window bounds (like liquid glass circles).
  final EdgeInsets capturePadding;

  const BackgroundCaptureConfig({
    this.frameRate = 30,
    this.pixelRatio = 1.0,
    this.excludeSelf = true,
    this.capturePadding = EdgeInsets.zero,
  });

  Map<String, dynamic> toMap() => {
        'frameRate': frameRate,
        'pixelRatio': pixelRatio,
        'excludeSelf': excludeSelf,
        'paddingTop': capturePadding.top,
        'paddingRight': capturePadding.right,
        'paddingBottom': capturePadding.bottom,
        'paddingLeft': capturePadding.left,
      };
}

/// Event data for background capture events.
class BackgroundCaptureEvent {
  final String paletteId;
  final String type;
  final Map<String, dynamic> data;

  const BackgroundCaptureEvent({
    required this.paletteId,
    required this.type,
    required this.data,
  });
}

/// Client for BackgroundCaptureService.
///
/// Captures the screen content behind palette windows and streams it
/// as a Flutter texture for use with liquid glass effects.
///
/// This client uses the self channel (floating_palette/self) which is
/// available in each palette's Flutter engine, ensuring the texture is
/// registered on the correct engine.
///
/// Usage:
/// ```dart
/// final client = BackgroundCaptureClient();
///
/// // Check permission first
/// final permission = await client.checkPermission();
/// if (permission != BackgroundCapturePermission.granted) {
///   await client.requestPermission();
///   return;
/// }
///
/// // Start capture
/// final textureId = await client.startCapture(
///   config: BackgroundCaptureConfig(frameRate: 30, pixelRatio: 0.5),
/// );
///
/// // Use texture in widget
/// Texture(textureId: textureId)
///
/// // Stop when done
/// await client.stopCapture();
/// ```
class BackgroundCaptureClient {
  // Use the 'self' channel which is set up on each palette engine
  static const _channel = MethodChannel('floating_palette/self');

  final _eventController = StreamController<BackgroundCaptureEvent>.broadcast();

  /// Stream of capture events.
  Stream<BackgroundCaptureEvent> get events => _eventController.stream;

  /// Check current screen recording permission status.
  Future<BackgroundCapturePermission> checkPermission() async {
    try {
      final result = await _channel.invokeMethod<String>('backgroundCapture.checkPermission');
      switch (result) {
        case 'granted':
          return BackgroundCapturePermission.granted;
        case 'denied':
          return BackgroundCapturePermission.denied;
        case 'restricted':
          return BackgroundCapturePermission.restricted;
        default:
          return BackgroundCapturePermission.notDetermined;
      }
    } on PlatformException catch (e) {
      _eventController.add(BackgroundCaptureEvent(
        paletteId: '',
        type: 'error',
        data: {'error': e.message ?? 'Unknown error'},
      ));
      return BackgroundCapturePermission.notDetermined;
    }
  }

  /// Request screen recording permission.
  /// This opens System Preferences to the Screen Recording section.
  Future<void> requestPermission() async {
    await _channel.invokeMethod<void>('backgroundCapture.requestPermission');
  }

  /// Start capturing the background behind this palette window.
  ///
  /// Returns the texture ID that can be used with [Texture] widget.
  /// Returns null if capture fails to start.
  Future<int?> startCapture({
    BackgroundCaptureConfig config = const BackgroundCaptureConfig(),
  }) async {
    try {
      final result = await _channel.invokeMethod<int>(
        'backgroundCapture.start',
        config.toMap(),
      );
      if (result != null) {
        _eventController.add(BackgroundCaptureEvent(
          paletteId: '',
          type: 'started',
          data: {'textureId': result},
        ));
      }
      return result;
    } on PlatformException catch (e) {
      _eventController.add(BackgroundCaptureEvent(
        paletteId: '',
        type: 'error',
        data: {'error': e.message ?? 'Unknown error'},
      ));
      return null;
    }
  }

  /// Stop capturing and release resources.
  Future<void> stopCapture() async {
    try {
      await _channel.invokeMethod<void>('backgroundCapture.stop');
      _eventController.add(const BackgroundCaptureEvent(
        paletteId: '',
        type: 'stopped',
        data: {},
      ));
    } on PlatformException catch (e) {
      _eventController.add(BackgroundCaptureEvent(
        paletteId: '',
        type: 'error',
        data: {'error': e.message ?? 'Unknown error'},
      ));
    }
  }

  /// Get the current texture ID for this palette.
  /// Returns null if no capture is active.
  Future<int?> getTextureId() async {
    return _channel.invokeMethod<int>('backgroundCapture.getTextureId');
  }

  void dispose() {
    _eventController.close();
  }
}
