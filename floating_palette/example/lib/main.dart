import 'package:floating_palette/floating_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import 'examples/notion/notion_screen.dart';
import 'examples/glass/glass_demo_screen.dart';
import 'examples/chat/chat_screen.dart';
import 'examples/clock/clock_screen.dart';
import 'examples/text_selection/text_selection_screen.dart';
import 'palette_setup.dart';
import 'theme/brand.dart';

// Export for native to find paletteMain entry point (defined in palette_setup.g.dart)
export 'palette_setup.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize PaletteHost - events are auto-registered from @FloatingPaletteApp
  await Palettes.init();

  // Clear any previously registered hotkeys (handles hot reload/restart)
  await hotKeyManager.unregisterAll();

  // Configure palettes (warmup happens per-screen)
  _configurePalettes();

  // Register global hotkey: Shift+Cmd+Space to toggle Spotlight
  await _setupSpotlightHotkey();

  runApp(const ExampleApp());
}

/// Register Shift+Cmd+Space as global hotkey for Spotlight.
Future<void> _setupSpotlightHotkey() async {
  final hotKey = HotKey(
    key: PhysicalKeyboardKey.space,
    modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
    scope: HotKeyScope.system, // Global hotkey
  );

  await hotKeyManager.register(
    hotKey,
    keyDownHandler: (hotKey) {
      _toggleSpotlight();
    },
  );
}

/// Toggle spotlight visibility.
void _toggleSpotlight() {
  if (Palettes.spotlight.isVisible) {
    Palettes.spotlight.hide();
  } else {
    Palettes.spotlight.show(
      position: PalettePosition.centerScreen(yOffset: -100),
    );
  }
}

/// Configure palettes (no warmup - each screen warms up its own palettes).
void _configurePalettes() {
  // Configure slash menu to intercept navigation keys even without focus
  // This allows arrow keys and enter to route to the menu while
  // the editor retains keyboard focus for typing
  final keysToIntercept = {
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.escape,
  };

  Palettes.slashMenu.updateConfig(
    keyboard: PaletteKeyboard(
      interceptKeys: false, // Don't intercept all keys
      alwaysIntercept: keysToIntercept,
    ),
  );
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Floating Palette Examples',
      debugShowCheckedModeBanner: false,
      theme: FPTheme.dark,
      home: const LauncherScreen(),
    );
  }
}

/// Launcher screen to pick which example to run.
class LauncherScreen extends StatelessWidget {
  const LauncherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: ListView(
              padding: const EdgeInsets.all(FPSpacing.lg),
            children: [
              const SizedBox(height: FPSpacing.xl),
              // Logo and title
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const FPLogo(size: 48),
                  const SizedBox(width: FPSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Floating Palette',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: FPColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Native floating windows for Flutter',
                        style: TextStyle(
                          fontSize: 14,
                          color: FPColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: FPSpacing.xl + FPSpacing.md),
              // Example cards
              _ExampleCard(
                title: 'Notion Clone',
                description:
                    'Editor with slash menu and style toolbar. '
                    'Demonstrates input routing between palettes.',
                icon: Icons.edit_note,
                color: FPColors.primary,
                onTap: () => _openExample(context, const NotionScreen()),
              ),
              const SizedBox(height: FPSpacing.md),
              _ExampleCard(
                title: 'Native Glass Effect',
                description:
                    'NSVisualEffectView blur masked to Flutter shapes. '
                    'No Screen Recording permission required.',
                icon: Icons.blur_on,
                color: FPColors.secondary,
                onTap: () => _openExample(context, const GlassDemoScreen()),
              ),
              const SizedBox(height: FPSpacing.md),
              _ExampleCard(
                title: 'AI Chat Bubble',
                description:
                    'Ollama-powered chat with Liquid Glass transparency. '
                    'Local LLM chat in a floating palette.',
                icon: Icons.auto_awesome,
                color: FPColors.secondary,
                onTap: () => _openExample(context, const ChatScreen()),
              ),
              const SizedBox(height: FPSpacing.md),
              _ExampleCard(
                title: 'Analog Clock',
                description:
                    'Transparent floating clock with Liquid Glass. '
                    'Demonstrates alwaysOnTop and keepAlive.',
                icon: Icons.access_time,
                color: FPColors.secondary,
                onTap: () => _openExample(context, const ClockScreen()),
              ),
              const SizedBox(height: FPSpacing.md),
              _ExampleCard(
                title: 'Text Selection',
                description:
                    'Detects text selection in any app via Accessibility API. '
                    'Shows a palette below the selected text.',
                icon: Icons.select_all,
                color: FPColors.primary,
                onTap: () => _openExample(context, const TextSelectionScreen()),
              ),
              const SizedBox(height: FPSpacing.xl),
              // Hotkey hint
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FPSpacing.md,
                    vertical: FPSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: FPColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.keyboard,
                        size: 16,
                        color: FPColors.textSecondary,
                      ),
                      const SizedBox(width: FPSpacing.sm),
                      Text(
                        'Press Shift+Cmd+Space for Spotlight',
                        style: TextStyle(
                          fontSize: 13,
                          color: FPColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  void _openExample(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _ExampleCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ExampleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ExampleCard> createState() => _ExampleCardState();
}

class _ExampleCardState extends State<_ExampleCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: FPColors.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered
                  ? widget.color.withValues(alpha: 0.5)
                  : FPColors.surfaceSubtle,
              width: 1,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.15),
                      blurRadius: 20,
                      spreadRadius: 0,
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: _isHovered ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _isHovered
                      ? [
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.3),
                            blurRadius: 12,
                            spreadRadius: 0,
                          ),
                        ]
                      : [],
                ),
                child: Icon(widget.icon, color: widget.color, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: FPColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: FPColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: _isHovered ? widget.color : FPColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
