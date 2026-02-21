import 'package:floating_palette/floating_palette.dart';
import 'package:flutter/material.dart';

import '../../palette_setup.dart';
import '../../theme/brand.dart';

/// Demo screen for the AI Chat Bubble palette.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  void initState() {
    super.initState();
    // Non-blocking warmup with auto-show on ready
    Palettes.chatBubble.scheduleWarmUp(autoShowOnReady: true);
  }

  @override
  void dispose() {
    Palettes.chatBubble.hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Chat Bubble'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              FPColors.surface,
              Color(0xFF1A1A2E),
              Color(0xFF1A1A3E),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: FPColors.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: FPColors.secondary.withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 40,
                  color: FPColors.secondary,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'AI Chat with Liquid Glass',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: FPColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Powered by local Ollama',
                style: TextStyle(
                  fontSize: 16,
                  color: FPColors.textSecondary,
                ),
              ),
              const SizedBox(height: 48),
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  color: FPColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: FPColors.surfaceSubtle,
                  ),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(
                      Icons.check_circle,
                      'Make sure Ollama is running on localhost:11434',
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.download,
                      'Run: ollama pull llama3.2',
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.keyboard,
                      'Type a message and press Enter',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _ChatButton(
                onPressed: () {
                  if (Palettes.chatBubble.isVisible) {
                    Palettes.chatBubble.hide();
                  } else {
                    Palettes.chatBubble.show(
                      position: PalettePosition.centerScreen(),
                    );
                  }
                  setState(() {});
                },
                isActive: Palettes.chatBubble.isVisible,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: FPColors.secondary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: FPColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom chat toggle button with hover effect.
class _ChatButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isActive;

  const _ChatButton({
    required this.onPressed,
    required this.isActive,
  });

  @override
  State<_ChatButton> createState() => _ChatButtonState();
}

class _ChatButtonState extends State<_ChatButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: widget.isActive
                ? FPColors.secondary.withValues(alpha: 0.2)
                : _isHovered
                    ? FPColors.secondary.withValues(alpha: 0.15)
                    : FPColors.secondary,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.isActive || _isHovered
                  ? FPColors.secondary
                  : Colors.transparent,
            ),
            boxShadow: _isHovered && !widget.isActive
                ? [
                    BoxShadow(
                      color: FPColors.secondary.withValues(alpha: 0.3),
                      blurRadius: 16,
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble,
                size: 18,
                color: widget.isActive
                    ? FPColors.secondary
                    : FPColors.surface,
              ),
              const SizedBox(width: 8),
              Text(
                widget.isActive ? 'Hide Chat' : 'Show Chat',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: widget.isActive
                      ? FPColors.secondary
                      : FPColors.surface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
