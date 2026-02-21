import 'package:flutter_quill/quill_delta.dart';

import 'block.dart';

/// Immutable operations on BlockDocument.
///
/// All operations return a new BlockDocument instance.
extension BlockDocumentOperations on BlockDocument {
  /// Split a block at the given offset, creating a new block below.
  ///
  /// The content before the offset stays in the original block,
  /// and the content after the offset goes to the new block.
  /// Focus moves to the new block at offset 0.
  BlockDocument splitBlock(BlockId blockId, int offset) {
    final blockIndex = getBlockIndex(blockId);
    if (blockIndex == null) return this;

    final block = blocks[blockIndex];
    if (!block.isTextCapable) return this;

    final plainText = block.plainText;

    // Clamp offset to valid range
    final clampedOffset = offset.clamp(0, plainText.length);

    // Split content
    final beforeText = plainText.substring(0, clampedOffset);
    final afterText = plainText.substring(clampedOffset);

    // Create updated blocks
    final updatedBlock = block.copyWith(
      content: Delta()
        ..insert(beforeText)
        ..insert('\n'),
    );

    // New block inherits type for most block types, but not for headings
    // (typing Enter after a heading should create a paragraph)
    final newBlockType = switch (block.type) {
      BlockType.heading1 ||
      BlockType.heading2 ||
      BlockType.heading3 =>
        BlockType.paragraph,
      _ => block.type,
    };

    final newBlock = Block.withText(newBlockType, afterText);

    // Build new block list
    final newBlocks = List<Block>.from(blocks);
    newBlocks[blockIndex] = updatedBlock;
    newBlocks.insert(blockIndex + 1, newBlock);

    return copyWith(
      blocks: newBlocks,
      focusedBlockId: newBlock.id,
      caretOffset: 0,
    );
  }

  /// Merge a block with the previous block (backspace at start of block).
  ///
  /// The content of the current block is appended to the previous block.
  /// Focus moves to the merge point (end of previous block's original content).
  BlockDocument mergeWithPrevious(BlockId blockId) {
    final blockIndex = getBlockIndex(blockId);
    if (blockIndex == null || blockIndex == 0) return this;

    final currentBlock = blocks[blockIndex];
    final previousBlock = blocks[blockIndex - 1];

    // Can only merge text-capable blocks
    if (!currentBlock.isTextCapable || !previousBlock.isTextCapable) {
      return this;
    }

    final previousText = previousBlock.plainText;
    final currentText = currentBlock.plainText;
    final mergePoint = previousText.length;

    // Create merged block
    final mergedBlock = previousBlock.copyWith(
      content: Delta()
        ..insert(previousText)
        ..insert(currentText)
        ..insert('\n'),
    );

    // Build new block list
    final newBlocks = List<Block>.from(blocks);
    newBlocks[blockIndex - 1] = mergedBlock;
    newBlocks.removeAt(blockIndex);

    return copyWith(
      blocks: newBlocks,
      focusedBlockId: mergedBlock.id,
      caretOffset: mergePoint,
    );
  }

  /// Merge a block with the next block (delete at end of block).
  ///
  /// The content of the next block is appended to the current block.
  /// Focus stays at the current position.
  BlockDocument mergeWithNext(BlockId blockId) {
    final blockIndex = getBlockIndex(blockId);
    if (blockIndex == null || blockIndex >= blocks.length - 1) return this;

    final currentBlock = blocks[blockIndex];
    final nextBlock = blocks[blockIndex + 1];

    // Can only merge text-capable blocks
    if (!currentBlock.isTextCapable || !nextBlock.isTextCapable) {
      return this;
    }

    final currentText = currentBlock.plainText;
    final nextText = nextBlock.plainText;

    // Create merged block
    final mergedBlock = currentBlock.copyWith(
      content: Delta()
        ..insert(currentText)
        ..insert(nextText)
        ..insert('\n'),
    );

    // Build new block list
    final newBlocks = List<Block>.from(blocks);
    newBlocks[blockIndex] = mergedBlock;
    newBlocks.removeAt(blockIndex + 1);

    return copyWith(
      blocks: newBlocks,
      focusedBlockId: mergedBlock.id,
      caretOffset: currentText.length,
    );
  }

  /// Transform a block to a different type.
  ///
  /// Content is preserved if the new type is text-capable.
  BlockDocument transformBlock(BlockId blockId, BlockType newType) {
    final blockIndex = getBlockIndex(blockId);
    if (blockIndex == null) return this;

    final block = blocks[blockIndex];

    // Handle divider specially - it has no content
    final newContent = newType == BlockType.divider
        ? (Delta()..insert('\n'))
        : block.content;

    final updatedBlock = block.copyWith(
      type: newType,
      content: newContent,
      // Clear checked state if not a todo
      checked: newType == BlockType.todo ? (block.checked ?? false) : null,
    );

    final newBlocks = List<Block>.from(blocks);
    newBlocks[blockIndex] = updatedBlock;

    return copyWith(blocks: newBlocks);
  }

  /// Update a block's content.
  BlockDocument updateContent(BlockId blockId, Delta content) {
    final blockIndex = getBlockIndex(blockId);
    if (blockIndex == null) return this;

    final block = blocks[blockIndex];
    final updatedBlock = block.copyWith(content: content);

    final newBlocks = List<Block>.from(blocks);
    newBlocks[blockIndex] = updatedBlock;

    return copyWith(blocks: newBlocks);
  }

  /// Update a block's checked state (for todo blocks).
  BlockDocument updateChecked(BlockId blockId, bool checked) {
    final blockIndex = getBlockIndex(blockId);
    if (blockIndex == null) return this;

    final block = blocks[blockIndex];
    if (block.type != BlockType.todo) return this;

    final updatedBlock = block.copyWith(checked: checked);

    final newBlocks = List<Block>.from(blocks);
    newBlocks[blockIndex] = updatedBlock;

    return copyWith(blocks: newBlocks);
  }

  /// Insert a new block after the specified block.
  BlockDocument insertBlockAfter(BlockId afterId, Block newBlock) {
    final afterIndex = getBlockIndex(afterId);
    if (afterIndex == null) return this;

    final newBlocks = List<Block>.from(blocks);
    newBlocks.insert(afterIndex + 1, newBlock);

    return copyWith(
      blocks: newBlocks,
      focusedBlockId: newBlock.id,
      caretOffset: 0,
    );
  }

  /// Insert a new block before the specified block.
  BlockDocument insertBlockBefore(BlockId beforeId, Block newBlock) {
    final beforeIndex = getBlockIndex(beforeId);
    if (beforeIndex == null) return this;

    final newBlocks = List<Block>.from(blocks);
    newBlocks.insert(beforeIndex, newBlock);

    return copyWith(
      blocks: newBlocks,
      focusedBlockId: newBlock.id,
      caretOffset: 0,
    );
  }

  /// Delete a block.
  ///
  /// If this is the last block, creates a new empty paragraph.
  /// Focus moves to the previous block, or the next if at start.
  BlockDocument deleteBlock(BlockId blockId) {
    final blockIndex = getBlockIndex(blockId);
    if (blockIndex == null) return this;

    // If only one block, replace with empty paragraph
    if (blocks.length == 1) {
      final newBlock = Block.empty(BlockType.paragraph);
      return copyWith(
        blocks: [newBlock],
        focusedBlockId: newBlock.id,
        caretOffset: 0,
      );
    }

    final newBlocks = List<Block>.from(blocks);
    newBlocks.removeAt(blockIndex);

    // Focus on previous block if available, otherwise next
    final newFocusIndex = blockIndex > 0 ? blockIndex - 1 : 0;
    final newFocusBlock = newBlocks[newFocusIndex];

    return copyWith(
      blocks: newBlocks,
      focusedBlockId: newFocusBlock.id,
      caretOffset: newFocusBlock.plainText.length,
    );
  }

  /// Move focus to a specific block.
  BlockDocument focusBlock(BlockId blockId, {int? offset}) {
    final block = getBlock(blockId);
    if (block == null) return this;

    final clampedOffset = offset?.clamp(0, block.plainText.length) ?? 0;

    return copyWith(
      focusedBlockId: blockId,
      caretOffset: clampedOffset,
    );
  }

  /// Move focus to the next block.
  BlockDocument focusNextBlock() {
    final currentIndex = focusedIndex;
    if (currentIndex == null || currentIndex >= blocks.length - 1) {
      return this;
    }

    final nextBlock = blocks[currentIndex + 1];
    return copyWith(
      focusedBlockId: nextBlock.id,
      caretOffset: 0,
    );
  }

  /// Move focus to the previous block.
  BlockDocument focusPreviousBlock() {
    final currentIndex = focusedIndex;
    if (currentIndex == null || currentIndex <= 0) {
      return this;
    }

    final prevBlock = blocks[currentIndex - 1];
    return copyWith(
      focusedBlockId: prevBlock.id,
      caretOffset: prevBlock.plainText.length,
    );
  }

  /// Move a block up in the list.
  BlockDocument moveBlockUp(BlockId blockId) {
    final blockIndex = getBlockIndex(blockId);
    if (blockIndex == null || blockIndex <= 0) return this;

    final newBlocks = List<Block>.from(blocks);
    final block = newBlocks.removeAt(blockIndex);
    newBlocks.insert(blockIndex - 1, block);

    return copyWith(blocks: newBlocks);
  }

  /// Move a block down in the list.
  BlockDocument moveBlockDown(BlockId blockId) {
    final blockIndex = getBlockIndex(blockId);
    if (blockIndex == null || blockIndex >= blocks.length - 1) return this;

    final newBlocks = List<Block>.from(blocks);
    final block = newBlocks.removeAt(blockIndex);
    newBlocks.insert(blockIndex + 1, block);

    return copyWith(blocks: newBlocks);
  }
}
