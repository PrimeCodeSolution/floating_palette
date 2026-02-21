import 'package:floating_palette/floating_palette.dart';
import 'package:flutter/material.dart';

import '../../palette_setup.dart';
import '../../theme/brand.dart';

/// Screen demonstrating native Liquid Glass effect.
class GlassDemoScreen extends StatefulWidget {
  const GlassDemoScreen({super.key});

  @override
  State<GlassDemoScreen> createState() => _GlassDemoScreenState();
}

class _GlassDemoScreenState extends State<GlassDemoScreen> {
  bool _customShapeVisible = false;
  bool _spotlightVisible = false;

  @override
  void initState() {
    super.initState();
    // Non-blocking warmup during idle time
    Palettes.customShapeGlass.scheduleWarmUp();
    Palettes.spotlight.scheduleWarmUp();
  }

  Future<void> _toggleCustomShape() async {
    if (_customShapeVisible) {
      await Palettes.customShapeGlass.hide();
    } else {
      await Palettes.customShapeGlass.show();
    }
    setState(() => _customShapeVisible = !_customShapeVisible);
  }

  Future<void> _toggleSpotlight() async {
    if (_spotlightVisible) {
      await Palettes.spotlight.hide();
    } else {
      await Palettes.spotlight.show(
        position: PalettePosition.centerScreen(yOffset: -100),
      );
    }
    setState(() => _spotlightVisible = !_spotlightVisible);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liquid Glass Effect'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        // Colorful gradient background using brand colors
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F0F13), // surface
              Color(0xFF1A1A3E), // dark blue
              Color(0xFF2A1A4E), // purple tint
              Color(0xFF0F0F13), // surface
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Background pattern to show blur better
            Positioned.fill(
              child: CustomPaint(
                painter: _PatternPainter(),
              ),
            ),
            // Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: FPColors.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: FPColors.secondary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.blur_on,
                      size: 40,
                      color: FPColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Liquid Glass',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: FPColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'macOS Tahoe native .glassEffect() modifier\n'
                    'Real-time blur with custom shapes',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: FPColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _GlassButton(
                        onPressed: _toggleCustomShape,
                        icon: _customShapeVisible
                            ? Icons.visibility_off
                            : Icons.auto_awesome,
                        label: _customShapeVisible
                            ? 'Hide Shapes'
                            : 'Custom Shapes',
                        color: FPColors.secondary,
                      ),
                      const SizedBox(width: 16),
                      _GlassButton(
                        onPressed: _toggleSpotlight,
                        icon: _spotlightVisible
                            ? Icons.visibility_off
                            : Icons.search,
                        label: _spotlightVisible
                            ? 'Hide Spotlight'
                            : 'Spotlight',
                        color: FPColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: FPSpacing.md,
                      vertical: FPSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: FPColors.surfaceSubtle.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _customShapeVisible || _spotlightVisible
                          ? 'Drag palettes to see glass effect'
                          : 'Click to show glass palettes',
                      style: const TextStyle(
                        fontSize: 13,
                        color: FPColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom button with glass-like appearance.
class _GlassButton extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color color;

  const _GlassButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  State<_GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<_GlassButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: _isHovered
                ? widget.color.withValues(alpha: 0.2)
                : FPColors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isHovered
                  ? widget.color.withValues(alpha: 0.5)
                  : FPColors.surfaceSubtle,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.2),
                      blurRadius: 12,
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 18, color: widget.color),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: FPColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paints a pattern background to demonstrate the blur effect.
class _PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = FPColors.primary.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw grid lines
    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw some circles with brand colors
    final cyanCircle = Paint()
      ..color = FPColors.primary.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final violetCircle = Paint()
      ..color = FPColors.secondary.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.3),
      80,
      cyanCircle,
    );
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.2),
      60,
      violetCircle,
    );
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.7),
      100,
      cyanCircle,
    );
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.8),
      50,
      violetCircle,
    );
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.75),
      70,
      cyanCircle,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
