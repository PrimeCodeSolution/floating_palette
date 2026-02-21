import 'dart:async';
import 'dart:math' show pi;

import 'package:flutter/painting.dart' show Alignment;

import '../bridge/service_client.dart';

/// Client for TransformService.
///
/// Handles scale, rotation, flip transforms.
class TransformClient extends ServiceClient {
  TransformClient(super.bridge);

  @override
  String get serviceName => 'transform';

  /// Set scale.
  Future<void> setScale(
    String id,
    double scale, {
    Alignment anchor = Alignment.center,
    bool animate = false,
    int? durationMs,
    String? curve,
  }) async {
    await send<void>('setScale', windowId: id, params: {
      'scale': scale,
      'anchorX': anchor.x,
      'anchorY': anchor.y,
      'animate': animate,
      if (durationMs != null) 'durationMs': durationMs,
      if (curve != null) 'curve': curve,
    });
  }

  /// Set rotation.
  ///
  /// [radians] - Rotation angle in radians (converted to degrees for native).
  Future<void> setRotation(
    String id,
    double radians, {
    Alignment anchor = Alignment.center,
    bool animate = false,
    int? durationMs,
    String? curve,
  }) async {
    // Native expects degrees, so convert from radians
    final degrees = radians * 180 / pi;
    await send<void>('setRotation', windowId: id, params: {
      'degrees': degrees,
      'anchorX': anchor.x,
      'anchorY': anchor.y,
      'animate': animate,
      if (durationMs != null) 'durationMs': durationMs,
      if (curve != null) 'curve': curve,
    });
  }

  /// Set flip state.
  Future<void> setFlip(
    String id, {
    bool horizontal = false,
    bool vertical = false,
    bool animate = false,
    int? durationMs,
    String? curve,
  }) async {
    await send<void>('setFlip', windowId: id, params: {
      'horizontal': horizontal,
      'vertical': vertical,
      'animate': animate,
      if (durationMs != null) 'durationMs': durationMs,
      if (curve != null) 'curve': curve,
    });
  }

  /// Reset all transforms.
  Future<void> reset(String id, {bool animate = false, int? durationMs}) async {
    await send<void>('reset', windowId: id, params: {
      'animate': animate,
      if (durationMs != null) 'durationMs': durationMs,
    });
  }

  /// Get current scale.
  Future<double> getScale(String id) async {
    final result = await send<double>('getScale', windowId: id);
    return result ?? 1.0;
  }

  /// Get current rotation.
  Future<double> getRotation(String id) async {
    final result = await send<double>('getRotation', windowId: id);
    return result ?? 0.0;
  }

  /// Get flip state.
  Future<({bool horizontal, bool vertical})> getFlip(String id) async {
    final result = await sendForMap('getFlip', windowId: id);
    return (
      horizontal: result?['horizontal'] as bool? ?? false,
      vertical: result?['vertical'] as bool? ?? false,
    );
  }
}
