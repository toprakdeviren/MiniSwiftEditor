//
//  SwiftTokenizerIncrementalTests.swift
//  MiniSwiftEditorTests
//
//  Tests for incremental tokenization
//

import Testing
@testable import MiniSwiftEditor

struct SwiftTokenizerIncrementalTests {
    
    @Test("Incremental tokenization produces same result as full tokenization - Replacement")
    func incrementalTokenization_replacement() {
        let tokenizer = SwiftTokenizer()
        let initialContent = "func test() {\n    let x = 42\n}"
        let buffer = StringBuffer(initialContent)
        
        // Initial tokenization
        _ = tokenizer.tokenize(document: buffer, changedRange: nil, delta: nil)
        
        // Modify buffer: change "42" to "100"
        // "func test() {\n    let x = " -> length 24
        // "42" -> length 2
        // Change: replace range 24..<26 with "100" (length 3). Delta +1.
        
        let replaceRange = 24..<26
        let replacement = "100"
        buffer.delete(range: replaceRange)
        buffer.insert(replacement, at: replaceRange.lowerBound)
        
        // Incremental tokenization
        // changedRange in new document: 24..<27
        let changedRange = 24..<27
        let delta = 1
        
        let incrementalTokens = tokenizer.tokenize(document: buffer, changedRange: changedRange, delta: delta)
        
        // Full tokenization for comparison
        let fullTokenizer = SwiftTokenizer()
        let fullTokens = fullTokenizer.tokenize(document: buffer, changedRange: nil, delta: nil)
        
        #expect(incrementalTokens == fullTokens, "Incremental tokens should match full tokens")
    }
    
    @Test("Incremental tokenization produces same result as full tokenization - Insertion")
    func incrementalTokenization_insertion() {
        let tokenizer = SwiftTokenizer()
        let initialContent = "func test() {}"
        let buffer = StringBuffer(initialContent)
        
        // Initial tokenization
        _ = tokenizer.tokenize(document: buffer, changedRange: nil, delta: nil)
        
        // Insert " var x = 1" at index 12 (before '}')
        let insertIndex = 12
        let insertion = " var x = 1"
        buffer.insert(insertion, at: insertIndex)
        
        // Incremental tokenization
        // changedRange in new document: 12..<22 (length 10)
        let changedRange = 12..<22
        let delta = 10
        
        let incrementalTokens = tokenizer.tokenize(document: buffer, changedRange: changedRange, delta: delta)
        
        // Full tokenization for comparison
        let fullTokenizer = SwiftTokenizer()
        let fullTokens = fullTokenizer.tokenize(document: buffer, changedRange: nil, delta: nil)
        
        #expect(incrementalTokens == fullTokens, "Incremental tokens should match full tokens")
    }
    
    @Test("Incremental tokenization produces same result as full tokenization - Deletion")
    func incrementalTokenization_deletion() {
        let tokenizer = SwiftTokenizer()
        let initialContent = "func test() { var x = 1 }"
        let buffer = StringBuffer(initialContent)
        
        // Initial tokenization
        _ = tokenizer.tokenize(document: buffer, changedRange: nil, delta: nil)
        
        // Delete " var x = 1" (range 12..<22)
        let deleteRange = 12..<22
        buffer.delete(range: deleteRange)
        
        // Incremental tokenization
        // changedRange in new document: 12..<12 (empty)
        let changedRange = 12..<12
        let delta = -10
        
        let incrementalTokens = tokenizer.tokenize(document: buffer, changedRange: changedRange, delta: delta)
        
        // Full tokenization for comparison
        let fullTokenizer = SwiftTokenizer()
        let fullTokens = fullTokenizer.tokenize(document: buffer, changedRange: nil, delta: nil)
        
        #expect(incrementalTokens == fullTokens, "Incremental tokens should match full tokens")
    }
}
