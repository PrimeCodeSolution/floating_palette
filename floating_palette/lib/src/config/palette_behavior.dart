import '../input/click_outside_behavior.dart';
import '../input/palette_group.dart';

/// How focus is handled when showing a palette.
enum FocusPolicy {
  /// Steal focus from the current app.
  steal,

  /// Request focus politely (may not always work).
  request,

  /// Don't change focus.
  none,
}

/// What happens to focus when a palette is hidden.
enum FocusRestoreMode {
  /// Don't change focus when hiding.
  none,

  /// Activate the main app window (default for in-app palettes).
  mainWindow,

  /// Hide the app entirely, returning to the previously active app.
  /// Use for spotlight-style palettes that overlay everything.
  previousApp,
}

/// Behavior configuration for a palette.
class PaletteBehavior {
  /// Hide when user clicks outside the palette.
  final bool hideOnClickOutside;

  /// Hide when user presses Escape.
  final bool hideOnEscape;

  /// Hide when palette loses focus.
  final bool hideOnFocusLost;

  /// How focus is handled when showing.
  final FocusPolicy focusPolicy;

  /// Whether the palette can be dragged.
  final bool draggable;

  /// Keep the palette rendering when it loses focus.
  ///
  /// When true, the palette's Flutter engine continues rendering after focus
  /// loss. Use for always-on palettes (clocks, status monitors, ambient animations).
  final bool keepAlive;

  /// What happens to focus when this palette is hidden.
  final FocusRestoreMode onHideFocus;

  /// Pin palette above all windows when shown.
  ///
  /// When true, the palette is automatically pinned at PinLevel.aboveAll
  /// every time it is shown, like Simulator's "Stay on Top".
  final bool alwaysOnTop;

  /// Optional exclusive group membership.
  ///
  /// Palettes in the same group are mutually exclusive - showing one
  /// automatically hides the others.
  ///
  /// See [PaletteGroup] for built-in groups like [PaletteGroup.menu].
  final PaletteGroup? group;

  const PaletteBehavior({
    this.hideOnClickOutside = true,
    this.hideOnEscape = true,
    this.hideOnFocusLost = false,
    this.focusPolicy = FocusPolicy.steal,
    this.draggable = false,
    this.keepAlive = false,
    this.alwaysOnTop = false,
    this.onHideFocus = FocusRestoreMode.mainWindow,
    this.group,
  });

  /// Modal-like behavior: must explicitly dismiss.
  const PaletteBehavior.modal()
      : hideOnClickOutside = false,
        hideOnEscape = true,
        hideOnFocusLost = false,
        focusPolicy = FocusPolicy.steal,
        draggable = false,
        keepAlive = false,
        alwaysOnTop = false,
        onHideFocus = FocusRestoreMode.mainWindow,
        group = null;

  /// Tooltip-like behavior: dismisses easily.
  const PaletteBehavior.tooltip()
      : hideOnClickOutside = true,
        hideOnEscape = true,
        hideOnFocusLost = true,
        focusPolicy = FocusPolicy.none,
        draggable = false,
        keepAlive = false,
        alwaysOnTop = false,
        onHideFocus = FocusRestoreMode.none,
        group = null;

  /// Persistent panel: stays until explicitly hidden.
  const PaletteBehavior.persistent()
      : hideOnClickOutside = false,
        hideOnEscape = false,
        hideOnFocusLost = false,
        focusPolicy = FocusPolicy.request,
        draggable = true,
        keepAlive = true,
        alwaysOnTop = false,
        onHideFocus = FocusRestoreMode.none,
        group = null;

  /// Spotlight-style: hides app when dismissed (returns to previous app).
  const PaletteBehavior.spotlight()
      : hideOnClickOutside = true,
        hideOnEscape = true,
        hideOnFocusLost = false,
        focusPolicy = FocusPolicy.steal,
        draggable = false,
        keepAlive = false,
        alwaysOnTop = false,
        onHideFocus = FocusRestoreMode.previousApp,
        group = null;

  /// Menu behavior: dismisses on click outside, part of exclusive menu group.
  ///
  /// Only one menu can be visible at a time - showing a new menu
  /// automatically hides any existing menu.
  const PaletteBehavior.menu()
      : hideOnClickOutside = true,
        hideOnEscape = true,
        hideOnFocusLost = false,
        focusPolicy = FocusPolicy.steal,
        draggable = false,
        keepAlive = false,
        alwaysOnTop = false,
        onHideFocus = FocusRestoreMode.mainWindow,
        group = PaletteGroup.menu;

  PaletteBehavior copyWith({
    bool? hideOnClickOutside,
    bool? hideOnEscape,
    bool? hideOnFocusLost,
    FocusPolicy? focusPolicy,
    bool? draggable,
    bool? keepAlive,
    bool? alwaysOnTop,
    FocusRestoreMode? onHideFocus,
    PaletteGroup? group,
  }) {
    return PaletteBehavior(
      hideOnClickOutside: hideOnClickOutside ?? this.hideOnClickOutside,
      hideOnEscape: hideOnEscape ?? this.hideOnEscape,
      hideOnFocusLost: hideOnFocusLost ?? this.hideOnFocusLost,
      focusPolicy: focusPolicy ?? this.focusPolicy,
      draggable: draggable ?? this.draggable,
      keepAlive: keepAlive ?? this.keepAlive,
      alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
      onHideFocus: onHideFocus ?? this.onHideFocus,
      group: group ?? this.group,
    );
  }

  Map<String, dynamic> toMap() => {
        'hideOnClickOutside': hideOnClickOutside,
        'hideOnEscape': hideOnEscape,
        'hideOnFocusLost': hideOnFocusLost,
        'focusPolicy': focusPolicy.name,
        'draggable': draggable,
        'keepAlive': keepAlive,
        'alwaysOnTop': alwaysOnTop,
        'onHideFocus': onHideFocus.name,
        'group': group?.name,
      };

  /// Whether to take keyboard focus based on [focusPolicy].
  bool get shouldFocus => focusPolicy != FocusPolicy.none;

  /// Convert [hideOnClickOutside] to [ClickOutsideBehavior].
  ClickOutsideBehavior get clickOutsideBehavior =>
      hideOnClickOutside ? ClickOutsideBehavior.dismiss : ClickOutsideBehavior.passthrough;
}
