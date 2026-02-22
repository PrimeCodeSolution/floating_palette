# floating_palette_annotations

[![pub package](https://img.shields.io/pub/v/floating_palette_annotations.svg)](https://pub.dev/packages/floating_palette_annotations)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Pure Dart annotations for [floating_palette](https://pub.dev/packages/floating_palette) code generation. No Flutter dependency.

## Installation

```yaml
dependencies:
  floating_palette_annotations: ^0.1.0
```

## Annotations Reference

### @FloatingPaletteApp

Top-level annotation placed on a class to define your palette application.

```dart
@FloatingPaletteApp(
  defaults: PaletteDefaults(
    width: 400,
    hideOnClickOutside: true,
  ),
  contentWrapper: MyProviderWrapper, // Optional DI/state wrapper for all palettes
  palettes: [
    PaletteAnnotation(
      id: 'editor',
      widget: EditorPalette,
      events: [Event(FilterChanged)],
    ),
    PaletteAnnotation(id: 'emoji-picker', widget: EmojiPicker),
  ],
)
class PaletteSetup {}
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `palettes` | `List<PaletteAnnotation>` | **required** | List of palette definitions |
| `defaults` | `PaletteDefaults?` | `null` | Default config applied to all palettes |
| `contentWrapper` | `Type?` | `null` | Widget wrapper for DI/state management |

### PaletteAnnotation

Defines a single palette.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `id` | `String` | **required** | Unique identifier |
| `widget` | `Type` | **required** | Widget class to render |
| `args` | `Type?` | `null` | Optional typed args class |
| `events` | `List<Event>` | `[]` | Events this palette sends/receives |
| `eventNamespace` | `String?` | Same as `id` | Namespace for event IDs (for sharing) |
| `preset` | `Preset?` | `null` | Preset for sensible defaults |
| **Size** | | | |
| `width` | `double?` | `400` | Fixed width in pixels |
| `minHeight` | `double?` | `100` | Minimum height |
| `maxHeight` | `double?` | `600` | Maximum height before scrolling |
| `initialWidth` | `double?` | Same as `width` | Initial width for resizable palettes |
| `initialHeight` | `double?` | Same as `minHeight` | Initial height for resizable palettes |
| `resizable` | `bool?` | `false` | Allow user resize |
| `allowSnap` | `bool?` | `false` | Allow macOS window snapping |
| **Behavior** | | | |
| `hideOnClickOutside` | `bool?` | `true` | Hide when clicking outside |
| `hideOnEscape` | `bool?` | `true` | Hide on Escape key |
| `hideOnFocusLost` | `bool?` | `false` | Hide when losing focus |
| `draggable` | `bool?` | `false` | Allow dragging |
| `keepAlive` | `bool?` | `false` | Keep rendering when unfocused |
| `focus` | `TakesFocus?` | `TakesFocus.yes` | Keyboard focus behavior |
| `onHideFocus` | `OnHideFocus?` | `OnHideFocus.mainWindow` | Focus behavior on hide |
| `alwaysOnTop` | `bool?` | `false` | Pin above all windows when shown |

### Event

Registers an event type for a palette. Event IDs are auto-generated as `${eventNamespace}.${snake_case(className)}`.

```dart
PaletteAnnotation(
  id: 'editor',
  widget: EditorPalette,
  events: [
    Event(FilterChanged),   // → editor.filter_changed
    Event(SlashTrigger),    // → editor.slash_trigger
  ],
)
```

### Preset

Pre-configured palette types with sensible defaults. Individual fields override preset values.

| Value | Description | Key Defaults |
|-------|-------------|-------------|
| `Preset.menu` | Dropdown/context menu | Near cursor, hides on click/escape, takes focus, 280×400 |
| `Preset.tooltip` | Tooltip/hint popup | Near cursor, no focus, hides on click/escape/focus lost, 200×150 |
| `Preset.modal` | Dialog | Centered, hides on escape only, takes focus, 480×200 |
| `Preset.spotlight` | Command palette | Centered near top, returns to previous app on hide, 600×400 |
| `Preset.persistent` | Floating panel | No auto-hide, draggable, keeps alive, 300 wide |

### PaletteDefaults

Global defaults applied to all palettes in the `@FloatingPaletteApp`.

| Parameter | Type | Description |
|-----------|------|-------------|
| `width` | `double?` | Default width |
| `height` | `double?` | Default height |
| `hideOnClickOutside` | `bool?` | Default click-outside behavior |
| `hideOnEscape` | `bool?` | Default escape behavior |

### Behavior Enums

**TakesFocus** — Whether the palette takes keyboard focus when shown:

| Value | Description |
|-------|-------------|
| `TakesFocus.yes` | Take focus (default) |
| `TakesFocus.no` | Don't take focus (for companions/tooltips) |

**OnHideFocus** — What happens to focus when the palette is hidden:

| Value | Description |
|-------|-------------|
| `OnHideFocus.none` | Don't change focus |
| `OnHideFocus.mainWindow` | Activate main app window (default) |
| `OnHideFocus.previousApp` | Hide app, return to previous app (spotlight-style) |

## Example

```dart
import 'package:floating_palette_annotations/floating_palette_annotations.dart';

@FloatingPaletteApp(palettes: [
  PaletteAnnotation(
    id: 'spotlight',
    widget: SpotlightSearch,
    preset: Preset.spotlight,
    width: 640,
    minHeight: 60,
    maxHeight: 500,
    draggable: true,
  ),
  PaletteAnnotation(
    id: 'chat-bubble',
    widget: ChatBubble,
    width: 600,
    initialWidth: 600,
    initialHeight: 360,
    resizable: true,
    allowSnap: true,
    hideOnClickOutside: false,
    draggable: true,
    events: [Event(MessageSent)],
  ),
])
class PaletteSetup {}
```

## See Also

- [floating_palette](https://pub.dev/packages/floating_palette) — Main package with runtime, controllers, and native bridge
- [floating_palette_generator](https://pub.dev/packages/floating_palette_generator) — Code generator
