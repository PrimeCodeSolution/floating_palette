import 'dart:async';
import 'dart:convert';

import 'package:floating_palette/floating_palette.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/brand.dart';

/// Chat message model
class ChatMessage {
  final String content;
  final bool isUser;

  ChatMessage({required this.content, required this.isUser});
}

/// AI Chat Bubble with Liquid Glass effect.
///
/// Sizing is controlled by native resize (resizable: true in palette config).
class ChatBubblePalette extends StatefulWidget {
  const ChatBubblePalette({super.key});

  @override
  State<ChatBubblePalette> createState() => _ChatBubblePaletteState();
}

class _ChatBubblePaletteState extends State<ChatBubblePalette> {
  // Liquid Glass
  final GlassEffectService _glassService = GlassEffectService();
  String? _windowId;
  bool _glassEnabled = false;

  // Chat state
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _error;

  // Ollama config
  static const String _ollamaUrl = 'http://localhost:11434/api/generate';
  static const String _model = 'llama3.2';

  // Layout
  static const double cornerRadius = 16.0;
  Size _lastSize = Size.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initGlass();
      _focusNode.requestFocus();
      _setupFocusListener();
    });
  }

  void _setupFocusListener() {
    PaletteSelf.onFocusGained(() {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) _focusNode.requestFocus();
        });
      }
    });
  }

  Future<void> _initGlass() async {
    _windowId = PaletteWindow.currentId;
    if (_windowId == null || !_glassService.isAvailable) return;

    if (_glassService.enable(_windowId!)) {
      setState(() => _glassEnabled = true);
      _glassService.setDark(_windowId!, true);
      _glassService.setTintOpacity(_windowId!, 0.9, cornerRadius: cornerRadius); // 90% tint for better readability
    }
  }

  void _updateGlassPath(Size size) {
    if (_windowId == null || !_glassEnabled) return;
    if (size.width <= 0 || size.height <= 0) return;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(cornerRadius),
    );
    _glassService.updateRRect(_windowId!, rrect, windowHeight: size.height);
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(ChatMessage(content: text, isUser: true));
      _inputController.clear();
      _isLoading = true;
      _error = null;
    });
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse(_ollamaUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': _model,
          'prompt': text,
          'stream': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse = data['response'] as String? ?? 'No response';
        setState(() {
          _messages.add(ChatMessage(content: aiResponse.trim(), isUser: false));
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Error: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Connection failed';
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    if (_windowId != null) {
      _glassService.disable(_windowId!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: PaletteScaffold(
        backgroundColor: Colors.transparent,
        cornerRadius: 0,
        resizable: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);

            // Update glass when size changes
            if (size != _lastSize && size.width > 0 && size.height > 0) {
              _lastSize = size;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _updateGlassPath(size);
              });
            }

            return _buildContent();
          },
        ),
      ),
    );
  }

  Widget _buildContent() {
    return AnimatedGradientBorder(
      enabled: _isLoading,
      borderWidth: 2.0,
      borderRadius: cornerRadius,
      colors: const [
        FPColors.secondary,
        Color(0xFF9C6AFF),
        Color(0xFFB388FF),
        FPColors.secondary,
      ],
      animationDuration: const Duration(seconds: 2),
      child: Stack(
        children: [
          // Static border (only when not loading)
          if (!_isLoading)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(cornerRadius),
                border: Border.all(
                  color: FPColors.surfaceSubtle,
                  width: 1,
                ),
              ),
            ),
          // Content
          Column(
            children: [
              // Draggable header
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => PaletteWindow.startDrag(),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        color: FPColors.secondary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Ollama Chat',
                        style: TextStyle(
                          color: FPColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _model,
                        style: const TextStyle(
                          color: FPColors.textSecondary,
                          fontSize: 11,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Messages area (expands to fill)
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: _messages.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length && _isLoading) {
                      return _buildTypingIndicator();
                    }
                    return _buildMessageBubble(_messages[index]);
                  },
                ),
              ),
              // Error
              if (_error != null)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: FPColors.error,
                      fontSize: 11,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              // Input bar
              _buildInputBar(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: FPColors.secondary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 14,
                color: FPColors.secondary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isUser
                    ? FPColors.primary
                    : FPColors.surfaceSubtle.withValues(alpha: 0.8),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(isUser ? 12 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 12),
                ),
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  color: isUser ? FPColors.surface : FPColors.textPrimary,
                  fontSize: 13,
                  height: 1.4,
                  decoration: TextDecoration.none,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 32),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: FPColors.secondary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 14,
              color: FPColors.secondary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: FPColors.surfaceSubtle.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '...',
              style: TextStyle(
                color: FPColors.textSecondary,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: FPColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: FPColors.surfaceSubtle,
                ),
              ),
              child: TextField(
                controller: _inputController,
                focusNode: _focusNode,
                onSubmitted: (_) => _sendMessage(),
                style: const TextStyle(
                  color: FPColors.textPrimary,
                  fontSize: 14,
                  decoration: TextDecoration.none,
                ),
                decoration: const InputDecoration(
                  hintText: 'Ask anything...',
                  hintStyle:
                      TextStyle(color: FPColors.textSecondary, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                  isDense: true,
                ),
                cursorColor: FPColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _isLoading
                    ? FPColors.surfaceSubtle
                    : FPColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _isLoading ? Icons.more_horiz : Icons.arrow_upward_rounded,
                color: _isLoading ? FPColors.textSecondary : FPColors.surface,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
