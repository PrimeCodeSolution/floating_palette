/// Convert class name to snake_case, stripping 'Event' suffix.
///
/// Examples:
/// - FilterChanged → filter_changed
/// - SlashTriggerEvent → slash_trigger
/// - MyHTTPHandler → my_http_handler
String toSnakeCase(String name) {
  // Strip 'Event' suffix if present
  if (name.endsWith('Event')) {
    name = name.substring(0, name.length - 5);
  }

  // Convert PascalCase/camelCase to snake_case
  final buffer = StringBuffer();
  for (var i = 0; i < name.length; i++) {
    final char = name[i];
    if (char.toUpperCase() == char && char.toLowerCase() != char) {
      // It's an uppercase letter
      if (buffer.isNotEmpty) {
        buffer.write('_');
      }
      buffer.write(char.toLowerCase());
    } else {
      buffer.write(char);
    }
  }
  return buffer.toString();
}

/// Convert kebab-case or snake_case ID to camelCase.
///
/// Examples:
/// - command-palette → commandPalette
/// - snake_case → snakeCase
String toCamelCase(String id) {
  final parts = id.split(RegExp(r'[-_]'));
  if (parts.isEmpty) return id;

  return parts.first +
      parts.skip(1).map((p) => p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1)).join();
}
