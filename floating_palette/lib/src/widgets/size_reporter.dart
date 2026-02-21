// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../ffi/ffi.dart' as ffi;

/// A widget that reports its size to native and resizes the window.
///
/// Uses synchronous FFI to resize the native panel DURING layout,
/// achieving zero-latency resize where the panel resizes BEFORE Flutter paints.
///
/// This is more efficient than using post-frame callbacks or polling,
/// as it only fires when the size actually changes during layout.
///
/// **Note:** This is an internal widget used by [PaletteScaffold].
/// Users should not use this directly - just use PaletteScaffold and
/// content will automatically resize the window.
///
/// The window ID is set globally via [SizeReporter.setWindowId] by the
/// palette runner, since each palette runs in its own Flutter engine
/// (one window per engine).
class SizeReporter extends SingleChildRenderObjectWidget {
  /// Called whenever the child's size changes (after FFI resize).
  final void Function(Size size)? onSizeChanged;

  /// Global window ID for this engine.
  /// Set by the palette runner on startup.
  static String? _windowId;

  /// Set the window ID for this engine.
  /// Called by the palette runner during initialization.
  static void setWindowId(String id) {
    _windowId = id;
  }

  /// Get the current window ID.
  static String? get windowId => _windowId;

  /// Static flag to force next layout to report size.
  /// Set to true when palette is re-shown.
  static bool _forceNextReportGlobal = false;

  /// Static flag to suppress size reporting.
  /// When true, SizeReporter will not call FFI to resize window.
  /// Used during animations when caller pre-resizes window to final size.
  static bool _suppressReporting = false;

  /// Force the next layout to report size, even if unchanged.
  /// Call this when the palette is re-shown to ensure correct initial size.
  static void forceNextReport() {
    _forceNextReportGlobal = true;
  }

  /// Check and consume the force flag.
  static bool consumeForceFlag() {
    if (_forceNextReportGlobal) {
      _forceNextReportGlobal = false;
      return true;
    }
    return false;
  }

  /// Suppress size reporting temporarily.
  ///
  /// When suppressed, SizeReporter will not call FFI to resize window,
  /// but will still call [onSizeChanged] callback.
  ///
  /// Use this during animations when you pre-resize the window to the
  /// final size and don't want intermediate sizes reported.
  static void suppressReporting(bool suppress) {
    _suppressReporting = suppress;
  }

  /// Check if reporting is currently suppressed.
  static bool get isReportingSuppressed => _suppressReporting;

  const SizeReporter({
    super.key,
    this.onSizeChanged,
    required Widget child,
  }) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSizeReporter(onSizeChanged: onSizeChanged);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderSizeReporter renderObject,
  ) {
    renderObject.onSizeChanged = onSizeChanged;
  }
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter({required this.onSizeChanged});

  void Function(Size size)? onSizeChanged;
  Size? _lastSize;

  @override
  void performLayout() {
    // Use UNCONSTRAINED layout so child can size to its intrinsic size
    // The initial window size (300x200) shouldn't limit content size
    // SizeReporter will resize the window to match content
    const unconstrainedLayout = BoxConstraints(
      minWidth: 0,
      maxWidth: double.infinity,
      minHeight: 0,
      maxHeight: double.infinity,
    );

    child!.layout(unconstrainedLayout, parentUsesSize: true);

    // Get the child's desired size (this is what we'll report to native)
    final childSize = child!.size;

    // SizeReporter itself must respect parent constraints
    // If parent gives tight constraints, we must match them for Flutter's layout
    // But we report the CHILD's actual size to native for window sizing
    size = constraints.constrain(childSize);

    // Check if we need to force a report (e.g., palette re-shown)
    final forceReport = SizeReporter.consumeForceFlag();

    // If force flag was set, clear cached size to ensure report happens
    if (forceReport) {
      _lastSize = null;
    }

    // Only resize if size actually changed (with epsilon for float jitter)
    // OR if we're forcing a report (e.g., after palette re-show)
    final shouldReport = forceReport ||
        _lastSize == null ||
        (childSize.width - _lastSize!.width).abs() > 0.5 ||
        (childSize.height - _lastSize!.height).abs() > 0.5;

    if (shouldReport) {
      _lastSize = childSize;

      // Get the window ID for this engine
      final windowId = SizeReporter.windowId;
      if (windowId == null) {
        // ignore: avoid_print
        print('[SizeReporter] No windowId set - skipping resize');
        return;
      }

      // Size change logged only when explicitly debugging layout issues
      // debugPrint('[SizeReporter] Resizing "$windowId" to ${childSize.width}x${childSize.height}');

      // FFI call - dispatches resize to run after layout completes
      // Uses DispatchQueue.main.async on native side to avoid layout re-entry
      try {
        ffi.SyncNativeBridge.instance.resizeWindow(
          windowId,
          childSize.width,
          childSize.height,
        );
      } catch (e) {
        // FFI not available (e.g., running in test environment)
        // ignore: avoid_print
        print('[SizeReporter] FFI error: $e');
      }

      // Notify listener
      onSizeChanged?.call(childSize);
    }
  }
}

/// A widget that measures its child's intrinsic size and reports changes.
///
/// Unlike [SizeReporter], this measures the child's preferred/intrinsic size,
/// not its actual laid out size. This is useful when the child is in a
/// constrained context but you want to know what size it "wants" to be.
///
/// **Note:** This is an internal widget. The window ID is obtained from
/// [SizeReporter.windowId] which is set by the palette runner.
class IntrinsicSizeReporter extends StatefulWidget {
  /// The child widget to measure.
  final Widget child;

  /// Called whenever the child's intrinsic size changes.
  final void Function(Size size)? onSizeChanged;

  /// The width constraint to use when measuring intrinsic height.
  final double width;

  const IntrinsicSizeReporter({
    super.key,
    required this.child,
    this.onSizeChanged,
    required this.width,
  });

  @override
  State<IntrinsicSizeReporter> createState() => _IntrinsicSizeReporterState();
}

class _IntrinsicSizeReporterState extends State<IntrinsicSizeReporter> {
  final _childKey = GlobalKey();
  Size? _lastReportedSize;

  @override
  void initState() {
    super.initState();
    _measureAfterFrame();
  }

  @override
  void didUpdateWidget(IntrinsicSizeReporter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _measureAfterFrame();
  }

  void _measureAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _measureAndReport();
    });
  }

  void _measureAndReport() {
    final renderBox =
        _childKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    // Get the window ID for this engine
    final windowId = SizeReporter.windowId;
    if (windowId == null) return;

    // Get the intrinsic dimensions
    final intrinsicHeight = renderBox.getMinIntrinsicHeight(widget.width);
    final intrinsicWidth = renderBox.getMinIntrinsicWidth(double.infinity);

    final size = Size(
      intrinsicWidth.clamp(0, widget.width),
      intrinsicHeight,
    );

    // Only report if changed significantly (>0.5 pixel)
    if (_lastReportedSize == null ||
        (size.width - _lastReportedSize!.width).abs() > 0.5 ||
        (size.height - _lastReportedSize!.height).abs() > 0.5) {
      _lastReportedSize = size;

      // FFI call
      try {
        ffi.SyncNativeBridge.instance.resizeWindow(
          windowId,
          size.width,
          size.height,
        );
      } catch (e) {
        // FFI not available
      }

      widget.onSizeChanged?.call(size);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _childKey,
      child: widget.child,
    );
  }
}
