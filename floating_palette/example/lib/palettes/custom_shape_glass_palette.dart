import 'dart:math';
import 'package:floating_palette/floating_palette.dart';
import 'package:flutter/material.dart';

/// Shapes that can be rendered with Liquid Glass effect
enum GlassShape { circle, star, blob, roundedRect }

/// Demo palette showcasing CustomPainter + Liquid Glass integration.
/// Draws various shapes and sends them to native for the glass effect.
class CustomShapeGlassPalette extends StatefulWidget {
  const CustomShapeGlassPalette({super.key});

  @override
  State<CustomShapeGlassPalette> createState() =>
      _CustomShapeGlassPaletteState();
}

class _CustomShapeGlassPaletteState extends State<CustomShapeGlassPalette>
    with TickerProviderStateMixin {
  static const Size _windowSize = Size(350, 500);
  static const Size _shapeSize = Size(350, 350);
  static const double _ballSize = 48.0;

  final GlassEffectService _glassService = GlassEffectService();
  final Random _rand = Random();
  late AnimationController _animController;
  GlassShape _currentShape = GlassShape.circle;
  String? _windowId;
  bool _glassEnabled = false;
  bool _isPaused = false;

  // Throttle glass updates to ~30fps to reduce FFI traffic
  int _lastUpdateFrame = 0;

  double _shapeTintOpacity = 0.0;
  Offset _ballPosition = const Offset(175, 175);
  Offset _ballVelocity = const Offset(160, 120);
  final Stopwatch _physicsClock = Stopwatch();
  int _lastPhysicsMicros = 0;
  Offset _pendingImpulse = Offset.zero;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _animController.addListener(_tickBall);
    _physicsClock.start();
    _ballPosition = Offset(_shapeSize.width / 2, _shapeSize.height / 2);
    _ballVelocity = _randomVelocity();

    // Initialize glass after first frame to ensure window is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initGlass();
    });
  }

  Future<void> _initGlass() async {
    _windowId = PaletteWindow.currentId;
    if (_windowId == null || !_glassService.isAvailable) return;

    final success = _glassService.enable(_windowId!);
    if (success && mounted) {
      setState(() => _glassEnabled = true);
      _animController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    if (_windowId != null) {
      _glassService.disable(_windowId!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: MouseRegion(
        cursor: SystemMouseCursors.move,
        child: GestureDetector(
          onPanStart: (_) => PaletteWindow.startDrag(),
          onPanUpdate: (details) {
            final impulse = details.delta * 12.0;
            _pendingImpulse = _pendingImpulse + impulse;
          },
          child: PaletteScaffold(
            backgroundColor: Colors.transparent,
            cornerRadius: 0, // Shape defines corners
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, _) {
                // Throttle glass updates (every 2nd frame ~30fps)
                final currentFrame = _animController.value.hashCode;
                if (_windowId != null &&
                    _glassEnabled &&
                    currentFrame != _lastUpdateFrame) {
                  _lastUpdateFrame = currentFrame;
                  // Schedule glass update after this frame
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _glassEnabled) {
                      _updateGlassPath(_shapeSize, _windowSize);
                    }
                  });
                }

                return SizedBox(
                  width: _windowSize.width,
                  height: _windowSize.height,
                  child: Column(
                    children: [
                      SizedBox(
                        width: _shapeSize.width,
                        height: _shapeSize.height,
                        child: Stack(
                          children: [
                            // CustomPaint draws the shape border/overlay
                            Positioned.fill(
                              child: CustomPaint(
                                painter: GlassShapePainter(
                                  shape: _currentShape,
                                  animationValue: _animController.value,
                                  shapeTintOpacity: _shapeTintOpacity,
                                ),
                              ),
                            ),
                            // Bouncing ball with optional content inside
                            ClipPath(
                              clipper: _GlassShapeClipper(
                                shape: _currentShape,
                                animationValue: _animController.value,
                              ),
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: _ballPosition.dx - _ballSize / 2,
                                    top: _ballPosition.dy - _ballSize / 2,
                                    child: _buildBall(),
                                  ),
                                ],
                              ),
                            ),
                            // Status text
                            Positioned(
                              top: 20,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Text(
                                  _glassEnabled
                                      ? 'Liquid Glass: ${_currentShape.name}'
                                      : 'Initializing...',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Bottom controls with background
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xDD1E1E1E),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 8,
                        ),
                        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildShapeButtons(),
                            const SizedBox(height: 6),
                            _buildPausePlayButton(),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: _buildTintSlider(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _updateGlassPath(Size shapeSize, Size windowSize) {
    if (_windowId == null || !_glassEnabled) return;

    final shapePath = _buildShapePath(
      shapeSize,
      _currentShape,
      _animController.value,
    );
    final ballPath = Path()
      ..addOval(Rect.fromCircle(center: _ballPosition, radius: _ballSize / 2));
    _glassService.updatePath(
      _windowId!,
      shapePath,
      windowHeight: windowSize.height,
      layerId: 0,
    );
    _glassService.updatePath(
      _windowId!,
      ballPath,
      windowHeight: windowSize.height,
      layerId: 1,
    );
  }

  void _tickBall() {
    final micros = _physicsClock.elapsedMicroseconds;
    if (_lastPhysicsMicros == 0) {
      _lastPhysicsMicros = micros;
      return;
    }

    var dt = (micros - _lastPhysicsMicros) / 1000000.0;
    _lastPhysicsMicros = micros;
    if (dt <= 0) return;
    if (dt > 0.05) dt = 0.05;

    final path = _buildShapePath(
      _shapeSize,
      _currentShape,
      _animController.value,
    );
    final colliderRadius = _collisionRadius();
    if (!_isBallInside(path, _ballPosition, colliderRadius)) {
      final center = Offset(_shapeSize.width / 2, _shapeSize.height / 2);
      final t = _findLastInsideFraction(
        path,
        center,
        _ballPosition,
        colliderRadius,
      );
      _ballPosition = _lerpOffset(center, _ballPosition, t);
      _ballVelocity = _ballVelocity * 0.7;
      final normal = _estimateNormal(path, _ballPosition, colliderRadius);
      if (normal.distance > 0.0001) {
        final n = normal / normal.distance;
        final push = _dot(_ballVelocity, n);
        if (push > 0) {
          _ballVelocity = _ballVelocity - n * push;
        }
      }
    }

    const gravity = Offset(0, 160);
    const maxSpeed = 320.0;
    const maxStep = 1 / 120;
    const maxIterations = 8;
    const restitution = 0.9;
    const pushInEpsilon = 0.6;

    var remaining = dt;
    var position = _ballPosition;
    var velocity = _ballVelocity + _pendingImpulse;
    _pendingImpulse = Offset.zero;
    var iterations = 0;

    while (remaining > 0 && iterations < maxIterations) {
      final step = remaining > maxStep ? maxStep : remaining;
      velocity = velocity + gravity * step;
      velocity = _clampMagnitude(velocity, maxSpeed);

      final next = position + velocity * step;
      if (_isBallInside(path, next, colliderRadius)) {
        position = next;
        remaining -= step;
        iterations++;
        continue;
      }

      final hitT = _findLastInsideFraction(
        path,
        position,
        next,
        colliderRadius,
      );
      final contact = _lerpOffset(position, next, hitT);
      final normal = _estimateNormal(path, contact, colliderRadius);
      if (normal.distance > 0.0001) {
        final n = normal / normal.distance;
        velocity = velocity - n * (2 * _dot(velocity, n));
        velocity = velocity * restitution;
        position = contact - n * pushInEpsilon;
      } else {
        velocity = Offset(-velocity.dx, -velocity.dy) * restitution;
        position = contact;
      }

      remaining -= step * hitT;
      if (hitT < 0.001) {
        break;
      }
      iterations++;
    }

    _ballPosition = position;
    _ballVelocity = velocity;
  }

  Offset _randomVelocity() {
    final angle = _rand.nextDouble() * pi * 2;
    final speed = 140 + _rand.nextDouble() * 120;
    return Offset(cos(angle) * speed, sin(angle) * speed);
  }

  double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

  Offset _clampMagnitude(Offset v, double max) {
    final mag = v.distance;
    if (mag <= max) return v;
    return v / mag * max;
  }

  bool _isBallInside(Path path, Offset center, double radius) {
    if (!path.contains(center)) return false;
    const samples = 8;
    for (var i = 0; i < samples; i++) {
      final angle = (i / samples) * pi * 2;
      final p = center + Offset(cos(angle) * radius, sin(angle) * radius);
      if (!path.contains(p)) return false;
    }
    return true;
  }

  double _findLastInsideFraction(
    Path path,
    Offset from,
    Offset to,
    double radius,
  ) {
    var lo = 0.0;
    var hi = 1.0;
    for (var i = 0; i < 8; i++) {
      final mid = (lo + hi) / 2;
      final p = _lerpOffset(from, to, mid);
      if (_isBallInside(path, p, radius)) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  Offset _lerpOffset(Offset a, Offset b, double t) {
    return Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);
  }

  Offset _estimateNormal(Path path, Offset p, double radius) {
    const dirs = [
      Offset(1, 0),
      Offset(-1, 0),
      Offset(0, 1),
      Offset(0, -1),
      Offset(1, 1),
      Offset(-1, 1),
      Offset(1, -1),
      Offset(-1, -1),
    ];
    const eps = 2.5;
    for (final d in dirs) {
      final probe = p + Offset(d.dx * (radius + eps), d.dy * (radius + eps));
      if (!path.contains(probe)) {
        return d;
      }
    }
    return -_ballVelocity;
  }

  double _collisionRadius() => _ballSize / 2;

  /// The bouncing ball with content inside. Swap the child widget here.
  Widget _buildBall() {
    return Container(
      width: _ballSize,
      height: _ballSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0x22FFFFFF),
        border: Border.all(color: const Color(0x55FFFFFF), width: 1),
      ),
      child: const Center(
        // child: SizedBox.shrink(),
        child: FlutterLogo(style: FlutterLogoStyle.markOnly),
      ),
    );
  }

  Path _buildShapePath(Size size, GlassShape shape, double animValue) {
    switch (shape) {
      case GlassShape.circle:
        return _buildCircle(size, animValue);
      case GlassShape.star:
        return _buildStar(size, animValue);
      case GlassShape.blob:
        return _buildBlob(size, animValue);
      case GlassShape.roundedRect:
        return _buildRoundedRect(size, animValue);
    }
  }

  Path _buildCircle(Size size, double animValue) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = min(size.width, size.height) / 2 * 0.85;
    final radius = baseRadius * (0.85 + 0.15 * animValue);
    return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  Path _buildStar(Size size, double animValue, {int points = 5}) {
    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width, size.height) / 2 * 0.85;
    final outerRadius = maxRadius * (0.85 + 0.15 * animValue);
    final innerRadius = outerRadius * 0.5;

    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? outerRadius : innerRadius;
      final angle = (i * pi / points) - pi / 2;
      final point = center + Offset(cos(angle) * r, sin(angle) * r);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  Path _buildBlob(Size size, double animValue) {
    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = min(size.width, size.height) / 2 * 0.7;

    const numPoints = 8;
    final List<Offset> points = [];

    for (int i = 0; i < numPoints; i++) {
      final angle = (i / numPoints) * 2 * pi;
      final wobble = sin(angle * 3 + animValue * 2 * pi) * 15;
      final wobble2 = cos(angle * 2 - animValue * pi) * 10;
      final radius = baseRadius + wobble + wobble2;
      points.add(center + Offset(cos(angle) * radius, sin(angle) * radius));
    }

    // Create smooth curve through points using cubic bezier
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < numPoints; i++) {
      final p0 = points[i];
      final p1 = points[(i + 1) % numPoints];
      final p2 = points[(i + 2) % numPoints];

      final cp1 = Offset(
        p0.dx + (p1.dx - points[(i - 1 + numPoints) % numPoints].dx) / 4,
        p0.dy + (p1.dy - points[(i - 1 + numPoints) % numPoints].dy) / 4,
      );
      final cp2 = Offset(
        p1.dx - (p2.dx - p0.dx) / 4,
        p1.dy - (p2.dy - p0.dy) / 4,
      );

      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
    }

    path.close();
    return path;
  }

  Path _buildRoundedRect(Size size, double animValue) {
    final padding = 20.0 + 10.0 * animValue;
    final cornerRadius = 20.0 + 10.0 * animValue;
    return Path()..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          padding,
          padding,
          size.width - padding * 2,
          size.height - padding * 2,
        ),
        Radius.circular(cornerRadius),
      ),
    );
  }

  Widget _buildTintSlider() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Tint: ${(_shapeTintOpacity * 100).toInt()}%',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w400,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: Colors.white70,
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
            overlayColor: Colors.white24,
          ),
          child: Slider(
            value: _shapeTintOpacity,
            min: 0.0,
            max: 1.0,
            onChanged: (value) => setState(() => _shapeTintOpacity = value),
          ),
        ),
      ],
    );
  }

  Widget _buildPausePlayButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isPaused = !_isPaused;
          if (_isPaused) {
            _animController.stop();
            _lastPhysicsMicros = 0;
          } else {
            _physicsClock.reset();
            _physicsClock.start();
            _lastPhysicsMicros = 0;
            _animController.repeat(reverse: true);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: _isPaused
              ? const Color(0x60FFFFFF)
              : const Color(0x30FFFFFF),
          borderRadius: BorderRadius.circular(6),
          border: _isPaused
              ? Border.all(color: const Color(0x80FFFFFF), width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isPaused ? Icons.play_arrow : Icons.pause,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              _isPaused ? 'Resume' : 'Pause',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShapeButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: GlassShape.values.map((shape) {
        final isSelected = _currentShape == shape;
        return GestureDetector(
          onTap: () => setState(() => _currentShape = shape),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0x60FFFFFF)
                  : const Color(0x30FFFFFF),
              borderRadius: BorderRadius.circular(6),
              border: isSelected
                  ? Border.all(color: const Color(0x80FFFFFF), width: 1)
                  : null,
            ),
            child: Text(
              shape.name,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// CustomPainter that draws the shape border/overlay.
/// The actual glass effect is applied natively based on the path sent via GlassEffectService.
class GlassShapePainter extends CustomPainter {
  final GlassShape shape;
  final double animationValue;
  final double shapeTintOpacity;

  GlassShapePainter({
    required this.shape,
    required this.animationValue,
    this.shapeTintOpacity = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(size);

    // Reduce border visibility as tint increases (avoid double shape appearance)
    final borderAlpha = (0.3 * (1 - shapeTintOpacity)).clamp(0.0, 1.0);
    final glowAlpha = (0.12 * (1 - shapeTintOpacity)).clamp(0.0, 1.0);

    if (shapeTintOpacity > 0.01) {
      final fillPaint = Paint()
        ..color = Color.fromRGBO(30, 30, 30, shapeTintOpacity)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);
    }

    if (borderAlpha > 0.01) {
      final borderPaint = Paint()
        ..color = Color.fromRGBO(255, 255, 255, borderAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawPath(path, borderPaint);
    }

    if (glowAlpha > 0.01) {
      final glowPaint = Paint()
        ..color = Color.fromRGBO(255, 255, 255, glowAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawPath(path, glowPaint);
    }
  }

  Path _buildPath(Size size) {
    switch (shape) {
      case GlassShape.circle:
        return _buildCircle(size);
      case GlassShape.star:
        return _buildStar(size);
      case GlassShape.blob:
        return _buildBlob(size);
      case GlassShape.roundedRect:
        return _buildRoundedRect(size);
    }
  }

  Path _buildCircle(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = min(size.width, size.height) / 2 * 0.85;
    final radius = baseRadius * (0.85 + 0.15 * animationValue);
    return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  Path _buildStar(Size size, {int points = 5}) {
    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width, size.height) / 2 * 0.85;
    final outerRadius = maxRadius * (0.85 + 0.15 * animationValue);
    final innerRadius = outerRadius * 0.5;

    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? outerRadius : innerRadius;
      final angle = (i * pi / points) - pi / 2;
      final point = center + Offset(cos(angle) * r, sin(angle) * r);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  Path _buildBlob(Size size) {
    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = min(size.width, size.height) / 2 * 0.7;

    const numPoints = 8;
    final List<Offset> points = [];

    for (int i = 0; i < numPoints; i++) {
      final angle = (i / numPoints) * 2 * pi;
      final wobble = sin(angle * 3 + animationValue * 2 * pi) * 15;
      final wobble2 = cos(angle * 2 - animationValue * pi) * 10;
      final radius = baseRadius + wobble + wobble2;
      points.add(center + Offset(cos(angle) * radius, sin(angle) * radius));
    }

    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < numPoints; i++) {
      final p0 = points[i];
      final p1 = points[(i + 1) % numPoints];
      final p2 = points[(i + 2) % numPoints];

      final cp1 = Offset(
        p0.dx + (p1.dx - points[(i - 1 + numPoints) % numPoints].dx) / 4,
        p0.dy + (p1.dy - points[(i - 1 + numPoints) % numPoints].dy) / 4,
      );
      final cp2 = Offset(
        p1.dx - (p2.dx - p0.dx) / 4,
        p1.dy - (p2.dy - p0.dy) / 4,
      );

      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
    }

    path.close();
    return path;
  }

  Path _buildRoundedRect(Size size) {
    final padding = 20.0 + 10.0 * animationValue;
    final cornerRadius = 20.0 + 10.0 * animationValue;
    return Path()..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          padding,
          padding,
          size.width - padding * 2,
          size.height - padding * 2,
        ),
        Radius.circular(cornerRadius),
      ),
    );
  }

  @override
  bool shouldRepaint(GlassShapePainter oldDelegate) {
    return oldDelegate.shape != shape ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.shapeTintOpacity != shapeTintOpacity;
  }
}

class _GlassShapeClipper extends CustomClipper<Path> {
  final GlassShape shape;
  final double animationValue;

  _GlassShapeClipper({required this.shape, required this.animationValue});

  @override
  Path getClip(Size size) {
    final baseSize = Size(size.width, size.height);
    switch (shape) {
      case GlassShape.circle:
        return _buildCircle(baseSize);
      case GlassShape.star:
        return _buildStar(baseSize);
      case GlassShape.blob:
        return _buildBlob(baseSize);
      case GlassShape.roundedRect:
        return _buildRoundedRect(baseSize);
    }
  }

  Path _buildCircle(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = min(size.width, size.height) / 2 * 0.85;
    final radius = baseRadius * (0.85 + 0.15 * animationValue);
    return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  Path _buildStar(Size size, {int points = 5}) {
    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width, size.height) / 2 * 0.85;
    final outerRadius = maxRadius * (0.85 + 0.15 * animationValue);
    final innerRadius = outerRadius * 0.5;

    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? outerRadius : innerRadius;
      final angle = (i * pi / points) - pi / 2;
      final point = center + Offset(cos(angle) * r, sin(angle) * r);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  Path _buildBlob(Size size) {
    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = min(size.width, size.height) / 2 * 0.7;

    const numPoints = 8;
    final List<Offset> points = [];

    for (int i = 0; i < numPoints; i++) {
      final angle = (i / numPoints) * 2 * pi;
      final wobble = sin(angle * 3 + animationValue * 2 * pi) * 15;
      final wobble2 = cos(angle * 2 - animationValue * pi) * 10;
      final radius = baseRadius + wobble + wobble2;
      points.add(center + Offset(cos(angle) * radius, sin(angle) * radius));
    }

    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < numPoints; i++) {
      final p0 = points[i];
      final p1 = points[(i + 1) % numPoints];
      final p2 = points[(i + 2) % numPoints];

      final cp1 = Offset(
        p0.dx + (p1.dx - points[(i - 1 + numPoints) % numPoints].dx) / 4,
        p0.dy + (p1.dy - points[(i - 1 + numPoints) % numPoints].dy) / 4,
      );
      final cp2 = Offset(
        p1.dx - (p2.dx - p0.dx) / 4,
        p1.dy - (p2.dy - p0.dy) / 4,
      );

      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
    }

    path.close();
    return path;
  }

  Path _buildRoundedRect(Size size) {
    final padding = 20.0 + 10.0 * animationValue;
    final cornerRadius = 20.0 + 10.0 * animationValue;
    return Path()..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          padding,
          padding,
          size.width - padding * 2,
          size.height - padding * 2,
        ),
        Radius.circular(cornerRadius),
      ),
    );
  }

  @override
  bool shouldReclip(_GlassShapeClipper oldClipper) {
    return oldClipper.shape != shape ||
        oldClipper.animationValue != animationValue;
  }
}
