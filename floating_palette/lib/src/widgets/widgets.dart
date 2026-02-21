/// Widgets for floating palette content.
///
/// This module provides widgets for building palette content:
/// - [PaletteScaffold] - Root widget for palette content (handles sizing)
/// - [PaletteWindow] - Utilities for window operations (dragging, etc.)
///
/// Internal widgets (not exported):
/// - SizeReporter - Internal widget for content-driven window sizing
/// - IntrinsicSizeReporter - Internal widget for intrinsic size measurement
library;

// NOTE: size_reporter.dart is intentionally NOT exported.
// It's an internal widget used by PaletteScaffold.
// SizeReporter uses a static windowId set by the palette runner,
// since each palette runs in its own Flutter engine (one window per engine).

export 'animated_gradient_border.dart';
export 'palette_border.dart';
export 'palette_scaffold.dart';
export 'palette_window.dart';
export 'palette_background_capture.dart';
