import 'package:floating_palette/floating_palette.dart';
import 'package:flutter/material.dart';

import '../events/keyboard_events.dart';
import '../events/notion_events.dart';
import '../theme/brand.dart';

/// Virtual keyboard palette - sends key events to the editor.
class VirtualKeyboardPalette extends StatefulWidget {
  const VirtualKeyboardPalette({super.key});

  @override
  State<VirtualKeyboardPalette> createState() => _VirtualKeyboardPaletteState();
}

class _VirtualKeyboardPaletteState extends State<VirtualKeyboardPalette> {
  bool _shift = false;
  SnapVisualState _snapState = SnapVisualState.detached;

  @override
  void initState() {
    super.initState();
    _setupSnapListener();
  }

  void _setupSnapListener() {
    // Listen for typed snap state updates from host
    PaletteContext.current.on<SnapStateEvent>((event) {
      setState(() {
        _snapState = event.state;
      });
    });
  }

  /// Send a key event using typed event for handling on host side.
  void _sendKey(String key) {
    PaletteMessenger.sendEvent(KeyboardKeyPressed(key));
  }

  void _emitKey(String key) {
    final char = _shift ? key.toUpperCase() : key;
    _sendKey(char);
    if (_shift) setState(() => _shift = false);
  }

  void _onBackspace() => _sendKey('backspace');

  void _onEnter() => _sendKey('enter');

  void _onSpace() => _sendKey(' ');

  /// Get icon color based on snap state.
  Color get _snapIconColor => switch (_snapState) {
        SnapVisualState.attached => FPColors.success,
        SnapVisualState.proximity => FPColors.warning,
        SnapVisualState.detached => FPColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: PaletteScaffold(
        decoration: BoxDecoration(
          color: FPColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: FPColors.surfaceSubtle,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDragHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildRow(['1', '2', '3', '4', '5', '6', '7', '8', '9', '0']),
                  _buildRow(['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p']),
                  _buildRow(['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l']),
                  _buildSpecialRow(),
                  _buildBottomRow(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => PaletteWindow.startDrag(),
      child: MouseRegion(
        cursor: SystemMouseCursors.move,
        child: Container(
          height: 28,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: FPColors.surfaceSubtle, width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Snap indicator icon (always visible, color indicates state)
              Icon(
                _snapState == SnapVisualState.attached
                    ? Icons.link
                    : Icons.link_off,
                size: 14,
                color: _snapIconColor,
              ),
              const SizedBox(width: 8),
              // Drag handle bar
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: FPColors.textSecondary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(List<String> keys) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: keys
            .map((k) => _KeyButton(
                  label: _shift ? k.toUpperCase() : k,
                  onTap: () => _emitKey(k),
                ))
            .toList(),
      );

  Widget _buildSpecialRow() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _KeyButton(
            label: _shift ? 'SHIFT' : 'Shift',
            isActive: _shift,
            onTap: () => setState(() => _shift = !_shift),
            width: 50,
          ),
          ...['z', 'x', 'c', 'v', 'b', 'n', 'm'].map((k) => _KeyButton(
                label: _shift ? k.toUpperCase() : k,
                onTap: () => _emitKey(k),
              )),
          _KeyButton(label: 'Del', onTap: _onBackspace, width: 50),
        ],
      );

  Widget _buildBottomRow() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _KeyButton(label: 'Space', onTap: _onSpace, width: 200),
          _KeyButton(label: 'Enter', onTap: _onEnter, width: 60),
        ],
      );
}

class _KeyButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final double width;
  final bool isActive;

  const _KeyButton({
    required this.label,
    required this.onTap,
    this.width = 32,
    this.isActive = false,
  });

  @override
  State<_KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<_KeyButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: widget.width,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.isActive
                  ? FPColors.primary.withValues(alpha: 0.2)
                  : _isHovered
                      ? FPColors.surfaceSubtle
                      : FPColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: widget.isActive
                    ? FPColors.primary.withValues(alpha: 0.5)
                    : _isHovered
                        ? FPColors.textSecondary.withValues(alpha: 0.3)
                        : FPColors.surfaceSubtle,
              ),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 14,
                color: widget.isActive
                    ? FPColors.primary
                    : FPColors.textPrimary,
                fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
