import 'package:test/test.dart';

import 'package:floating_palette_generator/src/utils.dart';

void main() {
  // ══════════════════════════════════════════════════════════════════════════
  // toSnakeCase
  // ══════════════════════════════════════════════════════════════════════════

  group('toSnakeCase', () {
    test('converts PascalCase', () {
      expect(toSnakeCase('FilterChanged'), 'filter_changed');
    });

    test('strips Event suffix', () {
      expect(toSnakeCase('SlashTriggerEvent'), 'slash_trigger');
    });

    test('handles consecutive uppercase (acronyms)', () {
      expect(toSnakeCase('ABC'), 'a_b_c');
    });

    test('handles mixed case with acronyms', () {
      expect(toSnakeCase('MyHTTPHandler'), 'my_h_t_t_p_handler');
    });

    test('handles single character', () {
      expect(toSnakeCase('A'), 'a');
    });

    test('handles already lowercase', () {
      expect(toSnakeCase('simple'), 'simple');
    });

    test('handles single word PascalCase', () {
      expect(toSnakeCase('Filter'), 'filter');
    });

    test('strips Event suffix but not partial match', () {
      expect(toSnakeCase('EventBus'), 'event_bus');
      // 'Event' alone becomes empty string
      expect(toSnakeCase('Event'), '');
    });

    test('handles camelCase input', () {
      expect(toSnakeCase('filterChanged'), 'filter_changed');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // toCamelCase
  // ══════════════════════════════════════════════════════════════════════════

  group('toCamelCase', () {
    test('converts kebab-case', () {
      expect(toCamelCase('command-palette'), 'commandPalette');
    });

    test('converts snake_case', () {
      expect(toCamelCase('snake_case'), 'snakeCase');
    });

    test('handles simple word', () {
      expect(toCamelCase('menu'), 'menu');
    });

    test('handles multiple segments', () {
      expect(toCamelCase('my-long-palette-name'), 'myLongPaletteName');
    });

    test('handles empty parts from consecutive separators', () {
      expect(toCamelCase('a--b'), 'aB');
    });

    test('preserves case of first segment', () {
      expect(toCamelCase('MyWidget'), 'MyWidget');
    });
  });
}
