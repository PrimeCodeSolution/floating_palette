import 'package:flutter/painting.dart' show Alignment, Axis;

import '../services/transform_client.dart';

/// Helper for palette transform operations (scale, rotate, flip).
class TransformHelper {
  final TransformClient _transform;

  const TransformHelper(this._transform);

  /// Scale the palette.
  Future<void> scale(
    String id,
    double factor, {
    Alignment anchor = Alignment.center,
    bool animate = false,
    Duration? duration,
    String curve = 'easeOut',
  }) =>
      _transform.setScale(
        id,
        factor,
        anchor: anchor,
        animate: animate,
        durationMs: duration?.inMilliseconds,
        curve: curve,
      );

  /// Rotate the palette.
  Future<void> rotate(
    String id,
    double radians, {
    Alignment anchor = Alignment.center,
    bool animate = false,
    Duration? duration,
    String curve = 'easeOut',
  }) =>
      _transform.setRotation(
        id,
        radians,
        anchor: anchor,
        animate: animate,
        durationMs: duration?.inMilliseconds,
        curve: curve,
      );

  /// Flip the palette along an axis.
  Future<void> flip(
    String id, {
    Axis axis = Axis.horizontal,
    bool animate = false,
    Duration? duration,
    String curve = 'easeOut',
  }) async {
    final current = await _transform.getFlip(id);
    await _transform.setFlip(
      id,
      horizontal: axis == Axis.horizontal ? !current.horizontal : current.horizontal,
      vertical: axis == Axis.vertical ? !current.vertical : current.vertical,
      animate: animate,
      durationMs: duration?.inMilliseconds,
      curve: curve,
    );
  }

  /// Reset all transforms.
  Future<void> reset(String id, {bool animate = false, Duration? duration}) =>
      _transform.reset(id, animate: animate, durationMs: duration?.inMilliseconds);
}
