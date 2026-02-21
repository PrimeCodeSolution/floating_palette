import 'dart:math';

import 'package:flutter_quill/quill_delta.dart';

/// Unique identifier for a block.
typedef BlockId = String;

/// Types of blocks supported in the editor.
enum BlockType {
  paragraph,
  heading1,
  heading2,
  heading3,
  bulletList,
  numberedList,
  todo,
  quote,
  code,
  divider,
}

/// A single block in the document.
///
/// Each block has a type, rich text content (as a Quill Delta),
/// and optional properties like checked state for todos.
class Block {
  final BlockId id;
  final BlockType type;
  final Delta content;
  final bool? checked; // For todo blocks
  final List<Block> children; // For nested blocks (future)

  const Block({
    required this.id,
    required this.type,
    required this.content,
    this.checked,
    this.children = const [],
  });

  /// Whether this block type can contain text.
  bool get isTextCapable => type != BlockType.divider;

  /// Whether content is empty (just contains newline or whitespace).
  bool get isEmpty {
    final plainText = _deltaToPlainText(content);
    return plainText.trim().isEmpty;
  }

  /// Get plain text content without trailing newline.
  String get plainText => _deltaToPlainText(content).trimRight();

  /// Create a copy with modified properties.
  Block copyWith({
    BlockId? id,
    BlockType? type,
    Delta? content,
    bool? checked,
    List<Block>? children,
  }) {
    return Block(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      checked: checked ?? this.checked,
      children: children ?? this.children,
    );
  }

  /// Create an empty block of the given type.
  factory Block.empty(BlockType type) => Block(
        id: _generateId(),
        type: type,
        content: Delta()..insert('\n'),
      );

  /// Create a block with the given text content.
  factory Block.withText(BlockType type, String text) => Block(
        id: _generateId(),
        type: type,
        content: Delta()
          ..insert(text)
          ..insert('\n'),
      );

  /// Convert to JSON map for serialization.
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'content': content.toJson(),
        if (checked != null) 'checked': checked,
        if (children.isNotEmpty)
          'children': children.map((c) => c.toJson()).toList(),
      };

  /// Create from JSON map.
  factory Block.fromJson(Map<String, dynamic> json) => Block(
        id: json['id'] as String,
        type: BlockType.values.byName(json['type'] as String),
        content: Delta.fromJson(json['content'] as List),
        checked: json['checked'] as bool?,
        children: (json['children'] as List<dynamic>?)
                ?.map((c) => Block.fromJson(c as Map<String, dynamic>))
                .toList() ??
            const [],
      );

  @override
  String toString() => 'Block($id, $type, "${plainText.length > 20 ? '${plainText.substring(0, 20)}...' : plainText}")';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Block &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// The full document state containing all blocks.
class BlockDocument {
  final List<Block> blocks;
  final BlockId? focusedBlockId;
  final int? caretOffset; // Offset within focused block

  const BlockDocument({
    required this.blocks,
    this.focusedBlockId,
    this.caretOffset,
  });

  /// Get the currently focused block, if any.
  Block? get focusedBlock {
    if (focusedBlockId == null) return null;
    try {
      return blocks.firstWhere((b) => b.id == focusedBlockId);
    } catch (_) {
      return null;
    }
  }

  /// Get the index of the focused block, or null if not found.
  int? get focusedIndex {
    if (focusedBlockId == null) return null;
    final idx = blocks.indexWhere((b) => b.id == focusedBlockId);
    return idx >= 0 ? idx : null;
  }

  /// Get a block by its ID.
  Block? getBlock(BlockId id) {
    try {
      return blocks.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get the index of a block by its ID.
  int? getBlockIndex(BlockId id) {
    final idx = blocks.indexWhere((b) => b.id == id);
    return idx >= 0 ? idx : null;
  }

  /// Create a copy with modified properties.
  BlockDocument copyWith({
    List<Block>? blocks,
    BlockId? focusedBlockId,
    int? caretOffset,
    bool clearFocus = false,
  }) {
    return BlockDocument(
      blocks: blocks ?? this.blocks,
      focusedBlockId: clearFocus ? null : (focusedBlockId ?? this.focusedBlockId),
      caretOffset: clearFocus ? null : (caretOffset ?? this.caretOffset),
    );
  }

  /// Create an empty document with a single paragraph block.
  factory BlockDocument.empty() => BlockDocument(
        blocks: [Block.empty(BlockType.paragraph)],
      );

  /// Convert to JSON map for serialization.
  Map<String, dynamic> toJson() => {
        'blocks': blocks.map((b) => b.toJson()).toList(),
        if (focusedBlockId != null) 'focusedBlockId': focusedBlockId,
        if (caretOffset != null) 'caretOffset': caretOffset,
      };

  /// Create from JSON map.
  factory BlockDocument.fromJson(Map<String, dynamic> json) => BlockDocument(
        blocks: (json['blocks'] as List<dynamic>)
            .map((b) => Block.fromJson(b as Map<String, dynamic>))
            .toList(),
        focusedBlockId: json['focusedBlockId'] as String?,
        caretOffset: json['caretOffset'] as int?,
      );

  @override
  String toString() => 'BlockDocument(${blocks.length} blocks, focused: $focusedBlockId)';
}

// ════════════════════════════════════════════════════════════════════════════
// Private Helpers
// ════════════════════════════════════════════════════════════════════════════

final _random = Random();
int _idCounter = 0;

/// Generate a unique block ID.
String _generateId() {
  final timestamp = DateTime.now().microsecondsSinceEpoch;
  final randomPart = _random.nextInt(0xFFFF);
  _idCounter++;
  return 'blk_${timestamp.toRadixString(36)}_${randomPart.toRadixString(36)}_${_idCounter.toRadixString(36)}';
}

String _deltaToPlainText(Delta delta) {
  final buffer = StringBuffer();
  for (final op in delta.toList()) {
    if (op.isInsert && op.data is String) {
      buffer.write(op.data as String);
    }
  }
  return buffer.toString();
}
