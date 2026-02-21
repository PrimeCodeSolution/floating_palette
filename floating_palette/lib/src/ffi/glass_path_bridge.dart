import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Path commands matching native enum GlassPathCommand.
/// Used to build arbitrary paths for glass mask effect.
enum GlassPathCommand {
  moveTo, // 0 - 1 point (x, y)
  lineTo, // 1 - 1 point (x, y)
  quadTo, // 2 - 2 points (cx, cy, x, y)
  cubicTo, // 3 - 3 points (c1x, c1y, c2x, c2y, x, y)
  close, // 4 - 0 points
}

/// FFI struct matching native GlassPathBuffer.
///
/// Uses @Packed(1) to ensure exact byte layout with no padding.
/// This guarantees both Dart and Swift use identical memory layout.
///
/// Memory layout (packed, no padding):
/// - frameId: 8 bytes (uint64) at offset 0
/// - commandCount: 4 bytes (uint32) at offset 8
/// - commands: 1024 bytes (uint8[1024]) at offset 12
/// - pointCount: 4 bytes (uint32) at offset 1036
/// - points: 8192 bytes (float[2048]) at offset 1040
/// - windowHeight: 4 bytes (float) at offset 9232
/// - frameIdPost: 8 bytes (uint64) at offset 9236
///
/// Total: 9244 bytes (packed)
///
/// Supports up to 1024 path commands and 2048 floats (1024 points).
/// For a circle with circumference ~900px sampled every 2px = ~450 commands.
@Packed(1)
final class GlassPathBuffer extends Struct {
  @Uint64()
  external int frameId;

  @Uint32()
  external int commandCount;

  @Array(1024)
  external Array<Uint8> commands;

  @Uint32()
  external int pointCount;

  @Array(2048)
  external Array<Float> points;

  @Float()
  external double windowHeight;

  @Uint64()
  external int frameIdPost;
}

/// Native function signatures for glass mask FFI.
typedef _CreateGlassPathBufferNative = Pointer<Void> Function(Pointer<Char>);
typedef _CreateGlassPathBufferDart = Pointer<Void> Function(Pointer<Char>);
typedef _CreateGlassPathBufferLayerNative = Pointer<Void> Function(Pointer<Char>, Int32);
typedef _CreateGlassPathBufferLayerDart = Pointer<Void> Function(Pointer<Char>, int);

typedef _DestroyGlassPathBufferNative = Void Function(Pointer<Char>);
typedef _DestroyGlassPathBufferDart = void Function(Pointer<Char>);
typedef _DestroyGlassPathBufferLayerNative = Void Function(Pointer<Char>, Int32);
typedef _DestroyGlassPathBufferLayerDart = void Function(Pointer<Char>, int);

typedef _SetGlassEnabledNative = Void Function(Pointer<Char>, Bool);
typedef _SetGlassEnabledDart = void Function(Pointer<Char>, bool);

typedef _SetGlassMaterialNative = Void Function(Pointer<Char>, Int32);
typedef _SetGlassMaterialDart = void Function(Pointer<Char>, int);
typedef _SetGlassMaterialLayerNative = Void Function(Pointer<Char>, Int32, Int32);
typedef _SetGlassMaterialLayerDart = void Function(Pointer<Char>, int, int);

typedef _SetGlassDarkNative = Void Function(Pointer<Char>, Bool);
typedef _SetGlassDarkDart = void Function(Pointer<Char>, bool);
typedef _SetGlassDarkLayerNative = Void Function(Pointer<Char>, Int32, Bool);
typedef _SetGlassDarkLayerDart = void Function(Pointer<Char>, int, bool);

typedef _SetGlassTintOpacityNative = Void Function(Pointer<Char>, Float, Float);
typedef _SetGlassTintOpacityDart = void Function(Pointer<Char>, double, double);
typedef _SetGlassTintOpacityLayerNative = Void Function(Pointer<Char>, Int32, Float, Float);
typedef _SetGlassTintOpacityLayerDart = void Function(Pointer<Char>, int, double, double);

/// Low-level FFI bridge for writing path data to native glass mask.
///
/// This bridge manages shared memory between Flutter and native code.
/// Flutter writes path commands/points, native reads and applies as mask.
///
/// Thread safety:
/// - frameIdPost is written FIRST (signals write in progress)
/// - All data is written
/// - frameId is written LAST (signals write complete)
/// - Native reads frameId, copies data, reads frameIdPost
/// - If frameId != frameIdPost, native skips frame (torn read)
class GlassPathBridge {
  static GlassPathBridge? _instance;
  static GlassPathBridge get instance {
    _instance ??= GlassPathBridge._();
    return _instance!;
  }

  late final DynamicLibrary _lib;
  late final _CreateGlassPathBufferDart _createBuffer;
  _CreateGlassPathBufferLayerDart? _createBufferLayer;
  late final _DestroyGlassPathBufferDart _destroyBuffer;
  _DestroyGlassPathBufferLayerDart? _destroyBufferLayer;
  late final _SetGlassEnabledDart _setEnabled;
  late final _SetGlassMaterialDart _setMaterial;
  _SetGlassMaterialLayerDart? _setMaterialLayer;
  late final _SetGlassDarkDart _setDark;
  _SetGlassDarkLayerDart? _setDarkLayer;
  late final _SetGlassTintOpacityDart _setTintOpacity;
  _SetGlassTintOpacityLayerDart? _setTintOpacityLayer;

  bool _initialized = false;

  /// Active buffers per window ID and layer.
  final Map<String, Map<int, Pointer<GlassPathBuffer>>> _buffers = {};

  /// Frame IDs per window ID and layer (incremented on each write).
  final Map<String, Map<int, int>> _frameIds = {};

  GlassPathBridge._() {
    _initialize();
  }

  void _initialize() {
    if (_initialized) return;

    // Unsupported platform - leave _initialized = false, isAvailable will return false
    if (!Platform.isMacOS && !Platform.isWindows) {
      return;
    }

    try {
      if (Platform.isMacOS) {
        _lib = DynamicLibrary.process();
      } else if (Platform.isWindows) {
        _lib = DynamicLibrary.open('floating_palette_plugin.dll');
      }

      _createBuffer = _lib
          .lookup<NativeFunction<_CreateGlassPathBufferNative>>(
            'FloatingPalette_CreateGlassPathBuffer',
          )
          .asFunction();
      try {
        _createBufferLayer = _lib
            .lookup<NativeFunction<_CreateGlassPathBufferLayerNative>>(
              'FloatingPalette_CreateGlassPathBufferLayer',
            )
            .asFunction();
      } catch (_) {
        _createBufferLayer = null;
      }

      _destroyBuffer = _lib
          .lookup<NativeFunction<_DestroyGlassPathBufferNative>>(
            'FloatingPalette_DestroyGlassPathBuffer',
          )
          .asFunction();
      try {
        _destroyBufferLayer = _lib
            .lookup<NativeFunction<_DestroyGlassPathBufferLayerNative>>(
              'FloatingPalette_DestroyGlassPathBufferLayer',
            )
            .asFunction();
      } catch (_) {
        _destroyBufferLayer = null;
      }

      _setEnabled = _lib
          .lookup<NativeFunction<_SetGlassEnabledNative>>(
            'FloatingPalette_SetGlassEnabled',
          )
          .asFunction();

      _setMaterial = _lib
          .lookup<NativeFunction<_SetGlassMaterialNative>>(
            'FloatingPalette_SetGlassMaterial',
          )
          .asFunction();
      try {
        _setMaterialLayer = _lib
            .lookup<NativeFunction<_SetGlassMaterialLayerNative>>(
              'FloatingPalette_SetGlassMaterialLayer',
            )
            .asFunction();
      } catch (_) {
        _setMaterialLayer = null;
      }

      _setDark = _lib
          .lookup<NativeFunction<_SetGlassDarkNative>>(
            'FloatingPalette_SetGlassDark',
          )
          .asFunction();
      try {
        _setDarkLayer = _lib
            .lookup<NativeFunction<_SetGlassDarkLayerNative>>(
              'FloatingPalette_SetGlassDarkLayer',
            )
            .asFunction();
      } catch (_) {
        _setDarkLayer = null;
      }

      _setTintOpacity = _lib
          .lookup<NativeFunction<_SetGlassTintOpacityNative>>(
            'FloatingPalette_SetGlassTintOpacity',
          )
          .asFunction();
      try {
        _setTintOpacityLayer = _lib
            .lookup<NativeFunction<_SetGlassTintOpacityLayerNative>>(
              'FloatingPalette_SetGlassTintOpacityLayer',
            )
            .asFunction();
      } catch (_) {
        _setTintOpacityLayer = null;
      }

      _initialized = true;
    } catch (e) {
      _initialized = false;
      rethrow;
    }
  }

  /// Whether the bridge is available.
  bool get isAvailable => _initialized;

  /// Create a path buffer for a window and layer.
  /// Returns true if successful.
  bool createBuffer(String windowId, {int layerId = 0}) {
    if (!_initialized) return false;

    final idPtr = windowId.toNativeUtf8().cast<Char>();
    try {
      final ptr = _createBufferLayer != null
          ? _createBufferLayer!(idPtr, layerId)
          : (layerId == 0 ? _createBuffer(idPtr) : nullptr);
      if (ptr == nullptr) return false;

      final layerBuffers = _buffers.putIfAbsent(windowId, () => {});
      final layerFrames = _frameIds.putIfAbsent(windowId, () => {});
      layerBuffers[layerId] = ptr.cast<GlassPathBuffer>();
      layerFrames[layerId] = 0;
      return true;
    } finally {
      calloc.free(idPtr);
    }
  }

  /// Destroy the path buffer for a window and layer.
  void destroyBuffer(String windowId, {int layerId = 0}) {
    if (!_initialized) return;

    final layerBuffers = _buffers[windowId];
    final layerFrames = _frameIds[windowId];
    layerBuffers?.remove(layerId);
    layerFrames?.remove(layerId);
    if (layerBuffers != null && layerBuffers.isEmpty) {
      _buffers.remove(windowId);
    }
    if (layerFrames != null && layerFrames.isEmpty) {
      _frameIds.remove(windowId);
    }

    final idPtr = windowId.toNativeUtf8().cast<Char>();
    try {
      if (_destroyBufferLayer != null) {
        _destroyBufferLayer!(idPtr, layerId);
      } else if (layerId == 0) {
        _destroyBuffer(idPtr);
      }
    } finally {
      calloc.free(idPtr);
    }
  }

  /// Destroy all path buffers for a window.
  void destroyAllBuffers(String windowId) {
    final layers = _buffers[windowId]?.keys.toList() ?? const [];
    for (final layerId in layers) {
      destroyBuffer(windowId, layerId: layerId);
    }
  }

  /// Enable glass effect for a window.
  void setEnabled(String windowId, bool enabled) {
    if (!_initialized) return;

    final idPtr = windowId.toNativeUtf8().cast<Char>();
    try {
      _setEnabled(idPtr, enabled);
    } finally {
      calloc.free(idPtr);
    }
  }

  /// Set the blur material for a window and layer.
  void setMaterial(String windowId, int material, {int layerId = 0}) {
    if (!_initialized) return;

    final idPtr = windowId.toNativeUtf8().cast<Char>();
    try {
      if (_setMaterialLayer != null) {
        _setMaterialLayer!(idPtr, layerId, material);
      } else {
        _setMaterial(idPtr, material);
      }
    } finally {
      calloc.free(idPtr);
    }
  }

  /// Set dark mode for a window and layer.
  void setDark(String windowId, bool isDark, {int layerId = 0}) {
    if (!_initialized) return;

    final idPtr = windowId.toNativeUtf8().cast<Char>();
    try {
      if (_setDarkLayer != null) {
        _setDarkLayer!(idPtr, layerId, isDark);
      } else {
        _setDark(idPtr, isDark);
      }
    } finally {
      calloc.free(idPtr);
    }
  }

  /// Set tint opacity for a window's glass effect.
  /// A dark tint layer is added behind the glass to reduce transparency.
  /// [opacity]: 0.0 = fully transparent (default), 1.0 = fully opaque black
  /// [cornerRadius]: Corner radius for the tint layer (default 16)
  void setTintOpacity(
    String windowId,
    double opacity, {
    double cornerRadius = 16,
    int layerId = 0,
  }) {
    if (!_initialized) return;

    final idPtr = windowId.toNativeUtf8().cast<Char>();
    try {
      if (_setTintOpacityLayer != null) {
        _setTintOpacityLayer!(idPtr, layerId, opacity, cornerRadius);
      } else {
        _setTintOpacity(idPtr, opacity, cornerRadius);
      }
    } finally {
      calloc.free(idPtr);
    }
  }

  /// Write raw path commands and points to the buffer.
  ///
  /// This is the low-level API. For convenience, use [GlassEffectService].
  ///
  /// [commands] - List of path commands (moveTo, lineTo, etc.)
  /// [points] - Flat list of coordinates [x0, y0, x1, y1, ...]
  /// [windowHeight] - Height for Y-flip (Flutter Y=0 top, macOS Y=0 bottom)
  void writePath({
    required String windowId,
    required List<GlassPathCommand> commands,
    required List<double> points,
    required double windowHeight,
    int layerId = 0,
  }) {
    final buffer = _buffers[windowId]?[layerId];
    if (buffer == null) return;

    final layerFrames = _frameIds.putIfAbsent(windowId, () => {});
    final frameId = (layerFrames[layerId] ?? 0) + 1;
    layerFrames[layerId] = frameId;

    // Signal write in progress
    buffer.ref.frameIdPost = frameId;

    buffer.ref.windowHeight = windowHeight;

    // Write commands (max 1024)
    final cmdCount = commands.length < 1024 ? commands.length : 1024;
    buffer.ref.commandCount = cmdCount;
    for (int i = 0; i < cmdCount; i++) {
      buffer.ref.commands[i] = commands[i].index;
    }

    // Write points (max 2048 floats = 1024 points)
    final ptCount = points.length < 2048 ? points.length : 2048;
    buffer.ref.pointCount = ptCount ~/ 2;
    for (int i = 0; i < ptCount; i++) {
      buffer.ref.points[i] = points[i];
    }

    // Signal write complete
    buffer.ref.frameId = frameId;
  }

  /// Check if a buffer exists for a window and layer.
  bool hasBuffer(String windowId, {int layerId = 0}) =>
      _buffers[windowId]?.containsKey(layerId) ?? false;
}
