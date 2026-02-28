import '../bridge/service_client.dart';
import 'text_selection.dart';

/// Internal service client for the native TextSelectionService.
///
/// Not intended for direct public use — see [TextSelectionMonitor] instead.
class TextSelectionClient extends ServiceClient {
  TextSelectionClient(super.bridge);

  @override
  String get serviceName => 'textSelection';

  /// Check whether Accessibility permission has been granted.
  Future<bool> checkPermission() async {
    final result = await sendForMap('checkPermission');
    return result?['granted'] as bool? ?? false;
  }

  /// Prompt the user to grant Accessibility permission (opens System Settings).
  Future<void> requestPermission() async {
    await send<void>('requestPermission');
  }

  /// One-shot query of the current text selection.
  ///
  /// Returns null if nothing is selected or the focused element
  /// doesn't support text selection.
  Future<SelectedText?> getSelection() async {
    final result = await sendForMap('getSelection');
    if (result == null) return null;
    return SelectedText.fromMap(result);
  }

  /// Start monitoring text selection changes system-wide.
  Future<void> startMonitoring() async {
    await send<void>('startMonitoring');
  }

  /// Stop monitoring text selection changes.
  Future<void> stopMonitoring() async {
    await send<void>('stopMonitoring');
  }

  // ════════════════════════════════════════════════════════════════════════
  // Events
  // ════════════════════════════════════════════════════════════════════════

  /// Called when text is selected (or selection changes) in any app.
  void onSelectionChanged(void Function(SelectedText selection) callback) {
    onEvent('selectionChanged', (event) {
      callback(SelectedText.fromMap(event.data));
    });
  }

  /// Called when the text selection is cleared.
  void onSelectionCleared(void Function() callback) {
    onEvent('selectionCleared', (event) {
      callback();
    });
  }
}
