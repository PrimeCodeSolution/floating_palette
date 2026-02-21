import 'package:flutter/material.dart';

import '../../palette_setup.dart';
import '../../theme/brand.dart';

/// Demo screen for the Analog Clock palette.
class ClockScreen extends StatefulWidget {
  const ClockScreen({super.key});

  @override
  State<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen> {
  @override
  void initState() {
    super.initState();
    Palettes.clock.scheduleWarmUp(autoShowOnReady: true);
  }

  @override
  void dispose() {
    Palettes.clock.hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analog Clock'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              FPColors.surface,
              Color(0xFF1A1A2E),
              Color(0xFF2A1A3E),
            ],
          ),
        ),
        child: Center(
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
                  Icons.access_time,
                  size: 40,
                  color: FPColors.secondary,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Analog Clock',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: FPColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Transparent floating clock with Liquid Glass\n'
                'Stays on top of all windows',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: FPColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  color: FPColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: FPColors.surfaceSubtle,
                  ),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(
                      Icons.push_pin,
                      'alwaysOnTop: stays above all windows',
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.visibility,
                      'keepAlive: continues ticking when unfocused',
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.blur_on,
                      'Circular glass mask via GlassEffectService',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _ClockButton(
                onPressed: () {
                  if (Palettes.clock.isVisible) {
                    Palettes.clock.hide();
                  } else {
                    Palettes.clock.show();
                  }
                  setState(() {});
                },
                isActive: Palettes.clock.isVisible,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: FPColors.secondary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: FPColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _ClockButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isActive;

  const _ClockButton({
    required this.onPressed,
    required this.isActive,
  });

  @override
  State<_ClockButton> createState() => _ClockButtonState();
}

class _ClockButtonState extends State<_ClockButton> {
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: widget.isActive
                ? FPColors.secondary.withValues(alpha: 0.2)
                : _isHovered
                    ? FPColors.secondary.withValues(alpha: 0.15)
                    : FPColors.secondary,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.isActive || _isHovered
                  ? FPColors.secondary
                  : Colors.transparent,
            ),
            boxShadow: _isHovered && !widget.isActive
                ? [
                    BoxShadow(
                      color: FPColors.secondary.withValues(alpha: 0.3),
                      blurRadius: 16,
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.access_time,
                size: 18,
                color: widget.isActive
                    ? FPColors.secondary
                    : FPColors.surface,
              ),
              const SizedBox(width: 8),
              Text(
                widget.isActive ? 'Hide Clock' : 'Show Clock',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: widget.isActive
                      ? FPColors.secondary
                      : FPColors.surface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
