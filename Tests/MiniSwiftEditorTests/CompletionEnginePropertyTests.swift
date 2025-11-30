//
//  CompletionEnginePropertyTests.swift
//  MiniSwiftEditorTests
//
//  Property-based tests for CompletionEngine
//

import Foundation
import Testing
@testable import MiniSwiftEditor

struct CompletionEnginePropertyTests {
    
    @Test("Property 25: Completion Prefix Filtering")
    func completionPrefixFiltering() {
        let engine = CompletionEngine()
        
        // Test with random prefixes
        for _ in 0..<100 {
            let prefix = randomPrefix()
            let completions = engine.completions(for: prefix, at: 0)
            
            // Verify all completions start with prefix
            for item in completions {
                #expect(item.label.hasPrefix(prefix), "Completion '\(item.label)' should start with prefix '\(prefix)'")
            }
        }
    }
    
    @Test("Keyword Coverage")
    func keywordCoverage() {
        let engine = CompletionEngine()
        let keywords = ["func", "var", "let", "class", "struct"]
        
        for keyword in keywords {
            // Test with full keyword
            let fullCompletions = engine.completions(for: keyword, at: 0)
            #expect(fullCompletions.contains { $0.label == keyword }, "Should contain exact match for '\(keyword)'")
            
            // Test with partial prefix
            let prefix = String(keyword.prefix(2))
            let partialCompletions = engine.completions(for: prefix, at: 0)
            #expect(partialCompletions.contains { $0.label == keyword }, "Should contain match for prefix '\(prefix)' of '\(keyword)'")
        }
    }
    
    // MARK: - Helpers
    
    func randomPrefix() -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let len = Int.random(in: 1...3)
        return String((0..<len).map { _ in chars.randomElement()! })
    }
}
