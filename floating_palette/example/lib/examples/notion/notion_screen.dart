import 'dart:async';

import 'package:floating_palette/floating_palette_advanced.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../events/keyboard_events.dart';
import '../../events/notion_events.dart';
import '../../palette_setup.dart';
import '../../theme/brand.dart';
import 'models/block.dart';
import 'models/block_operations.dart';

/// Notion-like example with editor, slash menu, and style menu.
class NotionScreen extends StatefulWidget {
  const NotionScreen({super.key});

  @override
  State<NotionScreen> createState() => _NotionScreenState();
}

class _NotionScreenState extends State<NotionScreen> {
  late final ScreenClient _screenClient;
  Timer? _styleMenuDebounce;
  Rect? _pendingSelectionRect;

  /// The block document state - host owns the source of truth.
  BlockDocument _document = BlockDocument.empty();

  /// Gap between selection and style menu.
  static const _styleMenuGap = 40.0; // Enough space to not cover text

  @override
  void initState() {
    super.initState();
    final bridge = PaletteHost.instance.bridge;
    _screenClient = ScreenClient(bridge);

    // Schedule warmup during idle time to avoid blocking UI
    Palettes.editor.scheduleWarmUp(
      autoShowOnReady: true,
      position: PalettePosition.centerScreen(),
    );
    Palettes.slashMenu.scheduleWarmUp();
    Palettes.styleMenu.scheduleWarmUp();
    Palettes.virtualKeyboard.scheduleWarmUp();

    // Initialize focused block state (editor syncs via local state, not host-driven initially)
    _document = _document.copyWith(
      focusedBlockId: _document.blocks.first.id,
      caretOffset: 0,
    );

    // ════════════════════════════════════════════════════════════════
    // Slash Menu Handlers (typed events)
    // ════════════════════════════════════════════════════════════════

    // Listen for slash menu trigger from editor palette
    Palettes.editor.onEvent<ShowSlashMenuEvent>((event) {
      if (!mounted) return;
      if (event.caretX != null && event.caretY != null) {
        _showSlashMenuAtCaret(Offset(event.caretX!, event.caretY!));
      } else {
        // Fallback to relative positioning
        _showSlashMenuFallback();
      }
    });

    // Listen for slash menu selection
    Palettes.slashMenu.onEvent<SlashMenuSelectEvent>((event) {
      if (!mounted) return;
      debugPrint('[NotionScreen] SlashMenuSelectEvent: ${event.type}');
      // Update host's block type state (no sync - editor handles /query removal)
      final focusedBlockId =
          _document.focusedBlockId ?? _document.blocks.first.id;
      final parsedType = _parseBlockType(event.type);
      if (parsedType != null) {
        setState(() {
          _document = _document.transformBlock(focusedBlockId, parsedType);
        });
      }
      // Send to editor to handle /query removal and apply formatting
      Palettes.editor.sendEvent(InsertBlockEvent(type: event.type));
    });

    // Listen for slash menu filter updates
    Palettes.editor.onEvent<SlashMenuFilterEvent>((event) {
      if (!mounted) return;
      // Forward filter to slash menu
      Palettes.slashMenu.sendEvent(event);
    });

    // Listen for slash menu cancel
    Palettes.editor.onEvent<SlashMenuCancelEvent>((_) {
      if (!mounted) return;
      debugPrint('[NotionScreen] SlashMenuCancelEvent');
      Palettes.slashMenu.hide();
    });

    // ════════════════════════════════════════════════════════════════
    // Style Menu Handlers (typed events)
    // ════════════════════════════════════════════════════════════════

    // Listen for style menu show request from editor palette
    Palettes.editor.onEvent<ShowStyleMenuEvent>((event) {
      if (!mounted) return;
      if (event.selectionLeft != 0 ||
          event.selectionTop != 0 ||
          event.selectionRight != 0 ||
          event.selectionBottom != 0) {
        _pendingSelectionRect = Rect.fromLTRB(
          event.selectionLeft,
          event.selectionTop,
          event.selectionRight,
          event.selectionBottom,
        );
        _styleMenuDebounce?.cancel();
        _styleMenuDebounce = Timer(const Duration(milliseconds: 300), () {
          final rect = _pendingSelectionRect;
          if (rect != null) {
            _showStyleMenuAtSelection(rect);
          }
        });
      }
    });

    // Listen for style menu hide request
    Palettes.editor.onEvent<HideStyleMenuEvent>((_) {
      if (!mounted) return;
      _styleMenuDebounce?.cancel();
      _pendingSelectionRect = null;
      Palettes.styleMenu.hide();
    });

    // Listen for style action from style menu
    Palettes.styleMenu.onEvent<StyleActionEvent>((event) {
      if (!mounted) return;
      debugPrint('[NotionScreen] StyleActionEvent: ${event.style}');
      // Forward to editor to apply the style
      Palettes.editor.sendEvent(ApplyStyleEvent(style: event.style));
      // Style menu stays open for multiple style applications
    });

    // Forward style state from editor to style menu
    Palettes.editor.onEvent<StyleStateEvent>((event) {
      if (!mounted) return;
      Palettes.styleMenu.sendEvent(event);
    });

    // ════════════════════════════════════════════════════════════════
    // Block Operation Handlers (typed events)
    // ════════════════════════════════════════════════════════════════

    // Listen for block split request from editor
    Palettes.editor.onEvent<BlockSplitEvent>((event) {
      if (!mounted) return;
      _handleBlockSplit(event.beforeText, event.afterText);
    });

    // Listen for merge with previous block request
    Palettes.editor.onEvent<BlockMergePrevEvent>((event) {
      if (!mounted) return;
      _handleMergeWithPrevious(
        event.prevBlockText,
        event.currentBlockText,
        event.mergeOffset,
      );
    });

    // Listen for merge with next block request
    Palettes.editor.onEvent<BlockMergeNextEvent>((event) {
      if (!mounted) return;
      _handleMergeWithNext(
        event.currentBlockText,
        event.nextBlockText,
        event.mergeOffset,
      );
    });

    // ════════════════════════════════════════════════════════════════
    // General Handlers (typed events)
    // ════════════════════════════════════════════════════════════════

    // Listen for close request from editor palette
    Palettes.editor.onEvent<CloseEditorEvent>((_) {
      if (!mounted) return;
      _hideAll();
    });

    // ════════════════════════════════════════════════════════════════
    // Virtual Keyboard Handlers (typed events)
    // ════════════════════════════════════════════════════════════════

    // Show/hide keyboard on toggle event from editor
    Palettes.editor.onEvent<ToggleKeyboard>((_) async {
      if (!mounted) return;
      if (Palettes.virtualKeyboard.isVisible) {
        await Palettes.virtualKeyboard.detach();
        Palettes.virtualKeyboard.sendEvent(
          const SnapStateEvent(state: SnapVisualState.detached),
        );
        await Palettes.virtualKeyboard.hide();
      } else {
        await Palettes.virtualKeyboard.show();
        await Palettes.virtualKeyboard.attachBelow(Palettes.editor, gap: 4);
        Palettes.virtualKeyboard.sendEvent(
          const SnapStateEvent(state: SnapVisualState.attached),
        );

        // Enable auto-snap for re-attachment after drag-away
        // Keyboard's top can snap to editor's bottom
        await Palettes.virtualKeyboard.enableAutoSnap(
          AutoSnapConfig.withTargets(
            targets: {Palettes.editor}, // Type-safe reference
            canSnapFrom: {SnapEdge.top},
            acceptsSnapOn: {},
          ),
        );

        // Editor accepts snaps on its bottom
        await Palettes.editor.enableAutoSnap(
          const AutoSnapConfig(
            canSnapFrom: {},
            acceptsSnapOn: {SnapEdge.bottom},
          ),
        );
      }
    });

    // Forward key presses from virtual keyboard to editor
    Palettes.virtualKeyboard.onEvent<KeyboardKeyPressed>((event) {
      if (!mounted) return;
      Palettes.editor.sendEvent(event);
    });

    // Listen for snap events to update keyboard visual state
    Palettes.virtualKeyboard.onSnapEvent((event) {
      switch (event) {
        case SnapSnapped():
          Palettes.virtualKeyboard.sendEvent(
            const SnapStateEvent(state: SnapVisualState.attached),
          );
        case SnapDetached():
          Palettes.virtualKeyboard.sendEvent(
            const SnapStateEvent(state: SnapVisualState.detached),
          );
        case SnapProximityEntered():
          Palettes.virtualKeyboard.sendEvent(
            const SnapStateEvent(state: SnapVisualState.proximity),
          );
        case SnapProximityExited():
          // Only go to detached if not already attached
          if (!Palettes.virtualKeyboard.isSnapped) {
            Palettes.virtualKeyboard.sendEvent(
              const SnapStateEvent(state: SnapVisualState.detached),
            );
          }
        case SnapDragging(:final snapDistance):
          // Show proximity feedback as user drags toward detach threshold
          // snapDistance > 0 but still attached = show orange proximity
          if (snapDistance > 25) {
            Palettes.virtualKeyboard.sendEvent(
              const SnapStateEvent(state: SnapVisualState.proximity),
            );
          } else {
            Palettes.virtualKeyboard.sendEvent(
              const SnapStateEvent(state: SnapVisualState.attached),
            );
          }
        case SnapDragStarted() || SnapDragEnded() || SnapProximityUpdated():
          // Ignore other drag events
          break;
      }
    });
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Block Operations
  // ════════════════════════════════════════════════════════════════════════════

  /// Handle block split request from editor.
  ///
  /// Updates the host's block structure but does NOT sync back to editor.
  /// The editor handles the split locally by inserting a newline.
  void _handleBlockSplit(String beforeText, String afterText) {
    final focusedBlockId =
        _document.focusedBlockId ?? _document.blocks.first.id;
    final focusedBlock = _document.getBlock(focusedBlockId);
    final blockType = focusedBlock?.type ?? BlockType.paragraph;

    // Create two blocks with the split content
    final updatedBlock = Block.withText(blockType, beforeText);

    // New block type: headings become paragraphs, others stay same
    final newBlockType = switch (blockType) {
      BlockType.heading1 ||
      BlockType.heading2 ||
      BlockType.heading3 => BlockType.paragraph,
      _ => blockType,
    };
    final newBlock = Block.withText(newBlockType, afterText);

    // Replace the focused block with the two new blocks
    final blockIndex = _document.getBlockIndex(focusedBlockId) ?? 0;
    final newBlocks = List<Block>.from(_document.blocks);
    newBlocks[blockIndex] = updatedBlock;
    newBlocks.insert(blockIndex + 1, newBlock);

    setState(() {
      _document = _document.copyWith(
        blocks: newBlocks,
        focusedBlockId: newBlock.id,
        caretOffset: 0,
      );
    });

    debugPrint('[NotionScreen] Block split: "$beforeText" | "$afterText"');
    debugPrint(
      '[NotionScreen] Document now has ${_document.blocks.length} blocks',
    );
    debugPrint('[NotionScreen] Focus on block: ${_document.focusedBlockId}');

    // Don't sync back to editor - it handles the split locally
  }

  /// Handle merge with previous block request.
  ///
  /// Updates the host's block structure but does NOT sync back to editor.
  /// The editor handles the merge locally by deleting the newline.
  void _handleMergeWithPrevious(
    String prevBlockText,
    String currentBlockText,
    int mergeOffset,
  ) {
    final focusedBlockId = _document.focusedBlockId;
    if (focusedBlockId == null) return;

    final blockIndex = _document.getBlockIndex(focusedBlockId);
    if (blockIndex == null || blockIndex == 0) return;

    // Get the previous block's type
    final prevBlock = _document.blocks[blockIndex - 1];

    // Create merged block with combined text
    final mergedBlock = Block.withText(
      prevBlock.type,
      prevBlockText + currentBlockText,
    );

    // Update blocks list
    final newBlocks = List<Block>.from(_document.blocks);
    newBlocks[blockIndex - 1] = mergedBlock;
    newBlocks.removeAt(blockIndex);

    setState(() {
      _document = _document.copyWith(
        blocks: newBlocks,
        focusedBlockId: mergedBlock.id,
        caretOffset: mergeOffset,
      );
    });

    debugPrint(
      '[NotionScreen] Merged with previous: "$prevBlockText" + "$currentBlockText"',
    );
    debugPrint(
      '[NotionScreen] Document now has ${_document.blocks.length} blocks',
    );

    // Don't sync back to editor - it handles the merge locally
  }

  /// Handle merge with next block request.
  ///
  /// Updates the host's block structure but does NOT sync back to editor.
  /// The editor handles the merge locally by deleting the newline.
  void _handleMergeWithNext(
    String currentBlockText,
    String nextBlockText,
    int mergeOffset,
  ) {
    final focusedBlockId = _document.focusedBlockId;
    if (focusedBlockId == null) return;

    final blockIndex = _document.getBlockIndex(focusedBlockId);
    if (blockIndex == null || blockIndex >= _document.blocks.length - 1) return;

    // Get the current block's type
    final currentBlock = _document.blocks[blockIndex];

    // Create merged block with combined text
    final mergedBlock = Block.withText(
      currentBlock.type,
      currentBlockText + nextBlockText,
    );

    // Update blocks list
    final newBlocks = List<Block>.from(_document.blocks);
    newBlocks[blockIndex] = mergedBlock;
    newBlocks.removeAt(blockIndex + 1);

    setState(() {
      _document = _document.copyWith(
        blocks: newBlocks,
        focusedBlockId: mergedBlock.id,
        caretOffset: mergeOffset,
      );
    });

    debugPrint(
      '[NotionScreen] Merged with next: "$currentBlockText" + "$nextBlockText"',
    );
    debugPrint(
      '[NotionScreen] Document now has ${_document.blocks.length} blocks',
    );

    // Don't sync back to editor - it handles the merge locally
  }

  /// Parse block type string to enum.
  BlockType? _parseBlockType(String typeStr) {
    return switch (typeStr) {
      'text' || 'paragraph' => BlockType.paragraph,
      'heading1' => BlockType.heading1,
      'heading2' => BlockType.heading2,
      'heading3' => BlockType.heading3,
      'bullet' || 'bulletList' => BlockType.bulletList,
      'numbered' || 'numberedList' => BlockType.numberedList,
      'todo' => BlockType.todo,
      'quote' => BlockType.quote,
      'code' => BlockType.code,
      'divider' => BlockType.divider,
      _ => null,
    };
  }

  /// Hide all palettes.
  void _hideAll() => Palettes.hideAll();

  @override
  void dispose() {
    _styleMenuDebounce?.cancel();
    _screenClient.dispose();
    super.dispose();
  }

  /// Show slash menu at the exact caret screen position.
  ///
  /// The caret position is reported by the editor palette in screen coordinates.
  Future<void> _showSlashMenuAtCaret(Offset caretScreenPos) async {
    // Get screen work area for space calculations
    final screens = await _screenClient.getScreens();
    if (screens.isEmpty) return;

    final primary = screens.firstWhere(
      (s) => s.isPrimary,
      orElse: () => screens.first,
    );
    final workArea = primary.workArea.toScreenRect();

    // Calculate how many items fit below the caret
    // Item height must match slash_menu_palette.dart
    final menuTop = caretScreenPos.below(8);
    final itemsFit = workArea.itemsThatFitBelow(
      menuTop,
      itemHeight: 60.0, // ListTile dense with subtitle + margins
      margin: 16.0, // Safety margin from screen edge
      padding: 16.0, // ListView vertical padding
    );

    // Only constrain if not all items fit (9 total items in slash menu)
    // null = let content size naturally, no constraint
    final int? maxItems = itemsFit < 9 ? itemsFit.clamp(1, 9) : null;

    // Send reset with max items before showing
    Palettes.slashMenu.sendEvent(
      SlashMenuResetEvent(maxVisibleItems: maxItems),
    );

    // Show slash menu with its top-left just below the caret position
    Palettes.slashMenu.showAtPosition(
      menuTop,
      anchor: Anchor.topLeft,
      keys: {
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.enter,
      },
    );
  }

  /// Fallback: position relative to editor bounds when caret position unavailable.
  Future<void> _showSlashMenuFallback() async {
    // Send reset to clear filter/selection state before showing
    Palettes.slashMenu.sendEvent(const SlashMenuResetEvent());

    // Get editor's screen rect for platform-aware offset helpers
    final editorRect = await Palettes.editor.screenRect;

    // Use the new showRelativeTo API with platform-aware offset
    await Palettes.slashMenu.showRelativeTo(
      Palettes.editor,
      theirAnchor: Anchor.bottomLeft, // Editor's bottom-left
      myAnchor: Anchor.topLeft, // Slash menu's top-left
      offset:
          editorRect.offsetRight(16) +
          editorRect.offsetDown(8), // 16px right, 8px below
      keys: {
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.enter,
      },
    );
  }

  /// Show style menu positioned smartly relative to selection.
  ///
  /// Uses ScreenRect helpers for platform-aware coordinate handling.
  Future<void> _showStyleMenuAtSelection(Rect selectionRect) async {
    // Convert to ScreenRect for platform-aware operations
    final rect = selectionRect.toScreenRect();

    // Get screen work area using cached client
    final screens = await _screenClient.getScreens();
    if (screens.isEmpty) return;

    final primaryScreen = screens.firstWhere(
      (s) => s.isPrimary,
      orElse: () => screens.first,
    );
    final workArea = primaryScreen.workArea.toScreenRect();

    // Use platform-aware visualTop/visualBottom (handles macOS/Windows differences)
    final selectionCenterY = (rect.visualTop + rect.visualBottom) / 2;
    final screenCenterY = (workArea.visualTop + workArea.visualBottom) / 2;

    // If selection is in upper half of screen, show menu below
    // If selection is in lower half, show menu above
    final showBelow = selectionCenterY > screenCenterY;

    debugPrint(
      '[NotionScreen] Selection visualTop: ${rect.visualTop}, visualBottom: ${rect.visualBottom}, centerY: $selectionCenterY',
    );
    debugPrint(
      '[NotionScreen] Screen centerY: $screenCenterY, Show ${showBelow ? "BELOW" : "ABOVE"}',
    );

    // Calculate horizontal center of selection for menu centering
    final selectionCenterX = rect.centerX;

    if (showBelow) {
      // Position below selection using platform-aware offset
      final position = Offset(
        selectionCenterX,
        rect.visualBottom,
      ).below(_styleMenuGap);
      await Palettes.styleMenu.showAtPosition(
        position,
        anchor: Anchor.topCenter,
      );
    } else {
      // Position above selection using platform-aware offset
      final position = Offset(
        selectionCenterX,
        rect.visualTop,
      ).above(_styleMenuGap);
      await Palettes.styleMenu.showAtPosition(
        position,
        anchor: Anchor.bottomCenter,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notion Clone'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          _ToolbarButton(
            icon: Icons.edit,
            tooltip: 'Show Editor',
            onPressed: () => Palettes.editor.show(
              position: PalettePosition.centerScreen(yOffset: -100),
            ),
          ),
          _ToolbarButton(
            icon: Icons.menu,
            tooltip: 'Show Slash Menu',
            onPressed: () => Palettes.slashMenu.show(),
          ),
          _ToolbarButton(
            icon: Icons.format_bold,
            tooltip: 'Show Style Menu',
            onPressed: () => Palettes.styleMenu.show(),
          ),
          const SizedBox(width: 8),
          _ToolbarButton(
            icon: Icons.close,
            tooltip: 'Hide All',
            onPressed: _hideAll,
            color: FPColors.error,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: FPColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.edit_note,
                  size: 40,
                  color: FPColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Notion Clone Example',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: FPColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'This example demonstrates input routing between palettes.\n\n'
                '- Editor palette: Main text editing surface\n'
                '- Slash menu: Triggered by typing "/"\n'
                '- Style menu: Appears on text selection\n\n'
                'Use the toolbar buttons to show each palette.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: FPColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: FPSpacing.md,
                  vertical: FPSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: FPColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: FPColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 16,
                      color: FPColors.primary,
                    ),
                    SizedBox(width: FPSpacing.sm),
                    Text(
                      'Tip: Type "/" in the editor to open the slash menu',
                      style: TextStyle(
                        fontSize: 13,
                        color: FPColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Toolbar button with hover effect.
class _ToolbarButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  @override
  State<_ToolbarButton> createState() => _ToolbarButtonState();
}

class _ToolbarButtonState extends State<_ToolbarButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? FPColors.primary;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isHovered
                  ? color.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.icon,
              size: 20,
              color: _isHovered ? color : FPColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
