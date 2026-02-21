/// A command sent to the native layer.
class NativeCommand {
  /// The service to handle this command.
  final String service;

  /// The command name.
  final String command;

  /// The window ID this command targets (null for global commands).
  final String? windowId;

  /// Command parameters.
  final Map<String, dynamic> params;

  const NativeCommand({
    required this.service,
    required this.command,
    this.windowId,
    this.params = const {},
  });

  Map<String, dynamic> toMap() => {
        'service': service,
        'command': command,
        if (windowId != null) 'windowId': windowId,
        'params': params,
      };
}
