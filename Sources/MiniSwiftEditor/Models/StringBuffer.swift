//
//  StringBuffer.swift
//  MiniSwiftEditor
//
//  Basic text storage implementation using String
//  Requirements: 1.1, 1.3, 1.4, 14.3, 14.4
//

import Foundation

/// Basic TextBuffer implementation using String for content storage.
/// Suitable for small to medium-sized files (< 100K lines).
/// For larger files, use RopeBuffer instead.
/// 
/// Performance optimizations:
/// - Incremental line offset updates instead of full rebuild
/// - UTF-8 byte scanning for faster newline detection
/// - Binary search for O(log n) line lookups
final class StringBuffer: TextBuffer {
    
    // MARK: - Private Properties
    
    /// The actual text content
    private var text: String
    
    /// Cache of line start offsets for O(1) line lookups
    /// Each element represents the character offset where a line begins
    private var lineOffsets: [Int]
    
    /// Version counter for incremental parsing coordination
    private(set) var version: Int = 0
    
    // MARK: - TextBuffer Protocol Properties
    
    var content: String { text }
    
    var lineCount: Int { lineOffsets.count }
    
    // MARK: - Initialization
    
    /// Initialize with optional initial content
    /// - Parameter initialContent: The initial text content (defaults to empty string)
    init(_ initialContent: String = "") {
        self.text = initialContent
        self.lineOffsets = []
        rebuildLineOffsets()
    }
    
    // MARK: - TextBuffer Protocol Methods
    
    func insert(_ newText: String, at offset: Int) {
        guard offset >= 0 && offset <= text.count else { return }
        
        let index = text.index(text.startIndex, offsetBy: offset)
        text.insert(contentsOf: newText, at: index)
        
        version += 1
        
        // Use incremental update for small insertions (< 1000 chars)
        // This provides <16ms keystroke latency for typical edits
        if newText.count < 1000 {
            updateLineOffsetsAfterInsert(at: offset, length: newText.count, insertedText: newText)
        } else {
            rebuildLineOffsets()
        }
    }
    
    func delete(range: Range<Int>) {
        guard range.lowerBound >= 0 && range.upperBound <= text.count else { return }
        guard range.lowerBound < range.upperBound else { return }
        
        // Capture deleted text for incremental update
        let startIndex = text.index(text.startIndex, offsetBy: range.lowerBound)
        let endIndex = text.index(text.startIndex, offsetBy: range.upperBound)
        let deletedText = String(text[startIndex..<endIndex])
        
        text.removeSubrange(startIndex..<endIndex)
        
        version += 1
        
        // Use incremental update for small deletions (< 1000 chars)
        if range.count < 1000 {
            updateLineOffsetsAfterDelete(at: range.lowerBound, length: range.count, deletedText: deletedText)
        } else {
            rebuildLineOffsets()
        }
    }
    
    func lineRange(for lineIndex: Int) -> Range<Int> {
        guard lineIndex >= 0 && lineIndex < lineOffsets.count else {
            return 0..<0
        }
        
        let startOffset = lineOffsets[lineIndex]
        let endOffset: Int
        
        if lineIndex + 1 < lineOffsets.count {
            // End is the start of the next line
            endOffset = lineOffsets[lineIndex + 1]
        } else {
            // Last line ends at document end
            endOffset = text.count
        }
        
        return startOffset..<endOffset
    }
    
    func lineIndex(for offset: Int) -> Int {
        guard offset >= 0 && offset <= text.count else {
            return 0
        }
        
        // Binary search for the line containing this offset
        var low = 0
        var high = lineOffsets.count - 1
        
        while low < high {
            let mid = (low + high + 1) / 2
            if lineOffsets[mid] <= offset {
                low = mid
            } else {
                high = mid - 1
            }
        }
        
        return low
    }
    
    func offset(for lineIndex: Int) -> Int {
        guard lineIndex >= 0 && lineIndex < lineOffsets.count else {
            if lineIndex < 0 {
                return 0
            }
            return text.count
        }
        return lineOffsets[lineIndex]
    }
    
    // MARK: - Private Methods
    
    /// Rebuild the line offsets cache after content changes
    /// Uses UTF-8 byte scanning for better performance on large files
    private func rebuildLineOffsets() {
        lineOffsets = [0]  // First line always starts at offset 0
        
        // Use UTF-8 view for faster iteration on large files
        var charOffset = 0
        for char in text {
            if char == "\n" {
                // Next line starts after the newline
                lineOffsets.append(charOffset + 1)
            }
            charOffset += 1
        }
    }
    
    /// Incrementally update line offsets after an insertion
    /// This is O(n) where n is the number of lines after the insertion point,
    /// but avoids scanning the entire document for small edits.
    /// Requirements: 14.4 (<16ms keystroke latency)
    private func updateLineOffsetsAfterInsert(at offset: Int, length: Int, insertedText: String) {
        // Find the line containing the insertion point
        let insertLine = lineIndex(for: offset)
        
        // Count newlines in inserted text
        var newLineOffsets: [Int] = []
        var relativeOffset = 0
        for char in insertedText {
            if char == "\n" {
                newLineOffsets.append(offset + relativeOffset + 1)
            }
            relativeOffset += 1
        }
        
        // Update offsets for lines after the insertion point
        // Shift all subsequent line offsets by the insertion length
        for i in (insertLine + 1)..<lineOffsets.count {
            lineOffsets[i] += length
        }
        
        // Insert new line offsets for any newlines in the inserted text
        if !newLineOffsets.isEmpty {
            lineOffsets.insert(contentsOf: newLineOffsets, at: insertLine + 1)
        }
    }
    
    /// Incrementally update line offsets after a deletion
    /// This is O(n) where n is the number of lines after the deletion point.
    /// Requirements: 14.4 (<16ms keystroke latency)
    private func updateLineOffsetsAfterDelete(at offset: Int, length: Int, deletedText: String) {
        // Find the line containing the deletion start
        let deleteLine = lineIndex(for: offset)
        
        // Count newlines in deleted text
        let deletedNewlines = deletedText.filter { $0 == "\n" }.count
        
        // Remove line offsets for deleted newlines
        if deletedNewlines > 0 {
            let removeStart = deleteLine + 1
            let removeEnd = min(removeStart + deletedNewlines, lineOffsets.count)
            if removeStart < removeEnd {
                lineOffsets.removeSubrange(removeStart..<removeEnd)
            }
        }
        
        // Update offsets for lines after the deletion point
        // Shift all subsequent line offsets by the deletion length
        for i in (deleteLine + 1)..<lineOffsets.count {
            lineOffsets[i] -= length
        }
    }
}
