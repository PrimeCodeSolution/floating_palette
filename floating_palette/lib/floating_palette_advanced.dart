/// Floating Palette - Advanced API for power users.
///
/// This library exports the full API including:
/// - Native bridge for direct method channel access
/// - Individual service clients
/// - FFI for synchronous native calls
/// - Testing utilities
///
/// ## When to use this
///
/// Use this library when you need:
/// - Direct access to service clients (WindowClient, FrameClient, etc.)
/// - Custom native bridge implementations
/// - FFI for synchronous operations
/// - Mock bridge for testing
///
/// ## Simple API
///
/// For most use cases, import `floating_palette.dart` instead.
library;

// Re-export everything from the simple API
export 'floating_palette.dart';

// ════════════════════════════════════════════════════════════════════════════════
// Core (additional)
// ════════════════════════════════════════════════════════════════════════════════

export 'src/core/core.dart';

// ════════════════════════════════════════════════════════════════════════════════
// Bridge (native communication layer)
// ════════════════════════════════════════════════════════════════════════════════

export 'src/bridge/bridge.dart';

// ════════════════════════════════════════════════════════════════════════════════
// Services (individual service clients)
// ════════════════════════════════════════════════════════════════════════════════

export 'src/services/services.dart';

// ════════════════════════════════════════════════════════════════════════════════
// Input (full input management)
// ════════════════════════════════════════════════════════════════════════════════

export 'src/input/input.dart';

// ════════════════════════════════════════════════════════════════════════════════
// Positioning (full positioning utilities)
// ════════════════════════════════════════════════════════════════════════════════

export 'src/positioning/positioning.dart';

// ════════════════════════════════════════════════════════════════════════════════
// Configuration (all config classes)
// ════════════════════════════════════════════════════════════════════════════════

export 'src/config/config.dart';

// ════════════════════════════════════════════════════════════════════════════════
// Controller (full controller with helpers)
// ════════════════════════════════════════════════════════════════════════════════

export 'src/controller/controller.dart';

// ════════════════════════════════════════════════════════════════════════════════
// Events (full events)
// ════════════════════════════════════════════════════════════════════════════════

export 'src/events/events.dart';

// ════════════════════════════════════════════════════════════════════════════════
// Runner (palette entry points)
// ════════════════════════════════════════════════════════════════════════════════

export 'src/runner/runner.dart';

// ════════════════════════════════════════════════════════════════════════════════
// Widgets (all palette widgets)
// ════════════════════════════════════════════════════════════════════════════════

export 'src/widgets/widgets.dart';

// ════════════════════════════════════════════════════════════════════════════════
// FFI (synchronous native calls)
// ════════════════════════════════════════════════════════════════════════════════

export 'src/ffi/ffi.dart';

// ════════════════════════════════════════════════════════════════════════════════
// Testing (mocks and test utilities)
// ════════════════════════════════════════════════════════════════════════════════

export 'src/testing/testing.dart';

// ════════════════════════════════════════════════════════════════════════════════
// Snap (full snap API including behavior enums)
// ════════════════════════════════════════════════════════════════════════════════

export 'src/snap/snap.dart';
