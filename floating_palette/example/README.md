# floating_palette example

Demonstrates the floating_palette plugin with several palette types:

- **Demo** — playground palette for testing basic functionality
- **Notion-style editor** — rich text editor with slash menu and style menu palettes
- **Spotlight search** — command-palette style search with Liquid Glass
- **Custom Shape Glass** — Liquid Glass rendering with custom clip paths
- **Chat Bubble** — resizable AI chat palette (Ollama-powered)
- **Virtual Keyboard** — on-screen keyboard that sends key events to the editor

## Running the example

```bash
cd floating_palette/example

# Generate the Palettes class
dart run build_runner build

# Run the app
flutter run -d macos
```

## Code generation

The example uses `@FloatingPaletteApp` in `lib/palette_setup.dart` to declare all palettes. Running `build_runner` generates `palette_setup.g.dart` with a type-safe `Palettes` class and controllers.
