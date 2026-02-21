# floating_palette_generator

Code generator for [floating_palette](https://pub.dev/packages/floating_palette). Processes `@FloatingPaletteApp` annotations to generate a type-safe `Palettes` class with controllers for each palette.

This package is a `build_runner` generator — add it as a dev dependency.

## Setup

```yaml
# pubspec.yaml
dependencies:
  floating_palette: ^0.0.1
  floating_palette_annotations: ^0.1.0

dev_dependencies:
  floating_palette_generator: ^0.1.0
  build_runner: ^2.4.0
```

## Usage

```bash
dart run build_runner build
```

See the [main package](https://pub.dev/packages/floating_palette) for full documentation.
