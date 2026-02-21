/// FFI bindings for synchronous native calls.
///
/// This module provides direct synchronous calls to native code,
/// bypassing MethodChannel for time-critical operations.
///
/// Key features:
/// - [SyncNativeBridge] - High-level API for synchronous FFI calls
/// - [GlassPathBridge] - Low-level FFI for glass mask effects
/// - Window resizing (for SizeReporter)
/// - Cursor position queries
/// - Screen bounds queries
/// - Active app bounds queries
library;

export 'glass_path_bridge.dart' show GlassPathBridge, GlassPathCommand;
export 'native_bridge.dart' show SyncNativeBridge, Point, NativeRect;
