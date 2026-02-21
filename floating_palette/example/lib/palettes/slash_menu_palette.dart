import 'dart:async';

import 'package:floating_palette/floating_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../events/notion_events.dart';
import '../theme/brand.dart';

/// Slash menu palette - command palette triggered by '/'.
class SlashMenuPalette extends StatefulWidget {
  const SlashMenuPalette({super.key});

  @override
  State<SlashMenuPalette> createState() => _SlashMenuPaletteState();
}

class _SlashMenuPaletteState extends State<SlashMenuPalette> {
  int _selectedIndex = 0;
  String _filter = '';
  int? _maxVisibleItems; // null = show all, set by host based on screen space
  StreamSubscription<PaletteKeyEvent>? _keySubscription;
  final ScrollController _scrollController = ScrollController();

  // Item height must match host calculation
  // Item (ListTile ~52px) + margin (8px) + divider (1px) ≈ 61px
  static const _itemHeight = 61.0;
  static const _verticalPadding = 16.0; // 8px top + 8px bottom padding

  final _items = [
    _MenuItem(
      icon: Icons.text_fields,
      label: 'Text',
      description: 'Plain text block',
    ),
    _MenuItem(
      icon: Icons.title,
      label: 'Heading 1',
      description: 'Large heading',
    ),
    _MenuItem(
      icon: Icons.format_size,
      label: 'Heading 2',
      description: 'Medium heading',
    ),
    _MenuItem(
      icon: Icons.format_list_bulleted,
      label: 'Bullet List',
      description: 'Bulleted list',
    ),
    _MenuItem(
      icon: Icons.format_list_numbered,
      label: 'Numbered List',
      description: 'Numbered list',
    ),
    _MenuItem(
      icon: Icons.check_box,
      label: 'Todo',
      description: 'Task with checkbox',
    ),
    _MenuItem(icon: Icons.code, label: 'Code', description: 'Code block'),
    _MenuItem(
      icon: Icons.format_quote,
      label: 'Quote',
      description: 'Quote block',
    ),
    _MenuItem(
      icon: Icons.horizontal_rule,
      label: 'Divider',
      description: 'Horizontal line',
    ),
  ];

  List<_MenuItem> get _filteredItems {
    if (_filter.isEmpty) return _items;
    return _items
        .where(
          (item) => item.label.toLowerCase().contains(_filter.toLowerCase()),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    // Listen for key events routed from main app via native
    _keySubscription = PaletteKeyReceiver.instance.keyDownStream.listen(
      _handleKey,
    );

    // Listen for filter updates from editor
    _setupMessageListener();
  }

  void _setupMessageListener() {
    if (!PaletteContext.isInPalette) return;

    // Handle typed filter event
    PaletteContext.current.on<SlashMenuFilterEvent>((event) {
      setState(() {
        _filter = event.filter;
        // Reset selection when filter changes
        _selectedIndex = 0;
      });
    });

    // Handle typed reset event
    PaletteContext.current.on<SlashMenuResetEvent>((event) {
      setState(() {
        _filter = '';
        _selectedIndex = 0;
        _maxVisibleItems = event.maxVisibleItems;
      });
      // Reset scroll position
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    });
  }

  @override
  void dispose() {
    _keySubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleKey(PaletteKeyEvent event) {
    final items = _filteredItems;
    if (items.isEmpty) return;

    final previousIndex = _selectedIndex;

    if (event.key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % items.length;
      });
      final wrapped = previousIndex == items.length - 1 && _selectedIndex == 0;
      _scrollToSelected(wrapped: wrapped, direction: 1);
    } else if (event.key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1 + items.length) % items.length;
      });
      final wrapped = previousIndex == 0 && _selectedIndex == items.length - 1;
      _scrollToSelected(wrapped: wrapped, direction: -1);
    } else if (event.key == LogicalKeyboardKey.enter) {
      _selectItem(items[_selectedIndex]);
    } else if (event.key == LogicalKeyboardKey.escape) {
      PaletteMessenger.sendEvent(const SlashMenuCancelEvent());
      PaletteWindow.hide();
    }
  }

  void _scrollToSelected({required bool wrapped, required int direction}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      final items = _filteredItems;
      if (items.isEmpty) return;

      // If no constraint, no scrolling needed (all items visible)
      if (_maxVisibleItems == null || items.length <= _maxVisibleItems!) return;

      final maxScroll = _scrollController.position.maxScrollExtent;

      if (wrapped) {
        // Wrap-around: jump immediately to start or end
        if (_selectedIndex == 0) {
          // Wrapped to first item - scroll to top (0)
          _scrollController.jumpTo(0);
        } else {
          // Wrapped to last item - scroll to bottom
          _scrollController.jumpTo(maxScroll);
        }
      } else {
        // Normal navigation: ensure selected item is visible
        final viewportHeight = _maxVisibleItems! * _itemHeight;
        final itemTop = _selectedIndex * _itemHeight;
        final itemBottom = itemTop + _itemHeight;
        final currentScroll = _scrollController.offset;

        double targetScroll = currentScroll;

        if (direction > 0) {
          // Moving down - check if item is below visible area
          if (itemBottom > currentScroll + viewportHeight) {
            targetScroll = itemBottom - viewportHeight;
          }
        } else {
          // Moving up - check if item is above visible area
          if (itemTop < currentScroll) {
            targetScroll = itemTop;
          }
        }

        if (targetScroll != currentScroll) {
          _scrollController.animateTo(
            targetScroll.clamp(0, maxScroll),
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  void _selectItem(_MenuItem item) {
    // Map label to block type identifier
    final typeMap = {
      'Text': 'text',
      'Heading 1': 'heading1',
      'Heading 2': 'heading2',
      'Bullet List': 'bullet',
      'Numbered List': 'numbered',
      'Todo': 'todo',
      'Code': 'code',
      'Quote': 'quote',
      'Divider': 'divider',
    };

    // Send selection back to host with block type
    PaletteMessenger.sendEvent(SlashMenuSelectEvent(
      type: typeMap[item.label] ?? 'text',
    ));
    // Hide self after selection
    PaletteWindow.hide();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;

    // Calculate constrained height if maxVisibleItems is set
    // Show full items only (no partial items)
    final int visibleCount = _maxVisibleItems != null
        ? items.length.clamp(1, _maxVisibleItems!)
        : items.length;
    final double? constrainedHeight = _maxVisibleItems != null
        ? visibleCount * _itemHeight + _verticalPadding
        : null;

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
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SizedBox(
          width: 280,
          height: constrainedHeight, // null = intrinsic, set = constrained
          child: items.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No matching commands',
                    style: TextStyle(
                      fontSize: 14,
                      color: FPColors.textSecondary,
                    ),
                  ),
                )
              : ListView.separated(
                  controller: _scrollController,
                  shrinkWrap: constrainedHeight == null,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 16,
                    endIndent: 16,
                    color: FPColors.surfaceSubtle,
                  ),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isSelected = index == _selectedIndex;

                    return MouseRegion(
                      onEnter: (_) {
                        if (_selectedIndex != index) {
                          setState(() => _selectedIndex = index);
                        }
                      },
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? FPColors.primary.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(
                                  color: FPColors.primary.withValues(alpha: 0.3),
                                )
                              : null,
                        ),
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            item.icon,
                            size: 20,
                            color: isSelected
                                ? FPColors.primary
                                : FPColors.textSecondary,
                          ),
                          title: Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  isSelected ? FontWeight.w500 : FontWeight.normal,
                              color: isSelected
                                  ? FPColors.textPrimary
                                  : FPColors.textSecondary,
                            ),
                          ),
                          subtitle: Text(
                            item.description,
                            style: const TextStyle(
                              fontSize: 12,
                              color: FPColors.textSecondary,
                            ),
                          ),
                          onTap: () => _selectItem(item),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final String description;

  _MenuItem({
    required this.icon,
    required this.label,
    required this.description,
  });
}
