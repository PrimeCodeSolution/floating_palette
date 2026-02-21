import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Animation curve types for native glass interpolation.
/// Must match native GlassAnimationCurve enum.
enum GlassAnimationCurve {
  /// Linear interpolation (t)
  linear, // 0

  /// Ease out quadratic (1 - (1-t)^2)
  easeOut, // 1

  /// Ease out cubic (1 - (1-t)^3) - default, matches Flutter's easeOutCubic
  easeOutCubic, // 2

  /// Ease in-out quadratic (t < 0.5 ? 2t^2 : 1 - (-2t+2)^2/2)
  easeInOut, // 3
}

/// FFI struct for animation parameters.
///
/// Uses @Packed(1) to ensure exact byte layout with no padding.
/// This guarantees both Dart and Swift use identical memory layout.
///
/// Memory layout (packed, 76 bytes total):
/// - animationId: 8 bytes (uint64) at offset 0
/// - isAnimating: 1 byte (uint8) at offset 8
/// - curveType: 1 byte (uint8) at offset 9
/// - _padding: 2 bytes at offset 10
/// - startX: 4 bytes (float) at offset 12
/// - startY: 4 bytes (float) at offset 16
/// - startWidth: 4 bytes (float) at offset 20
/// - startHeight: 4 bytes (float) at offset 24
/// - targetX: 4 bytes (float) at offset 28
/// - targetY: 4 bytes (float) at offset 32
/// - targetWidth: 4 bytes (float) at offset 36
/// - targetHeight: 4 bytes (float) at offset 40
/// - cornerRadius: 4 bytes (float) at offset 44
/// - startTime: 8 bytes (double) at offset 48
/// - duration: 8 bytes (double) at offset 56
/// - windowHeight: 4 bytes (float) at offset 64
/// - _padding2: 4 bytes at offset 68
/// - animationIdPost: 8 bytes (uint64) at offset 72
///
/// Total: 80 bytes (packed with alignment padding for doubles)
@Packed(1)
final class GlassAnimationBuffer extends Struct {
  @Uint64()
  external int animationId;

  @Uint8()
  external int isAnimating;

  @Uint8()
  external int curveType;

  @Array(2)
  external Array<Uint8> _padding;

  // Start bounds
  @Float()
  external double startX;

  @Float()
  external double startY;

  @Float()
  external double startWidth;

  @Float()
  external double startHeight;

  // Target bounds
  @Float()
  external double targetX;

  @Float()
  external double targetY;

  @Float()
  external double targetWidth;

  @Float()
  external double targetHeight;

  @Float()
  external double cornerRadius;

  @Double()
  external double startTime;

  @Double()
  external double duration;

  @Float()
  external double windowHeight;

  @Array(4)
  external Array<Uint8> _padding2;

  @Uint64()
  external int animationIdPost;
}

/// Native function signatures for glass animation FFI.
typedef _GetCurrentTimeNative = Double Function();
typedef _GetCurrentTimeDart = double Function();

typedef _CreateAnimationBufferNative = Pointer<Void> Function(
  Pointer<Char>,
  Int32,
);
typedef _CreateAnimationBufferDart = Pointer<Void> Function(
  Pointer<Char>,
  int,
);

typedef _DestroyAnimationBufferNative = Void Function(Pointer<Char>, Int32);
typedef _DestroyAnimationBufferDart = void Function(Pointer<Char>, int);

/// Low-level FFI bridge for native glass animation.
///
/// This bridge enables native-driven animation interpolation:
/// - Dart writes animation parameters ONCE at animation start
/// - Native interpolates at display refresh rate (60-120Hz)
/// - Perfect VSync alignment, no per-frame FFI calls
///
/// Thread safety uses same torn-write detection as GlassPathBridge:
/// - animationIdPost is written FIRST (signals write in progress)
/// - All data is written
/// - animationId is written LAST (signals write complete)
/// - Native reads animationId, copies data, reads animationIdPost
/// - If animationId != animationIdPost, native skips (torn read)
class GlassAnimationBridge {
  static GlassAnimationBridge? _instance;
  static GlassAnimationBridge get instance {
    _instance ??= GlassAnimationBridge._();
    return _instance!;
  }

  late final DynamicLibrary _lib;
  _GetCurrentTimeDart? _getCurrentTime;
  _CreateAnimationBufferDart? _createAnimationBuffer;
  _DestroyAnimationBufferDart? _destroyAnimationBuffer;

  bool _initialized = false;

  /// Active animation buffers per window ID and layer.
  final Map<String, Map<int, Pointer<GlassAnimationBuffer>>> _buffers = {};

  /// Animation IDs per window ID and layer (incremented on each animation start).
  final Map<String, Map<int, int>> _animationIds = {};

  GlassAnimationBridge._() {
    _initialize();
  }

  void _initialize() {
    if (_initialized) return;

    if (!Platform.isMacOS && !Platform.isWindows) {
      return;
    }

    try {
      if (Platform.isMacOS) {
        _lib = DynamicLibrary.process();
      } else if (Platform.isWindows) {
        _lib = DynamicLibrary.open('floating_palette_plugin.dll');
      }

      // Try to lookup animation FFI functions (may not be available in older builds)
      try {
        _getCurrentTime = _lib
            .lookup<NativeFunction<_GetCurrentTimeNative>>(
              'FloatingPalette_GetCurrentTime',
            )
            .asFunction();
      } catch (_) {
        _getCurrentTime = null;
      }

      try {
        _createAnimationBuffer = _lib
            .lookup<NativeFunction<_CreateAnimationBufferNative>>(
              'FloatingPalette_CreateAnimationBuffer',
            )
            .asFunction();
      } catch (_) {
        _createAnimationBuffer = null;
      }

      try {
        _destroyAnimationBuffer = _lib
            .lookup<NativeFunction<_DestroyAnimationBufferNative>>(
              'FloatingPalette_DestroyAnimationBuffer',
            )
            .asFunction();
      } catch (_) {
        _destroyAnimationBuffer = null;
      }

      _initialized = true;
    } catch (e) {
      _initialized = false;
    }
  }

  /// Whether native animation is available.
  bool get isAvailable =>
      _initialized &&
      _getCurrentTime != null &&
      _createAnimationBuffer != null &&
      _destroyAnimationBuffer != null;

  /// Get CACurrentMediaTime from native for clock synchronization.
  /// Returns 0.0 if not available.
  double getCurrentTime() {
    if (!isAvailable) return 0.0;
    return _getCurrentTime!();
  }

  /// Create an animation buffer for a window and layer.
  /// Returns true if successful.
  bool createBuffer(String windowId, {int layerId = 0}) {
    if (!isAvailable) return false;

    final idPtr = windowId.toNativeUtf8().cast<Char>();
    try {
      final ptr = _createAnimationBuffer!(idPtr, layerId);
      if (ptr == nullptr) return false;

      final layerBuffers = _buffers.putIfAbsent(windowId, () => {});
      final layerIds = _animationIds.putIfAbsent(windowId, () => {});
      layerBuffers[layerId] = ptr.cast<GlassAnimationBuffer>();
      layerIds[layerId] = 0;
      return true;
    } finally {
      calloc.free(idPtr);
    }
  }

  /// Destroy the animation buffer for a window and layer.
  void destroyBuffer(String windowId, {int layerId = 0}) {
    if (!isAvailable) return;

    final layerBuffers = _buffers[windowId];
    final layerIds = _animationIds[windowId];
    layerBuffers?.remove(layerId);
    layerIds?.remove(layerId);
    if (layerBuffers != null && layerBuffers.isEmpty) {
      _buffers.remove(windowId);
    }
    if (layerIds != null && layerIds.isEmpty) {
      _animationIds.remove(windowId);
    }

    final idPtr = windowId.toNativeUtf8().cast<Char>();
    try {
      _destroyAnimationBuffer!(idPtr, layerId);
    } finally {
      calloc.free(idPtr);
    }
  }

  /// Destroy all animation buffers for a window.
  void destroyAllBuffers(String windowId) {
    final layers = _buffers[windowId]?.keys.toList() ?? const [];
    for (final layerId in layers) {
      destroyBuffer(windowId, layerId: layerId);
    }
  }

  /// Check if a buffer exists for a window and layer.
  bool hasBuffer(String windowId, {int layerId = 0}) =>
      _buffers[windowId]?.containsKey(layerId) ?? false;

  /// Start a native-driven animation.
  ///
  /// Writes animation parameters to shared memory ONCE.
  /// Native will interpolate at display refresh rate until duration elapsed.
  ///
  /// [windowId] - The palette window identifier
  /// [layerId] - Layer ID (default 0)
  /// [startX], [startY], [startWidth], [startHeight] - Starting bounds
  /// [targetX], [targetY], [targetWidth], [targetHeight] - Target bounds
  /// [cornerRadius] - Corner radius for RRect
  /// [duration] - Animation duration in seconds
  /// [curve] - Animation curve type
  /// [windowHeight] - Window height for Y coordinate flipping
  void startAnimation({
    required String windowId,
    int layerId = 0,
    required double startX,
    required double startY,
    required double startWidth,
    required double startHeight,
    required double targetX,
    required double targetY,
    required double targetWidth,
    required double targetHeight,
    required double cornerRadius,
    required double duration,
    GlassAnimationCurve curve = GlassAnimationCurve.easeOutCubic,
    required double windowHeight,
  }) {
    final buffer = _buffers[windowId]?[layerId];
    if (buffer == null) return;

    final layerIds = _animationIds.putIfAbsent(windowId, () => {});
    final animId = (layerIds[layerId] ?? 0) + 1;
    layerIds[layerId] = animId;

    // Signal write in progress
    buffer.ref.animationIdPost = animId;

    // Write animation parameters
    buffer.ref.isAnimating = 1;
    buffer.ref.curveType = curve.index;
    buffer.ref.startX = startX;
    buffer.ref.startY = startY;
    buffer.ref.startWidth = startWidth;
    buffer.ref.startHeight = startHeight;
    buffer.ref.targetX = targetX;
    buffer.ref.targetY = targetY;
    buffer.ref.targetWidth = targetWidth;
    buffer.ref.targetHeight = targetHeight;
    buffer.ref.cornerRadius = cornerRadius;
    buffer.ref.startTime = getCurrentTime();
    buffer.ref.duration = duration;
    buffer.ref.windowHeight = windowHeight;

    // Signal write complete
    buffer.ref.animationId = animId;
  }

  /// Set static (non-animated) bounds.
  ///
  /// Use this when not animating to set the glass mask to a fixed position.
  /// Native will apply these bounds without interpolation.
  ///
  /// [windowId] - The palette window identifier
  /// [layerId] - Layer ID (default 0)
  /// [x], [y], [width], [height] - Target bounds
  /// [cornerRadius] - Corner radius for RRect
  /// [windowHeight] - Window height for Y coordinate flipping
  void setStaticBounds({
    required String windowId,
    int layerId = 0,
    required double x,
    required double y,
    required double width,
    required double height,
    required double cornerRadius,
    required double windowHeight,
  }) {
    final buffer = _buffers[windowId]?[layerId];
    if (buffer == null) return;

    final layerIds = _animationIds.putIfAbsent(windowId, () => {});
    final animId = (layerIds[layerId] ?? 0) + 1;
    layerIds[layerId] = animId;

    // Signal write in progress
    buffer.ref.animationIdPost = animId;

    // Write static bounds (isAnimating = 0)
    buffer.ref.isAnimating = 0;
    buffer.ref.curveType = 0;
    buffer.ref.startX = x;
    buffer.ref.startY = y;
    buffer.ref.startWidth = width;
    buffer.ref.startHeight = height;
    buffer.ref.targetX = x;
    buffer.ref.targetY = y;
    buffer.ref.targetWidth = width;
    buffer.ref.targetHeight = height;
    buffer.ref.cornerRadius = cornerRadius;
    buffer.ref.startTime = 0;
    buffer.ref.duration = 0;
    buffer.ref.windowHeight = windowHeight;

    // Signal write complete
    buffer.ref.animationId = animId;
  }
}
