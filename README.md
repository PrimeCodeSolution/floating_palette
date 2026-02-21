# floating_palette

Native floating windows for Flutter desktop apps. Build Notion-style menus, Spotlight-style search, tooltips, and more — each running in its own native window.

## Packages

| Package | Description |
|---------|-------------|
| [floating_palette](floating_palette/) | Main plugin — runtime, native bridge, controllers |
| [floating_palette_annotations](floating_palette_annotations/) | Annotations for code generation (`@FloatingPaletteApp`, `@Palette`) |
| [floating_palette_generator](floating_palette_generator/) | `build_runner` code generator |

## Getting Started

Add all three packages to your app:

```yaml
dependencies:
  floating_palette: ^0.1.0
  floating_palette_annotations: ^0.1.0

dev_dependencies:
  floating_palette_generator: ^0.1.0
  build_runner: ^2.4.0
```

See the [main package README](floating_palette/README.md) for full usage instructions.

## License

MIT — see [LICENSE](LICENSE).
