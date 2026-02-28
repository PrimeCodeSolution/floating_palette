import 'package:floating_palette/floating_palette.dart';
import 'package:flutter/material.dart';

import '../../events/text_selection_events.dart';
import '../../palette_setup.dart';
import '../../theme/brand.dart';

/// Example screen demonstrating the [TextSelectionMonitor].
///
/// When the user selects text in any macOS app, a floating palette
/// appears below the selection showing the selected text.
class TextSelectionScreen extends StatefulWidget {
  const TextSelectionScreen({super.key});

  @override
  State<TextSelectionScreen> createState() => _TextSelectionScreenState();
}

class _TextSelectionScreenState extends State<TextSelectionScreen> {
  // Static state survives navigation — monitor keeps running across pages.
  static TextSelectionMonitor? _monitor;
  static bool _hasPermission = false;
  static bool _isMonitoring = false;
  static String _lastSelection = '';
  static Rect _lastBounds = Rect.zero;
  static String _lastPositionInfo = '';
  static String _lastBoundsError = '';

  @override
  void initState() {
    super.initState();
    if (_monitor == null) {
      _monitor = TextSelectionMonitor(bridge: PaletteHost.instance.bridge);
      Palettes.textSelection.scheduleWarmUp();
      _checkPermission();
    } else if (_isMonitoring) {
      // Re-attach callbacks so setState works for this instance.
      _attachCallbacks();
    } else {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    final granted = await _monitor!.checkPermission();
    if (mounted) {
      setState(() => _hasPermission = granted);
    }
  }

  Future<void> _requestPermission() async {
    await _monitor!.requestPermission();
    // Re-check after user returns from System Settings
    await Future.delayed(const Duration(seconds: 1));
    _checkPermission();
  }

  void _attachCallbacks() {
    _monitor!.onSelectionChanged((selection) {
      if (!mounted) return;
      debugPrint('[TextSelection] selection: "${selection.text.substring(0, selection.text.length.clamp(0, 40))}" '
          'bounds=${selection.bounds} app=${selection.appName}');

      final Rect bounds = selection.bounds;

      // Use text bounds if available, otherwise center on screen.
      final PalettePosition position;
      final String positionInfo;
      if (bounds != Rect.zero) {
        final pos = Offset(bounds.left, bounds.top - 4);
        debugPrint('[TextSelection] positioning at $pos (anchor=topLeft)');
        positionInfo = '$pos';
        position = PalettePosition(
          target: Target.custom,
          customPosition: pos,
          anchor: Anchor.topLeft,
        );
      } else {
        debugPrint('[TextSelection] no bounds, centering on screen');
        positionInfo = 'screen center';
        position = const PalettePosition(target: Target.screen);
      }

      setState(() {
        _lastSelection = selection.text;
        _lastBounds = bounds;
        _lastPositionInfo = positionInfo;
        _lastBoundsError = selection.boundsError ?? '';
      });

      Palettes.textSelection.show(position: position);
      Palettes.textSelection.sendEvent(
        TextUpdateEvent(text: selection.text, appName: selection.appName),
      );
    });

    _monitor!.onSelectionCleared(() {
      if (!mounted) return;
      setState(() => _lastSelection = '');
      Palettes.textSelection.hide();
    });
  }

  Future<void> _startMonitoring() async {
    _attachCallbacks();
    await _monitor!.startMonitoring();
    if (mounted) setState(() => _isMonitoring = true);
  }

  Future<void> _stopMonitoring() async {
    await _monitor!.stopMonitoring();
    Palettes.textSelection.hide();
    if (mounted) setState(() => _isMonitoring = false);
  }

  @override
  void dispose() {
    // Don't dispose the static monitor — it stays alive across navigation.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text Selection'),
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
                  color: FPColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: FPColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.select_all,
                  size: 40,
                  color: FPColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Text Selection',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: FPColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Select text in any app to see a floating palette\n'
                'appear below the selection.',
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
                  border: Border.all(color: FPColors.surfaceSubtle),
                ),
                child: Column(
                  children: [
                    _buildStatusRow(
                      Icons.security,
                      'Accessibility permission',
                      _hasPermission ? 'Granted' : 'Not granted',
                      _hasPermission ? FPColors.primary : FPColors.textSecondary,
                    ),
                    const SizedBox(height: 12),
                    _buildStatusRow(
                      Icons.monitor_heart,
                      'Monitoring',
                      _isMonitoring ? 'Active' : 'Inactive',
                      _isMonitoring ? FPColors.primary : FPColors.textSecondary,
                    ),
                    if (_lastSelection.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildStatusRow(
                        Icons.text_snippet,
                        'Last selection',
                        _lastSelection.length > 40
                            ? '${_lastSelection.substring(0, 40)}...'
                            : _lastSelection,
                        FPColors.textSecondary,
                      ),
                    ],
                    if (_lastBounds != Rect.zero || _lastPositionInfo.isNotEmpty || _lastBoundsError.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildStatusRow(
                        Icons.crop_free,
                        'Bounds',
                        _lastBounds == Rect.zero
                            ? 'Rect.zero'
                            : '(${_lastBounds.left.toStringAsFixed(1)}, ${_lastBounds.top.toStringAsFixed(1)}, ${_lastBounds.width.toStringAsFixed(1)}, ${_lastBounds.height.toStringAsFixed(1)})',
                        FPColors.textSecondary,
                      ),
                      const SizedBox(height: 12),
                      _buildStatusRow(
                        Icons.place,
                        'Position',
                        _lastPositionInfo,
                        FPColors.textSecondary,
                      ),
                      if (_lastBoundsError.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildStatusRow(
                          Icons.error_outline,
                          'AX error',
                          _lastBoundsError,
                          const Color(0xFFE57373),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              if (!_hasPermission) ...[
                const SizedBox(height: 32),
                _PermissionButton(onPressed: _requestPermission),
              ],
              if (_hasPermission) ...[
                const SizedBox(height: 32),
                _ToggleButton(
                  isMonitoring: _isMonitoring,
                  onStart: _startMonitoring,
                  onStop: _stopMonitoring,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow(
    IconData icon,
    String label,
    String value,
    Color valueColor,
  ) {
    return Row(
      children: [
        Icon(icon, color: FPColors.textSecondary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: FPColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
        Flexible(
          child: SelectableText(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}

class _ToggleButton extends StatefulWidget {
  final bool isMonitoring;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const _ToggleButton({
    required this.isMonitoring,
    required this.onStart,
    required this.onStop,
  });

  @override
  State<_ToggleButton> createState() => _ToggleButtonState();
}

class _ToggleButtonState extends State<_ToggleButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isStop = widget.isMonitoring;
    final label = isStop ? 'Stop Monitoring' : 'Start Monitoring';
    final icon = isStop ? Icons.stop_circle_outlined : Icons.play_circle_outline;
    final color = isStop ? const Color(0xFFE57373) : FPColors.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: isStop ? widget.onStop : widget.onStart,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: _isHovered
                ? color.withValues(alpha: 0.15)
                : color,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isHovered ? color : Colors.transparent,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 16,
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: _isHovered ? color : FPColors.surface,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _isHovered ? color : FPColors.surface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _PermissionButton({required this.onPressed});

  @override
  State<_PermissionButton> createState() => _PermissionButtonState();
}

class _PermissionButtonState extends State<_PermissionButton> {
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
            color: _isHovered
                ? FPColors.primary.withValues(alpha: 0.15)
                : FPColors.primary,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isHovered ? FPColors.primary : Colors.transparent,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: FPColors.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.security,
                size: 18,
                color: _isHovered ? FPColors.primary : FPColors.surface,
              ),
              const SizedBox(width: 8),
              Text(
                'Grant Accessibility Permission',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _isHovered ? FPColors.primary : FPColors.surface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
