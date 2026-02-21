# floating_palette_annotations

Annotations for the [floating_palette](https://pub.dev/packages/floating_palette) code generator.

This is a pure Dart package with no Flutter dependency.

## Usage

```dart
import 'package:floating_palette_annotations/floating_palette_annotations.dart';

@FloatingPaletteApp(palettes: [
  PaletteAnnotation(
    id: 'command-menu',
    widget: CommandMenu,
    preset: Preset.menu,
    width: 320,
  ),
])
class PaletteSetup {}
```

Then run `dart run build_runner build` with `floating_palette_generator` in your `dev_dependencies`.

See the [main package](https://pub.dev/packages/floating_palette) for full documentation.
