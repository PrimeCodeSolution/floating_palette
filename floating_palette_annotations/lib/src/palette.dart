import 'behavior_enums.dart';
import 'preset.dart';

/// Registers an event type for a palette.
///
/// Event IDs are auto-generated as `${eventNamespace}.${snake_case(className)}`.
/// The namespace defaults to the palette ID, or can be overridden with [PaletteAnnotation.eventNamespace].
/// The 'Event' suffix is stripped if present.
///
/// ```dart
/// PaletteAnnotation(
///   id: 'editor',
///   widget: EditorPalette,
///   events: [
///     Event(FilterChanged),   // → editor.filter_changed
///     Event(SlashTrigger),    // → editor.slash_trigger
///   ],
/// )
/// ```
class Event {
  /// The event class type.
  ///
  /// Must extend `PaletteEvent` (runtime class) and have a static `fromMap` factory.
  final Type type;

  const Event(this.type);
}

/// Definition of a single palette for code generation.
///
/// Used in [@FloatingPaletteApp] to define palettes that will be generated.
///
/// ```dart
/// @FloatingPaletteApp(palettes: [
///   PaletteAnnotation(
///     id: 'command-palette',
///     widget: CommandPalette,
///     events: [Event(QueryChanged)],
///   ),
///   PaletteAnnotation(id: 'slash-menu', widget: SlashMenu, width: 500),
/// ])
/// class PaletteSetup {}
/// ```
class PaletteAnnotation {
  /// Unique identifier for this palette.
  final String id;

  /// The widget class to render.
  final Type widget;

  /// Optional args class for type-safe data passing.
  final Type? args;

  /// Events that this palette can send/receive.
  ///
  /// Event IDs are auto-generated as `${eventNamespace}.${snake_case(className)}`.
  final List<Event> events;

  /// Namespace for event IDs. Defaults to [id].
  ///
  /// Use this to share events across palettes with stable IDs.
  /// Event IDs become `${eventNamespace}.${snake_case(className)}`.
  ///
  /// ```dart
  /// PaletteAnnotation(
  ///   id: 'editor',
  ///   widget: EditorPalette,
  ///   eventNamespace: 'notion',  // Override namespace
  ///   events: [Event(FilterChanged)],  // → notion.filter_changed
  /// ),
  /// PaletteAnnotation(
  ///   id: 'slash-menu',
  ///   widget: SlashMenuPalette,
  ///   eventNamespace: 'notion',  // Same namespace
  ///   events: [Event(FilterChanged)],  // → notion.filter_changed (shared)
  /// ),
  /// ```
  ///
  /// **Note:** If you leave this unset (defaults to [id]), renaming a palette
  /// will change its event IDs. Set an explicit namespace for ID stability.
  final String? eventNamespace;

  /// Optional preset for sensible defaults.
  ///
  /// When set, provides default values for size, behavior, etc.
  /// Individual fields override preset defaults.
  ///
  /// ```dart
  /// PaletteAnnotation(
  ///   id: 'menu',
  ///   widget: MyMenu,
  ///   preset: Preset.menu,  // Use menu defaults
  ///   width: 320,           // Override width
  /// )
  /// ```
  final Preset? preset;

  // ═══════════════════════════════════════════════════════════════════════════
  // Size Config
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fixed width of the palette. Defaults to 400.
  final double? width;

  /// Minimum height (content can grow up to [maxHeight]). Defaults to 100.
  final double? minHeight;

  /// Maximum height before scrolling. Defaults to 600.
  final double? maxHeight;

  /// Initial width when showing a resizable palette (defaults to [width]).
  final double? initialWidth;

  /// Initial height when showing a resizable palette (defaults to [minHeight]).
  final double? initialHeight;

  /// Whether the palette can be resized by the user. Defaults to false.
  final bool? resizable;

  /// Allow macOS window snapping when resizable. Defaults to false.
  final bool? allowSnap;

  // ═══════════════════════════════════════════════════════════════════════════
  // Behavior Config (simplified for code generation)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Hide when user clicks outside the palette.
  final bool? hideOnClickOutside;

  /// Hide when user presses Escape.
  final bool? hideOnEscape;

  /// Hide when palette loses focus.
  final bool? hideOnFocusLost;

  /// Whether the palette can be dragged.
  final bool? draggable;

  /// Keep the palette rendering when it loses focus.
  ///
  /// Use for always-on palettes (clocks, status monitors, ambient animations).
  /// Defaults to false.
  final bool? keepAlive;

  /// Whether to take keyboard focus when shown.
  ///
  /// - [TakesFocus.yes] = take focus when shown (default)
  /// - [TakesFocus.no] = don't take focus (for companions/tooltips)
  final TakesFocus? focus;

  /// What happens to focus when this palette is hidden.
  ///
  /// - [OnHideFocus.none] = don't change focus
  /// - [OnHideFocus.mainWindow] = activate main app window (default)
  /// - [OnHideFocus.previousApp] = hide app, return to previous app (spotlight-style)
  final OnHideFocus? onHideFocus;

  /// Pin palette above all windows when shown.
  ///
  /// When true, the palette is automatically pinned at [PinLevel.aboveAll]
  /// every time it is shown, similar to Simulator's "Stay on Top" behavior.
  /// Users can still call `unpin()` manually to temporarily lower it.
  final bool? alwaysOnTop;

  /// Controls what counts as "clicking outside" the palette.
  ///
  /// - [ClickOutsideScope.nonPalette] = only non-palette clicks dismiss (default)
  /// - [ClickOutsideScope.anywhere] = any click outside this palette dismisses,
  ///   including clicks on sibling palettes
  final ClickOutsideScope? clickOutsideScope;

  const PaletteAnnotation({
    required this.id,
    required this.widget,
    this.args,
    this.events = const [],
    this.eventNamespace,
    this.preset,
    this.width,
    this.minHeight,
    this.maxHeight,
    this.initialWidth,
    this.initialHeight,
    this.resizable,
    this.allowSnap,
    this.hideOnClickOutside,
    this.hideOnEscape,
    this.hideOnFocusLost,
    this.draggable,
    this.keepAlive,
    this.focus,
    this.onHideFocus,
    this.alwaysOnTop,
    this.clickOutsideScope,
  });
}
