import 'package:floating_palette/floating_palette.dart';
import 'package:floating_palette_annotations/floating_palette_annotations.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Enums for Type Safety
// ═══════════════════════════════════════════════════════════════════════════

// Note: BlockType is defined in models/block.dart - use that as the canonical source

/// Style types for style menu.
enum StyleType {
  bold,
  italic,
  underline,
  strikethrough,
  code,
  link,
  textColor,
  highlight,
}

/// Snap visual states.
enum SnapVisualState { detached, proximity, attached }

// ═══════════════════════════════════════════════════════════════════════════
// Editor → Host Events
// ═══════════════════════════════════════════════════════════════════════════

/// Triggered when "/" is typed in the editor to show slash menu.
@PaletteEventType('editor.show_slash_menu')
class ShowSlashMenuEvent extends PaletteEvent {
  static const id = 'editor.show_slash_menu';

  @override
  String get eventId => id;

  final double? caretX;
  final double? caretY;

  const ShowSlashMenuEvent({this.caretX, this.caretY});

  @override
  Map<String, dynamic> toMap() => {
        if (caretX != null) 'caretX': caretX,
        if (caretY != null) 'caretY': caretY,
      };

  static ShowSlashMenuEvent fromMap(Map<String, dynamic> m) => ShowSlashMenuEvent(
        caretX: (m['caretX'] as num?)?.toDouble(),
        caretY: (m['caretY'] as num?)?.toDouble(),
      );
}

/// Triggered when filter text changes after "/".
@PaletteEventType('editor.slash_menu_filter')
class SlashMenuFilterEvent extends PaletteEvent {
  static const id = 'editor.slash_menu_filter';

  @override
  String get eventId => id;

  final String filter;

  const SlashMenuFilterEvent({required this.filter});

  @override
  Map<String, dynamic> toMap() => {'filter': filter};

  static SlashMenuFilterEvent fromMap(Map<String, dynamic> m) =>
      SlashMenuFilterEvent(filter: m['filter'] as String? ?? '');
}

/// Triggered when slash menu should be cancelled/hidden.
@PaletteEventType('editor.slash_menu_cancel')
class SlashMenuCancelEvent extends PaletteEvent {
  static const id = 'editor.slash_menu_cancel';

  @override
  String get eventId => id;

  const SlashMenuCancelEvent();

  @override
  Map<String, dynamic> toMap() => {};

  static SlashMenuCancelEvent fromMap(Map<String, dynamic> _) =>
      const SlashMenuCancelEvent();
}

/// Triggered when text is selected to show style menu.
@PaletteEventType('editor.show_style_menu')
class ShowStyleMenuEvent extends PaletteEvent {
  static const id = 'editor.show_style_menu';

  @override
  String get eventId => id;

  final double selectionLeft;
  final double selectionTop;
  final double selectionRight;
  final double selectionBottom;

  const ShowStyleMenuEvent({
    required this.selectionLeft,
    required this.selectionTop,
    required this.selectionRight,
    required this.selectionBottom,
  });

  @override
  Map<String, dynamic> toMap() => {
        'selectionLeft': selectionLeft,
        'selectionTop': selectionTop,
        'selectionRight': selectionRight,
        'selectionBottom': selectionBottom,
      };

  static ShowStyleMenuEvent fromMap(Map<String, dynamic> m) => ShowStyleMenuEvent(
        selectionLeft: (m['selectionLeft'] as num?)?.toDouble() ?? 0,
        selectionTop: (m['selectionTop'] as num?)?.toDouble() ?? 0,
        selectionRight: (m['selectionRight'] as num?)?.toDouble() ?? 0,
        selectionBottom: (m['selectionBottom'] as num?)?.toDouble() ?? 0,
      );
}

/// Triggered when style menu should be hidden.
@PaletteEventType('editor.hide_style_menu')
class HideStyleMenuEvent extends PaletteEvent {
  static const id = 'editor.hide_style_menu';

  @override
  String get eventId => id;

  const HideStyleMenuEvent();

  @override
  Map<String, dynamic> toMap() => {};

  static HideStyleMenuEvent fromMap(Map<String, dynamic> _) =>
      const HideStyleMenuEvent();
}

/// Triggered to update style menu with current selection's style state.
@PaletteEventType('editor.style_state')
class StyleStateEvent extends PaletteEvent {
  static const id = 'editor.style_state';

  @override
  String get eventId => id;

  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;
  final bool code;

  const StyleStateEvent({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
    this.code = false,
  });

  @override
  Map<String, dynamic> toMap() => {
        'bold': bold,
        'italic': italic,
        'underline': underline,
        'strikethrough': strikethrough,
        'code': code,
      };

  static StyleStateEvent fromMap(Map<String, dynamic> m) => StyleStateEvent(
        bold: m['bold'] == true,
        italic: m['italic'] == true,
        underline: m['underline'] == true,
        strikethrough: m['strikethrough'] == true,
        code: m['code'] == true,
      );
}

/// Triggered when Enter is pressed to split a block.
@PaletteEventType('editor.block_split')
class BlockSplitEvent extends PaletteEvent {
  static const id = 'editor.block_split';

  @override
  String get eventId => id;

  final String beforeText;
  final String afterText;

  const BlockSplitEvent({
    required this.beforeText,
    required this.afterText,
  });

  @override
  Map<String, dynamic> toMap() => {
        'beforeText': beforeText,
        'afterText': afterText,
      };

  static BlockSplitEvent fromMap(Map<String, dynamic> m) => BlockSplitEvent(
        beforeText: m['beforeText'] as String? ?? '',
        afterText: m['afterText'] as String? ?? '',
      );
}

/// Triggered when Backspace at block start to merge with previous.
@PaletteEventType('editor.block_merge_prev')
class BlockMergePrevEvent extends PaletteEvent {
  static const id = 'editor.block_merge_prev';

  @override
  String get eventId => id;

  final String prevBlockText;
  final String currentBlockText;
  final int mergeOffset;

  const BlockMergePrevEvent({
    required this.prevBlockText,
    required this.currentBlockText,
    required this.mergeOffset,
  });

  @override
  Map<String, dynamic> toMap() => {
        'prevBlockText': prevBlockText,
        'currentBlockText': currentBlockText,
        'mergeOffset': mergeOffset,
      };

  static BlockMergePrevEvent fromMap(Map<String, dynamic> m) => BlockMergePrevEvent(
        prevBlockText: m['prevBlockText'] as String? ?? '',
        currentBlockText: m['currentBlockText'] as String? ?? '',
        mergeOffset: m['mergeOffset'] as int? ?? 0,
      );
}

/// Triggered when Delete at block end to merge with next.
@PaletteEventType('editor.block_merge_next')
class BlockMergeNextEvent extends PaletteEvent {
  static const id = 'editor.block_merge_next';

  @override
  String get eventId => id;

  final String currentBlockText;
  final String nextBlockText;
  final int mergeOffset;

  const BlockMergeNextEvent({
    required this.currentBlockText,
    required this.nextBlockText,
    required this.mergeOffset,
  });

  @override
  Map<String, dynamic> toMap() => {
        'currentBlockText': currentBlockText,
        'nextBlockText': nextBlockText,
        'mergeOffset': mergeOffset,
      };

  static BlockMergeNextEvent fromMap(Map<String, dynamic> m) => BlockMergeNextEvent(
        currentBlockText: m['currentBlockText'] as String? ?? '',
        nextBlockText: m['nextBlockText'] as String? ?? '',
        mergeOffset: m['mergeOffset'] as int? ?? 0,
      );
}

/// Triggered when editor close button is pressed.
@PaletteEventType('editor.close_editor')
class CloseEditorEvent extends PaletteEvent {
  static const id = 'editor.close_editor';

  @override
  String get eventId => id;

  const CloseEditorEvent();

  @override
  Map<String, dynamic> toMap() => {};

  static CloseEditorEvent fromMap(Map<String, dynamic> _) =>
      const CloseEditorEvent();
}

// ═══════════════════════════════════════════════════════════════════════════
// Host → Editor Events
// ═══════════════════════════════════════════════════════════════════════════

/// Sent to editor when a block type is selected from slash menu.
@PaletteEventType('editor.insert_block')
class InsertBlockEvent extends PaletteEvent {
  static const id = 'editor.insert_block';

  @override
  String get eventId => id;

  final String type;

  const InsertBlockEvent({required this.type});

  @override
  Map<String, dynamic> toMap() => {'type': type};

  static InsertBlockEvent fromMap(Map<String, dynamic> m) =>
      InsertBlockEvent(type: m['type'] as String? ?? 'text');
}

/// Sent to editor when a style is selected from style menu.
@PaletteEventType('editor.apply_style')
class ApplyStyleEvent extends PaletteEvent {
  static const id = 'editor.apply_style';

  @override
  String get eventId => id;

  final String style;

  const ApplyStyleEvent({required this.style});

  @override
  Map<String, dynamic> toMap() => {'style': style};

  static ApplyStyleEvent fromMap(Map<String, dynamic> m) =>
      ApplyStyleEvent(style: m['style'] as String? ?? '');
}

/// Sent to editor when host updates the document state.
@PaletteEventType('editor.document_update')
class DocumentUpdateEvent extends PaletteEvent {
  static const id = 'editor.document_update';

  @override
  String get eventId => id;

  final List<Map<String, dynamic>> blocks;
  final String? focusedBlockId;
  final int caretOffset;

  const DocumentUpdateEvent({
    required this.blocks,
    this.focusedBlockId,
    this.caretOffset = 0,
  });

  @override
  Map<String, dynamic> toMap() => {
        'blocks': blocks,
        if (focusedBlockId != null) 'focusedBlockId': focusedBlockId,
        'caretOffset': caretOffset,
      };

  static DocumentUpdateEvent fromMap(Map<String, dynamic> m) => DocumentUpdateEvent(
        blocks: (m['blocks'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
        focusedBlockId: m['focusedBlockId'] as String?,
        caretOffset: m['caretOffset'] as int? ?? 0,
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// Slash Menu Events
// ═══════════════════════════════════════════════════════════════════════════

/// Triggered when an item is selected from the slash menu.
@PaletteEventType('slash-menu.slash_menu_select')
class SlashMenuSelectEvent extends PaletteEvent {
  static const id = 'slash-menu.slash_menu_select';

  @override
  String get eventId => id;

  final String type;

  const SlashMenuSelectEvent({required this.type});

  @override
  Map<String, dynamic> toMap() => {'type': type};

  static SlashMenuSelectEvent fromMap(Map<String, dynamic> m) =>
      SlashMenuSelectEvent(type: m['type'] as String? ?? 'text');
}

/// Sent to slash menu to reset its state (filter, selection, max items).
@PaletteEventType('slash-menu.slash_menu_reset')
class SlashMenuResetEvent extends PaletteEvent {
  static const id = 'slash-menu.slash_menu_reset';

  @override
  String get eventId => id;

  final int? maxVisibleItems;

  const SlashMenuResetEvent({this.maxVisibleItems});

  @override
  Map<String, dynamic> toMap() => {
        if (maxVisibleItems != null) 'maxVisibleItems': maxVisibleItems,
      };

  static SlashMenuResetEvent fromMap(Map<String, dynamic> m) =>
      SlashMenuResetEvent(maxVisibleItems: m['maxVisibleItems'] as int?);
}

// ═══════════════════════════════════════════════════════════════════════════
// Style Menu Events
// ═══════════════════════════════════════════════════════════════════════════

/// Triggered when a style button is pressed in the style menu.
@PaletteEventType('style-menu.style_action')
class StyleActionEvent extends PaletteEvent {
  static const id = 'style-menu.style_action';

  @override
  String get eventId => id;

  final String style;

  const StyleActionEvent({required this.style});

  @override
  Map<String, dynamic> toMap() => {'style': style};

  static StyleActionEvent fromMap(Map<String, dynamic> m) =>
      StyleActionEvent(style: m['style'] as String? ?? '');
}

// ═══════════════════════════════════════════════════════════════════════════
// Virtual Keyboard Events
// ═══════════════════════════════════════════════════════════════════════════

/// Sent to keyboard to update its visual snap state indicator.
@PaletteEventType('virtual-keyboard.snap_state')
class SnapStateEvent extends PaletteEvent {
  static const id = 'virtual-keyboard.snap_state';

  @override
  String get eventId => id;

  final SnapVisualState state;

  const SnapStateEvent({required this.state});

  @override
  Map<String, dynamic> toMap() => {'state': state.name};

  static SnapStateEvent fromMap(Map<String, dynamic> m) {
    final stateName = m['state'] as String?;
    final state = SnapVisualState.values.firstWhere(
      (e) => e.name == stateName,
      orElse: () => SnapVisualState.detached,
    );
    return SnapStateEvent(state: state);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Legacy Events (for backward compatibility during transition)
// ═══════════════════════════════════════════════════════════════════════════

/// Triggered when "/" is typed in the editor.
@PaletteEventType('notion.slash_trigger')
class SlashTriggerEvent extends PaletteEvent {
  /// Event ID constant (matches @PaletteEventType annotation).
  static const id = 'notion.slash_trigger';

  @override
  String get eventId => id;

  final double x;
  final double y;

  const SlashTriggerEvent({required this.x, required this.y});

  @override
  Map<String, dynamic> toMap() => {'x': x, 'y': y};

  static SlashTriggerEvent fromMap(Map<String, dynamic> m) => SlashTriggerEvent(
    x: (m['x'] as num).toDouble(),
    y: (m['y'] as num).toDouble(),
  );
}

/// Triggered when text is selected for styling.
@PaletteEventType('notion.style_trigger')
class StyleTriggerEvent extends PaletteEvent {
  static const id = 'notion.style_trigger';

  @override
  String get eventId => id;

  final double x;
  final double y;
  final String selectedText;

  const StyleTriggerEvent({
    required this.x,
    required this.y,
    required this.selectedText,
  });

  @override
  Map<String, dynamic> toMap() => {'x': x, 'y': y, 'text': selectedText};

  static StyleTriggerEvent fromMap(Map<String, dynamic> m) => StyleTriggerEvent(
    x: (m['x'] as num).toDouble(),
    y: (m['y'] as num).toDouble(),
    selectedText: m['text'] as String,
  );
}

/// Triggered when a menu item is selected.
@PaletteEventType('notion.menu_selected')
class MenuSelectedEvent extends PaletteEvent {
  static const id = 'notion.menu_selected';

  @override
  String get eventId => id;

  final String itemId;

  const MenuSelectedEvent({required this.itemId});

  @override
  Map<String, dynamic> toMap() => {'id': itemId};

  static MenuSelectedEvent fromMap(Map<String, dynamic> m) =>
      MenuSelectedEvent(itemId: m['id'] as String);
}

/// Triggered when a style is applied.
@PaletteEventType('notion.style_applied')
class StyleAppliedEvent extends PaletteEvent {
  static const id = 'notion.style_applied';

  @override
  String get eventId => id;

  final String style;

  const StyleAppliedEvent({required this.style});

  @override
  Map<String, dynamic> toMap() => {'style': style};

  static StyleAppliedEvent fromMap(Map<String, dynamic> m) =>
      StyleAppliedEvent(style: m['style'] as String);
}

/// Triggered when filter text changes.
@PaletteEventType('notion.filter_changed')
class FilterChangedEvent extends PaletteEvent {
  static const id = 'notion.filter_changed';

  @override
  String get eventId => id;

  final String filter;

  const FilterChangedEvent({required this.filter});

  @override
  Map<String, dynamic> toMap() => {'filter': filter};

  static FilterChangedEvent fromMap(Map<String, dynamic> m) =>
      FilterChangedEvent(filter: m['filter'] as String);
}
