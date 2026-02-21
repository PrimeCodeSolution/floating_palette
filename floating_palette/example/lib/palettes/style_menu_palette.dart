import 'package:floating_palette/floating_palette.dart';
import 'package:flutter/material.dart';

import '../events/notion_events.dart';
import '../theme/brand.dart';

/// Style menu palette - floating toolbar for text formatting.
///
/// Appears when text is selected in the editor.
/// Uses PaletteScaffold for automatic window sizing.
class StyleMenuPalette extends StatefulWidget {
  const StyleMenuPalette({super.key});

  @override
  State<StyleMenuPalette> createState() => _StyleMenuPaletteState();
}

class _StyleMenuPaletteState extends State<StyleMenuPalette> {
  final Map<String, bool> _activeStyles = {
    'bold': false,
    'italic': false,
    'underline': false,
    'strikethrough': false,
    'code': false,
  };

  @override
  void initState() {
    super.initState();
    if (!PaletteContext.isInPalette) return;

    // Handle typed style state event
    PaletteContext.current.on<StyleStateEvent>((event) {
      setState(() {
        _activeStyles['bold'] = event.bold;
        _activeStyles['italic'] = event.italic;
        _activeStyles['underline'] = event.underline;
        _activeStyles['strikethrough'] = event.strikethrough;
        _activeStyles['code'] = event.code;
      });
    });
  }

  void _onStyleTap(String style) {
    // Send typed style action to host
    PaletteMessenger.sendEvent(StyleActionEvent(style: style));
    // Don't hide - allow multiple style applications
    // Menu hides via: hideOnClickOutside, hideOnEscape, or host's hide-style-menu
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: PaletteScaffold(
        overflowPadding: const EdgeInsets.only(bottom: 32),
        decoration: BoxDecoration(
          color: FPColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: FPColors.surfaceSubtle,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StyleButton(
                icon: Icons.format_bold,
                tooltip: 'Bold',
                isActive: _activeStyles['bold'] == true,
                onTap: () => _onStyleTap('bold'),
              ),
              _StyleButton(
                icon: Icons.format_italic,
                tooltip: 'Italic',
                isActive: _activeStyles['italic'] == true,
                onTap: () => _onStyleTap('italic'),
              ),
              _StyleButton(
                icon: Icons.format_underline,
                tooltip: 'Underline',
                isActive: _activeStyles['underline'] == true,
                onTap: () => _onStyleTap('underline'),
              ),
              _StyleButton(
                icon: Icons.strikethrough_s,
                tooltip: 'Strikethrough',
                isActive: _activeStyles['strikethrough'] == true,
                onTap: () => _onStyleTap('strikethrough'),
              ),
              const _Divider(),
              _StyleButton(
                icon: Icons.code,
                tooltip: 'Code',
                isActive: _activeStyles['code'] == true,
                onTap: () => _onStyleTap('code'),
              ),
              _StyleButton(
                icon: Icons.link,
                tooltip: 'Link',
                isActive: false,
                onTap: () => _onStyleTap('link'),
              ),
              const _Divider(),
              _StyleButton(
                icon: Icons.format_color_text,
                tooltip: 'Text color',
                isActive: false,
                onTap: () => _onStyleTap('textColor'),
              ),
              _StyleButton(
                icon: Icons.highlight,
                tooltip: 'Highlight',
                isActive: false,
                onTap: () => _onStyleTap('highlight'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StyleButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback? onTap;

  const _StyleButton({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    this.onTap,
  });

  @override
  State<_StyleButton> createState() => _StyleButtonState();
}

class _StyleButtonState extends State<_StyleButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isActive
                  ? FPColors.primary.withValues(alpha: 0.2)
                  : _isHovered
                      ? FPColors.surfaceSubtle
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: isActive
                  ? Border.all(
                      color: FPColors.primary.withValues(alpha: 0.4),
                    )
                  : null,
            ),
            child: Icon(
              widget.icon,
              size: 18,
              color: isActive
                  ? FPColors.primary
                  : _isHovered
                      ? FPColors.textPrimary
                      : FPColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: FPColors.surfaceSubtle,
    );
  }
}
