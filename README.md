# floating_palette

Native floating windows for Flutter desktop apps. Build Notion-style menus, Spotlight-style search, tooltips, and more — each running in its own native window.

<!-- TODO: add hero gif showing palette examples -->

## Packages

| Package | Version | Description |
|---------|---------|-------------|
| [floating_palette](floating_palette/) | [![pub](https://img.shields.io/pub/v/floating_palette.svg)](https://pub.dev/packages/floating_palette) | Main plugin — runtime, native bridge, controllers |
| [floating_palette_annotations](floating_palette_annotations/) | [![pub](https://img.shields.io/pub/v/floating_palette_annotations.svg)](https://pub.dev/packages/floating_palette_annotations) | Annotations for code generation |
| [floating_palette_generator](floating_palette_generator/) | [![pub](https://img.shields.io/pub/v/floating_palette_generator.svg)](https://pub.dev/packages/floating_palette_generator) | `build_runner` code generator |

## Quick Start

**1. Install**

```yaml
dependencies:
  floating_palette: ^0.1.0
  floating_palette_annotations: ^0.1.0

dev_dependencies:
  floating_palette_generator: ^0.1.0
  build_runner: ^2.4.0
```

**2. Define**

```dart
@FloatingPaletteApp(palettes: [
  PaletteAnnotation(
    id: 'command-menu',
    widget: CommandMenu,
    preset: Preset.menu,
  ),
])
class PaletteSetup {}
```

**3. Show**

```dart
await Palettes.init();
Palettes.commandMenu.show(position: PalettePosition.nearCursor());
```

See the [main package README](floating_palette/README.md) for full documentation.

## Examples

The [example app](floating_palette/example/) demonstrates:

- Notion-style editor with slash menu and style toolbar
- Spotlight-style search with glass effects
- Custom shape glass palette
- AI chat bubble (resizable, snappable)
- Analog clock (transparent, keep-alive)
- Virtual keyboard with snap-to-palette

<!-- TODO: add example gifs/screenshots -->

## Platform Support

| Platform | Status |
|----------|--------|
| macOS | Full support |
| Windows | Planned |
| Linux | Not yet supported |

## License

MIT — see [LICENSE](LICENSE).
