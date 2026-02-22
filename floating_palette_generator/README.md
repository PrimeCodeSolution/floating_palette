# floating_palette_generator

[![pub package](https://img.shields.io/pub/v/floating_palette_generator.svg)](https://pub.dev/packages/floating_palette_generator)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Code generator for [floating_palette](https://pub.dev/packages/floating_palette). Processes `@FloatingPaletteApp` annotations to generate type-safe palette controllers and entry points.

This package is a `build_runner` generator — add it as a dev dependency.

## Installation

```yaml
# pubspec.yaml
dependencies:
  floating_palette: ^0.1.0
  floating_palette_annotations: ^0.1.0

dev_dependencies:
  floating_palette_generator: ^0.1.0
  build_runner: ^2.4.0
```

## What It Generates

From a single `@FloatingPaletteApp` annotation, the generator produces:

### `Palettes` class

Type-safe controller access with lazy initialization:

```dart
// Generated from PaletteAnnotation(id: 'command-menu', ...)
Palettes.commandMenu.show();   // PaletteController<void>
Palettes.commandMenu.hide();
Palettes.commandMenu.onEvent<CommandSelected>((e) => ...);

// Batch operations
await Palettes.hideAll();
await Palettes.init();
```

### `paletteMain()` entry point

A `@pragma('vm:entry-point')` function that native code calls to launch palette Flutter engines. Includes the builder map that maps palette IDs to widget constructors.

### Event registration

`_registerAllEvents()` — auto-registers all event types declared in the annotation so `onEvent<T>()` works without manual setup.

## Usage

### Build (one-time)

```bash
dart run build_runner build
```

### Watch (continuous)

```bash
dart run build_runner watch
```

### Clean and rebuild

```bash
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

## See Also

- [floating_palette](https://pub.dev/packages/floating_palette) — Main package with full documentation
- [floating_palette_annotations](https://pub.dev/packages/floating_palette_annotations) — Annotation definitions
