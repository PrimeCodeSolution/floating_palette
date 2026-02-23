import 'dart:async';

import 'package:floating_palette/floating_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';

import '../events/keyboard_events.dart';
import '../events/notion_events.dart';
import '../theme/brand.dart';

/// Editor palette - rich text editor using flutter_quill.
///
/// Uses PaletteScaffold for automatic window sizing.
/// Palette grows with content as text is added.
class EditorPalette extends StatefulWidget {
  const EditorPalette({super.key});

  @override
  State<EditorPalette> createState() => _EditorPaletteState();
}

class _EditorPaletteState extends State<EditorPalette> {
  late final QuillController _controller;
  late final FocusNode _focusNode;
  final _scrollController = ScrollController();
  final _editorKey = GlobalKey<EditorState>();
  final _headerKey = GlobalKey();
  StreamSubscription<DocChange>? _documentChangesSub;

  bool _hadSelection = false;
  bool _handlingBlockInsert = false; // Prevent cancel during block insert
  bool _handlingDocumentUpdate = false; // Prevent events during host sync
  bool _handlingBlockSplit = false; // Skip newline formatting during block split
  int? _slashIndex; // Position of "/" when slash menu is active
  bool _escArmed = false;
  bool _applyingBlockReset = false;
  PaletteSizeConfig _sizeConfig = const PaletteSizeConfig(); // Runtime size config
  double? _measuredHeaderHeight; // Dynamically measured header height

  // Triple-click tracking for line selection
  int _tapCount = 0;
  DateTime? _lastTapTime;
  Offset? _lastTapPosition;
  static const _multiTapTimeout = Duration(milliseconds: 300);
  static const _multiTapSlop = 20.0; // Max distance between taps

  // Padding is explicit in code (EdgeInsets.all(16)), so reference it as a constant
  static const _editorPadding = 32.0; // 16 top + 16 bottom

  @override
  void initState() {
    super.initState();
    // Disable external rich paste - quill_native_bridge isn't available in palette subprocess
    _controller = QuillController.basic(
      config: const QuillControllerConfig(
        clipboardConfig: QuillClipboardConfig(
          enableExternalRichPaste: false,
        ),
      ),
    );
    _focusNode = FocusNode();

    // Listen for document changes
    _documentChangesSub = _controller.document.changes.listen(_onDocumentChanged);

    // Listen for selection changes
    _controller.addListener(_onSelectionChanged);

    // Listen for messages from host and request focus after layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupMessageListener();
      _setupFocusHandling();
      _loadSizeConfig();
      _measureHeaderHeight();
      // Request focus after layout is complete
      _focusNode.requestFocus();
    });
  }

  void _setupMessageListener() {
    if (!PaletteContext.isInPalette) return;

    // Handle typed events from host
    PaletteContext.current.on<InsertBlockEvent>((event) {
      _handleInsertBlock(event.type);
    });

    PaletteContext.current.on<ApplyStyleEvent>((event) {
      _handleApplyStyle(event.style);
    });

    PaletteContext.current.on<DocumentUpdateEvent>((event) {
      _handleDocumentUpdate({
        'blocks': event.blocks,
        'focusedBlockId': event.focusedBlockId,
        'caretOffset': event.caretOffset,
      });
    });

    // Handle typed keyboard events from virtual keyboard
    PaletteContext.current.on<KeyboardKeyPressed>((event) {
      _handleKeyboardInput(event.key);
    });
  }

  /// Handle key input from the virtual keyboard.
  void _handleKeyboardInput(String key) {
    if (key == 'backspace') {
      _handleBackspace();
    } else if (key == 'enter') {
      final offset = _controller.selection.baseOffset;
      _controller.replaceText(
        offset,
        0,
        '\n',
        TextSelection.collapsed(offset: offset + 1),
      );
      _scrollToCursor();
    } else {
      // Insert character at cursor
      final selection = _controller.selection;
      final baseOffset = selection.baseOffset;
      final extentOffset = selection.extentOffset;
      final deleteLength =
          extentOffset > baseOffset ? extentOffset - baseOffset : 0;
      _controller.replaceText(
        baseOffset,
        deleteLength,
        key,
        TextSelection.collapsed(offset: baseOffset + key.length),
      );
    }
  }

  /// Handle backspace key from virtual keyboard.
  void _handleBackspace() {
    final selection = _controller.selection;
    if (selection.isCollapsed) {
      final offset = selection.baseOffset;
      if (offset > 0) {
        _controller.replaceText(
          offset - 1,
          1,
          '',
          TextSelection.collapsed(offset: offset - 1),
        );
      }
    } else {
      // Delete selection
      final start = selection.start;
      final end = selection.end;
      _controller.replaceText(
        start,
        end - start,
        '',
        TextSelection.collapsed(offset: start),
      );
    }
  }

  void _setupFocusHandling() {
    if (!PaletteContext.isInPalette) return;

    // When window loses focus, unfocus the editor to stop cursor blinking
    PaletteSelf.onFocusLost(() {
      _focusNode.unfocus();
      if (_escArmed) {
        setState(() => _escArmed = false);
      }
    });

    // When window gains focus, restore editor focus
    PaletteSelf.onFocusGained(() {
      _focusNode.requestFocus();
    });
  }

  /// Load size config from native side.
  Future<void> _loadSizeConfig() async {
    if (!PaletteContext.isInPalette) return;

    try {
      final config = await PaletteSelf.sizeConfig;
      if (mounted) {
        setState(() => _sizeConfig = config);
      }
    } catch (e) {
      debugPrint('[EditorPalette] Error loading size config: $e');
    }
  }

  /// Measure the actual header height after layout.
  void _measureHeaderHeight() {
    final renderBox = _headerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && mounted) {
      setState(() => _measuredHeaderHeight = renderBox.size.height);
    }
  }

  /// Calculate editor max height dynamically.
  /// Returns null if measurements aren't ready yet (uses QuillEditor's default behavior).
  double? get _editorMaxHeight {
    final headerHeight = _measuredHeaderHeight;
    if (headerHeight == null) return null;
    return _sizeConfig.maxHeight - headerHeight - _editorPadding;
  }

  @override
  void dispose() {
    _documentChangesSub?.cancel();
    _controller.removeListener(_onSelectionChanged);
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Document Change Handling
  // ════════════════════════════════════════════════════════════════════════════

  void _onDocumentChanged(DocChange change) {
    // Skip processing during host-initiated updates
    if (_handlingDocumentUpdate) return;

    final plainText = _controller.document.toPlainText();
    final cursorPos = _controller.selection.baseOffset;

    // Look for slash command at cursor position
    // Pattern: (start of text OR space OR newline) + "/" + optional filter text
    final slashMatch = _findSlashCommandAtCursor(plainText, cursorPos);
    final hasSlashCommand = slashMatch != null;
    final hadSlashCommand = _slashIndex != null;

    if (hasSlashCommand && !hadSlashCommand) {
      // "/" was just typed - open slash menu
      _slashIndex = slashMatch.slashIndex;
      _triggerSlashMenu();
    } else if (hasSlashCommand && hadSlashCommand) {
      // User is typing filter text after "/"
      PaletteMessenger.sendEvent(SlashMenuFilterEvent(filter: slashMatch.filter));
    } else if (!hasSlashCommand && hadSlashCommand && !_handlingBlockInsert) {
      // "/" was deleted or command completed - close slash menu
      _slashIndex = null;
      PaletteMessenger.sendEvent(const SlashMenuCancelEvent());
    }

    _handleNewlineChange(change);
  }

  /// Find slash command at or before cursor position.
  /// Returns null if no valid slash command found.
  ///
  /// Valid slash positions:
  /// - Start of text: "/command"
  /// - After space: "text /command"
  /// - After newline: "line1\n/command"
  _SlashMatch? _findSlashCommandAtCursor(String text, int cursorPos) {
    if (cursorPos <= 0 || cursorPos > text.length) return null;

    // Look backwards from cursor to find "/"
    // The slash command is: /[filter text][cursor]
    // So we search backwards for "/" and check what's before it

    final textBeforeCursor = text.substring(0, cursorPos);

    // Find the last "/" that could be a command trigger
    // Match: (^|[ \n])/([a-zA-Z0-9]*)$
    // This means: start OR space OR newline, then /, then optional alphanumeric filter
    final match = RegExp(r'(?:^|[ \n])/([a-zA-Z0-9]*)$').firstMatch(textBeforeCursor);

    if (match == null) return null;

    // Calculate the actual slash position
    // If match starts with space/newline, slash is at match.start + 1
    // If at start of text, slash is at match.start
    final matchStart = match.start;
    final slashIndex = (matchStart == 0 || text[matchStart] == '/')
        ? matchStart
        : matchStart + 1;

    return _SlashMatch(
      slashIndex: slashIndex,
      filter: match.group(1) ?? '',
    );
  }

  void _onSelectionChanged() {
    final selection = _controller.selection;
    final isCollapsed = selection.isCollapsed;

    if (!isCollapsed && !_hadSelection) {
      _showStyleMenu();
      _sendStyleState();
    } else if (!isCollapsed && _hadSelection) {
      _sendStyleState();
    } else if (isCollapsed && _hadSelection) {
      PaletteMessenger.sendEvent(const HideStyleMenuEvent());
    }

    _hadSelection = !isCollapsed;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Triple-Click Line Selection
  // ════════════════════════════════════════════════════════════════════════════

  /// Handle tap down for triple-click line selection.
  /// Returns true if the tap was handled (triple-click), false otherwise.
  bool _handleTapDown(TapDownDetails details, TextPosition Function(Offset) getPosition) {
    final now = DateTime.now();
    final position = details.globalPosition;

    // Check if this is a consecutive tap (within timeout and slop)
    final isConsecutive = _lastTapTime != null &&
        _lastTapPosition != null &&
        now.difference(_lastTapTime!) < _multiTapTimeout &&
        (position - _lastTapPosition!).distance < _multiTapSlop;

    if (isConsecutive) {
      _tapCount++;
    } else {
      _tapCount = 1;
    }

    _lastTapTime = now;
    _lastTapPosition = position;

    debugPrint('[EditorPalette] tapCount=$_tapCount, isConsecutive=$isConsecutive');

    // Triple-click: select entire line
    if (_tapCount >= 3) {
      _tapCount = 0; // Reset for next triple-click
      // Use current cursor position (set by previous taps) instead of tap position
      // This avoids scroll offset issues with localPosition
      final cursorOffset = _controller.selection.baseOffset;
      debugPrint('[EditorPalette] Triple-click, cursor at offset $cursorOffset');
      _selectLineAt(cursorOffset);
      return true; // Handled - don't do default tap handling
    }

    return false; // Let default handling continue
  }

  /// Select the entire line at the given offset.
  /// Schedules selection after frame to override any tap-up handlers.
  void _selectLineAt(int offset) {
    final plainText = _controller.document.toPlainText();
    if (plainText.isEmpty) return;

    debugPrint('[EditorPalette] _selectLineAt: offset=$offset, textLength=${plainText.length}');

    // Find line start (previous newline + 1, or 0)
    int lineStart = 0;
    for (int i = offset - 1; i >= 0; i--) {
      if (plainText[i] == '\n') {
        lineStart = i + 1;
        break;
      }
    }

    // Find line end (next newline, or end of text)
    int lineEnd = plainText.length;
    for (int i = offset; i < plainText.length; i++) {
      if (plainText[i] == '\n') {
        lineEnd = i;
        break;
      }
    }

    debugPrint('[EditorPalette] Selecting line: $lineStart-$lineEnd');

    // Schedule selection AFTER current frame to override tap-up handlers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.updateSelection(
        TextSelection(baseOffset: lineStart, extentOffset: lineEnd),
        ChangeSource.local,
      );
    });
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Cursor Position Helpers
  // ════════════════════════════════════════════════════════════════════════════

  /// Get the screen position of the cursor.
  Future<Offset?> _getCursorScreenPosition() async {
    final editorState = _editorKey.currentState;
    if (editorState == null) return null;

    try {
      final renderEditor = editorState.renderEditor;
      final selection = _controller.selection;

      // Get local rect for cursor position
      final localRect = renderEditor.getLocalRectForCaret(
        TextPosition(offset: selection.baseOffset),
      );

      // Convert to global coordinates (relative to Flutter view)
      final renderBox = renderEditor as RenderBox;
      final globalOffset = renderBox.localToGlobal(localRect.bottomLeft);

      // Get window bounds and use localToScreen for platform-aware conversion
      final windowBounds = await PaletteSelf.screenRect;
      return windowBounds.localToScreen(globalOffset);
    } catch (e) {
      debugPrint('[EditorPalette] Error getting cursor position: $e');
      return null;
    }
  }

  /// Get the screen rect of the current selection.
  Future<Rect?> _getSelectionScreenRect() async {
    final editorState = _editorKey.currentState;
    if (editorState == null) return null;

    try {
      final renderEditor = editorState.renderEditor;
      final selection = _controller.selection;

      if (selection.isCollapsed) return null;

      // Get local rects for selection start and end
      final startRect = renderEditor.getLocalRectForCaret(
        TextPosition(offset: selection.start),
      );
      final endRect = renderEditor.getLocalRectForCaret(
        TextPosition(offset: selection.end),
      );

      // Convert to global coordinates (relative to Flutter view)
      final renderBox = renderEditor as RenderBox;
      final topLeft = renderBox.localToGlobal(Offset(startRect.left, startRect.top));
      final bottomRight = renderBox.localToGlobal(Offset(endRect.right, endRect.bottom));

      // Get window bounds and use localToScreen for platform-aware conversion
      final windowBounds = await PaletteSelf.screenRect;
      final screenTopLeft = windowBounds.localToScreen(topLeft);
      final screenBottomRight = windowBounds.localToScreen(bottomRight);

      return Rect.fromPoints(screenTopLeft, screenBottomRight);
    } catch (e) {
      debugPrint('[EditorPalette] Error getting selection rect: $e');
      return null;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Menu Triggers
  // ════════════════════════════════════════════════════════════════════════════

  Future<void> _triggerSlashMenu() async {
    final cursorPos = await _getCursorScreenPosition();

    if (cursorPos != null) {
      PaletteMessenger.sendEvent(ShowSlashMenuEvent(
        caretX: cursorPos.dx,
        caretY: cursorPos.dy,
      ));
    } else {
      // Fallback - host will position relative to editor
      PaletteMessenger.sendEvent(const ShowSlashMenuEvent());
    }
  }

  Future<void> _showStyleMenu() async {
    final selectionRect = await _getSelectionScreenRect();

    if (selectionRect != null) {
      PaletteMessenger.sendEvent(ShowStyleMenuEvent(
        selectionLeft: selectionRect.left,
        selectionTop: selectionRect.top,
        selectionRight: selectionRect.right,
        selectionBottom: selectionRect.bottom,
      ));
    } else {
      // Fallback with zeros - host will handle
      PaletteMessenger.sendEvent(const ShowStyleMenuEvent(
        selectionLeft: 0,
        selectionTop: 0,
        selectionRight: 0,
        selectionBottom: 0,
      ));
    }
  }

  void _sendStyleState() {
    final attrs = _controller.getSelectionStyle().attributes;
    PaletteMessenger.sendEvent(StyleStateEvent(
      bold: attrs.containsKey(Attribute.bold.key),
      italic: attrs.containsKey(Attribute.italic.key),
      underline: attrs.containsKey(Attribute.underline.key),
      strikethrough: attrs.containsKey(Attribute.strikeThrough.key),
      code: attrs.containsKey(Attribute.inlineCode.key),
    ));
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Block Operations (from Host)
  // ════════════════════════════════════════════════════════════════════════════

  void _handleInsertBlock(String type) {
    // Prevent _onDocumentChanged from sending cancel while we modify the document
    _handlingBlockInsert = true;

    try {
      // Remove the slash command (/ + filter text) and update selection
      if (_slashIndex != null) {
        final cursorPos = _controller.selection.baseOffset;
        final deleteLength = cursorPos - _slashIndex!;
        if (deleteLength > 0) {
          _controller.replaceText(
            _slashIndex!,
            deleteLength,
            '',
            TextSelection.collapsed(offset: _slashIndex!),
          );
        }
        _slashIndex = null;
      }

      // Get current cursor position for formatting
      final cursorPos = _controller.selection.baseOffset;

      // Apply block format based on type
      // Use formatSelection for block attributes — it applies to the
      // current line's newline character, unlike formatText(offset, 0, ...)
      // which is a no-op for block attributes.
      switch (type) {
        case 'heading1':
          _controller.formatSelection(Attribute.h1);
        case 'heading2':
          _controller.formatSelection(Attribute.h2);
        case 'heading3':
          _controller.formatSelection(Attribute.h3);
        case 'bullet':
          _controller.formatSelection(Attribute.ul);
        case 'numbered':
          _controller.formatSelection(Attribute.ol);
        case 'todo':
          _controller.formatSelection(Attribute.unchecked);
        case 'quote':
          _controller.formatSelection(Attribute.blockQuote);
        case 'code':
          _controller.formatSelection(Attribute.codeBlock);
        case 'divider':
          // Insert a horizontal rule
          _controller.replaceText(cursorPos, 0, '\n---\n', TextSelection.collapsed(offset: cursorPos + 5));
      }
    } finally {
      _handlingBlockInsert = false;
    }
  }

  void _handleApplyStyle(String styleName) {
    final selection = _controller.selection;
    if (selection.isCollapsed) return;

    // Map style name to Quill attribute
    final attribute = switch (styleName) {
      'bold' => Attribute.bold,
      'italic' => Attribute.italic,
      'underline' => Attribute.underline,
      'strikethrough' => Attribute.strikeThrough,
      'code' => Attribute.inlineCode,
      _ => null,
    };

    if (attribute != null) {
      final isActive = _controller
          .getSelectionStyle()
          .attributes
          .containsKey(attribute.key);
      final nextAttribute = isActive ? Attribute.clone(attribute, null) : attribute;
      _controller.formatSelection(nextAttribute);
    }
  }

  /// Handle document update from host.
  ///
  /// Reconstructs the Quill document from BlockDocument state.
  void _handleDocumentUpdate(Map<String, dynamic> data) {
    _handlingDocumentUpdate = true;

    try {
      final blocksJson = data['blocks'] as List<dynamic>?;
      final focusedBlockId = data['focusedBlockId'] as String?;
      final caretOffset = data['caretOffset'] as int? ?? 0;

      if (blocksJson == null || blocksJson.isEmpty) return;

      // Build combined document from all blocks
      final operations = <Map<String, dynamic>>[];
      int globalOffset = 0;
      int? focusOffset;

      for (final blockJson in blocksJson) {
        // Safely convert to Map<String, dynamic>
        final block = _toStringDynamicMap(blockJson);
        if (block == null) continue;

        final blockId = block['id'] as String?;
        final blockType = block['type'] as String? ?? 'paragraph';
        final contentJson = block['content'] as List<dynamic>?;

        if (blockId == null || contentJson == null) continue;

        // Track offset for focused block
        if (blockId == focusedBlockId) {
          focusOffset = globalOffset + caretOffset;
        }

        // Add block content operations
        for (final op in contentJson) {
          final opMap = _toStringDynamicMap(op);
          if (opMap == null) continue;

          if (opMap.containsKey('insert')) {
            final insert = opMap['insert'];
            if (insert is String) {
              globalOffset += insert.length;
            } else {
              globalOffset += 1; // Embed
            }
          }
          operations.add(opMap);
        }

        // Apply block-level formatting to the last newline
        if (operations.isNotEmpty) {
          final lastOp = operations.last;
          final attrs = _getQuillAttributesForBlockType(blockType);
          final existingAttrs = _toStringDynamicMap(lastOp['attributes']);

          // Add block spacing attribute to create visual separation between blocks
          // This makes Enter (new block) have more spacing than Shift+Enter (soft break)
          lastOp['attributes'] = {
            ...?existingAttrs,
            ...attrs,
            'line-height': 2.0, // Extra spacing for block boundaries
          };
        }
      }

      // Create new document from operations
      final delta = Delta.fromJson(operations);
      final newDoc = Document.fromDelta(delta);

      // Calculate cursor position
      final cursorPos = focusOffset ?? 0;
      final maxPos = newDoc.length - 1;
      final clampedPos = cursorPos.clamp(0, maxPos < 0 ? 0 : maxPos);

      // Update controller
      _controller.document = newDoc;
      _controller.updateSelection(
        TextSelection.collapsed(offset: clampedPos),
        ChangeSource.local,
      );

      debugPrint('[EditorPalette] Document updated: ${blocksJson.length} blocks, cursor at $clampedPos');
    } catch (e, stack) {
      debugPrint('[EditorPalette] Error handling document update: $e');
      debugPrint('[EditorPalette] Stack: $stack');
    } finally {
      _handlingDocumentUpdate = false;
    }
  }

  /// Safely convert dynamic map to a string-keyed dynamic map.
  Map<String, dynamic>? _toStringDynamicMap(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  /// Convert block type to Quill attributes.
  Map<String, dynamic> _getQuillAttributesForBlockType(String blockType) {
    return switch (blockType) {
      'heading1' => {'header': 1},
      'heading2' => {'header': 2},
      'heading3' => {'header': 3},
      'bulletList' => {'list': 'bullet'},
      'numberedList' => {'list': 'ordered'},
      'todo' => {'list': 'unchecked'},
      'quote' => {'blockquote': true},
      'code' => {'code-block': true},
      _ => {},
    };
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Build
  // ════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: FPColors.surfaceElevated,
      ),
      home: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            return _handleKeyEvent(event);
          }
          return KeyEventResult.ignored;
        },
        child: PaletteScaffold(
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
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: AnimatedGradientBorder(
            enabled: _escArmed,
            borderWidth: 2.0,
            borderRadius: 12,
            colors: const [
              FPColors.warning,
              Color(0xFFFF8A3D),
              FPColors.error,
              FPColors.warning,
            ],
            animationDuration: const Duration(seconds: 2),
            child: SizedBox(
              width: 700,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  _buildEditor(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  KeyEventResult _handleKeyEvent(KeyDownEvent event) {
    final key = event.logicalKey;
    final selection = _controller.selection;

    // Escape handling for close confirmation
    if (key == LogicalKeyboardKey.escape) {
      if (_escArmed) {
        Palette.hide();
      } else {
        setState(() => _escArmed = true);
      }
      return KeyEventResult.handled;
    }

    if (_escArmed) {
      setState(() => _escArmed = false);
    }

    // Enter key: split block (unless Shift is held for soft line break)
    if (key == LogicalKeyboardKey.enter) {
      if (_isShiftPressed()) {
        // Shift+Enter: soft line break - insert newline directly
        _insertNewlineAtCursor();
        return KeyEventResult.handled;
      }
      // Enter: notify host about block split, then insert newline
      _requestBlockSplit();
      // Skip block-level formatting reset (host handles heading→paragraph etc.)
      _handlingBlockSplit = true;
      // Insert the newline ourselves since returning ignored doesn't work
      _insertNewlineAtCursor();
      // Reset inline styles so bold/italic don't carry to the new block
      _resetInlineStyles();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handlingBlockSplit = false;
      });
      return KeyEventResult.handled;
    }

    // Backspace at start of block: merge with previous
    if (key == LogicalKeyboardKey.backspace) {
      if (selection.isCollapsed && _isAtBlockStart()) {
        final offset = selection.baseOffset;
        if (offset > 0) {
          _requestMergeWithPrevious();
          // Delete the newline before cursor (merge blocks)
          _controller.replaceText(
            offset - 1,
            1,
            '',
            TextSelection.collapsed(offset: offset - 1),
          );
          return KeyEventResult.handled;
        }
      }
    }

    // Delete at end of block: merge with next
    if (key == LogicalKeyboardKey.delete) {
      if (selection.isCollapsed && _isAtBlockEnd()) {
        final offset = selection.baseOffset;
        final docLength = _controller.document.length;
        if (offset < docLength - 1) {
          _requestMergeWithNext();
          // Delete the newline at cursor (merge blocks)
          _controller.replaceText(
            offset,
            1,
            '',
            TextSelection.collapsed(offset: offset),
          );
          return KeyEventResult.handled;
        }
      }
    }

    return KeyEventResult.ignored;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Block Operation Requests
  // ════════════════════════════════════════════════════════════════════════════

  /// Check if caret is at the start of the current block (line).
  bool _isAtBlockStart() {
    final selection = _controller.selection;
    if (!selection.isCollapsed) return false;

    final offset = selection.baseOffset;
    if (offset == 0) return true;

    // Check if previous character is a newline
    final plainText = _controller.document.toPlainText();
    if (offset > 0 && offset <= plainText.length) {
      return plainText[offset - 1] == '\n';
    }
    return false;
  }

  /// Check if caret is at the end of the current block (line).
  bool _isAtBlockEnd() {
    final selection = _controller.selection;
    if (!selection.isCollapsed) return false;

    final offset = selection.baseOffset;
    final plainText = _controller.document.toPlainText();
    final textLength = plainText.length;

    // At end of document (before trailing newline)
    if (offset >= textLength - 1) return true;

    // Check if next character is a newline
    if (offset < textLength) {
      return plainText[offset] == '\n';
    }
    return false;
  }

  /// Get the start offset of the current block.
  /// Insert a newline at the current cursor position and scroll to it.
  void _insertNewlineAtCursor() {
    final offset = _controller.selection.baseOffset;
    _controller.replaceText(
      offset,
      0,
      '\n',
      TextSelection.collapsed(offset: offset + 1),
    );
    // Scroll to cursor after insertion
    _scrollToCursor();
  }

  /// Scroll the editor to ensure the cursor is visible.
  void _scrollToCursor() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      final editorState = _editorKey.currentState;
      if (editorState == null) return;

      try {
        final renderEditor = editorState.renderEditor;
        final selection = _controller.selection;

        // Get the local rect for the cursor
        final cursorRect = renderEditor.getLocalRectForCaret(
          TextPosition(offset: selection.baseOffset),
        );

        // Get current scroll position and viewport height
        final scrollOffset = _scrollController.offset;
        final viewportHeight = _scrollController.position.viewportDimension;
        final maxScroll = _scrollController.position.maxScrollExtent;

        // Calculate if cursor is below visible area
        final cursorBottom = cursorRect.bottom;
        final visibleBottom = scrollOffset + viewportHeight;

        if (cursorBottom > visibleBottom - 20) {
          // Cursor is below visible area, scroll down
          final targetScroll = (cursorBottom - viewportHeight + 40).clamp(0.0, maxScroll);
          _scrollController.animateTo(
            targetScroll,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        } else if (cursorRect.top < scrollOffset + 20) {
          // Cursor is above visible area, scroll up
          final targetScroll = (cursorRect.top - 40).clamp(0.0, maxScroll);
          _scrollController.animateTo(
            targetScroll,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      } catch (e) {
        debugPrint('[EditorPalette] Error scrolling to cursor: $e');
      }
    });
  }

  int _getCurrentBlockStart() {
    final offset = _controller.selection.baseOffset;
    final plainText = _controller.document.toPlainText();

    // Find the previous newline
    for (var i = offset - 1; i >= 0; i--) {
      if (plainText[i] == '\n') {
        return i + 1;
      }
    }
    return 0;
  }

  /// Request the host to split the current block.
  void _requestBlockSplit() {
    final selection = _controller.selection;
    final plainText = _controller.document.toPlainText();
    final blockStart = _getCurrentBlockStart();
    final blockEnd = _getCurrentBlockEnd();
    final offsetInBlock = selection.baseOffset - blockStart;

    // Get the content of the current block
    final blockContent = plainText.substring(blockStart, blockEnd);

    // Split the content at the cursor position
    final beforeText = blockContent.substring(0, offsetInBlock);
    final afterText = blockContent.substring(offsetInBlock);

    PaletteMessenger.sendEvent(BlockSplitEvent(
      beforeText: beforeText,
      afterText: afterText,
    ));

    debugPrint('[EditorPalette] Requesting block split: before="$beforeText", after="$afterText"');
  }

  /// Get the end offset of the current block.
  int _getCurrentBlockEnd() {
    final offset = _controller.selection.baseOffset;
    final plainText = _controller.document.toPlainText();

    // Find the next newline
    for (var i = offset; i < plainText.length; i++) {
      if (plainText[i] == '\n') {
        return i;
      }
    }
    return plainText.length;
  }

  /// Request the host to merge current block with previous.
  void _requestMergeWithPrevious() {
    final plainText = _controller.document.toPlainText();
    final blockStart = _getCurrentBlockStart();
    final blockEnd = _getCurrentBlockEnd();
    final currentBlockText = plainText.substring(blockStart, blockEnd);

    // Get previous block text
    String prevBlockText = '';
    if (blockStart > 0) {
      final prevBlockEnd = blockStart - 1; // Before the newline
      int prevBlockStart = 0;
      for (var i = prevBlockEnd - 1; i >= 0; i--) {
        if (plainText[i] == '\n') {
          prevBlockStart = i + 1;
          break;
        }
      }
      prevBlockText = plainText.substring(prevBlockStart, prevBlockEnd);
    }

    PaletteMessenger.sendEvent(BlockMergePrevEvent(
      currentBlockText: currentBlockText,
      prevBlockText: prevBlockText,
      mergeOffset: prevBlockText.length, // Cursor position after merge
    ));

    debugPrint('[EditorPalette] Requesting merge with previous: "$prevBlockText" + "$currentBlockText"');
  }

  /// Request the host to merge current block with next.
  void _requestMergeWithNext() {
    final plainText = _controller.document.toPlainText();
    final blockStart = _getCurrentBlockStart();
    final blockEnd = _getCurrentBlockEnd();
    final currentBlockText = plainText.substring(blockStart, blockEnd);

    // Get next block text
    String nextBlockText = '';
    if (blockEnd < plainText.length - 1) {
      final nextBlockStart = blockEnd + 1; // After the newline
      int nextBlockEnd = plainText.length;
      for (var i = nextBlockStart; i < plainText.length; i++) {
        if (plainText[i] == '\n') {
          nextBlockEnd = i;
          break;
        }
      }
      nextBlockText = plainText.substring(nextBlockStart, nextBlockEnd);
    }

    PaletteMessenger.sendEvent(BlockMergeNextEvent(
      currentBlockText: currentBlockText,
      nextBlockText: nextBlockText,
      mergeOffset: currentBlockText.length, // Cursor stays at current position
    ));

    debugPrint('[EditorPalette] Requesting merge with next: "$currentBlockText" + "$nextBlockText"');
  }

  void _handleNewlineChange(DocChange change) {
    // Skip for block splits (Enter) - only apply formatting for soft breaks (Shift+Enter)
    if (_handlingBlockSplit) return;
    if (_applyingBlockReset || change.source != ChangeSource.local) return;

    final offsets = <int>[];
    var index = 0;
    for (final op in change.change.operations) {
      if (op.isRetain) {
        index += op.length ?? 0;
        continue;
      }
      if (op.isInsert) {
        final data = op.data;
        if (data is String) {
          for (var i = 0; i < data.length; i++) {
            if (data.codeUnitAt(i) == 10) {
              offsets.add(index + i);
            }
          }
          index += data.length;
        } else {
          index += 1;
        }
        continue;
      }
      if (op.isDelete) {
        // deletes don't move the index forward
      }
    }

    if (offsets.isEmpty) return;
    debugPrint('[EditorPalette] newline insert offsets=$offsets');

    _applyingBlockReset = true;
    try {
      for (final offset in offsets) {
        _applyBlockDefaults(lineOffset: offset);
      }
    } finally {
      _applyingBlockReset = false;
    }
  }

  void _applyBlockDefaults({int? lineOffset}) {
    final baseOffset = lineOffset ?? _controller.selection.baseOffset;
    if (baseOffset < 0) return;
    final docLength = _controller.document.length;
    final targetOffset = baseOffset >= docLength ? docLength - 1 : baseOffset;
    debugPrint(
      '[EditorPalette] apply defaults at offset=$targetOffset docLength=$docLength',
    );

    _resetInlineStyles();
    _controller.formatText(targetOffset, 1, Attribute.clone(Attribute.header, null));
    _controller.formatText(targetOffset, 1, Attribute.clone(Attribute.list, null));
    _controller.formatText(targetOffset, 1, Attribute.clone(Attribute.blockQuote, null));
    _controller.formatText(targetOffset, 1, Attribute.clone(Attribute.codeBlock, null));
    _controller.formatText(targetOffset, 1, Attribute.clone(Attribute.indent, null));
    _controller.formatText(targetOffset, 1, Attribute.clone(Attribute.align, null));
    _controller.formatText(targetOffset, 1, Attribute.clone(Attribute.direction, null));
    _controller.formatText(targetOffset, 1, LineHeightAttribute.lineHeightOneAndHalf);
    _sendStyleState();
  }

  /// Reset inline styles (bold, italic, etc.) at the current cursor position.
  void _resetInlineStyles() {
    if (_controller.selection.isCollapsed) {
      _controller.formatSelection(Attribute.clone(Attribute.bold, null));
      _controller.formatSelection(Attribute.clone(Attribute.italic, null));
      _controller.formatSelection(Attribute.clone(Attribute.underline, null));
      _controller.formatSelection(Attribute.clone(Attribute.strikeThrough, null));
      _controller.formatSelection(Attribute.clone(Attribute.inlineCode, null));
    }
  }

  bool _isShiftPressed() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight);
  }

  Widget _buildHeader() {
    return GestureDetector(
      key: _headerKey,
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => PaletteWindow.startDrag(),
      child: MouseRegion(
        cursor: SystemMouseCursors.move,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: FPColors.surfaceSubtle)),
          ),
          child: Row(
            children: [
              const Icon(Icons.edit_document, color: FPColors.primary, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Editor',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: FPColors.textSecondary,
                  ),
                ),
              ),
              _HeaderButton(
                icon: Icons.keyboard,
                tooltip: 'Toggle Keyboard',
                onTap: () => PaletteMessenger.sendEvent(const ToggleKeyboard()),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.drag_indicator,
                color: FPColors.textSecondary,
                size: 16,
              ),
              const SizedBox(width: 4),
              _HeaderButton(
                icon: Icons.close,
                tooltip: 'Close',
                onTap: () => PaletteMessenger.sendEvent(const CloseEditorEvent()),
                hoverColor: FPColors.error,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditor() {
    final baseTextStyle = DefaultTextStyle.of(context).style.copyWith(
      color: FPColors.textPrimary,
      fontSize: 16,
      height: 1.5,
      decoration: TextDecoration.none,
    );
    final paragraphStyle = DefaultTextBlockStyle(
      baseTextStyle,
      const HorizontalSpacing(0, 0),
      VerticalSpacing.zero, // No extra spacing for paragraphs
      VerticalSpacing.zero,
      null,
    );
    // Style for soft line breaks (Shift+Enter) - minimal spacing
    final lineHeightOneAndHalfStyle = DefaultTextBlockStyle(
      baseTextStyle,
      const HorizontalSpacing(0, 0),
      VerticalSpacing.zero, // No extra spacing for soft breaks
      VerticalSpacing.zero,
      null,
    );
    // Style for block boundaries (Enter) - extra spacing between blocks
    // NOTE: BoxDecoration doesn't work for dividers because flutter_quill renders
    // all blocks as one continuous document. Blocks are lines, not separate widgets.
    final lineHeightDoubleStyle = DefaultTextBlockStyle(
      baseTextStyle,
      const HorizontalSpacing(0, 0),
      const VerticalSpacing(16, 8), // Extra spacing above/below block boundaries
      VerticalSpacing.zero,
      null,
    );
    // Placeholder style to match text size
    final placeholderBlockStyle = DefaultTextBlockStyle(
      baseTextStyle.copyWith(color: FPColors.textSecondary),
      const HorizontalSpacing(0, 0),
      VerticalSpacing.zero,
      VerticalSpacing.zero,
      null,
    );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: QuillEditor.basic(
        controller: _controller,
        focusNode: _focusNode,
        scrollController: _scrollController,
        config: QuillEditorConfig(
          editorKey: _editorKey,
          placeholder: 'Type / for commands...',
          padding: EdgeInsets.zero,
          autoFocus: false, // Focus manually after layout
          expands: false,
          scrollable: true, // Enable scrolling when content exceeds maxHeight
          minHeight: 24, // Single line height
          // Max height dynamically calculated from measured header height
          maxHeight: _editorMaxHeight,
          // Triple-click selects line
          onTapDown: (details, getPosition) => _handleTapDown(details, getPosition),
          customStyles: DefaultStyles(
            paragraph: paragraphStyle,
            lineHeightOneAndHalf: lineHeightOneAndHalfStyle,
            lineHeightDouble: lineHeightDoubleStyle,
            placeHolder: placeholderBlockStyle,
          ),
        ),
      ),
    );
  }
}

/// Header button with hover effect.
class _HeaderButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? hoverColor;

  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.hoverColor,
  });

  @override
  State<_HeaderButton> createState() => _HeaderButtonState();
}

class _HeaderButtonState extends State<_HeaderButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final hoverColor = widget.hoverColor ?? FPColors.primary;
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
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _isHovered
                  ? hoverColor.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              widget.icon,
              size: 16,
              color: _isHovered ? hoverColor : FPColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Result of finding a slash command in text.
class _SlashMatch {
  final int slashIndex;
  final String filter;

  _SlashMatch({required this.slashIndex, required this.filter});
}
