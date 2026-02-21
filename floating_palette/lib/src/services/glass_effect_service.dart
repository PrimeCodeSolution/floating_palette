import 'dart:async';
import 'dart:ui';

import '../ffi/glass_animation_bridge.dart';
import '../ffi/glass_path_bridge.dart';

/// Material types for the glass blur effect.
///
/// These map to macOS NSVisualEffectView.Material values.
enum GlassMaterial {
  /// HUD-style window (dark, translucent)
  hudWindow,

  /// Sidebar-style blur
  sidebar,

  /// Popover-style blur
  popover,

  /// Menu-style blur
  menu,

  /// Sheet-style blur
  sheet,
}

/// High-level service for applying glass blur effects to palette windows.
///
/// This service provides an ergonomic API for Flutter widgets to apply
/// native macOS blur effects (NSVisualEffectView) masked to arbitrary shapes.
///
/// Usage:
/// ```dart
/// // Enable glass effect
/// final glass = GlassEffectService();
/// glass.enable(windowId, material: GlassMaterial.hudWindow);
///
/// // Update mask shape on each frame
/// @override
/// void paint(Canvas canvas, Size size) {
///   final path = Path()
///     ..addRRect(RRect.fromRectAndRadius(
///       Rect.fromLTWH(0, 0, size.width, size.height),
///       Radius.circular(12),
///     ));
///
///   glass.updatePath(windowId, path, windowHeight: size.height);
///
///   // Draw Flutter content on top...
/// }
///
/// // Disable when done
/// glass.disable(windowId);
/// ```
class GlassEffectService {
  final GlassPathBridge _bridge = GlassPathBridge.instance;
  final GlassAnimationBridge _animBridge = GlassAnimationBridge.instance;

  /// Whether the glass effect is available on this platform.
  bool get isAvailable => _bridge.isAvailable;

  /// Whether native-driven animation is available.
  ///
  /// When true, [animateRRect] can be used for smooth 60-120Hz animations
  /// without per-frame FFI calls.
  bool get isNativeAnimationAvailable => _animBridge.isAvailable;

  /// Enable glass effect for a palette window.
  ///
  /// [windowId] - The palette window identifier
  /// [material] - The blur material to use (default: hudWindow)
  ///
  /// Returns true if successfully enabled.
  bool enable(
    String windowId, {
    GlassMaterial material = GlassMaterial.hudWindow,
    int layerId = 0,
  }) {
    if (!_bridge.isAvailable) return false;

    if (!_bridge.hasBuffer(windowId, layerId: layerId)) {
      if (!_bridge.createBuffer(windowId, layerId: layerId)) return false;
    }

    _bridge.setEnabled(windowId, true);
    _bridge.setMaterial(windowId, material.index, layerId: layerId);
    return true;
  }

  /// Disable glass effect for a palette window.
  void disable(String windowId) {
    if (!_bridge.isAvailable) return;

    _bridge.setEnabled(windowId, false);
    _bridge.destroyAllBuffers(windowId);
  }

  /// Set the blur material for a window.
  void setMaterial(String windowId, GlassMaterial material, {int layerId = 0}) {
    if (!_bridge.isAvailable) return;
    _bridge.setMaterial(windowId, material.index, layerId: layerId);
  }

  /// Set dark mode for a window's glass effect.
  /// [isDark] - false = clear glass, true = dark/regular glass
  void setDark(String windowId, bool isDark, {int layerId = 0}) {
    if (!_bridge.isAvailable) return;
    _bridge.setDark(windowId, isDark, layerId: layerId);
  }

  /// Set tint opacity for a window's glass effect.
  ///
  /// A dark tint layer is added behind the glass to reduce transparency.
  /// This is useful when you want the glass effect but need better readability.
  ///
  /// [opacity] - 0.0 = fully transparent (default), 1.0 = fully opaque black
  /// [cornerRadius] - Corner radius for the tint layer (default 16)
  void setTintOpacity(
    String windowId,
    double opacity, {
    double cornerRadius = 16,
    int layerId = 0,
  }) {
    if (!_bridge.isAvailable) return;
    _bridge.setTintOpacity(
      windowId,
      opacity,
      cornerRadius: cornerRadius,
      layerId: layerId,
    );
  }

  /// Update the glass mask with a Flutter Path.
  ///
  /// This extracts path commands and writes them to shared memory
  /// for native to read and apply as CAShapeLayer mask.
  ///
  /// [windowId] - The palette window identifier
  /// [path] - The Flutter Path to use as mask
  /// [windowHeight] - Height for Y-flip (Flutter Y=0 top, macOS Y=0 bottom)
  void updatePath(
    String windowId,
    Path path, {
    required double windowHeight,
    int layerId = 0,
  }) {
    if (!_bridge.isAvailable) return;

    if (!_bridge.hasBuffer(windowId, layerId: layerId)) {
      if (!_bridge.createBuffer(windowId, layerId: layerId)) return;
    }

    final commands = <GlassPathCommand>[];
    final points = <double>[];

    for (final metric in path.computeMetrics()) {
      _extractPathCommands(metric, commands, points);
    }

    _bridge.writePath(
      windowId: windowId,
      commands: commands,
      points: points,
      windowHeight: windowHeight,
      layerId: layerId,
    );
  }

  /// Update the glass mask with raw commands and points.
  ///
  /// This is the low-level API for maximum control over the path.
  ///
  /// [windowId] - The palette window identifier
  /// [commands] - List of path commands
  /// [points] - Flat list of coordinates [x0, y0, x1, y1, ...]
  /// [windowHeight] - Height for Y-flip
  void updateRaw({
    required String windowId,
    required List<GlassPathCommand> commands,
    required List<double> points,
    required double windowHeight,
    int layerId = 0,
  }) {
    if (!_bridge.isAvailable) return;

    if (!_bridge.hasBuffer(windowId, layerId: layerId)) {
      if (!_bridge.createBuffer(windowId, layerId: layerId)) return;
    }

    _bridge.writePath(
      windowId: windowId,
      commands: commands,
      points: points,
      windowHeight: windowHeight,
      layerId: layerId,
    );
  }

  /// Update the glass mask with a simple rounded rectangle.
  ///
  /// Convenience method for the common case of rounded rect masks.
  void updateRRect(
    String windowId,
    RRect rrect, {
    required double windowHeight,
    int layerId = 0,
  }) {
    if (!_bridge.isAvailable) return;

    if (!_bridge.hasBuffer(windowId, layerId: layerId)) {
      if (!_bridge.createBuffer(windowId, layerId: layerId)) return;
    }

    final commands = <GlassPathCommand>[];
    final points = <double>[];

    _buildRRectPath(rrect, commands, points);

    _bridge.writePath(
      windowId: windowId,
      commands: commands,
      points: points,
      windowHeight: windowHeight,
      layerId: layerId,
    );
  }

  /// Update the glass mask with a simple rectangle.
  ///
  /// Convenience method for simple rectangular masks.
  void updateRect(
    String windowId,
    Rect rect, {
    required double windowHeight,
    int layerId = 0,
  }) {
    if (!_bridge.isAvailable) return;

    if (!_bridge.hasBuffer(windowId, layerId: layerId)) {
      if (!_bridge.createBuffer(windowId, layerId: layerId)) return;
    }

    final commands = <GlassPathCommand>[
      GlassPathCommand.moveTo,
      GlassPathCommand.lineTo,
      GlassPathCommand.lineTo,
      GlassPathCommand.lineTo,
      GlassPathCommand.close,
    ];

    final points = <double>[
      rect.left, rect.top,
      rect.right, rect.top,
      rect.right, rect.bottom,
      rect.left, rect.bottom,
    ];

    _bridge.writePath(
      windowId: windowId,
      commands: commands,
      points: points,
      windowHeight: windowHeight,
      layerId: layerId,
    );
  }

  // ════════════════════════════════════════════════════════════════════════════════
  // Native-Driven Animation
  // ════════════════════════════════════════════════════════════════════════════════

  /// Animate the glass mask between two RRect bounds using native interpolation.
  ///
  /// When [isNativeAnimationAvailable] is true, this writes animation parameters
  /// to native ONCE and native interpolates at display refresh rate (60-120Hz),
  /// eliminating per-frame FFI calls and achieving perfect VSync sync.
  ///
  /// If native animation is not available, this falls back to immediate
  /// [updateRRect] call with the target bounds.
  ///
  /// [windowId] - The palette window identifier
  /// [from] - Starting RRect bounds
  /// [to] - Target RRect bounds
  /// [windowHeight] - Window height for coordinate system
  /// [duration] - Animation duration (default 200ms)
  /// [curve] - Animation curve (default easeOutCubic)
  /// [onComplete] - Optional callback when animation completes
  /// [layerId] - Layer ID (default 0)
  ///
  /// Returns true if native animation was started, false if fallback was used.
  bool animateRRect(
    String windowId,
    RRect from,
    RRect to, {
    required double windowHeight,
    Duration duration = const Duration(milliseconds: 200),
    GlassAnimationCurve curve = GlassAnimationCurve.easeOutCubic,
    VoidCallback? onComplete,
    int layerId = 0,
  }) {
    // Fallback if native animation not available
    if (!_animBridge.isAvailable) {
      updateRRect(windowId, to, windowHeight: windowHeight, layerId: layerId);
      onComplete?.call();
      return false;
    }

    // Ensure animation buffer exists
    if (!_animBridge.hasBuffer(windowId, layerId: layerId)) {
      if (!_animBridge.createBuffer(windowId, layerId: layerId)) {
        // Failed to create buffer, fallback
        updateRRect(windowId, to, windowHeight: windowHeight, layerId: layerId);
        onComplete?.call();
        return false;
      }
    }

    // Start native-driven animation
    _animBridge.startAnimation(
      windowId: windowId,
      layerId: layerId,
      startX: from.left,
      startY: from.top,
      startWidth: from.width,
      startHeight: from.height,
      targetX: to.left,
      targetY: to.top,
      targetWidth: to.width,
      targetHeight: to.height,
      cornerRadius: to.tlRadiusX, // Assume uniform corners
      duration: duration.inMicroseconds / 1000000.0,
      curve: curve,
      windowHeight: windowHeight,
    );

    // Schedule completion callback
    if (onComplete != null) {
      Future.delayed(duration, onComplete);
    }

    return true;
  }

  /// Set static (non-animated) RRect bounds via the animation buffer.
  ///
  /// Use this when not animating to set the glass mask to a fixed position
  /// through the animation buffer (which takes priority over path buffer).
  ///
  /// If native animation is not available, falls back to [updateRRect].
  void setStaticRRect(
    String windowId,
    RRect rrect, {
    required double windowHeight,
    int layerId = 0,
  }) {
    // Fallback if native animation not available
    if (!_animBridge.isAvailable) {
      updateRRect(windowId, rrect, windowHeight: windowHeight, layerId: layerId);
      return;
    }

    // Ensure animation buffer exists
    if (!_animBridge.hasBuffer(windowId, layerId: layerId)) {
      if (!_animBridge.createBuffer(windowId, layerId: layerId)) {
        // Failed to create buffer, fallback
        updateRRect(windowId, rrect, windowHeight: windowHeight, layerId: layerId);
        return;
      }
    }

    _animBridge.setStaticBounds(
      windowId: windowId,
      layerId: layerId,
      x: rrect.left,
      y: rrect.top,
      width: rrect.width,
      height: rrect.height,
      cornerRadius: rrect.tlRadiusX,
      windowHeight: windowHeight,
    );
  }

  /// Destroy animation buffers for a window.
  ///
  /// Call this when done with native animations to free resources.
  void destroyAnimationBuffers(String windowId) {
    _animBridge.destroyAllBuffers(windowId);
  }

  /// Extract path commands from a PathMetric.
  void _extractPathCommands(
    PathMetric metric,
    List<GlassPathCommand> commands,
    List<double> points,
  ) {
    // Sample the path at regular intervals
    // Buffer now holds 1024 commands and 2048 floats (1024 points)
    // Circle circumference ~2πr, for r=140 that's ~880px
    // At step=2, we get ~440 samples which fits comfortably
    const step = 2.0; // Sample every 2 logical pixels for smooth curves
    final length = metric.length;

    Tangent? firstTangent;
    Tangent? lastTangent;

    for (double distance = 0; distance <= length; distance += step) {
      final tangent = metric.getTangentForOffset(distance);
      if (tangent == null) continue;

      if (firstTangent == null) {
        firstTangent = tangent;
        commands.add(GlassPathCommand.moveTo);
      } else {
        commands.add(GlassPathCommand.lineTo);
      }
      points.add(tangent.position.dx);
      points.add(tangent.position.dy);
      lastTangent = tangent;
    }

    // Add final point if not at length
    if (lastTangent != null) {
      final endTangent = metric.getTangentForOffset(length);
      if (endTangent != null &&
          (endTangent.position - lastTangent.position).distance > 0.5) {
        commands.add(GlassPathCommand.lineTo);
        points.add(endTangent.position.dx);
        points.add(endTangent.position.dy);
      }
    }

    // Close path if it's a closed contour
    if (metric.isClosed && firstTangent != null) {
      commands.add(GlassPathCommand.close);
    }
  }

  /// Build path commands for a rounded rectangle.
  void _buildRRectPath(
    RRect rrect,
    List<GlassPathCommand> commands,
    List<double> points,
  ) {
    final left = rrect.left;
    final top = rrect.top;
    final right = rrect.right;
    final bottom = rrect.bottom;

    final tlRadiusX = rrect.tlRadiusX;
    final tlRadiusY = rrect.tlRadiusY;
    final trRadiusX = rrect.trRadiusX;
    final trRadiusY = rrect.trRadiusY;
    final brRadiusX = rrect.brRadiusX;
    final brRadiusY = rrect.brRadiusY;
    final blRadiusX = rrect.blRadiusX;
    final blRadiusY = rrect.blRadiusY;

    // Kappa for approximating circular arcs with cubic beziers
    const kappa = 0.5522847498;

    // Start at top-left after corner
    commands.add(GlassPathCommand.moveTo);
    points.addAll([left + tlRadiusX, top]);

    // Top edge
    commands.add(GlassPathCommand.lineTo);
    points.addAll([right - trRadiusX, top]);

    // Top-right corner
    if (trRadiusX > 0 && trRadiusY > 0) {
      commands.add(GlassPathCommand.cubicTo);
      points.addAll([
        right - trRadiusX * (1 - kappa), top,
        right, top + trRadiusY * (1 - kappa),
        right, top + trRadiusY,
      ]);
    }

    // Right edge
    commands.add(GlassPathCommand.lineTo);
    points.addAll([right, bottom - brRadiusY]);

    // Bottom-right corner
    if (brRadiusX > 0 && brRadiusY > 0) {
      commands.add(GlassPathCommand.cubicTo);
      points.addAll([
        right, bottom - brRadiusY * (1 - kappa),
        right - brRadiusX * (1 - kappa), bottom,
        right - brRadiusX, bottom,
      ]);
    }

    // Bottom edge
    commands.add(GlassPathCommand.lineTo);
    points.addAll([left + blRadiusX, bottom]);

    // Bottom-left corner
    if (blRadiusX > 0 && blRadiusY > 0) {
      commands.add(GlassPathCommand.cubicTo);
      points.addAll([
        left + blRadiusX * (1 - kappa), bottom,
        left, bottom - blRadiusY * (1 - kappa),
        left, bottom - blRadiusY,
      ]);
    }

    // Left edge
    commands.add(GlassPathCommand.lineTo);
    points.addAll([left, top + tlRadiusY]);

    // Top-left corner
    if (tlRadiusX > 0 && tlRadiusY > 0) {
      commands.add(GlassPathCommand.cubicTo);
      points.addAll([
        left, top + tlRadiusY * (1 - kappa),
        left + tlRadiusX * (1 - kappa), top,
        left + tlRadiusX, top,
      ]);
    }

    // Close path
    commands.add(GlassPathCommand.close);
  }
}
