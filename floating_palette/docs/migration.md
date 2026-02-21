# Migration Guide

This guide helps you migrate from earlier versions of floating_palette to the current API.

## Overview of Changes

The refactored API focuses on:
- **Simpler setup**: One annotation, one init call
- **Dependency injection**: No more singletons
- **Presets**: Quick configuration for common patterns
- **Better testing**: Mock bridge and test utilities

## Quick Reference

| Old API | New API |
|---------|---------|
| `NativeBridge.instance` | `PaletteHost.instance.bridge` |
| `InputManager.instance` | `PaletteHost.instance.inputManager` |
| `PaletteWindow.currentId` | `Palette.of(context).id` |
| `PaletteMessenger.emit(...)` | `Palette.of(context).emit(...)` |
| `PaletteSelf.hide()` | `Palette.of(context).hide()` |
| `PaletteController(id: ...)` | `PaletteHost.instance.palette(...)` |
| `ServiceClient()` | `ServiceClient(bridge)` |

## Step-by-Step Migration

### 1. Update Palette Setup

**Before:**
```dart
@FloatingPaletteApp(palettes: [
  PaletteAnnotation(
    id: 'menu',
    widget: MyMenu,
    width: 280,
    hideOnClickOutside: true,
    hideOnEscape: true,
    focus: TakesFocus.yes,
  ),
])
class PaletteSetup {}
```

**After:**
```dart
@FloatingPaletteApp(palettes: [
  PaletteAnnotation(
    id: 'menu',
    widget: MyMenu,
    preset: Preset.menu,  // Use preset for common defaults
    width: 280,           // Override specific values
    events: [
      Event(ItemSelected), // -> menu.item_selected
    ],
  ),
])
class PaletteSetup {}
```

### 2. Update Initialization

**Before:**
```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Palettes.init();  // Synchronous, no await
  runApp(const MyApp());
}
```

**After:**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Palettes.init();  // Now async, await required
  runApp(const MyApp());
}
```

### 3. Update Palette Widgets

**Before:**
```dart
class MyMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final windowId = PaletteWindow.currentId;

    return GestureDetector(
      onTap: () {
        PaletteMessenger.emit(ItemSelected('foo'));
        PaletteSelf.hide();
      },
      child: Text('Tap me'),
    );
  }
}
```

**After:**
```dart
class MyMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final windowId = palette.id;

    return GestureDetector(
      onTap: () {
        palette.emit(ItemSelected('foo'));
        palette.hide();
      },
      child: Text('Tap me'),
    );
  }
}
```

### 4. Update Event Classes

**Before:**
```dart
class ItemSelected extends PaletteEvent {
  final String itemId;
  const ItemSelected(this.itemId);

  @override
  Map<String, dynamic> toMap() => {'itemId': itemId};

  static ItemSelected fromMap(Map<String, dynamic> m) =>
      ItemSelected(m['itemId'] as String);
}
```

**After:**
```dart
class ItemSelected extends PaletteEvent {
  // Event IDs are auto-generated from the palette ID and class name.
  // Example: menu + ItemSelected -> menu.item_selected
  static const id = 'menu.item_selected';

  @override
  String get eventId => id;

  final String itemId;
  const ItemSelected(this.itemId);

  @override
  Map<String, dynamic> toMap() => {'itemId': itemId};

  static ItemSelected fromMap(Map<String, dynamic> m) =>
      ItemSelected(m['itemId'] as String);
}
```

The `eventId` getter provides a stable identifier that survives code obfuscation.
Event registration is now automatic based on the palette's `events:` list.
You no longer call `PaletteEvent.register(...)` manually.

### 5. Update Service Client Usage

**Before:**
```dart
class MyService {
  final _focusClient = FocusClient();  // No argument

  Future<void> focusMain() async {
    await _focusClient.focusMainWindow();
  }
}
```

**After:**
```dart
class MyService {
  late final _focusClient = FocusClient(PaletteHost.instance.bridge);

  Future<void> focusMain() async {
    await _focusClient.focusMainWindow();
  }
}
```

Or use the generated Palettes helper:
```dart
await Palettes.focusMainWindow();
```

### 6. Update Direct Bridge Usage

**Before:**
```dart
final bridge = NativeBridge.instance;
await bridge.send(NativeCommand(...));
```

**After:**
```dart
final bridge = PaletteHost.instance.bridge;
await bridge.send(NativeCommand(...));
```

### 8. Update Input Manager Usage

**Before:**
```dart
InputManager.instance.onDismissRequested((id) {
  // handle dismiss
});
```

**After:**
```dart
PaletteHost.instance.inputManager.onDismissRequested((id) {
  // handle dismiss
});
```

Or this is handled automatically if you use `Palettes.init()`.

### 9. Update Tests

**Before:**
```dart
void main() {
  setUp(() {
    NativeBridge.reset();  // Reset singleton
  });

  test('test', () {
    final client = MessageClient();  // No args
    // ...
  });
}
```

**After:**
```dart
import 'package:floating_palette/src/testing/testing.dart';

void main() {
  late PaletteTestHost testHost;

  setUp(() async {
    testHost = await PaletteTestHost.create();
  });

  tearDown(() async {
    await testHost.dispose();
  });

  test('test', () async {
    final controller = testHost.createController('test');
    await controller.show();
    testHost.verifyCommand('visibility', 'show');
  });
}
```

## Removed APIs

These APIs have been removed and should be replaced:

| Removed | Replacement |
|---------|-------------|
| `NativeBridge.instance` | `PaletteHost.instance.bridge` |
| `NativeBridge.reset()` | Use `PaletteTestHost` for testing |
| `InputManager.instance` | `PaletteHost.instance.inputManager` |
| `PaletteWindow` | `Palette.of(context)` |
| `PaletteMessenger` | `Palette.of(context)` |
| `PaletteSelf` | `Palette.of(context)` |
| `GlassEffectService` | `AppearanceClient` or controller methods |

## New Features

### Presets

Use presets for quick configuration:

```dart
PaletteAnnotation(
  id: 'menu',
  widget: MyMenu,
  preset: Preset.menu,  // menu, tooltip, modal, spotlight, persistent
)
```

### Capability Checking

Check platform support before using features:

```dart
final caps = PaletteHost.instance.capabilities;
if (caps.blur) {
  controller.setBlur(enabled: true);
}
```

### Hot Restart Recovery

State automatically syncs after hot restart:

```dart
// Happens automatically in Palettes.init()
// No manual handling needed
```

### Test Utilities

New testing infrastructure:

```dart
final testHost = await PaletteTestHost.create();
final controller = testHost.createController('test');
await controller.show();
testHost.verifyCommand('visibility', 'show');
```

## Common Issues

### "PaletteHost not initialized"

Make sure you call `await Palettes.init()` before using any palette functionality:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Palettes.init();  // Don't forget await!
  runApp(const MyApp());
}
```

### "Missing 'eventId' getter"

Add the `eventId` getter to your event classes:

```dart
class MyEvent extends PaletteEvent {
  @override
  // Use the auto-generated ID format:
  // "${paletteId}.${snake_case(className)}"
  String get eventId => 'my_palette.my_event';
  // ...
}
```

### "Cannot find type 'Palette'"

Import from the main package:

```dart
import 'package:floating_palette/floating_palette.dart';
```

### "ServiceClient requires bridge argument"

Pass the bridge from PaletteHost:

```dart
// Before
final client = FocusClient();

// After
final client = FocusClient(PaletteHost.instance.bridge);
```

### Generated Code Errors

Regenerate after updating:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Need Help?

- Check the [README](../README.md) for basic usage
- See [Advanced Guide](advanced.md) for power user features
- Report issues at https://github.com/anthropics/claude-code/issues
