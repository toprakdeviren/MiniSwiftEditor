//
//  SelectionManagerPropertyTests.swift
//  MiniSwiftEditorTests
//
//  Property-based tests for SelectionManager
//  Requirements: 6.4, 6.5, 6.6, 6.7
//

import Foundation
import Testing
@testable import MiniSwiftEditor

/// Property-based tests for SelectionManager
/// Uses randomized inputs to verify correctness properties
struct SelectionManagerPropertyTests {
    
    // MARK: - Test Helpers
    
    /// Generate random strings for testing
    static func randomString(length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 "
        return String((0..<length).map { _ in characters.randomElement()! })
    }
    
    /// Generate random multi-line strings
    static func randomMultilineString(lines: Int, maxLineLength: Int) -> String {
        (0..<lines).map { _ in
            let lineLength = Int.random(in: 0...maxLineLength)
            let chars = "abcdefghijklmnopqrstuvwxyz0123456789 "
            return String((0..<lineLength).map { _ in chars.randomElement()! })
        }.joined(separator: "\n")
    }
    
    /// Generate random string with words (for word selection tests)
    static func randomStringWithWords(wordCount: Int, maxWordLength: Int) -> String {
        let words = (0..<wordCount).map { _ in
            let wordLength = Int.random(in: 1...maxWordLength)
            let chars = "abcdefghijklmnopqrstuvwxyz"
            return String((0..<wordLength).map { _ in chars.randomElement()! })
        }
        return words.joined(separator: " ")
    }
    
    /// Get all directions for testing
    static var allDirections: [Direction] {
        [.left, .right, .up, .down, .lineStart, .lineEnd, .documentStart, .documentEnd, .wordLeft, .wordRight]
    }
}


// MARK: - Property 11: Caret Movement Bounds
// **Feature: code-editor, Property 11: Caret Movement Bounds**
// **Validates: Requirements 6.4**
//
// For any document and caret position, moving the caret in any direction
// should result in a valid position within document bounds (0 <= position <= document.length).

extension SelectionManagerPropertyTests {
    
    @Test("Property 11: Caret Movement Bounds - All directions stay within bounds")
    func caretMovement_staysWithinBounds() {
        // Run 100 iterations with different random inputs
        for _ in 0..<100 {
            // Generate random multi-line content
            let lineCount = Int.random(in: 1...10)
            let content = Self.randomMultilineString(lines: lineCount, maxLineLength: 50)
            let document = TextDocument(content)
            let documentLength = document.content.count
            
            let selectionManager = SelectionManager(document: document)
            
            // Generate random starting position
            let startPosition = Int.random(in: 0...documentLength)
            selectionManager.setSelection(Selection(anchor: startPosition, head: startPosition))
            
            // Test all directions
            for direction in Self.allDirections {
                // Reset to start position
                selectionManager.setSelection(Selection(anchor: startPosition, head: startPosition))
                
                // Move caret (not extending)
                selectionManager.moveCaret(direction: direction, extending: false)
                
                // Verify position is within bounds
                let newPosition = selectionManager.selection.head
                #expect(newPosition >= 0,
                       "Position should be >= 0 after moving \(direction), got \(newPosition)")
                #expect(newPosition <= documentLength,
                       "Position should be <= \(documentLength) after moving \(direction), got \(newPosition)")
            }
        }
    }
    
    @Test("Property 11: Caret Movement Bounds - Extending selection stays within bounds")
    func caretMovement_extendingStaysWithinBounds() {
        for _ in 0..<100 {
            let lineCount = Int.random(in: 1...10)
            let content = Self.randomMultilineString(lines: lineCount, maxLineLength: 50)
            let document = TextDocument(content)
            let documentLength = document.content.count
            
            let selectionManager = SelectionManager(document: document)
            
            // Generate random starting position
            let startPosition = Int.random(in: 0...documentLength)
            selectionManager.setSelection(Selection(anchor: startPosition, head: startPosition))
            
            // Test all directions with extending
            for direction in Self.allDirections {
                // Reset to start position
                selectionManager.setSelection(Selection(anchor: startPosition, head: startPosition))
                
                // Move caret (extending selection)
                selectionManager.moveCaret(direction: direction, extending: true)
                
                // Verify both anchor and head are within bounds
                let anchor = selectionManager.selection.anchor
                let head = selectionManager.selection.head
                
                #expect(anchor >= 0 && anchor <= documentLength,
                       "Anchor should be within bounds after extending \(direction)")
                #expect(head >= 0 && head <= documentLength,
                       "Head should be within bounds after extending \(direction)")
            }
        }
    }
    
    @Test("Property 11: Caret Movement Bounds - Left at position 0 stays at 0")
    func caretMovement_leftAtZeroStaysAtZero() {
        for _ in 0..<100 {
            let content = Self.randomString(length: Int.random(in: 0...100))
            let document = TextDocument(content)
            let selectionManager = SelectionManager(document: document)
            
            // Start at position 0
            selectionManager.setSelection(Selection(anchor: 0, head: 0))
            
            // Move left
            selectionManager.moveCaret(direction: .left, extending: false)
            
            // Should stay at 0
            #expect(selectionManager.selection.head == 0,
                   "Moving left at position 0 should stay at 0")
        }
    }
    
    @Test("Property 11: Caret Movement Bounds - Right at end stays at end")
    func caretMovement_rightAtEndStaysAtEnd() {
        for _ in 0..<100 {
            let content = Self.randomString(length: Int.random(in: 0...100))
            let document = TextDocument(content)
            let documentLength = document.content.count
            let selectionManager = SelectionManager(document: document)
            
            // Start at end
            selectionManager.setSelection(Selection(anchor: documentLength, head: documentLength))
            
            // Move right
            selectionManager.moveCaret(direction: .right, extending: false)
            
            // Should stay at end
            #expect(selectionManager.selection.head == documentLength,
                   "Moving right at end should stay at end")
        }
    }
    
    @Test("Property 11: Caret Movement Bounds - Document start always goes to 0")
    func caretMovement_documentStartGoesToZero() {
        for _ in 0..<100 {
            let content = Self.randomString(length: Int.random(in: 0...100))
            let document = TextDocument(content)
            let documentLength = document.content.count
            let selectionManager = SelectionManager(document: document)
            
            // Start at random position
            let startPosition = Int.random(in: 0...documentLength)
            selectionManager.setSelection(Selection(anchor: startPosition, head: startPosition))
            
            // Move to document start
            selectionManager.moveCaret(direction: .documentStart, extending: false)
            
            // Should be at 0
            #expect(selectionManager.selection.head == 0,
                   "Document start should go to position 0")
        }
    }
    
    @Test("Property 11: Caret Movement Bounds - Document end always goes to length")
    func caretMovement_documentEndGoesToLength() {
        for _ in 0..<100 {
            let content = Self.randomString(length: Int.random(in: 0...100))
            let document = TextDocument(content)
            let documentLength = document.content.count
            let selectionManager = SelectionManager(document: document)
            
            // Start at random position
            let startPosition = Int.random(in: 0...documentLength)
            selectionManager.setSelection(Selection(anchor: startPosition, head: startPosition))
            
            // Move to document end
            selectionManager.moveCaret(direction: .documentEnd, extending: false)
            
            // Should be at document length
            #expect(selectionManager.selection.head == documentLength,
                   "Document end should go to position \(documentLength)")
        }
    }
    
    @Test("Property 11: Caret Movement Bounds - Multiple movements stay within bounds")
    func caretMovement_multipleMovementsStayWithinBounds() {
        for _ in 0..<100 {
            let lineCount = Int.random(in: 1...10)
            let content = Self.randomMultilineString(lines: lineCount, maxLineLength: 50)
            let document = TextDocument(content)
            let documentLength = document.content.count
            let selectionManager = SelectionManager(document: document)
            
            // Start at random position
            let startPosition = Int.random(in: 0...documentLength)
            selectionManager.setSelection(Selection(anchor: startPosition, head: startPosition))
            
            // Perform multiple random movements
            for _ in 0..<20 {
                let direction = Self.allDirections.randomElement()!
                let extending = Bool.random()
                
                selectionManager.moveCaret(direction: direction, extending: extending)
                
                // Verify bounds after each movement
                let head = selectionManager.selection.head
                let anchor = selectionManager.selection.anchor
                
                #expect(head >= 0 && head <= documentLength,
                       "Head should be within bounds after movement")
                #expect(anchor >= 0 && anchor <= documentLength,
                       "Anchor should be within bounds after movement")
            }
        }
    }
}


// MARK: - Property 12: Word Selection Boundaries
// **Feature: code-editor, Property 12: Word Selection Boundaries**
// **Validates: Requirements 6.6**
//
// For any document and position within a word, double-click selection should select
// exactly the word boundaries (from word start to word end, where word is defined
// as contiguous alphanumeric characters).

extension SelectionManagerPropertyTests {
    
    @Test("Property 12: Word Selection Boundaries - Selects contiguous alphanumeric characters")
    func wordSelection_selectsContiguousAlphanumeric() {
        for _ in 0..<100 {
            // Generate content with words
            let content = Self.randomStringWithWords(wordCount: Int.random(in: 1...10), maxWordLength: 10)
            let document = TextDocument(content)
            let selectionManager = SelectionManager(document: document)
            
            guard !content.isEmpty else { continue }
            
            // Find a position within a word
            let words = content.split(separator: " ", omittingEmptySubsequences: false)
            var offset = 0
            
            for word in words {
                if !word.isEmpty {
                    // Click somewhere in this word
                    let positionInWord = offset + Int.random(in: 0..<word.count)
                    
                    selectionManager.selectWord(at: positionInWord)
                    
                    let selection = selectionManager.selection
                    let selectedText = String(content[content.index(content.startIndex, offsetBy: selection.anchor)..<content.index(content.startIndex, offsetBy: selection.head)])
                    
                    // Verify the selected text is the word
                    #expect(selectedText == String(word),
                           "Selected text '\(selectedText)' should equal word '\(word)'")
                    
                    break // Test one word per iteration
                }
                offset += word.count + 1 // +1 for space
            }
        }
    }
    
    @Test("Property 12: Word Selection Boundaries - Selection starts at word boundary")
    func wordSelection_startsAtWordBoundary() {
        for _ in 0..<100 {
            let content = Self.randomStringWithWords(wordCount: Int.random(in: 2...8), maxWordLength: 8)
            let document = TextDocument(content)
            let selectionManager = SelectionManager(document: document)
            
            guard content.count > 1 else { continue }
            
            // Find a word character position
            for (index, char) in content.enumerated() {
                if char.isLetter || char.isNumber {
                    selectionManager.selectWord(at: index)
                    
                    let anchor = selectionManager.selection.anchor
                    
                    // Character before anchor should not be a word character (or anchor is at start)
                    if anchor > 0 {
                        let prevIndex = content.index(content.startIndex, offsetBy: anchor - 1)
                        let prevChar = content[prevIndex]
                        #expect(!prevChar.isLetter && !prevChar.isNumber && prevChar != "_",
                               "Character before word start should not be a word character")
                    }
                    
                    break
                }
            }
        }
    }
    
    @Test("Property 12: Word Selection Boundaries - Selection ends at word boundary")
    func wordSelection_endsAtWordBoundary() {
        for _ in 0..<100 {
            let content = Self.randomStringWithWords(wordCount: Int.random(in: 2...8), maxWordLength: 8)
            let document = TextDocument(content)
            let selectionManager = SelectionManager(document: document)
            
            guard content.count > 1 else { continue }
            
            // Find a word character position
            for (index, char) in content.enumerated() {
                if char.isLetter || char.isNumber {
                    selectionManager.selectWord(at: index)
                    
                    let head = selectionManager.selection.head
                    
                    // Character at head should not be a word character (or head is at end)
                    if head < content.count {
                        let nextIndex = content.index(content.startIndex, offsetBy: head)
                        let nextChar = content[nextIndex]
                        #expect(!nextChar.isLetter && !nextChar.isNumber && nextChar != "_",
                               "Character at word end should not be a word character")
                    }
                    
                    break
                }
            }
        }
    }
    
    @Test("Property 12: Word Selection Boundaries - All selected characters are word characters")
    func wordSelection_allSelectedAreWordCharacters() {
        for _ in 0..<100 {
            let content = Self.randomStringWithWords(wordCount: Int.random(in: 2...8), maxWordLength: 8)
            let document = TextDocument(content)
            let selectionManager = SelectionManager(document: document)
            
            guard content.count > 1 else { continue }
            
            // Find a word character position
            for (index, char) in content.enumerated() {
                if char.isLetter || char.isNumber {
                    selectionManager.selectWord(at: index)
                    
                    let selection = selectionManager.selection
                    let startIndex = content.index(content.startIndex, offsetBy: selection.anchor)
                    let endIndex = content.index(content.startIndex, offsetBy: selection.head)
                    let selectedText = String(content[startIndex..<endIndex])
                    
                    // All characters in selection should be word characters
                    for selectedChar in selectedText {
                        #expect(selectedChar.isLetter || selectedChar.isNumber || selectedChar == "_",
                               "All selected characters should be word characters, found '\(selectedChar)'")
                    }
                    
                    break
                }
            }
        }
    }
    
    @Test("Property 12: Word Selection Boundaries - Clicking on space selects space")
    func wordSelection_clickingOnSpaceSelectsSpace() {
        for _ in 0..<100 {
            let content = Self.randomStringWithWords(wordCount: Int.random(in: 3...8), maxWordLength: 5)
            let document = TextDocument(content)
            let selectionManager = SelectionManager(document: document)
            
            // Find a space position
            for (index, char) in content.enumerated() {
                if char == " " {
                    selectionManager.selectWord(at: index)
                    
                    let selection = selectionManager.selection
                    
                    // Selection should be exactly 1 character (the space)
                    #expect(selection.head - selection.anchor == 1,
                           "Clicking on space should select exactly 1 character")
                    
                    break
                }
            }
        }
    }
}


// MARK: - Property 13: Line Selection Completeness
// **Feature: code-editor, Property 13: Line Selection Completeness**
// **Validates: Requirements 6.7**
//
// For any document and position on a line, triple-click selection should select
// the entire line including the newline character (if present).

extension SelectionManagerPropertyTests {
    
    @Test("Property 13: Line Selection Completeness - Selects entire line content")
    func lineSelection_selectsEntireLineContent() {
        for _ in 0..<100 {
            let lineCount = Int.random(in: 1...10)
            let content = Self.randomMultilineString(lines: lineCount, maxLineLength: 30)
            let document = TextDocument(content)
            let selectionManager = SelectionManager(document: document)
            
            guard !content.isEmpty else { continue }
            
            // Split into lines
            let lines = content.components(separatedBy: "\n")
            
            // Select a random line
            let lineIndex = Int.random(in: 0..<lines.count)
            
            selectionManager.selectLine(at: lineIndex)
            
            let selection = selectionManager.selection
            let startIndex = content.index(content.startIndex, offsetBy: selection.anchor)
            let endIndex = content.index(content.startIndex, offsetBy: selection.head)
            let selectedText = String(content[startIndex..<endIndex])
            
            // The selected text should contain the line content
            let lineContent = lines[lineIndex]
            #expect(selectedText.hasPrefix(lineContent),
                   "Selected text should start with line content '\(lineContent)', got '\(selectedText)'")
        }
    }
    
    @Test("Property 13: Line Selection Completeness - Includes newline for non-last lines")
    func lineSelection_includesNewlineForNonLastLines() {
        for _ in 0..<100 {
            let lineCount = Int.random(in: 2...10)
            let content = Self.randomMultilineString(lines: lineCount, maxLineLength: 30)
            let document = TextDocument(content)
            let selectionManager = SelectionManager(document: document)
            
            let lines = content.components(separatedBy: "\n")
            
            // Select a non-last line
            let lineIndex = Int.random(in: 0..<(lines.count - 1))
            
            selectionManager.selectLine(at: lineIndex)
            
            let selection = selectionManager.selection
            let startIndex = content.index(content.startIndex, offsetBy: selection.anchor)
            let endIndex = content.index(content.startIndex, offsetBy: selection.head)
            let selectedText = String(content[startIndex..<endIndex])
            
            // Should include the newline character
            #expect(selectedText.hasSuffix("\n"),
                   "Selection of non-last line should include newline character")
        }
    }
    
    @Test("Property 13: Line Selection Completeness - Selection starts at line beginning")
    func lineSelection_startsAtLineBeginning() {
        for _ in 0..<100 {
            let lineCount = Int.random(in: 1...10)
            let content = Self.randomMultilineString(lines: lineCount, maxLineLength: 30)
            let document = TextDocument(content)
            let selectionManager = SelectionManager(document: document)
            
            guard !content.isEmpty else { continue }
            
            let lines = content.components(separatedBy: "\n")
            let lineIndex = Int.random(in: 0..<lines.count)
            
            // Calculate expected line start
            var expectedStart = 0
            for i in 0..<lineIndex {
                expectedStart += lines[i].count + 1 // +1 for newline
            }
            
            selectionManager.selectLine(at: lineIndex)
            
            #expect(selectionManager.selection.anchor == expectedStart,
                   "Selection should start at line beginning \(expectedStart), got \(selectionManager.selection.anchor)")
        }
    }
    
    @Test("Property 13: Line Selection Completeness - Selection length matches line length plus newline")
    func lineSelection_lengthMatchesLineWithNewline() {
        for _ in 0..<100 {
            let lineCount = Int.random(in: 2...10)
            let content = Self.randomMultilineString(lines: lineCount, maxLineLength: 30)
            let document = TextDocument(content)
            let selectionManager = SelectionManager(document: document)
            
            let lines = content.components(separatedBy: "\n")
            
            // Select a non-last line
            let lineIndex = Int.random(in: 0..<(lines.count - 1))
            
            selectionManager.selectLine(at: lineIndex)
            
            let selection = selectionManager.selection
            let selectionLength = selection.head - selection.anchor
            let expectedLength = lines[lineIndex].count + 1 // +1 for newline
            
            #expect(selectionLength == expectedLength,
                   "Selection length should be \(expectedLength), got \(selectionLength)")
        }
    }
    
    @Test("Property 13: Line Selection Completeness - Last line selection does not include trailing newline")
    func lineSelection_lastLineNoTrailingNewline() {
        for _ in 0..<100 {
            let lineCount = Int.random(in: 1...10)
            let content = Self.randomMultilineString(lines: lineCount, maxLineLength: 30)
            let document = TextDocument(content)
            let selectionManager = SelectionManager(document: document)
            
            let lines = content.components(separatedBy: "\n")
            let lastLineIndex = lines.count - 1
            
            selectionManager.selectLine(at: lastLineIndex)
            
            let selection = selectionManager.selection
            let selectionLength = selection.head - selection.anchor
            let expectedLength = lines[lastLineIndex].count
            
            #expect(selectionLength == expectedLength,
                   "Last line selection length should be \(expectedLength), got \(selectionLength)")
        }
    }
    
    @Test("Property 13: Line Selection Completeness - selectLineContaining works correctly")
    func lineSelection_selectLineContainingWorks() {
        for _ in 0..<100 {
            let lineCount = Int.random(in: 2...10)
            let content = Self.randomMultilineString(lines: lineCount, maxLineLength: 30)
            let document = TextDocument(content)
            let selectionManager = SelectionManager(document: document)
            
            guard content.count > 0 else { continue }
            
            // Pick a random offset
            let offset = Int.random(in: 0..<content.count)
            
            // Select line containing that offset
            selectionManager.selectLineContaining(offset: offset)
            
            let selection = selectionManager.selection
            
            // The offset should be within the selection
            #expect(offset >= selection.anchor && offset < selection.head,
                   "Offset \(offset) should be within selection \(selection.anchor)..<\(selection.head)")
        }
    }
}
