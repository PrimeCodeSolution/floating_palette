/// Core infrastructure for floating palettes.
library;

export 'capabilities.dart';
export 'capability_guard.dart';
export 'palette_host.dart';
export 'protocol.dart';
// PaletteRegistry is not exported to avoid conflict with runner/palette_runner.dart
// It's available as PaletteHost.instance.registry
