import 'dart:async';
import 'package:flutter/material.dart';

/// Controller for imperatively controlling a [PaletteBorder].
///
/// Use this when you need to trigger border effects without rebuilding
/// the widget tree (e.g., from a service or callback).
///
/// ```dart
/// final controller = PaletteBorderController();
///
/// // Later:
/// controller.flash(Colors.red);
/// controller.pulse(Colors.orange, count: 2);
/// controller.set(Colors.blue);
/// controller.clear();
/// ```
class PaletteBorderController extends ChangeNotifier {
  Color _color = Colors.transparent;
  double _width = 2.0;
  double _glowRadius = 0.0;
  bool _isAnimating = false;

  /// Current border color.
  Color get color => _color;

  /// Current border width.
  double get width => _width;

  /// Current glow radius.
  double get glowRadius => _glowRadius;

  /// Whether an animation is currently running.
  bool get isAnimating => _isAnimating;

  Timer? _animationTimer;

  /// Set a solid border color.
  void set(Color color, {double? width, double? glowRadius}) {
    _color = color;
    if (width != null) _width = width;
    if (glowRadius != null) _glowRadius = glowRadius;
    notifyListeners();
  }

  /// Clear the border (transparent).
  void clear() {
    _color = Colors.transparent;
    _glowRadius = 0.0;
    notifyListeners();
  }

  /// Flash the border briefly.
  ///
  /// [color] - The flash color
  /// [duration] - How long the flash lasts (default 300ms)
  void flash(Color color, {Duration duration = const Duration(milliseconds: 300)}) {
    _cancelAnimation();
    _color = color;
    _glowRadius = 8.0;
    _isAnimating = true;
    notifyListeners();

    _animationTimer = Timer(duration, () {
      _color = Colors.transparent;
      _glowRadius = 0.0;
      _isAnimating = false;
      notifyListeners();
    });
  }

  /// Pulse the border multiple times.
  ///
  /// [color] - The pulse color
  /// [count] - Number of pulses (default 2)
  /// [interval] - Time between pulses (default 200ms)
  void pulse(Color color, {int count = 2, Duration interval = const Duration(milliseconds: 200)}) {
    _cancelAnimation();
    _isAnimating = true;

    int currentPulse = 0;
    bool isOn = true;

    void doPulse() {
      if (currentPulse >= count * 2) {
        _color = Colors.transparent;
        _glowRadius = 0.0;
        _isAnimating = false;
        notifyListeners();
        return;
      }

      if (isOn) {
        _color = color;
        _glowRadius = 8.0;
      } else {
        _color = Colors.transparent;
        _glowRadius = 0.0;
      }
      notifyListeners();

      isOn = !isOn;
      currentPulse++;
      _animationTimer = Timer(interval, doPulse);
    }

    doPulse();
  }

  /// Show a warning effect (red flash + optional shake).
  void warning({Duration duration = const Duration(milliseconds: 500)}) {
    flash(const Color(0xFFEF4444), duration: duration);
  }

  /// Show a success effect (green flash).
  void success({Duration duration = const Duration(milliseconds: 300)}) {
    flash(const Color(0xFF10B981), duration: duration);
  }

  void _cancelAnimation() {
    _animationTimer?.cancel();
    _animationTimer = null;
  }

  @override
  void dispose() {
    _cancelAnimation();
    super.dispose();
  }
}

/// A decorative border wrapper for palette content.
///
/// Provides animated colored borders with optional glow effects.
/// Can be controlled declaratively via props or imperatively via controller.
///
/// ## Declarative Usage (widget tree state)
///
/// ```dart
/// PaletteBorder(
///   color: _isWarning ? Colors.red : Colors.transparent,
///   width: 2.0,
///   glowRadius: _isWarning ? 8.0 : 0.0,
///   child: PaletteScaffold(...),
/// )
/// ```
///
/// ## Imperative Usage (controller)
///
/// ```dart
/// final _controller = PaletteBorderController();
///
/// PaletteBorder(
///   controller: _controller,
///   child: PaletteScaffold(...),
/// )
///
/// // Trigger effects:
/// _controller.flash(Colors.red);
/// _controller.pulse(Colors.orange, count: 2);
/// ```
class PaletteBorder extends StatefulWidget {
  /// The child widget to wrap with a border.
  final Widget child;

  /// Border color (declarative mode).
  ///
  /// Ignored if [controller] is provided.
  final Color color;

  /// Border width.
  final double width;

  /// Outer glow radius. Set to 0 for no glow.
  final double glowRadius;

  /// Corner radius for the border.
  final double cornerRadius;

  /// Animation duration for color transitions.
  final Duration animationDuration;

  /// Animation curve for color transitions.
  final Curve animationCurve;

  /// Controller for imperative control.
  ///
  /// When provided, [color] and [glowRadius] props are ignored.
  final PaletteBorderController? controller;

  const PaletteBorder({
    super.key,
    required this.child,
    this.color = Colors.transparent,
    this.width = 2.0,
    this.glowRadius = 0.0,
    this.cornerRadius = 12.0,
    this.animationDuration = const Duration(milliseconds: 200),
    this.animationCurve = Curves.easeInOut,
    this.controller,
  });

  @override
  State<PaletteBorder> createState() => _PaletteBorderState();
}

class _PaletteBorderState extends State<PaletteBorder> {
  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(PaletteBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerChanged);
      widget.controller?.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final color = controller?.color ?? widget.color;
    final glowRadius = controller?.glowRadius ?? widget.glowRadius;

    return AnimatedContainer(
      duration: widget.animationDuration,
      curve: widget.animationCurve,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.cornerRadius),
        border: Border.all(
          color: color,
          width: color == Colors.transparent ? 0 : widget.width,
        ),
        boxShadow: glowRadius > 0
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: glowRadius,
                  spreadRadius: glowRadius / 4,
                ),
              ]
            : null,
      ),
      child: widget.child,
    );
  }
}
