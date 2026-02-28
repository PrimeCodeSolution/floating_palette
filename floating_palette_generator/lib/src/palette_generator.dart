import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:floating_palette_annotations/floating_palette_annotations.dart';

import 'utils.dart';

/// Generates entry points and controllers from @FloatingPaletteApp annotation.
class PaletteGenerator extends GeneratorForAnnotation<FloatingPaletteApp> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@FloatingPaletteApp can only be applied to classes.',
        element: element,
      );
    }

    final palettes = _parsePalettes(annotation);
    final events = _collectAllEvents(palettes);
    final contentWrapper = annotation.peek('contentWrapper')?.typeValue;

    final buffer = StringBuffer();

    _generateEventRegistration(buffer, events);
    _generateEntryPoint(buffer, events);
    _generateBuildersMap(buffer, palettes, contentWrapper);
    _generatePalettesClass(buffer, palettes, events);

    return buffer.toString();
  }

  void _generateEventRegistration(StringBuffer buffer, List<_EventInfo> events) {
    if (events.isEmpty) return;

    buffer.writeln('// ════════════════════════════════════════════════════════════════');
    buffer.writeln('// EVENT REGISTRATION (called automatically by Palettes.init)');
    buffer.writeln('// ════════════════════════════════════════════════════════════════');
    buffer.writeln();
    buffer.writeln('void _registerAllEvents() {');
    for (final event in events) {
      buffer.writeln("  PaletteEvent.register<${event.typeName}>('${event.eventId}', ${event.typeName}.fromMap);");
    }
    buffer.writeln('}');
    buffer.writeln();
  }

  void _generateEntryPoint(StringBuffer buffer, List<_EventInfo> events) {
    buffer.writeln('// ════════════════════════════════════════════════════════════════');
    buffer.writeln('// PALETTE ENTRY POINT (called by native for all palettes)');
    buffer.writeln('// ════════════════════════════════════════════════════════════════');
    buffer.writeln();
    buffer.writeln("@pragma('vm:entry-point')");
    if (events.isNotEmpty) {
      buffer.writeln('void paletteMain() => initPaletteEngine(_paletteBuilders, registerEvents: _registerAllEvents);');
    } else {
      buffer.writeln('void paletteMain() => initPaletteEngine(_paletteBuilders);');
    }
    buffer.writeln();
  }

  void _generateBuildersMap(StringBuffer buffer, List<_PaletteInfo> palettes, DartType? contentWrapper) {
    buffer.writeln('final _paletteBuilders = <String, Widget Function()>{');
    for (final palette in palettes) {
      final widgetName = palette.widgetName;
      if (contentWrapper != null) {
        buffer.writeln("  '${palette.id}': () => _wrapContent(const $widgetName()),");
      } else {
        buffer.writeln("  '${palette.id}': () => const $widgetName(),");
      }
    }
    buffer.writeln('};');
    buffer.writeln();

    if (contentWrapper != null) {
      final wrapperName = contentWrapper.getDisplayString();
      buffer.writeln('Widget _wrapContent(Widget child) => $wrapperName(child: child);');
      buffer.writeln();
    }
  }

  void _generatePalettesClass(StringBuffer buffer, List<_PaletteInfo> palettes, List<_EventInfo> events) {
    buffer.writeln('// ════════════════════════════════════════════════════════════════');
    buffer.writeln('// TYPE-SAFE CONTROLLERS (used in main app)');
    buffer.writeln('// ════════════════════════════════════════════════════════════════');
    buffer.writeln();
    buffer.writeln('abstract final class Palettes {');
    buffer.writeln('  // Controller cache');
    buffer.writeln('  static final _controllers = <String, PaletteController>{};');
    buffer.writeln();

    // Generate lazy getters for each palette
    for (final palette in palettes) {
      final fieldName = toCamelCase(palette.id);
      final argsType = palette.argsName ?? 'void';
      final configCode = palette.generateConfig();

      buffer.writeln('  static PaletteController<$argsType> get $fieldName =>');
      buffer.writeln("      _controllers.putIfAbsent('${palette.id}', () => PaletteHost.instance.palette<$argsType>(");
      buffer.writeln("        '${palette.id}',");
      if (configCode.isNotEmpty) {
        buffer.writeln(configCode);
      }
      buffer.writeln('      )) as PaletteController<$argsType>;');
      buffer.writeln();
    }

    // Generate _all getter
    final fieldNames = palettes.map((p) => toCamelCase(p.id)).toList();
    buffer.writeln('  // ════════════════════════════════════════════════════════════════');
    buffer.writeln('  // Batch Operations');
    buffer.writeln('  // ════════════════════════════════════════════════════════════════');
    buffer.writeln();
    buffer.writeln('  /// All registered palette controllers.');
    buffer.writeln('  static List<PaletteController> get all => [${fieldNames.join(', ')}];');
    buffer.writeln();
    buffer.writeln('  /// IDs of currently visible palettes.');
    buffer.writeln('  static List<String> get visibleIds => all.where((p) => p.isVisible).map((p) => p.id).toList();');
    buffer.writeln();
    buffer.writeln('  /// Whether any palette is currently visible.');
    buffer.writeln('  static bool get isAnyVisible => all.any((p) => p.isVisible);');
    buffer.writeln();
    buffer.writeln('  /// Saved visibility state for [softHide]/[restore].');
    buffer.writeln('  static Set<String> _savedVisibility = {};');
    buffer.writeln();
    buffer.writeln('  /// Hide all palettes.');
    buffer.writeln('  ///');
    buffer.writeln('  /// [except] - IDs of palettes to keep visible.');
    buffer.writeln('  static Future<void> hideAll({Set<String>? except, bool animate = true}) async {');
    buffer.writeln('    await Future.wait<void>([');
    buffer.writeln('      for (final p in all)');
    buffer.writeln("        if (p.isVisible && (except == null || !except.contains(p.id)))");
    buffer.writeln('          p.hide(animate: animate),');
    buffer.writeln('    ], eagerError: false);');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  /// Soft hide: save current visibility state and hide all palettes.');
    buffer.writeln('  ///');
    buffer.writeln('  /// Use [restore] to bring back the previously visible palettes.');
    buffer.writeln('  static Future<void> softHide({Set<String>? except, bool animate = true}) async {');
    buffer.writeln('    _savedVisibility = visibleIds.where((id) => except == null || !except.contains(id)).toSet();');
    buffer.writeln('    await hideAll(except: except, animate: animate);');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  /// Restore palettes that were visible before [softHide].');
    buffer.writeln('  static Future<void> restore({bool animate = true}) async {');
    buffer.writeln('    final toRestore = _savedVisibility;');
    buffer.writeln('    _savedVisibility = {};');
    buffer.writeln('    await Future.wait<void>([');
    buffer.writeln('      for (final p in all)');
    buffer.writeln('        if (toRestore.contains(p.id) && !p.isVisible)');
    buffer.writeln('          p.show(animate: animate),');
    buffer.writeln('    ], eagerError: false);');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  /// Whether there is saved state from [softHide].');
    buffer.writeln('  static bool get hasSavedState => _savedVisibility.isNotEmpty;');
    buffer.writeln();
    buffer.writeln('  // ════════════════════════════════════════════════════════════════');
    buffer.writeln('  // Initialization');
    buffer.writeln('  // ════════════════════════════════════════════════════════════════');
    buffer.writeln();
    buffer.writeln('  static bool _initialized = false;');
    buffer.writeln();
    buffer.writeln('  /// Initialize palettes with automatic event registration and dismiss handling.');
    buffer.writeln('  ///');
    buffer.writeln('  /// Call this once at app startup. Automatically sets up:');
    buffer.writeln('  /// - PaletteHost (bridge, input manager, capabilities)');
    if (events.isNotEmpty) {
      buffer.writeln('  /// - Event registration for all events in @FloatingPaletteApp');
    }
    buffer.writeln('  /// - Click-outside dismiss handling for palettes with hideOnClickOutside');
    buffer.writeln('  ///');
    buffer.writeln('  /// Example:');
    buffer.writeln('  /// ```dart');
    buffer.writeln('  /// void main() async {');
    buffer.writeln('  ///   WidgetsFlutterBinding.ensureInitialized();');
    buffer.writeln('  ///   await Palettes.init();');
    buffer.writeln('  ///   runApp(MyApp());');
    buffer.writeln('  /// }');
    buffer.writeln('  /// ```');
    buffer.writeln('  static Future<void> init() async {');
    buffer.writeln('    if (_initialized) return;');
    buffer.writeln('    _initialized = true;');
    buffer.writeln();
    buffer.writeln('    // Initialize PaletteHost (bridge, input manager, etc.)');
    buffer.writeln('    await PaletteHost.initialize();');
    buffer.writeln();
    if (events.isNotEmpty) {
      buffer.writeln('    // Register all events defined in @FloatingPaletteApp');
      buffer.writeln('    _registerAllEvents();');
      buffer.writeln();
    }
    buffer.writeln('    // Auto-hide palettes when clicked outside');
    buffer.writeln('    PaletteHost.instance.inputManager.onDismissRequested((paletteId) {');
    buffer.writeln('      final controller = all.cast<PaletteController>().firstWhere(');
    buffer.writeln('        (p) => p.id == paletteId,');
    buffer.writeln('        orElse: () => throw StateError(');
    buffer.writeln("          'Palette \$paletteId not found. Did you forget to add it to @FloatingPaletteApp?',");
    buffer.writeln('        ),');
    buffer.writeln('      );');
    buffer.writeln('      controller.hide();');
    buffer.writeln('    });');
    buffer.writeln();
    buffer.writeln('    // Eagerly register all controllers (needed for hot restart recovery)');
    buffer.writeln('    // ignore: unnecessary_statements');
    buffer.writeln('    all;');
    buffer.writeln();
    buffer.writeln('    // Recover state after hot restart (sync Dart state with native windows)');
    buffer.writeln('    await PaletteHost.instance.recover();');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  // ════════════════════════════════════════════════════════════════');
    buffer.writeln('  // Focus Management');
    buffer.writeln('  // ════════════════════════════════════════════════════════════════');
    buffer.writeln();
    buffer.writeln('  /// Activate the main app window (return keyboard focus to main app).');
    buffer.writeln('  ///');
    buffer.writeln("  /// Call this after showing a palette that doesn't need keyboard input");
    buffer.writeln('  /// to ensure hotkeys in the main app continue to work.');
    buffer.writeln('  static Future<void> focusMainWindow() => PaletteHost.instance.focusMainWindow();');
    buffer.writeln();
    buffer.writeln('  // ════════════════════════════════════════════════════════════════');
    buffer.writeln('  // Screen Utilities');
    buffer.writeln('  // ════════════════════════════════════════════════════════════════');
    buffer.writeln();
    buffer.writeln('  /// Get bounds of the currently active (frontmost) application window.');
    buffer.writeln('  ///');
    buffer.writeln("  /// Useful for positioning palettes relative to the user's active app,");
    buffer.writeln('  /// similar to how macOS Spotlight appears near the active window.');
    buffer.writeln('  static Future<ActiveAppInfo?> getActiveAppBounds() => PaletteHost.instance.getActiveAppBounds();');
    buffer.writeln();
    buffer.writeln('  // ════════════════════════════════════════════════════════════════');
    buffer.writeln('  // Lookup');
    buffer.writeln('  // ════════════════════════════════════════════════════════════════');
    buffer.writeln();
    buffer.writeln('  /// Look up a palette controller by ID.');
    buffer.writeln('  ///');
    buffer.writeln('  /// Useful for resolving IDs from snap events to controllers.');
    buffer.writeln('  /// Returns null if no palette with that ID exists.');
    buffer.writeln('  ///');
    buffer.writeln('  /// Example:');
    buffer.writeln('  /// ```dart');
    buffer.writeln('  /// Palettes.keyboard.onSnapEvent((event) {');
    buffer.writeln('  ///   if (event is SnapSnapped) {');
    buffer.writeln('  ///     final target = Palettes.byId(event.targetId);');
    buffer.writeln("  ///     print('Snapped to \${target?.id}');");
    buffer.writeln('  ///   }');
    buffer.writeln('  /// });');
    buffer.writeln('  /// ```');
    buffer.writeln('  static PaletteController? byId(String id) {');
    buffer.writeln('    return _controllers[id];');
    buffer.writeln('  }');

    buffer.writeln('}');
  }
  
  List<_PaletteInfo> _parsePalettes(ConstantReader annotation) {
    final palettesReader = annotation.read('palettes');
    final palettes = <_PaletteInfo>[];

    for (final paletteReader in palettesReader.listValue) {
      final reader = ConstantReader(paletteReader);

      final id = reader.read('id').stringValue;
      final widgetType = reader.read('widget').typeValue;
      final argsType = reader.peek('args')?.typeValue;

      // Parse eventNamespace (defaults to palette id)
      final eventNamespace = reader.peek('eventNamespace')?.stringValue ?? id;

      // Parse events for this palette
      final events = _parsePaletteEvents(reader, eventNamespace);

      // Parse behavior config
      final hideOnClickOutside = reader.peek('hideOnClickOutside')?.boolValue;
      final hideOnEscape = reader.peek('hideOnEscape')?.boolValue;
      final hideOnFocusLost = reader.peek('hideOnFocusLost')?.boolValue;
      final draggable = reader.peek('draggable')?.boolValue;
      final keepAlive = reader.peek('keepAlive')?.boolValue;
      final alwaysOnTop = reader.peek('alwaysOnTop')?.boolValue;

      // Parse size config
      final width = reader.peek('width')?.doubleValue;
      final minHeight = reader.peek('minHeight')?.doubleValue;
      final maxHeight = reader.peek('maxHeight')?.doubleValue;
      final initialWidth = reader.peek('initialWidth')?.doubleValue;
      final initialHeight = reader.peek('initialHeight')?.doubleValue;
      final resizable = reader.peek('resizable')?.boolValue;
      final allowSnap = reader.peek('allowSnap')?.boolValue;

      // Parse enum values by name (resilient to enum reordering)
      final focusReader = reader.peek('focus');
      String? focusPolicy;
      if (focusReader != null && !focusReader.isNull) {
        final name = focusReader.objectValue.getField('_name')?.toStringValue();
        const focusMapping = {'yes': 'steal', 'no': 'none'};
        focusPolicy = name != null ? focusMapping[name] : null;
      }

      final onHideFocusReader = reader.peek('onHideFocus');
      String? onHideFocus;
      if (onHideFocusReader != null && !onHideFocusReader.isNull) {
        final name = onHideFocusReader.objectValue.getField('_name')?.toStringValue();
        const onHideFocusMapping = {'none': 'none', 'mainWindow': 'mainWindow', 'previousApp': 'previousApp'};
        onHideFocus = name != null ? onHideFocusMapping[name] : null;
      }

      // Parse clickOutsideScope enum
      final clickOutsideScopeReader = reader.peek('clickOutsideScope');
      String? clickOutsideScope;
      if (clickOutsideScopeReader != null && !clickOutsideScopeReader.isNull) {
        final name = clickOutsideScopeReader.objectValue.getField('_name')?.toStringValue();
        const clickOutsideScopeMapping = {'nonPalette': 'nonPalette', 'anywhere': 'anywhere'};
        clickOutsideScope = name != null ? clickOutsideScopeMapping[name] : null;
      }

      // Parse preset enum
      final presetReader = reader.peek('preset');
      String? preset;
      if (presetReader != null && !presetReader.isNull) {
        final name = presetReader.objectValue.getField('_name')?.toStringValue();
        const presetMapping = {'menu': 'menu', 'tooltip': 'tooltip', 'modal': 'modal', 'spotlight': 'spotlight', 'persistent': 'persistent'};
        preset = name != null ? presetMapping[name] : null;
      }

      // Validate size constraints
      if (minHeight != null && maxHeight != null && minHeight > maxHeight) {
        throw InvalidGenerationSourceError(
          "Palette '$id': minHeight ($minHeight) must be <= maxHeight ($maxHeight).",
        );
      }
      if (initialWidth != null && width != null && initialWidth > width) {
        throw InvalidGenerationSourceError(
          "Palette '$id': initialWidth ($initialWidth) must be <= width ($width).",
        );
      }
      if (initialHeight != null && maxHeight != null && initialHeight > maxHeight) {
        throw InvalidGenerationSourceError(
          "Palette '$id': initialHeight ($initialHeight) must be <= maxHeight ($maxHeight).",
        );
      }

      palettes.add(_PaletteInfo(
        id: id,
        widgetName: widgetType.getDisplayString(),
        argsName: argsType?.getDisplayString(),
        events: events,
        preset: preset,
        width: width,
        minHeight: minHeight,
        maxHeight: maxHeight,
        initialWidth: initialWidth,
        initialHeight: initialHeight,
        resizable: resizable,
        allowSnap: allowSnap,
        hideOnClickOutside: hideOnClickOutside,
        hideOnEscape: hideOnEscape,
        hideOnFocusLost: hideOnFocusLost,
        draggable: draggable,
        keepAlive: keepAlive,
        alwaysOnTop: alwaysOnTop,
        focusPolicy: focusPolicy,
        onHideFocus: onHideFocus,
        clickOutsideScope: clickOutsideScope,
      ));
    }

    return palettes;
  }
  
  /// Parse events from a palette's events list.
  ///
  /// Auto-generates event IDs as `${namespace}.${snake_case(className)}`.
  List<_EventInfo> _parsePaletteEvents(ConstantReader paletteReader, String namespace) {
    final eventsReader = paletteReader.peek('events');
    if (eventsReader == null || eventsReader.isNull) return [];

    final events = <_EventInfo>[];

    for (final eventValue in eventsReader.listValue) {
      // Each item is a PaletteEvent(Type) - get the 'type' field
      final eventReader = ConstantReader(eventValue);
      final eventType = eventReader.read('type').typeValue;

      if (eventType is! InterfaceType) continue;

      final typeName = eventType.getDisplayString();
      final element = eventType.element;

      if (element is! ClassElement) {
        throw InvalidGenerationSourceError(
          '$typeName is not a class. Event types must be classes with a '
          'fromMap factory constructor.',
          element: element,
        );
      }

      // Auto-generate event ID: namespace.snake_case(className)
      final eventId = '$namespace.${toSnakeCase(typeName)}';

      events.add(_EventInfo(eventId: eventId, typeName: typeName));
    }

    return events;
  }

  /// Collect all events from all palettes and validate for duplicates.
  ///
  /// Events with the same ID and same type are deduplicated (shared events).
  /// Events with the same ID but different types are an error.
  /// Events with the same type but different IDs are an error (runtime would fail).
  List<_EventInfo> _collectAllEvents(List<_PaletteInfo> palettes) {
    final allEvents = <_EventInfo>[];
    final seenIds = <String, String>{}; // eventId -> typeName
    final seenTypes = <String, String>{}; // typeName -> eventId

    for (final palette in palettes) {
      for (final event in palette.events) {
        // Check: same type used with different IDs (would fail at runtime)
        final existingId = seenTypes[event.typeName];
        if (existingId != null && existingId != event.eventId) {
          throw InvalidGenerationSourceError(
            "Event type ${event.typeName} is used in multiple palettes with different "
            "namespaces: '$existingId' vs '${event.eventId}'. "
            "Use the same eventNamespace or different event types.",
          );
        }
        seenTypes[event.typeName] = event.eventId;

        // Check: same ID used with different types
        if (seenIds.containsKey(event.eventId)) {
          // Same ID, same type = OK (shared event via eventNamespace), skip duplicate
          if (seenIds[event.eventId] == event.typeName) continue;
          // Same ID, different type = error
          throw InvalidGenerationSourceError(
            "Duplicate event ID '${event.eventId}': "
            "${seenIds[event.eventId]} and ${event.typeName}.",
          );
        }
        seenIds[event.eventId] = event.typeName;
        allEvents.add(event);
      }
    }

    return allEvents;
  }

}

class _PaletteInfo {
  final String id;
  final String widgetName;
  final String? argsName;
  final List<_EventInfo> events;

  // Preset (provides defaults for size/behavior)
  final String? preset;

  // Size config (overrides preset)
  final double? width;
  final double? minHeight;
  final double? maxHeight;
  final double? initialWidth;
  final double? initialHeight;
  final bool? resizable;
  final bool? allowSnap;

  // Behavior config (overrides preset)
  final bool? hideOnClickOutside;
  final bool? hideOnEscape;
  final bool? hideOnFocusLost;
  final bool? draggable;
  final bool? keepAlive;
  final bool? alwaysOnTop;
  final String? focusPolicy;
  final String? onHideFocus;
  final String? clickOutsideScope;

  _PaletteInfo({
    required this.id,
    required this.widgetName,
    this.argsName,
    this.events = const [],
    this.preset,
    this.width,
    this.minHeight,
    this.maxHeight,
    this.initialWidth,
    this.initialHeight,
    this.resizable,
    this.allowSnap,
    this.hideOnClickOutside,
    this.hideOnEscape,
    this.hideOnFocusLost,
    this.draggable,
    this.keepAlive,
    this.alwaysOnTop,
    this.focusPolicy,
    this.onHideFocus,
    this.clickOutsideScope,
  });

  /// Whether any size config is specified.
  bool get hasSizeConfig =>
      width != null ||
      minHeight != null ||
      maxHeight != null ||
      initialWidth != null ||
      initialHeight != null ||
      resizable != null ||
      allowSnap != null;

  /// Whether any behavior config is specified.
  bool get hasBehaviorConfig =>
      hideOnClickOutside != null ||
      hideOnEscape != null ||
      hideOnFocusLost != null ||
      draggable != null ||
      keepAlive != null ||
      alwaysOnTop != null ||
      focusPolicy != null ||
      onHideFocus != null ||
      clickOutsideScope != null;

  /// Whether any config (preset or individual fields) is specified.
  bool get hasAnyConfig => preset != null || hasSizeConfig || hasBehaviorConfig;

  /// Generate PaletteConfig constructor code.
  String generateConfig() {
    if (!hasAnyConfig) return '';

    // If preset only (no overrides), use preset config directly
    if (preset != null && !hasSizeConfig && !hasBehaviorConfig) {
      return '''
    config: PalettePreset.$preset.config,''';
    }

    // If preset with overrides, use copyWith
    if (preset != null) {
      final copyWithParts = <String>[];

      // Size overrides
      if (hasSizeConfig) {
        final sizeParts = <String>[];
        if (width != null) sizeParts.add('width: $width');
        if (minHeight != null) sizeParts.add('minHeight: $minHeight');
        if (maxHeight != null) sizeParts.add('maxHeight: $maxHeight');
        if (initialWidth != null || initialHeight != null) {
          final fallbackWidth = width ?? 400;
          final fallbackHeight = minHeight ?? 100;
          final resolvedWidth = initialWidth ?? fallbackWidth;
          final resolvedHeight = initialHeight ?? fallbackHeight;
          sizeParts.add('initialSize: Size($resolvedWidth, $resolvedHeight)');
        }
        if (resizable != null) sizeParts.add('resizable: $resizable');
        if (allowSnap != null) sizeParts.add('allowSnap: $allowSnap');
        copyWithParts.add('size: PaletteSize(${sizeParts.join(', ')})');
      }

      // Behavior overrides
      if (hasBehaviorConfig) {
        final behaviorParts = <String>[];
        if (hideOnClickOutside != null) {
          behaviorParts.add('hideOnClickOutside: $hideOnClickOutside');
        }
        if (hideOnEscape != null) {
          behaviorParts.add('hideOnEscape: $hideOnEscape');
        }
        if (hideOnFocusLost != null) {
          behaviorParts.add('hideOnFocusLost: $hideOnFocusLost');
        }
        if (draggable != null) {
          behaviorParts.add('draggable: $draggable');
        }
        if (keepAlive != null) {
          behaviorParts.add('keepAlive: $keepAlive');
        }
        if (alwaysOnTop != null) {
          behaviorParts.add('alwaysOnTop: $alwaysOnTop');
        }
        if (focusPolicy != null) {
          behaviorParts.add('focusPolicy: FocusPolicy.$focusPolicy');
        }
        if (onHideFocus != null) {
          behaviorParts.add('onHideFocus: FocusRestoreMode.$onHideFocus');
        }
        if (clickOutsideScope != null) {
          behaviorParts.add('clickOutsideScope: ClickOutsideScope.$clickOutsideScope');
        }
        copyWithParts.add('behavior: PaletteBehavior(${behaviorParts.join(', ')})');
      }

      return '''
    config: PalettePreset.$preset.config.copyWith(
      ${copyWithParts.join(',\n      ')},
    ),''';
    }

    // No preset - build from scratch (original behavior)
    final configParts = <String>[];

    // Size config
    if (hasSizeConfig) {
      final sizeParts = <String>[];
      if (width != null) sizeParts.add('width: $width');
      if (minHeight != null) sizeParts.add('minHeight: $minHeight');
      if (maxHeight != null) sizeParts.add('maxHeight: $maxHeight');
      if (initialWidth != null || initialHeight != null) {
        final fallbackWidth = width ?? 400;
        final fallbackHeight = minHeight ?? 100;
        final resolvedWidth = initialWidth ?? fallbackWidth;
        final resolvedHeight = initialHeight ?? fallbackHeight;
        sizeParts.add('initialSize: Size($resolvedWidth, $resolvedHeight)');
      }
      if (resizable != null) sizeParts.add('resizable: $resizable');
      if (allowSnap != null) sizeParts.add('allowSnap: $allowSnap');
      configParts.add('size: PaletteSize(${sizeParts.join(', ')})');
    }

    // Behavior config
    if (hasBehaviorConfig) {
      final behaviorParts = <String>[];
      if (hideOnClickOutside != null) {
        behaviorParts.add('hideOnClickOutside: $hideOnClickOutside');
      }
      if (hideOnEscape != null) {
        behaviorParts.add('hideOnEscape: $hideOnEscape');
      }
      if (hideOnFocusLost != null) {
        behaviorParts.add('hideOnFocusLost: $hideOnFocusLost');
      }
      if (draggable != null) {
        behaviorParts.add('draggable: $draggable');
      }
      if (keepAlive != null) {
        behaviorParts.add('keepAlive: $keepAlive');
      }
      if (alwaysOnTop != null) {
        behaviorParts.add('alwaysOnTop: $alwaysOnTop');
      }
      if (focusPolicy != null) {
        behaviorParts.add('focusPolicy: FocusPolicy.$focusPolicy');
      }
      if (onHideFocus != null) {
        behaviorParts.add('onHideFocus: FocusRestoreMode.$onHideFocus');
      }
      if (clickOutsideScope != null) {
        behaviorParts.add('clickOutsideScope: ClickOutsideScope.$clickOutsideScope');
      }
      configParts.add('behavior: PaletteBehavior(${behaviorParts.join(', ')})');
    }

    return '''
    config: const PaletteConfig(
      ${configParts.join(',\n      ')},
    ),''';
  }
}

class _EventInfo {
  final String eventId;
  final String typeName;

  _EventInfo({required this.eventId, required this.typeName});
}
