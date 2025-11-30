//
//  SelectionManager.swift
//  MiniSwiftEditor
//
//  Selection management for the code editor
//  Requirements: 6.4, 6.5, 6.6, 6.7
//

import Foundation
import Combine

// MARK: - Direction

/// Direction for caret movement operations
/// Requirements: 6.4, 6.5
enum Direction {
    case left
    case right
    case up
    case down
    case lineStart
    case lineEnd
    case documentStart
    case documentEnd
    case wordLeft
    case wordRight
}

// MARK: - Selection Model

/// Represents a text selection with anchor and head positions.
/// Requirements: 6.1
public struct Selection: Equatable {
    /// Selection start position (anchor)
    public let anchor: Int
    /// Caret position (head)
    public let head: Int
    
    public init(anchor: Int, head: Int) {
        self.anchor = anchor
        self.head = head
    }
    
    /// Character range of the selection (normalized)
    public var range: Range<Int> {
        min(anchor, head)..<max(anchor, head)
    }
    
    /// Whether the selection is collapsed (just a caret)
    public var isCollapsed: Bool { anchor == head }
    
    /// Current caret position
    public var caretPosition: Int { head }
}

// MARK: - SelectionManager

/// Manages text selection state and operations for the code editor.
/// Implements anchor/head model for selection representation.
/// Requirements: 6.4, 6.5, 6.6, 6.7
final class SelectionManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current selection state
    @Published var selection: Selection
    
    // MARK: - Private Properties
    
    /// Reference to the text document for content access
    private weak var document: TextDocument?
    
    // MARK: - Initialization
    
    /// Initialize with a document reference
    /// - Parameter document: The text document to manage selection for
    init(document: TextDocument? = nil) {
        self.document = document
        self.selection = Selection(anchor: 0, head: 0)
    }
    
    /// Set the document reference
    /// - Parameter document: The text document
    func setDocument(_ document: TextDocument) {
        self.document = document
        // Reset selection to valid position
        let maxPosition = document.content.count
        if selection.head > maxPosition || selection.anchor > maxPosition {
            selection = Selection(anchor: 0, head: 0)
        }
    }

    
    // MARK: - Caret Movement
    
    /// Move the caret in the specified direction.
    /// Requirements: 6.4, 6.5
    /// - Parameters:
    ///   - direction: The direction to move
    ///   - extending: If true, extends selection; if false, collapses and moves
    func moveCaret(direction: Direction, extending: Bool) {
        guard let document = document else { return }
        
        let content = document.content
        let documentLength = content.count
        
        // Calculate new head position based on direction
        let newHead: Int
        
        switch direction {
        case .left:
            newHead = max(0, selection.head - 1)
            
        case .right:
            newHead = min(documentLength, selection.head + 1)
            
        case .up:
            newHead = calculateUpPosition(from: selection.head, in: content)
            
        case .down:
            newHead = calculateDownPosition(from: selection.head, in: content)
            
        case .lineStart:
            newHead = calculateLineStart(from: selection.head, in: content)
            
        case .lineEnd:
            newHead = calculateLineEnd(from: selection.head, in: content)
            
        case .documentStart:
            newHead = 0
            
        case .documentEnd:
            newHead = documentLength
            
        case .wordLeft:
            newHead = calculateWordLeft(from: selection.head, in: content)
            
        case .wordRight:
            newHead = calculateWordRight(from: selection.head, in: content)
        }
        
        // Clamp to valid bounds
        let clampedHead = max(0, min(documentLength, newHead))
        
        // Update selection
        if extending {
            // Extend selection: keep anchor, move head
            selection = Selection(anchor: selection.anchor, head: clampedHead)
        } else {
            // Collapse selection and move
            selection = Selection(anchor: clampedHead, head: clampedHead)
        }
    }
    
    // MARK: - Word Selection
    
    /// Select the word at the given offset (double-click behavior).
    /// A word is defined as contiguous alphanumeric characters.
    /// Requirements: 6.6
    /// - Parameter offset: Character offset within the document
    func selectWord(at offset: Int) {
        guard let document = document else { return }
        
        let content = document.content
        guard offset >= 0 && offset <= content.count else { return }
        
        // Handle empty document
        guard !content.isEmpty else {
            selection = Selection(anchor: 0, head: 0)
            return
        }
        
        // Clamp offset to valid range for character access
        let safeOffset = min(offset, content.count - 1)
        
        // Get the character at the offset
        let index = content.index(content.startIndex, offsetBy: safeOffset)
        let char = content[index]
        
        // If not on a word character, select just that character or nothing
        if !isWordCharacter(char) {
            // If at end of document, don't select anything
            if offset >= content.count {
                selection = Selection(anchor: offset, head: offset)
            } else {
                // Select the single non-word character
                selection = Selection(anchor: safeOffset, head: safeOffset + 1)
            }
            return
        }
        
        // Find word boundaries
        let wordStart = findWordStart(from: safeOffset, in: content)
        let wordEnd = findWordEnd(from: safeOffset, in: content)
        
        selection = Selection(anchor: wordStart, head: wordEnd)
    }
    
    // MARK: - Line Selection
    
    /// Select the entire line at the given line index (triple-click behavior).
    /// Includes the newline character if present.
    /// Requirements: 6.7
    /// - Parameter lineIndex: Zero-based line index
    func selectLine(at lineIndex: Int) {
        guard let document = document else { return }
        
        let content = document.content
        
        // Handle empty document
        guard !content.isEmpty else {
            selection = Selection(anchor: 0, head: 0)
            return
        }
        
        // Get line range from document
        // The lineRange already includes the newline character for non-last lines
        // (it goes from line start to the start of the next line)
        let lineRange = document.lineRange(for: lineIndex)
        
        selection = Selection(anchor: lineRange.lowerBound, head: lineRange.upperBound)
    }
    
    /// Select the entire line containing the given offset.
    /// Requirements: 6.7
    /// - Parameter offset: Character offset within the document
    func selectLineContaining(offset: Int) {
        guard let document = document else { return }
        
        let lineIndex = document.lineIndex(for: offset)
        selectLine(at: lineIndex)
    }
    
    // MARK: - Selection Operations
    
    /// Select all text in the document
    func selectAll() {
        guard let document = document else { return }
        selection = Selection(anchor: 0, head: document.content.count)
    }
    
    /// Collapse selection to caret position
    func collapseSelection() {
        selection = Selection(anchor: selection.head, head: selection.head)
    }
    
    /// Set selection directly
    /// - Parameter newSelection: The new selection state
    func setSelection(_ newSelection: Selection) {
        guard let document = document else {
            selection = newSelection
            return
        }
        
        // Clamp to document bounds
        let maxPos = document.content.count
        let clampedAnchor = max(0, min(maxPos, newSelection.anchor))
        let clampedHead = max(0, min(maxPos, newSelection.head))
        
        selection = Selection(anchor: clampedAnchor, head: clampedHead)
    }

    
    // MARK: - Private Helpers - Position Calculations
    
    /// Calculate position when moving up one line
    private func calculateUpPosition(from offset: Int, in content: String) -> Int {
        guard !content.isEmpty else { return 0 }
        
        // Find current line start
        let currentLineStart = calculateLineStart(from: offset, in: content)
        
        // If already at first line, go to document start
        guard currentLineStart > 0 else { return 0 }
        
        // Find previous line start (go back past the newline)
        let prevLineEnd = currentLineStart - 1
        let prevLineStart = calculateLineStart(from: prevLineEnd, in: content)
        
        // Calculate column offset in current line
        let columnOffset = offset - currentLineStart
        
        // Calculate previous line length
        let prevLineLength = prevLineEnd - prevLineStart
        
        // Move to same column in previous line, or end of line if shorter
        return prevLineStart + min(columnOffset, prevLineLength)
    }
    
    /// Calculate position when moving down one line
    private func calculateDownPosition(from offset: Int, in content: String) -> Int {
        guard !content.isEmpty else { return 0 }
        
        // Find current line start and end
        let currentLineStart = calculateLineStart(from: offset, in: content)
        let currentLineEnd = calculateLineEnd(from: offset, in: content)
        
        // If at last line, go to document end
        guard currentLineEnd < content.count else { return content.count }
        
        // Next line starts after the newline
        let nextLineStart = currentLineEnd + 1
        let nextLineEnd = calculateLineEnd(from: nextLineStart, in: content)
        
        // Calculate column offset in current line
        let columnOffset = offset - currentLineStart
        
        // Calculate next line length
        let nextLineLength = nextLineEnd - nextLineStart
        
        // Move to same column in next line, or end of line if shorter
        return nextLineStart + min(columnOffset, nextLineLength)
    }
    
    /// Calculate the start of the line containing the offset
    private func calculateLineStart(from offset: Int, in content: String) -> Int {
        guard !content.isEmpty && offset > 0 else { return 0 }
        
        let safeOffset = min(offset, content.count)
        
        // Search backwards for newline
        var pos = safeOffset - 1
        while pos >= 0 {
            let index = content.index(content.startIndex, offsetBy: pos)
            if content[index] == "\n" {
                return pos + 1
            }
            pos -= 1
        }
        
        return 0
    }
    
    /// Calculate the end of the line containing the offset (before newline)
    private func calculateLineEnd(from offset: Int, in content: String) -> Int {
        guard !content.isEmpty else { return 0 }
        
        let safeOffset = min(offset, content.count)
        
        // Search forwards for newline
        var pos = safeOffset
        while pos < content.count {
            let index = content.index(content.startIndex, offsetBy: pos)
            if content[index] == "\n" {
                return pos
            }
            pos += 1
        }
        
        return content.count
    }
    
    /// Calculate position when moving left by one word
    private func calculateWordLeft(from offset: Int, in content: String) -> Int {
        guard !content.isEmpty && offset > 0 else { return 0 }
        
        var pos = offset - 1
        
        // Skip any non-word characters
        while pos > 0 {
            let index = content.index(content.startIndex, offsetBy: pos)
            if isWordCharacter(content[index]) {
                break
            }
            pos -= 1
        }
        
        // Find start of word
        while pos > 0 {
            let prevIndex = content.index(content.startIndex, offsetBy: pos - 1)
            if !isWordCharacter(content[prevIndex]) {
                break
            }
            pos -= 1
        }
        
        return pos
    }
    
    /// Calculate position when moving right by one word
    private func calculateWordRight(from offset: Int, in content: String) -> Int {
        guard !content.isEmpty && offset < content.count else { return content.count }
        
        var pos = offset
        
        // Skip current word characters
        while pos < content.count {
            let index = content.index(content.startIndex, offsetBy: pos)
            if !isWordCharacter(content[index]) {
                break
            }
            pos += 1
        }
        
        // Skip non-word characters
        while pos < content.count {
            let index = content.index(content.startIndex, offsetBy: pos)
            if isWordCharacter(content[index]) {
                break
            }
            pos += 1
        }
        
        return pos
    }
    
    // MARK: - Private Helpers - Word Boundaries
    
    /// Check if a character is a word character (alphanumeric or underscore)
    private func isWordCharacter(_ char: Character) -> Bool {
        char.isLetter || char.isNumber || char == "_"
    }
    
    /// Find the start of the word containing the offset
    private func findWordStart(from offset: Int, in content: String) -> Int {
        guard offset > 0 else { return 0 }
        
        var pos = offset
        
        // Move backwards while on word characters
        while pos > 0 {
            let prevIndex = content.index(content.startIndex, offsetBy: pos - 1)
            if !isWordCharacter(content[prevIndex]) {
                break
            }
            pos -= 1
        }
        
        return pos
    }
    
    /// Find the end of the word containing the offset
    private func findWordEnd(from offset: Int, in content: String) -> Int {
        var pos = offset
        
        // Move forwards while on word characters
        while pos < content.count {
            let index = content.index(content.startIndex, offsetBy: pos)
            if !isWordCharacter(content[index]) {
                break
            }
            pos += 1
        }
        
        return pos
    }
}
