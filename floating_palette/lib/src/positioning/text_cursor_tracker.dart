import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'screen_rect.dart';

/// Tracks text cursor (caret) position in a TextField or similar widget.
///
/// Provides a simple API to get the exact pixel position of the text cursor,
/// useful for positioning menus, tooltips, or other UI relative to where
/// the user is typing.
///
/// ## Usage
///
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   final _textController = TextEditingController();
///   final _cursorTracker = TextCursorTracker();
///
///   void _onSlashTyped() {
///     // Get cursor rect in local coordinates
///     final cursorRect = _cursorTracker.cursorRect;
///     if (cursorRect != null) {
///       // Position a menu below the cursor
///       showMenu(at: cursorRect.bottomLeft);
///     }
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return TextField(
///       key: _cursorTracker.key,  // Attach the tracker's key
///       controller: _textController,
///     );
///   }
/// }
/// ```
///
/// ## For Palettes
///
/// When used inside a palette, combine with [PaletteSelf] to get screen coordinates:
///
/// ```dart
/// final localRect = _cursorTracker.cursorRect;
/// if (localRect != null) {
///   final screenPos = await PaletteSelf.localToScreen(localRect.bottomLeft);
///   PaletteMessenger.send('show-menu', {'x': screenPos.dx, 'y': screenPos.dy});
/// }
/// ```
class TextCursorTracker {
  /// The GlobalKey to attach to the TextField.
  ///
  /// Usage: `TextField(key: tracker.key, ...)`
  final GlobalKey key = GlobalKey();

  /// Find the RenderEditable inside the tracked widget.
  RenderEditable? get _renderEditable {
    final context = key.currentContext;
    if (context == null) return null;

    RenderEditable? result;

    void visitor(Element element) {
      if (result != null) return; // Already found
      if (element.renderObject is RenderEditable) {
        result = element.renderObject as RenderEditable;
        return;
      }
      element.visitChildren(visitor);
    }

    (context as Element).visitChildren(visitor);
    return result;
  }

  /// Whether the tracker is attached to a mounted widget.
  bool get isAttached => key.currentContext != null;

  /// Whether a RenderEditable was found (TextField is properly set up).
  bool get hasRenderEditable => _renderEditable != null;

  // ════════════════════════════════════════════════════════════════════════════
  // Cursor Position (Local Coordinates)
  // ════════════════════════════════════════════════════════════════════════════

  /// Get the cursor rect at a specific text offset.
  ///
  /// Returns the rect in local coordinates (relative to the TextField).
  /// Returns null if the tracker is not attached or RenderEditable not found.
  Rect? getCursorRectAt(int offset) {
    final renderEditable = _renderEditable;
    if (renderEditable == null) return null;

    return renderEditable.getLocalRectForCaret(TextPosition(offset: offset));
  }

  /// Get the cursor rect at the current selection/cursor position.
  ///
  /// Requires passing the TextEditingController to get the current selection.
  /// Returns null if no selection or tracker not attached.
  Rect? getCursorRect(TextEditingController controller) {
    if (!controller.selection.isValid) return null;
    return getCursorRectAt(controller.selection.baseOffset);
  }

  /// Get the cursor position (top-left of cursor rect) at a specific offset.
  Offset? getCursorPositionAt(int offset) {
    final rect = getCursorRectAt(offset);
    return rect != null ? Offset(rect.left, rect.top) : null;
  }

  /// Get the current cursor position.
  Offset? getCursorPosition(TextEditingController controller) {
    final rect = getCursorRect(controller);
    return rect != null ? Offset(rect.left, rect.top) : null;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Cursor Position (Widget-Relative Coordinates)
  // ════════════════════════════════════════════════════════════════════════════

  /// Get the cursor rect in coordinates relative to the Flutter view (window).
  ///
  /// This accounts for the TextField's position within the widget tree.
  Rect? getCursorRectInView(TextEditingController controller) {
    final renderEditable = _renderEditable;
    if (renderEditable == null) return null;
    if (!controller.selection.isValid) return null;

    final localRect = renderEditable.getLocalRectForCaret(
      TextPosition(offset: controller.selection.baseOffset),
    );

    // Convert to view coordinates
    final editableOffset = renderEditable.localToGlobal(Offset.zero);
    return localRect.shift(editableOffset);
  }

  /// Get a specific anchor point of the cursor in view coordinates.
  ///
  /// Common anchors:
  /// - `bottomLeft` - for dropdown menus below cursor
  /// - `topLeft` - for tooltips above cursor
  Offset? getCursorAnchorInView(
    TextEditingController controller, {
    CursorAnchor anchor = CursorAnchor.bottomLeft,
  }) {
    final rect = getCursorRectInView(controller);
    if (rect == null) return null;

    return switch (anchor) {
      CursorAnchor.topLeft => Offset(rect.left, rect.top),
      CursorAnchor.topRight => Offset(rect.right, rect.top),
      CursorAnchor.bottomLeft => Offset(rect.left, rect.bottom),
      CursorAnchor.bottomRight => Offset(rect.right, rect.bottom),
      CursorAnchor.center => rect.center,
    };
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Screen Coordinates (for Palettes)
  // ════════════════════════════════════════════════════════════════════════════

  /// Get the cursor rect in screen coordinates.
  ///
  /// [windowBounds] - The palette window's bounds from PaletteSelf.screenRect.
  ///
  /// Returns a [ScreenRect] for platform-aware positioning.
  ScreenRect? getCursorScreenRect(
    TextEditingController controller,
    ScreenRect windowBounds,
  ) {
    final viewRect = getCursorRectInView(controller);
    if (viewRect == null) return null;

    // Convert view coordinates to screen coordinates
    final screenTopLeft = windowBounds.localToScreen(
      Offset(viewRect.left, viewRect.top),
    );

    return ScreenRect(
      Rect.fromLTWH(
        screenTopLeft.dx,
        windowBounds.isMacOS
            ? screenTopLeft.dy - viewRect.height
            : screenTopLeft.dy,
        viewRect.width,
        viewRect.height,
      ),
      isMacOS: windowBounds.isMacOS,
    );
  }

  /// Get a cursor anchor point in screen coordinates.
  ///
  /// This is the most common use case for palettes - get screen position
  /// to show a menu below the cursor.
  ///
  /// [windowBounds] - The palette window's bounds from PaletteSelf.screenRect.
  Offset? getCursorScreenPosition(
    TextEditingController controller,
    ScreenRect windowBounds, {
    CursorAnchor anchor = CursorAnchor.bottomLeft,
  }) {
    final viewPos = getCursorAnchorInView(controller, anchor: anchor);
    if (viewPos == null) return null;

    return windowBounds.localToScreen(viewPos);
  }
}

/// Anchor points on the cursor rect.
enum CursorAnchor {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  center,
}

// ════════════════════════════════════════════════════════════════════════════
// Selection Bounds Extension
// ════════════════════════════════════════════════════════════════════════════

/// Extension to add selection bounds support to TextCursorTracker.
extension TextSelectionBounds on TextCursorTracker {
  /// Get the bounding rect for the current text selection.
  ///
  /// Returns null if:
  /// - No selection
  /// - Selection is collapsed (cursor, not selection)
  /// - Tracker not attached
  Rect? getSelectionRectInView(TextEditingController controller) {
    if (!controller.selection.isValid) return null;
    if (controller.selection.isCollapsed) return null; // No actual selection

    final startRect = getCursorRectAt(controller.selection.start);
    final endRect = getCursorRectAt(controller.selection.end);

    if (startRect == null || endRect == null) return null;

    // For single-line: combine start and end rects
    // For multi-line: this gives the bounding box
    final combinedRect = startRect.expandToInclude(endRect);

    // Convert to view coordinates
    final renderEditable = _renderEditablePublic;
    if (renderEditable == null) return null;

    final editableOffset = renderEditable.localToGlobal(Offset.zero);
    return combinedRect.shift(editableOffset);
  }

  /// Access to render editable for extensions.
  RenderEditable? get _renderEditablePublic {
    final context = key.currentContext;
    if (context == null) return null;

    RenderEditable? result;

    void visitor(Element element) {
      if (result != null) return;
      if (element.renderObject is RenderEditable) {
        result = element.renderObject as RenderEditable;
        return;
      }
      element.visitChildren(visitor);
    }

    (context as Element).visitChildren(visitor);
    return result;
  }

  /// Get selection bounds in screen coordinates.
  ///
  /// [windowBounds] - The palette window's bounds from PaletteSelf.screenRect.
  ScreenRect? getSelectionScreenRect(
    TextEditingController controller,
    ScreenRect windowBounds,
  ) {
    final viewRect = getSelectionRectInView(controller);
    if (viewRect == null) return null;

    // Convert view coordinates to screen coordinates
    final screenTopLeft = windowBounds.localToScreen(
      Offset(viewRect.left, viewRect.top),
    );
    final screenBottomRight = windowBounds.localToScreen(
      Offset(viewRect.right, viewRect.bottom),
    );

    // On macOS, Y is flipped, so we need to handle it correctly
    if (windowBounds.isMacOS) {
      return ScreenRect(
        Rect.fromLTRB(
          screenTopLeft.dx,
          screenBottomRight.dy, // bottom becomes top in macOS coords
          screenBottomRight.dx,
          screenTopLeft.dy, // top becomes bottom in macOS coords
        ),
        isMacOS: true,
      );
    }

    return ScreenRect(
      Rect.fromLTRB(
        screenTopLeft.dx,
        screenTopLeft.dy,
        screenBottomRight.dx,
        screenBottomRight.dy,
      ),
      isMacOS: false,
    );
  }

  /// Whether there is an active (non-collapsed) selection.
  bool hasSelection(TextEditingController controller) {
    return controller.selection.isValid && !controller.selection.isCollapsed;
  }
}
