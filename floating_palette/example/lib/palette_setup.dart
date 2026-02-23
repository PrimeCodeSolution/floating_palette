import 'package:flutter/widgets.dart';
import 'package:floating_palette/floating_palette.dart';
import 'package:floating_palette_annotations/floating_palette_annotations.dart';

// Palette widgets
import 'palettes/demo_palette.dart';
import 'palettes/editor_palette.dart';
import 'palettes/custom_shape_glass_palette.dart';
import 'palettes/slash_menu_palette.dart';
import 'palettes/style_menu_palette.dart';
import 'palettes/spotlight_palette.dart';
import 'palettes/chat_bubble_palette.dart';
import 'palettes/clock_palette.dart';
import 'palettes/virtual_keyboard_palette.dart';

// Events (for auto-registration)
import 'events/keyboard_events.dart';
import 'events/notion_events.dart';

part 'palette_setup.g.dart';

/// All palettes for example app.
///
/// Includes palettes for:
/// - Playground: demo palette for testing
/// - Notion: editor, slash menu, style menu
/// - Spotlight: search palette
///
/// **Event registration:**
/// Events are declared per-palette. IDs are auto-generated as
/// `${paletteId}.${snake_case(className)}` (e.g., `editor.filter_changed`).
@FloatingPaletteApp(
  palettes: [
    // Playground
    PaletteAnnotation(id: 'demo', widget: DemoPalette),

    // Notion example
    PaletteAnnotation(
      id: 'editor',
      widget: EditorPalette,
      hideOnClickOutside: false, // Editor stays open
      draggable: true,
      events: [
        // Editor → Host (outgoing)
        Event(ShowSlashMenuEvent),
        Event(SlashMenuFilterEvent),
        Event(SlashMenuCancelEvent),
        Event(ShowStyleMenuEvent),
        Event(HideStyleMenuEvent),
        Event(StyleStateEvent),
        Event(BlockSplitEvent),
        Event(BlockMergePrevEvent),
        Event(BlockMergeNextEvent),
        Event(CloseEditorEvent),
        Event(ToggleKeyboard),
        // Host → Editor (incoming)
        Event(InsertBlockEvent),
        Event(ApplyStyleEvent),
        Event(DocumentUpdateEvent),
        // Legacy (for backward compatibility)
        Event(FilterChangedEvent),
      ],
    ),
    PaletteAnnotation(
      id: 'slash-menu',
      widget: SlashMenuPalette,
      width: 280,
      minHeight: 56, // Allow small size when filtered
      maxHeight: 600, // Cap for scrolling
      focus: TakesFocus.no, // Focus stays on editor
      hideOnClickOutside: true,
      hideOnEscape: true,
      events: [
        // Slash Menu → Host (outgoing)
        Event(SlashMenuSelectEvent),
        // Host → Slash Menu (incoming)
        Event(SlashMenuResetEvent),
        // Legacy
        Event(SlashTriggerEvent),
        Event(MenuSelectedEvent),
      ],
    ),
    PaletteAnnotation(
      id: 'style-menu',
      widget: StyleMenuPalette,
      focus: TakesFocus.no, // Focus stays on editor for keyboard operations
      hideOnClickOutside: true,
      hideOnEscape: true,
      events: [
        // Style Menu → Host (outgoing)
        Event(StyleActionEvent),
        // Legacy
        Event(StyleTriggerEvent),
        Event(StyleAppliedEvent),
      ],
    ),

    // Spotlight example - functional search with Liquid Glass
    // Uses Preset.spotlight for sensible defaults (hides on click outside/escape,
    // returns to previous app on hide), with custom size overrides
    PaletteAnnotation(
      id: 'spotlight',
      widget: SpotlightPalette,
      preset: Preset.spotlight, // Sensible defaults for command palette
      width: 640, // Override default width
      minHeight: 60,
      maxHeight: 500, // Allow expansion for search results
      draggable: true, // Override: spotlight preset doesn't include draggable
    ),

    // Custom Shape Glass palette - Liquid Glass with custom shapes
    PaletteAnnotation(
      id: 'custom-shape-glass',
      widget: CustomShapeGlassPalette,
      width: 350,
      minHeight: 500,
      maxHeight: 500,
      hideOnClickOutside: false,
      hideOnEscape: true,
      draggable: true,
    ),

    // AI Chat Bubble - Ollama-powered chat with Liquid Glass (resizable)
    PaletteAnnotation(
      id: 'chat-bubble',
      widget: ChatBubblePalette,
      width: 600,
      minHeight: 200, // Minimum to fit input + header
      maxHeight: 600,
      initialWidth: 600,
      initialHeight: 360,
      resizable: true,
      allowSnap: true,
      hideOnClickOutside: false,
      hideOnEscape: true,
      draggable: true,
    ),

    // Analog Clock - transparent floating clock with Liquid Glass
    PaletteAnnotation(
      id: 'clock',
      widget: ClockPalette,
      width: 200,
      minHeight: 200,
      maxHeight: 200,
      hideOnClickOutside: false,
      hideOnEscape: true,
      draggable: true,
      keepAlive: true,
    ),

    // Virtual Keyboard - sends key events to editor
    PaletteAnnotation(
      id: 'virtual-keyboard',
      widget: VirtualKeyboardPalette,
      focus: TakesFocus.no, // Focus stays on editor
      hideOnClickOutside: false,
      hideOnEscape: true,
      draggable: true,
      width: 380,
      minHeight: 230,
      maxHeight: 230,
      events: [
        // Keyboard → Host (outgoing)
        Event(KeyboardKeyPressed),
        // Host → Keyboard (incoming)
        Event(SnapStateEvent),
      ],
    ),
  ],
)
class PaletteSetup {}
