import 'dart:async';
import 'dart:io';

import 'package:floating_palette/floating_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Spotlight palette - macOS Spotlight-like search with real app results.
///
/// Behavior:
/// - Initially shows just the search bar (single line)
/// - Results appear only when text is typed
/// - Draggable from the search bar area
/// - Escape or click outside to dismiss
class SpotlightPalette extends StatefulWidget {
  const SpotlightPalette({super.key});

  @override
  State<SpotlightPalette> createState() => _SpotlightPaletteState();
}

class _SpotlightPaletteState extends State<SpotlightPalette>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  int _selectedIndex = 0;
  List<_AppResult> _results = [];
  List<_AppResult> _allApps = [];
  StreamSubscription<PaletteKeyEvent>? _keySubscription;

  // Liquid Glass
  final GlassEffectService _glassService = GlassEffectService();
  String? _windowId;
  bool _glassEnabled = false;
  static const double _cornerRadius = 26.0;
  static const _animDuration = Duration(milliseconds: 200);

  // Glass path animation - driven by Flutter AnimationController for perfect sync
  late AnimationController _sizeAnimController;
  Size _currentSize = const Size(680, 56);
  Size _targetSize = const Size(680, 56);
  int _glassUpdateFrame = 0;
  bool _initialGlassApplied = false;

  /// Whether to show results (only when there's search text)
  bool get _showResults => _controller.text.isNotEmpty && _results.isNotEmpty;

  @override
  void initState() {
    super.initState();

    // Initialize glass path animation controller
    _sizeAnimController = AnimationController(
      vsync: this,
      duration: _animDuration,
    );
    _sizeAnimController.addListener(_onSizeAnimationTick);

    _loadApplications();
    _controller.addListener(_onSearchChanged);

    // Listen for keyboard events
    _keySubscription =
        PaletteKeyReceiver.instance.keyDownStream.listen(_handleKey);

    // Setup focus handling
    _setupFocusHandling();

    // Initialize glass effect
    WidgetsBinding.instance.addPostFrameCallback((_) => _initGlass());
  }

  Future<void> _initGlass() async {
    _windowId = PaletteWindow.currentId;
    if (_windowId == null || !_glassService.isAvailable) return;

    if (_glassService.enable(_windowId!)) {
      setState(() => _glassEnabled = true);
      _glassService.setDark(_windowId!, true);
      _glassService.setTintOpacity(_windowId!, 0.85, cornerRadius: _cornerRadius);
      // Initial glass path will be set by onSizeChanged callback
    }
  }

  void _onSizeAnimationTick() {
    // Throttle to ~30fps
    final currentFrame = (_sizeAnimController.value * 60).toInt();
    if (currentFrame == _glassUpdateFrame) return;
    _glassUpdateFrame = currentFrame;

    // Interpolate with same curve as AnimatedSize
    final t = Curves.easeOutCubic.transform(_sizeAnimController.value);
    final interpolatedHeight =
        _currentSize.height + (_targetSize.height - _currentSize.height) * t;

    _applyGlassPath(Size(680, interpolatedHeight));
  }

  void _animateToSize(Size newSize) {
    if (_windowId == null || !_glassEnabled) return;
    if (newSize.width <= 0 || newSize.height <= 0) return;
    if (newSize == _targetSize && !_sizeAnimController.isAnimating) return;

    // Always use Flutter-driven animation for perfect sync with AnimatedSize.
    // Native animation driver runs independently and causes drift.
    // Capture current interpolated size as starting point
    if (_sizeAnimController.isAnimating) {
      final t = Curves.easeOutCubic.transform(_sizeAnimController.value);
      final currentHeight =
          _currentSize.height + (_targetSize.height - _currentSize.height) * t;
      _currentSize = Size(680, currentHeight);
    } else {
      _currentSize = _targetSize;
    }

    _targetSize = newSize;
    _glassUpdateFrame = -1;
    _sizeAnimController.forward(from: 0.0);
  }

  void _onSizeChanged(Size size) {
    if (_windowId == null || !_glassEnabled) return;
    if (size.width <= 0 || size.height <= 0) return;

    // First size: apply immediately without animation
    if (!_initialGlassApplied) {
      _initialGlassApplied = true;
      _currentSize = size;
      _targetSize = size;
      _applyGlassPath(size);
      return;
    }

    // Subsequent sizes: animate
    _animateToSize(size);
  }

  void _applyGlassPath(Size size) {
    if (_windowId == null || !_glassEnabled) return;

    // Use updateRRect for precise corner rendering (avoids sampling artifacts)
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(_cornerRadius),
    );
    _glassService.updateRRect(_windowId!, rrect, windowHeight: size.height);
  }

  void _setupFocusHandling() {
    if (!PaletteContext.isInPalette) return;

    PaletteSelf.onFocusGained(() {
      _focusNode.requestFocus();
      // Reset search on show
      _controller.clear();
      setState(() {
        _selectedIndex = 0;
        _results = [];
      });

      // Reset animation state - onSizeChanged will apply correct size immediately
      _sizeAnimController.reset();
      _initialGlassApplied = false;

      // Reset to initial size for native animation
      _currentSize = const Size(680, 56);
      _targetSize = const Size(680, 56);
    });

    PaletteSelf.onFocusLost(() {
      _focusNode.unfocus();
    });
  }

  Future<void> _loadApplications() async {
    final apps = <_AppResult>[];

    // Scan /Applications directory
    final appsDir = Directory('/Applications');
    if (await appsDir.exists()) {
      await for (final entity in appsDir.list()) {
        if (entity is Directory && entity.path.endsWith('.app')) {
          final name = entity.path.split('/').last.replaceAll('.app', '');
          apps.add(_AppResult(
            name: name,
            path: entity.path,
            subtitle: 'Application',
          ));
        }
      }
    }

    // Sort alphabetically
    apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    setState(() {
      _allApps = apps;
    });

    // Load icons asynchronously
    _loadIcons();
  }

  Future<void> _loadIcons() async {
    for (final app in _allApps) {
      if (!mounted) return;
      try {
        final iconData = await PaletteWindow.getAppIcon(app.path);
        if (iconData != null && mounted) {
          setState(() {
            app.iconData = iconData;
          });
        }
      } catch (e) {
        // Ignore icon loading errors
      }
    }
  }

  void _onSearchChanged() {
    final query = _controller.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _results = [];
      } else {
        _results = _allApps
            .where((app) => app.name.toLowerCase().contains(query))
            .take(8)
            .toList();
      }
      _selectedIndex = 0;
    });
    // Glass animation triggered by onSizeChanged callback
  }

  void _handleKey(PaletteKeyEvent event) {
    _handleKeyEvent(event.key);
  }

  /// Handle keyboard navigation - called from both PaletteKeyReceiver and Focus widget
  KeyEventResult _handleKeyEvent(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_results.isNotEmpty) {
        setState(() {
          _selectedIndex = (_selectedIndex + 1) % _results.length;
        });
        return KeyEventResult.handled;
      }
    } else if (key == LogicalKeyboardKey.arrowUp) {
      if (_results.isNotEmpty) {
        setState(() {
          _selectedIndex =
              (_selectedIndex - 1 + _results.length) % _results.length;
        });
        return KeyEventResult.handled;
      }
    } else if (key == LogicalKeyboardKey.enter) {
      if (_results.isNotEmpty) {
        _launchApp(_results[_selectedIndex]);
        return KeyEventResult.handled;
      }
    } else if (key == LogicalKeyboardKey.escape) {
      PaletteWindow.hide();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _launchApp(_AppResult app) {
    // Launch the app using open command
    Process.run('open', [app.path]);
    PaletteWindow.hide();
  }

  @override
  void dispose() {
    _sizeAnimController.dispose();
    _keySubscription?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            return _handleKeyEvent(event.logicalKey);
          }
          return KeyEventResult.ignored;
        },
        child: PaletteScaffold(
          cornerRadius: _cornerRadius,
          decoration: BoxDecoration(
            color: _glassEnabled ? Colors.transparent : const Color(0xFF5A5A5A),
            borderRadius: BorderRadius.circular(_cornerRadius),
          ),
          onSizeChanged: _onSizeChanged,
          child: SizedBox(
            width: 680,
            child: AnimatedSize(
              duration: _animDuration,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Search input (draggable)
                  _buildSearchBar(),
                  // Results (only when searching)
                  if (_showResults) _buildResultsList(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => PaletteWindow.startDrag(),
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.search,
                size: 26,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w300,
                    color: Colors.white.withValues(alpha: 0.9),
                    letterSpacing: 0.3,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Spotlight Search',
                    hintStyle: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w300,
                      color: Colors.white.withValues(alpha: 0.45),
                      letterSpacing: 0.3,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        itemCount: _results.length,
        itemBuilder: (context, index) {
          final result = _results[index];
          final isSelected = index == _selectedIndex;

          return GestureDetector(
            onTap: () => _launchApp(result),
            child: MouseRegion(
              onEnter: (_) => setState(() => _selectedIndex = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                margin: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    // App icon
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: result.iconData != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: Image.memory(
                                result.iconData!,
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Icon(
                                Icons.apps,
                                size: 20,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    // App info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            result.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            result.subtitle,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Keyboard hint for selected
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '⏎',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AppResult {
  final String name;
  final String path;
  final String subtitle;
  Uint8List? iconData;

  _AppResult({
    required this.name,
    required this.path,
    required this.subtitle,
  });
}
