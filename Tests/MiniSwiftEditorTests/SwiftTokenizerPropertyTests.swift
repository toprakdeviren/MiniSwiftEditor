//
//  SwiftTokenizerPropertyTests.swift
//  MiniSwiftEditorTests
//
//  Property-based tests for SwiftTokenizer
//

import Testing
@testable import MiniSwiftEditor

/// Property-based tests for SwiftTokenizer implementation
/// Uses randomized inputs to verify correctness properties
@MainActor
struct SwiftTokenizerPropertyTests {
    
    // MARK: - Test Helpers
    
    /// Generate random Swift-like source code
    static func randomSwiftSource(length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 \n\t{}()[].,;:+-*/=<>!&|^~?@#$%\"\\"
        return String((0..<length).map { _ in characters.randomElement()! })
    }
    
    /// Generate random identifier
    static func randomIdentifier(length: Int) -> String {
        let firstChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_"
        let restChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
        guard length > 0 else { return "" }
        let first = String(firstChars.randomElement()!)
        let rest = String((0..<(length-1)).map { _ in restChars.randomElement()! })
        return first + rest
    }
    
    /// Generate random Swift code snippet
    static func randomSwiftSnippet() -> String {
        let snippets = [
            "let x = 42",
            "var name = \"hello\"",
            "func test() { }",
            "// comment",
            "/* block comment */",
            "if true { print(1) }",
            "class Foo { var x: Int = 0 }",
            "struct Bar { let y: String }",
            "enum Color { case red, green, blue }",
            "for i in 0..<10 { }",
            "while true { break }",
            "guard let x = optional else { return }",
            "switch value { case 1: break default: break }",
            "let arr = [1, 2, 3]",
            "let dict = [\"a\": 1]",
            "func add(_ a: Int, _ b: Int) -> Int { return a + b }",
            "protocol P { func f() }",
            "extension String { }",
            "import Foundation",
            "public final class C { private var x = 0 }",
        ]
        return snippets.randomElement()!
    }
    
    /// Generate random multi-line Swift code
    static func randomMultilineSwift(lines: Int) -> String {
        (0..<lines).map { _ in randomSwiftSnippet() }.joined(separator: "\n")
    }
}


// MARK: - Property 4: Token Coverage Completeness
// **Feature: code-editor, Property 4: Token Coverage Completeness**
// **Validates: Requirements 2.1, 2.2**
//
// For any valid Swift source text, tokenization should produce tokens that cover
// the entire document without gaps (every character belongs to exactly one token)
// and without overlaps.

extension SwiftTokenizerPropertyTests {
    
    @Test("Property 4: Token Coverage Completeness - No gaps in token ranges")
    func tokenCoverageCompleteness_noGaps() {
        let tokenizer = SwiftTokenizer()
        
        // Run 100 iterations with different random inputs
        for _ in 0..<100 {
            let source = Self.randomSwiftSource(length: Int.random(in: 1...500))
            let tokens = tokenizer.tokenize(source: source)
            
            // Skip empty source
            guard !source.isEmpty else { continue }
            
            // Verify tokens cover from 0 to source.count
            guard !tokens.isEmpty else {
                Issue.record("Empty source '\(source)' should produce at least one token")
                continue
            }
            
            // Check first token starts at 0
            #expect(tokens.first!.range.lowerBound == 0,
                   "First token should start at 0, but starts at \(tokens.first!.range.lowerBound)")
            
            // Check last token ends at source.count
            #expect(tokens.last!.range.upperBound == source.count,
                   "Last token should end at \(source.count), but ends at \(tokens.last!.range.upperBound)")
            
            // Check no gaps between consecutive tokens
            for i in 1..<tokens.count {
                let prevEnd = tokens[i-1].range.upperBound
                let currStart = tokens[i].range.lowerBound
                
                #expect(prevEnd == currStart,
                       "Gap between tokens at position \(prevEnd): token \(i-1) ends at \(prevEnd), token \(i) starts at \(currStart)")
            }
        }
    }
    
    @Test("Property 4: Token Coverage Completeness - No overlapping tokens")
    func tokenCoverageCompleteness_noOverlaps() {
        let tokenizer = SwiftTokenizer()
        
        for _ in 0..<100 {
            let source = Self.randomSwiftSource(length: Int.random(in: 1...500))
            let tokens = tokenizer.tokenize(source: source)
            
            // Check no overlapping tokens
            for i in 1..<tokens.count {
                let prevEnd = tokens[i-1].range.upperBound
                let currStart = tokens[i].range.lowerBound
                
                #expect(currStart >= prevEnd,
                       "Overlapping tokens: token \(i-1) ends at \(prevEnd), token \(i) starts at \(currStart)")
            }
        }
    }
    
    @Test("Property 4: Token Coverage Completeness - Total coverage equals source length")
    func tokenCoverageCompleteness_totalCoverage() {
        let tokenizer = SwiftTokenizer()
        
        for _ in 0..<100 {
            let source = Self.randomSwiftSource(length: Int.random(in: 0...500))
            let tokens = tokenizer.tokenize(source: source)
            
            // Sum of all token lengths should equal source length
            let totalCoverage = tokens.reduce(0) { $0 + ($1.range.upperBound - $1.range.lowerBound) }
            
            #expect(totalCoverage == source.count,
                   "Total token coverage \(totalCoverage) != source length \(source.count)")
        }
    }
    
    @Test("Property 4: Token Coverage Completeness - Valid Swift snippets")
    func tokenCoverageCompleteness_validSwiftSnippets() {
        let tokenizer = SwiftTokenizer()
        
        for _ in 0..<100 {
            let source = Self.randomMultilineSwift(lines: Int.random(in: 1...20))
            let tokens = tokenizer.tokenize(source: source)
            
            guard !source.isEmpty else { continue }
            
            // Verify complete coverage
            let totalCoverage = tokens.reduce(0) { $0 + ($1.range.upperBound - $1.range.lowerBound) }
            #expect(totalCoverage == source.count,
                   "Token coverage incomplete for Swift code")
            
            // Verify no gaps
            for i in 1..<tokens.count {
                #expect(tokens[i-1].range.upperBound == tokens[i].range.lowerBound,
                       "Gap found in Swift code tokenization")
            }
        }
    }
    
    @Test("Property 4: Token Coverage Completeness - Each character belongs to exactly one token")
    func tokenCoverageCompleteness_exactlyOneToken() {
        let tokenizer = SwiftTokenizer()
        
        for _ in 0..<100 {
            let source = Self.randomSwiftSource(length: Int.random(in: 1...200))
            let tokens = tokenizer.tokenize(source: source)
            
            var coverage = Array(repeating: 0, count: source.count)
            
            for token in tokens {
                for pos in token.range {
                    coverage[pos] += 1
                }
            }
            
            // Verify each position is covered exactly once
            for (pos, count) in coverage.enumerated() {
                #expect(count == 1,
                       "Position \(pos) is covered \(count) times, expected exactly 1")
            }
        }
    }
    
    @Test("Property 4: Token Coverage Completeness - Empty source produces no tokens")
    func tokenCoverageCompleteness_emptySource() {
        let tokenizer = SwiftTokenizer()
        
        for _ in 0..<100 {
            let tokens = tokenizer.tokenize(source: "")
            
            #expect(tokens.isEmpty,
                   "Empty source should produce no tokens, got \(tokens.count)")
        }
    }
    
    @Test("Property 4: Token Coverage Completeness - Single character sources")
    func tokenCoverageCompleteness_singleCharacter() {
        let tokenizer = SwiftTokenizer()
        let testChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 \n\t{}()[].,;:+-*/=<>!&|^~?@#$"
        
        for char in testChars {
            let source = String(char)
            let tokens = tokenizer.tokenize(source: source)
            
            // Single character should produce exactly one token
            #expect(tokens.count == 1,
                   "Single character '\(char)' should produce 1 token, got \(tokens.count)")
            
            if let token = tokens.first {
                #expect(token.range == 0..<1,
                       "Single character token should have range 0..<1, got \(token.range)")
            }
        }
    }
    
    @Test("Property 4: Token Coverage Completeness - Comments are fully tokenized")
    func tokenCoverageCompleteness_comments() {
        let tokenizer = SwiftTokenizer()
        
        let commentSources = [
            "// single line comment",
            "// comment\ncode",
            "/* block */",
            "/* multi\nline\nblock */",
            "code /* inline */ more",
            "// comment 1\n// comment 2",
        ]
        
        for source in commentSources {
            let tokens = tokenizer.tokenize(source: source)
            let totalCoverage = tokens.reduce(0) { $0 + ($1.range.upperBound - $1.range.lowerBound) }
            
            #expect(totalCoverage == source.count,
                   "Comment source '\(source)' not fully covered: \(totalCoverage) vs \(source.count)")
        }
    }
    
    @Test("Property 4: Token Coverage Completeness - String literals are fully tokenized")
    func tokenCoverageCompleteness_stringLiterals() {
        let tokenizer = SwiftTokenizer()
        
        let stringSources = [
            "\"hello\"",
            "\"hello world\"",
            "\"with\\\"escape\"",
            "\"line1\\nline2\"",
            "let x = \"value\"",
            "\"\" + \"test\"",
        ]
        
        for source in stringSources {
            let tokens = tokenizer.tokenize(source: source)
            let totalCoverage = tokens.reduce(0) { $0 + ($1.range.upperBound - $1.range.lowerBound) }
            
            #expect(totalCoverage == source.count,
                   "String source '\(source)' not fully covered: \(totalCoverage) vs \(source.count)")
        }
    }
    
    @Test("Property 4: Token Coverage Completeness - Number literals are fully tokenized")
    func tokenCoverageCompleteness_numberLiterals() {
        let tokenizer = SwiftTokenizer()
        
        let numberSources = [
            "42",
            "3.14",
            "1_000_000",
            "1e10",
            "1.5e-3",
            "let x = 42",
            "let pi = 3.14159",
        ]
        
        for source in numberSources {
            let tokens = tokenizer.tokenize(source: source)
            let totalCoverage = tokens.reduce(0) { $0 + ($1.range.upperBound - $1.range.lowerBound) }
            
            #expect(totalCoverage == source.count,
                   "Number source '\(source)' not fully covered: \(totalCoverage) vs \(source.count)")
        }
    }
}
