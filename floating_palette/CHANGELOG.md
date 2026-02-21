## 0.1.0

* Native floating palette windows for macOS using NSPanel
* Window management: create, show, hide, destroy with flicker-free reveal
* Liquid Glass effects (macOS 26+) with shared-memory path buffer and display-link rendering
* NSVisualEffectView fallback blur for older macOS versions
* Snap system: edge snapping, magnetic docking between palettes
* Transform support: resize, reposition, and animate palette frames
* Positioning: anchor-based placement relative to screen or parent window
* Focus policies: activating and non-activating panel modes
* Keyboard and mouse input forwarding to palette Flutter engines
* Native drag support via NSPanel performDrag
* Appearance control: transparency, shadow, corner radius, style mask
* Host-to-palette and palette-to-host messaging via method channels
* FFI interface for high-frequency operations (resize, glass path updates)
* Code generation: `@Palette` annotation produces type-safe `Palettes` class with controllers
