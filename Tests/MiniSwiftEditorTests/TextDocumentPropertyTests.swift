//
//  TextDocumentPropertyTests.swift
//  MiniSwiftEditorTests
//
//  Property-based tests for TextDocument
//

import Testing
@testable import MiniSwiftEditor

/// Property-based tests for TextDocument implementation
/// Uses randomized inputs to verify correctness properties
struct TextDocumentPropertyTests {
    
    // MARK: - Test Helpers
    
    /// Generate random strings for testing
    static func randomString(length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 \n\t"
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
    
    /// Generate random content with various Unicode characters
    static func randomUnicodeString(length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyz0123456789 \n\t日本語中文한국어émojis🎉🚀"
        return String((0..<length).map { _ in characters.randomElement()! })
    }
}

// MARK: - Property 3: Document Serialization Round-Trip
// **Feature: code-editor, Property 3: Document Serialization Round-Trip**
// **Validates: Requirements 1.5, 1.6**
//
// For any valid TextDocument, serializing and then deserializing should produce
// an equivalent document with identical content and structure.

extension TextDocumentPropertyTests {
    
    @Test("Property 3: Document Serialization Round-Trip - Basic content preservation")
    func serializationRoundTrip_basicContent() throws {
        // Run 100 iterations with different random inputs
        for _ in 0..<100 {
            let content = Self.randomString(length: Int.random(in: 0...500))
            let document = TextDocument(content)
            
            // Serialize then deserialize
            let serialized = try document.serialize()
            let restored = try TextDocument.deserialize(from: serialized)
            
            // Verify content is identical
            #expect(restored.content == document.content,
                   "Content mismatch after round-trip: expected '\(document.content)', got '\(restored.content)'")
        }
    }
    
    @Test("Property 3: Document Serialization Round-Trip - Multi-line content")
    func serializationRoundTrip_multilineContent() throws {
        for _ in 0..<100 {
            let lineCount = Int.random(in: 1...50)
            let content = Self.randomMultilineString(lines: lineCount, maxLineLength: 80)
            let document = TextDocument(content)
            
            // Serialize then deserialize
            let serialized = try document.serialize()
            let restored = try TextDocument.deserialize(from: serialized)
            
            // Verify content is identical
            #expect(restored.content == document.content,
                   "Multi-line content mismatch after round-trip")
            
            // Verify line count is preserved
            #expect(restored.lineCount == document.lineCount,
                   "Line count mismatch: expected \(document.lineCount), got \(restored.lineCount)")
        }
    }
    
    @Test("Property 3: Document Serialization Round-Trip - String serialization")
    func serializationRoundTrip_stringFormat() throws {
        for _ in 0..<100 {
            let content = Self.randomString(length: Int.random(in: 0...300))
            let document = TextDocument(content)
            
            // Serialize to string then deserialize
            let serializedString = try document.serializeToString()
            let restored = try TextDocument.deserialize(from: serializedString)
            
            // Verify content is identical
            #expect(restored.content == document.content,
                   "Content mismatch after string round-trip")
        }
    }
    
    @Test("Property 3: Document Serialization Round-Trip - Empty document")
    func serializationRoundTrip_emptyDocument() throws {
        for _ in 0..<100 {
            let document = TextDocument("")
            
            // Serialize then deserialize
            let serialized = try document.serialize()
            let restored = try TextDocument.deserialize(from: serialized)
            
            // Verify empty content is preserved
            #expect(restored.content == "",
                   "Empty document should remain empty after round-trip")
            #expect(restored.lineCount == 1,
                   "Empty document should have 1 line")
        }
    }
    
    @Test("Property 3: Document Serialization Round-Trip - After edits")
    func serializationRoundTrip_afterEdits() throws {
        for _ in 0..<100 {
            let initialContent = Self.randomString(length: Int.random(in: 10...100))
            let document = TextDocument(initialContent)
            
            // Perform some edits
            let editCount = Int.random(in: 1...5)
            for _ in 0..<editCount {
                if Bool.random() && document.content.count > 0 {
                    // Insert
                    let offset = Int.random(in: 0...document.content.count)
                    let text = Self.randomString(length: Int.random(in: 1...10))
                    document.insert(text, at: offset)
                } else if document.content.count > 1 {
                    // Delete
                    let start = Int.random(in: 0..<document.content.count - 1)
                    let end = Int.random(in: (start + 1)...min(start + 5, document.content.count))
                    document.delete(range: start..<end)
                }
            }
            
            // Serialize then deserialize
            let serialized = try document.serialize()
            let restored = try TextDocument.deserialize(from: serialized)
            
            // Verify content is identical after edits
            #expect(restored.content == document.content,
                   "Content mismatch after edits and round-trip")
        }
    }
    
    @Test("Property 3: Document Serialization Round-Trip - Special characters")
    func serializationRoundTrip_specialCharacters() throws {
        // Test with various special characters that might cause JSON encoding issues
        let specialContents = [
            "Hello\nWorld",
            "Tab\there",
            "Quote\"test",
            "Backslash\\test",
            "Unicode: 日本語",
            "Emoji: 🎉🚀",
            "Mixed: Hello\n\tWorld \"test\" 日本語 🎉",
            "Newlines:\n\n\n",
            "Carriage return:\r\n",
        ]
        
        for content in specialContents {
            let document = TextDocument(content)
            
            // Serialize then deserialize
            let serialized = try document.serialize()
            let restored = try TextDocument.deserialize(from: serialized)
            
            // Verify content is identical
            #expect(restored.content == document.content,
                   "Special character content mismatch: expected '\(document.content)', got '\(restored.content)'")
        }
    }
    
    @Test("Property 3: Document Serialization Round-Trip - Unicode content")
    func serializationRoundTrip_unicodeContent() throws {
        for _ in 0..<100 {
            let content = Self.randomUnicodeString(length: Int.random(in: 0...200))
            let document = TextDocument(content)
            
            // Serialize then deserialize
            let serialized = try document.serialize()
            let restored = try TextDocument.deserialize(from: serialized)
            
            // Verify content is identical
            #expect(restored.content == document.content,
                   "Unicode content mismatch after round-trip")
        }
    }
    
    @Test("Property 3: Document Serialization Round-Trip - DocumentData equivalence")
    func serializationRoundTrip_documentDataEquivalence() throws {
        for _ in 0..<100 {
            let content = Self.randomString(length: Int.random(in: 0...300))
            let document = TextDocument(content)
            
            // Get document data before serialization
            let originalData = document.toDocumentData()
            
            // Serialize then deserialize
            let serialized = try document.serialize()
            let restored = try TextDocument.deserialize(from: serialized)
            let restoredData = restored.toDocumentData()
            
            // Verify document data content is equivalent
            #expect(restoredData.content == originalData.content,
                   "DocumentData content mismatch after round-trip")
        }
    }
}
