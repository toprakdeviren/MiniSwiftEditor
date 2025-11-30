//
//  EditingOperationsPropertyTests.swift
//  MiniSwiftEditorTests
//
//  Property-based tests for basic editing operations
//  Requirements: 6.1, 6.2, 6.3
//

import Testing
@testable import MiniSwiftEditor

/// Property-based tests for basic editing operations
/// Uses randomized inputs to verify correctness properties
struct EditingOperationsPropertyTests {
    
    // MARK: - Test Helpers
    
    /// Generate random strings for testing
    static func randomString(length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 "
        return String((0..<length).map { _ in characters.randomElement()! })
    }
    
    /// Generate a random printable character
    static func randomCharacter() -> Character {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 !@#$%^&*()_+-=[]{}|;':\",./<>?"
        return characters.randomElement()!
    }
    
    /// Generate random multi-line strings
    static func randomMultilineString(lines: Int, maxLineLength: Int) -> String {
        (0..<lines).map { _ in
            let lineLength = Int.random(in: 0...maxLineLength)
            let chars = "abcdefghijklmnopqrstuvwxyz0123456789 "
            return String((0..<lineLength).map { _ in chars.randomElement()! })
        }.joined(separator: "\n")
    }
}

// MARK: - Property 8: Character Insertion Correctness
// **Feature: code-editor, Property 8: Character Insertion Correctness**
// **Validates: Requirements 6.1**
//
// For any document, caret position, and character, inserting that character
// should result in the document containing that character at exactly that position,
// with document length increased by 1.

extension EditingOperationsPropertyTests {
    
    @Test("Property 8: Character Insertion Correctness - Single character insertion increases length by 1")
    func characterInsertion_lengthIncrease() {
        // Run 100 iterations with different random inputs
        for _ in 0..<100 {
            let initialContent = Self.randomString(length: Int.random(in: 0...200))
            let document = TextDocument(initialContent)
            let initialLength = document.content.count
            
            // Generate random caret position within valid bounds
            let caretPosition = Int.random(in: 0...initialLength)
            
            // Generate random character to insert
            let charToInsert = Self.randomCharacter()
            
            // Insert the character
            document.insert(String(charToInsert), at: caretPosition)
            
            // Verify length increased by exactly 1
            #expect(document.content.count == initialLength + 1,
                   "Length should increase by 1: was \(initialLength), now \(document.content.count)")
        }
    }
    
    @Test("Property 8: Character Insertion Correctness - Character appears at correct position")
    func characterInsertion_correctPosition() {
        for _ in 0..<100 {
            let initialContent = Self.randomString(length: Int.random(in: 0...200))
            let document = TextDocument(initialContent)
            
            // Generate random caret position within valid bounds
            let caretPosition = Int.random(in: 0...document.content.count)
            
            // Generate random character to insert
            let charToInsert = Self.randomCharacter()
            
            // Insert the character
            document.insert(String(charToInsert), at: caretPosition)
            
            // Verify the character is at the correct position
            let index = document.content.index(document.content.startIndex, offsetBy: caretPosition)
            let charAtPosition = document.content[index]
            
            #expect(charAtPosition == charToInsert,
                   "Character at position \(caretPosition) should be '\(charToInsert)', got '\(charAtPosition)'")
        }
    }
    
    @Test("Property 8: Character Insertion Correctness - Content before caret unchanged")
    func characterInsertion_contentBeforeUnchanged() {
        for _ in 0..<100 {
            let initialContent = Self.randomString(length: Int.random(in: 1...200))
            let document = TextDocument(initialContent)
            
            // Generate random caret position (at least 1 to have content before)
            let caretPosition = Int.random(in: 1...document.content.count)
            
            // Get content before caret
            let contentBefore = String(initialContent.prefix(caretPosition))
            
            // Generate random character to insert
            let charToInsert = Self.randomCharacter()
            
            // Insert the character
            document.insert(String(charToInsert), at: caretPosition)
            
            // Verify content before caret is unchanged
            let newContentBefore = String(document.content.prefix(caretPosition))
            
            #expect(newContentBefore == contentBefore,
                   "Content before caret should be unchanged")
        }
    }
    
    @Test("Property 8: Character Insertion Correctness - Content after caret shifted")
    func characterInsertion_contentAfterShifted() {
        for _ in 0..<100 {
            let initialContent = Self.randomString(length: Int.random(in: 1...200))
            let document = TextDocument(initialContent)
            
            // Generate random caret position (not at end to have content after)
            guard initialContent.count > 0 else { continue }
            let caretPosition = Int.random(in: 0..<initialContent.count)
            
            // Get content after caret
            let contentAfter = String(initialContent.dropFirst(caretPosition))
            
            // Generate random character to insert
            let charToInsert = Self.randomCharacter()
            
            // Insert the character
            document.insert(String(charToInsert), at: caretPosition)
            
            // Verify content after caret is shifted by 1 (after the inserted char)
            let newContentAfter = String(document.content.dropFirst(caretPosition + 1))
            
            #expect(newContentAfter == contentAfter,
                   "Content after caret should be shifted by 1")
        }
    }
    
    @Test("Property 8: Character Insertion Correctness - Insert at beginning")
    func characterInsertion_atBeginning() {
        for _ in 0..<100 {
            let initialContent = Self.randomString(length: Int.random(in: 0...100))
            let document = TextDocument(initialContent)
            
            let charToInsert = Self.randomCharacter()
            
            // Insert at position 0
            document.insert(String(charToInsert), at: 0)
            
            // Verify the character is at the beginning
            #expect(document.content.first == charToInsert,
                   "First character should be '\(charToInsert)'")
            
            // Verify original content follows
            let restOfContent = String(document.content.dropFirst())
            #expect(restOfContent == initialContent,
                   "Rest of content should be original content")
        }
    }
    
    @Test("Property 8: Character Insertion Correctness - Insert at end")
    func characterInsertion_atEnd() {
        for _ in 0..<100 {
            let initialContent = Self.randomString(length: Int.random(in: 0...100))
            let document = TextDocument(initialContent)
            let initialLength = initialContent.count
            
            let charToInsert = Self.randomCharacter()
            
            // Insert at end
            document.insert(String(charToInsert), at: initialLength)
            
            // Verify the character is at the end
            #expect(document.content.last == charToInsert,
                   "Last character should be '\(charToInsert)'")
            
            // Verify original content precedes
            let contentBeforeEnd = String(document.content.dropLast())
            #expect(contentBeforeEnd == initialContent,
                   "Content before end should be original content")
        }
    }
}


// MARK: - Property 9: Backspace Deletion Correctness
// **Feature: code-editor, Property 9: Backspace Deletion Correctness**
// **Validates: Requirements 6.2**
//
// For any document with length > 0 and caret position > 0, pressing backspace
// should remove exactly the character before the caret, with document length decreased by 1.

extension EditingOperationsPropertyTests {
    
    @Test("Property 9: Backspace Deletion Correctness - Length decreases by 1")
    func backspaceDeletion_lengthDecrease() {
        for _ in 0..<100 {
            // Need at least 1 character to delete
            let initialContent = Self.randomString(length: Int.random(in: 1...200))
            let document = TextDocument(initialContent)
            let initialLength = document.content.count
            
            // Caret must be > 0 to have a character before it
            let caretPosition = Int.random(in: 1...initialLength)
            
            // Simulate backspace: delete the character before caret
            document.delete(range: (caretPosition - 1)..<caretPosition)
            
            // Verify length decreased by exactly 1
            #expect(document.content.count == initialLength - 1,
                   "Length should decrease by 1: was \(initialLength), now \(document.content.count)")
        }
    }
    
    @Test("Property 9: Backspace Deletion Correctness - Correct character removed")
    func backspaceDeletion_correctCharacterRemoved() {
        for _ in 0..<100 {
            let initialContent = Self.randomString(length: Int.random(in: 2...200))
            let document = TextDocument(initialContent)
            
            // Caret must be > 0 to have a character before it
            let caretPosition = Int.random(in: 1...initialContent.count)
            
            // Get the character that should be removed
            let charIndex = initialContent.index(initialContent.startIndex, offsetBy: caretPosition - 1)
            let charToRemove = initialContent[charIndex]
            
            // Get expected content after deletion
            var expectedContent = initialContent
            expectedContent.remove(at: charIndex)
            
            // Simulate backspace
            document.delete(range: (caretPosition - 1)..<caretPosition)
            
            // Verify the correct character was removed
            #expect(document.content == expectedContent,
                   "Content after backspace should match expected. Removed '\(charToRemove)' at position \(caretPosition - 1)")
        }
    }
    
    @Test("Property 9: Backspace Deletion Correctness - Content before deletion point unchanged")
    func backspaceDeletion_contentBeforeUnchanged() {
        for _ in 0..<100 {
            let initialContent = Self.randomString(length: Int.random(in: 2...200))
            let document = TextDocument(initialContent)
            
            // Caret must be > 1 to have content before the deleted character
            guard initialContent.count > 1 else { continue }
            let caretPosition = Int.random(in: 2...initialContent.count)
            
            // Get content before the character to be deleted
            let contentBefore = String(initialContent.prefix(caretPosition - 1))
            
            // Simulate backspace
            document.delete(range: (caretPosition - 1)..<caretPosition)
            
            // Verify content before deletion point is unchanged
            let newContentBefore = String(document.content.prefix(caretPosition - 1))
            
            #expect(newContentBefore == contentBefore,
                   "Content before deletion point should be unchanged")
        }
    }
    
    @Test("Property 9: Backspace Deletion Correctness - Content after deletion point shifted")
    func backspaceDeletion_contentAfterShifted() {
        for _ in 0..<100 {
            let initialContent = Self.randomString(length: Int.random(in: 2...200))
            let document = TextDocument(initialContent)
            
            // Caret must be > 0 and < length to have content after
            guard initialContent.count > 1 else { continue }
            let caretPosition = Int.random(in: 1..<initialContent.count)
            
            // Get content after the caret (which should remain after deletion)
            let contentAfter = String(initialContent.dropFirst(caretPosition))
            
            // Simulate backspace
            document.delete(range: (caretPosition - 1)..<caretPosition)
            
            // Verify content after is now at position (caretPosition - 1)
            let newContentAfter = String(document.content.dropFirst(caretPosition - 1))
            
            #expect(newContentAfter == contentAfter,
                   "Content after caret should be shifted left by 1")
        }
    }
    
    @Test("Property 9: Backspace Deletion Correctness - Delete at position 1")
    func backspaceDeletion_atPosition1() {
        for _ in 0..<100 {
            let initialContent = Self.randomString(length: Int.random(in: 1...100))
            let document = TextDocument(initialContent)
            
            // Delete first character (backspace at position 1)
            document.delete(range: 0..<1)
            
            // Verify first character is removed
            let expectedContent = String(initialContent.dropFirst())
            #expect(document.content == expectedContent,
                   "First character should be removed")
        }
    }
    
    @Test("Property 9: Backspace Deletion Correctness - Delete at end")
    func backspaceDeletion_atEnd() {
        for _ in 0..<100 {
            let initialContent = Self.randomString(length: Int.random(in: 1...100))
            let document = TextDocument(initialContent)
            let length = initialContent.count
            
            // Delete last character (backspace at end)
            document.delete(range: (length - 1)..<length)
            
            // Verify last character is removed
            let expectedContent = String(initialContent.dropLast())
            #expect(document.content == expectedContent,
                   "Last character should be removed")
        }
    }
}

// MARK: - Property 10: Forward Delete Correctness
// **Feature: code-editor, Property 10: Forward Delete Correctness**
// **Validates: Requirements 6.3**
//
// For any document and caret position < document.length, pressing delete
// should remove exactly the character after the caret, with document length decreased by 1.

extension EditingOperationsPropertyTests {
    
    @Test("Property 10: Forward Delete Correctness - Length decreases by 1")
    func forwardDelete_lengthDecrease() {
        for _ in 0..<100 {
            // Need at least 1 character to delete
            let initialContent = Self.randomString(length: Int.random(in: 1...200))
            let document = TextDocument(initialContent)
            let initialLength = document.content.count
            
            // Caret must be < length to have a character after it
            let caretPosition = Int.random(in: 0..<initialLength)
            
            // Simulate forward delete: delete the character at caret position
            document.delete(range: caretPosition..<(caretPosition + 1))
            
            // Verify length decreased by exactly 1
            #expect(document.content.count == initialLength - 1,
                   "Length should decrease by 1: was \(initialLength), now \(document.content.count)")
        }
    }
    
    @Test("Property 10: Forward Delete Correctness - Correct character removed")
    func forwardDelete_correctCharacterRemoved() {
        for _ in 0..<100 {
            let initialContent = Self.randomString(length: Int.random(in: 1...200))
            let document = TextDocument(initialContent)
            
            // Caret must be < length to have a character after it
            let caretPosition = Int.random(in: 0..<initialContent.count)
            
            // Get the character that should be removed
            let charIndex = initialContent.index(initialContent.startIndex, offsetBy: caretPosition)
            let charToRemove = initialContent[charIndex]
            
            // Get expected content after deletion
            var expectedContent = initialContent
            expectedContent.remove(at: charIndex)
            
            // Simulate forward delete
            document.delete(range: caretPosition..<(caretPosition + 1))
            
            // Verify the correct character was removed
            #expect(document.content == expectedContent,
                   "Content after forward delete should match expected. Removed '\(charToRemove)' at position \(caretPosition)")
        }
    }
    
    @Test("Property 10: Forward Delete Correctness - Content before caret unchanged")
    func forwardDelete_contentBeforeUnchanged() {
        for _ in 0..<100 {
            let initialContent = Self.randomString(length: Int.random(in: 2...200))
            let document = TextDocument(initialContent)
            
            // Caret must be > 0 to have content before, and < length to delete
            guard initialContent.count > 1 else { continue }
            let caretPosition = Int.random(in: 1..<initialContent.count)
            
            // Get content before the caret
            let contentBefore = String(initialContent.prefix(caretPosition))
            
            // Simulate forward delete
            document.delete(range: caretPosition..<(caretPosition + 1))
            
            // Verify content before caret is unchanged
            let newContentBefore = String(document.content.prefix(caretPosition))
            
            #expect(newContentBefore == contentBefore,
                   "Content before caret should be unchanged")
        }
    }
    
    @Test("Property 10: Forward Delete Correctness - Content after deleted char shifted")
    func forwardDelete_contentAfterShifted() {
        for _ in 0..<100 {
            let initialContent = Self.randomString(length: Int.random(in: 2...200))
            let document = TextDocument(initialContent)
            
            // Caret must be < length - 1 to have content after the deleted char
            guard initialContent.count > 1 else { continue }
            let caretPosition = Int.random(in: 0..<(initialContent.count - 1))
            
            // Get content after the character to be deleted
            let contentAfterDeleted = String(initialContent.dropFirst(caretPosition + 1))
            
            // Simulate forward delete
            document.delete(range: caretPosition..<(caretPosition + 1))
            
            // Verify content after deleted char is now at caret position
            let newContentAfter = String(document.content.dropFirst(caretPosition))
            
            #expect(newContentAfter == contentAfterDeleted,
                   "Content after deleted char should be shifted left by 1")
        }
    }
    
    @Test("Property 10: Forward Delete Correctness - Delete at position 0")
    func forwardDelete_atPosition0() {
        for _ in 0..<100 {
            let initialContent = Self.randomString(length: Int.random(in: 1...100))
            let document = TextDocument(initialContent)
            
            // Delete first character (forward delete at position 0)
            document.delete(range: 0..<1)
            
            // Verify first character is removed
            let expectedContent = String(initialContent.dropFirst())
            #expect(document.content == expectedContent,
                   "First character should be removed")
        }
    }
    
    @Test("Property 10: Forward Delete Correctness - Delete last character")
    func forwardDelete_lastCharacter() {
        for _ in 0..<100 {
            let initialContent = Self.randomString(length: Int.random(in: 1...100))
            let document = TextDocument(initialContent)
            let length = initialContent.count
            
            // Delete last character (forward delete at position length - 1)
            document.delete(range: (length - 1)..<length)
            
            // Verify last character is removed
            let expectedContent = String(initialContent.dropLast())
            #expect(document.content == expectedContent,
                   "Last character should be removed")
        }
    }
}
