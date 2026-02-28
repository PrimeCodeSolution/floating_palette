import '../bridge/native_bridge.dart';
import 'text_selection.dart';
import 'text_selection_client.dart';

/// System-wide text selection monitor.
///
/// Detects text selection in **any** macOS application (browsers, editors,
/// terminal, etc.) using the Accessibility API. When the user selects text
/// anywhere on the OS, you receive the selected text and its screen position.
///
/// Requires Accessibility permission and **no App Sandbox**.
///
/// ```dart
/// final monitor = TextSelectionMonitor();
///
/// // Check / request permission
/// if (!await monitor.checkPermission()) {
///   await monitor.requestPermission();
/// }
///
/// // Start monitoring
/// await monitor.startMonitoring();
/// monitor.onSelectionChanged((selection) {
///   print('${selection.text} at ${selection.bounds}');
/// });
/// monitor.onSelectionCleared(() => print('cleared'));
///
/// // Later...
/// await monitor.stopMonitoring();
/// monitor.dispose();
/// ```
class TextSelectionMonitor {
  final NativeBridge _bridge;
  final bool _ownsBridge;
  late final TextSelectionClient _client;

  /// Create a standalone text selection monitor.
  ///
  /// Creates its own [NativeBridge] internally. If you already have a bridge
  /// (e.g. from [PaletteHost]), pass it via the [bridge] parameter to share
  /// the channel.
  TextSelectionMonitor({NativeBridge? bridge})
      : _bridge = bridge ?? NativeBridge(),
        _ownsBridge = bridge == null {
    _client = TextSelectionClient(_bridge);
  }

  /// Check whether Accessibility permission has been granted.
  Future<bool> checkPermission() => _client.checkPermission();

  /// Prompt the user to grant Accessibility permission.
  ///
  /// Opens System Settings → Privacy & Security → Accessibility.
  Future<void> requestPermission() => _client.requestPermission();

  /// One-shot query of the current text selection.
  ///
  /// Returns null if nothing is selected or the focused element
  /// doesn't support text selection attributes.
  Future<SelectedText?> getSelection() => _client.getSelection();

  /// Start monitoring text selection changes system-wide.
  ///
  /// Events will be delivered via [onSelectionChanged] and
  /// [onSelectionCleared] callbacks.
  Future<void> startMonitoring() => _client.startMonitoring();

  /// Stop monitoring text selection changes.
  Future<void> stopMonitoring() => _client.stopMonitoring();

  /// Register a callback for text selection changes.
  ///
  /// Fires when text is selected (or the selection changes) in any
  /// application. The [SelectedText] includes the text, screen bounds,
  /// and source application info.
  void onSelectionChanged(void Function(SelectedText selection) callback) {
    _client.onSelectionChanged(callback);
  }

  /// Register a callback for when text selection is cleared.
  void onSelectionCleared(void Function() callback) {
    _client.onSelectionCleared(callback);
  }

  /// Dispose resources.
  ///
  /// Stops monitoring if active and cleans up the native bridge
  /// (if it was created internally).
  void dispose() {
    _client.dispose();
    if (_ownsBridge) {
      _bridge.dispose();
    }
  }
}
