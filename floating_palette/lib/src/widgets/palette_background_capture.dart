import 'dart:async';

import 'package:flutter/material.dart';

import '../services/background_capture_client.dart';

/// A widget that captures the desktop background behind a palette window
/// and provides it as a texture for use with liquid glass effects.
///
/// This widget automatically handles:
/// - Permission checking and requesting
/// - Starting/stopping capture based on widget lifecycle
/// - Providing a fallback when capture is unavailable
///
/// Example usage with liquid_glass_easy:
/// ```dart
/// PaletteBackgroundCapture(
///   config: BackgroundCaptureConfig(frameRate: 30, pixelRatio: 0.5),
///   builder: (context, backgroundWidget) {
///     return LiquidGlassView(
///       backgroundWidget: backgroundWidget,
///       children: [...],
///     );
///   },
/// )
/// ```
class PaletteBackgroundCapture extends StatefulWidget {
  /// Configuration for the background capture.
  final BackgroundCaptureConfig config;

  /// Builder that receives the background widget (Texture or fallback).
  final Widget Function(BuildContext context, Widget backgroundWidget) builder;

  /// Fallback widget to use when capture is unavailable.
  /// Defaults to a semi-transparent dark container.
  final Widget? fallback;

  /// Called when permission is denied.
  final VoidCallback? onPermissionDenied;

  /// Called when an error occurs during capture.
  final void Function(String error)? onError;

  const PaletteBackgroundCapture({
    super.key,
    this.config = const BackgroundCaptureConfig(),
    required this.builder,
    this.fallback,
    this.onPermissionDenied,
    this.onError,
  });

  @override
  State<PaletteBackgroundCapture> createState() =>
      _PaletteBackgroundCaptureState();
}

class _PaletteBackgroundCaptureState extends State<PaletteBackgroundCapture> {
  final _client = BackgroundCaptureClient();
  StreamSubscription<BackgroundCaptureEvent>? _eventSubscription;

  int? _textureId;
  bool _isCapturing = false;
  bool _hasStarted = false;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _eventSubscription = _client.events.listen(_handleEvent);
    // Start capture after first frame to ensure self channel is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCapture();
    });
  }

  @override
  void didUpdateWidget(PaletteBackgroundCapture oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If config changed, restart capture
    if (!_configEquals(widget.config, oldWidget.config) && _isCapturing) {
      _stopCapture();
      _startCapture();
    }
  }

  @override
  void dispose() {
    _stopCapture();
    _eventSubscription?.cancel();
    _client.dispose();
    super.dispose();
  }

  void _handleEvent(BackgroundCaptureEvent event) {
    switch (event.type) {
      case 'started':
        debugPrint(
            '[PaletteBackgroundCapture] Capture started, textureId: ${event.data['textureId']}');
        break;
      case 'stopped':
        debugPrint('[PaletteBackgroundCapture] Capture stopped');
        break;
      case 'error':
        final error = event.data['error'] as String? ?? 'Unknown error';
        debugPrint('[PaletteBackgroundCapture] Error: $error');
        widget.onError?.call(error);
        break;
    }
  }

  Future<void> _startCapture() async {
    if (_isCapturing || _hasStarted) return;
    _hasStarted = true;

    // Check permission first
    final permission = await _client.checkPermission();
    if (permission == BackgroundCapturePermission.denied ||
        permission == BackgroundCapturePermission.notDetermined) {
      // Open System Preferences for user to grant permission
      if (mounted) {
        setState(() => _permissionDenied = true);
        widget.onPermissionDenied?.call();
      }
      // Request opens System Preferences to Screen Recording
      await _client.requestPermission();
      return;
    }

    // Start capture (uses self channel - no paletteId needed)
    final textureId = await _client.startCapture(
      config: widget.config,
    );

    if (mounted) {
      setState(() {
        _textureId = textureId;
        _isCapturing = textureId != null;
        _permissionDenied = textureId == null;
      });
    }
  }

  Future<void> _stopCapture() async {
    if (!_isCapturing) return;

    await _client.stopCapture();

    if (mounted) {
      setState(() {
        _textureId = null;
        _isCapturing = false;
      });
    }
  }

  Widget _buildBackground() {
    if (_textureId != null) {
      return Texture(textureId: _textureId!);
    }

    // Return fallback - transparent by default to allow see-through
    return widget.fallback ?? const SizedBox.shrink();
  }

  /// Whether capture is available (permission granted and capturing).
  bool get isCapturing => _isCapturing && _textureId != null;

  /// Whether permission was denied.
  bool get isPermissionDenied => _permissionDenied;

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _buildBackground());
  }
}

/// Helper to compare BackgroundCaptureConfig for didUpdateWidget.
bool _configEquals(BackgroundCaptureConfig a, BackgroundCaptureConfig b) {
  if (identical(a, b)) return true;
  return a.frameRate == b.frameRate &&
      a.pixelRatio == b.pixelRatio &&
      a.excludeSelf == b.excludeSelf &&
      a.capturePadding == b.capturePadding;
}
