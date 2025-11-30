//
//  DecorationModelPropertyTests.swift
//  MiniSwiftEditorTests
//
//  Property-based tests for DecorationModel
//

import Testing
@testable import MiniSwiftEditor

/// Property-based tests for DecorationModel implementation
/// Uses randomized inputs to verify correctness properties
@MainActor
struct DecorationModelPropertyTests {
    
    // MARK: - Test Helpers
    
    /// All possible token kinds for random generation
    static let allTokenKinds: [TokenKind] = [
        .keyword, .identifier, .typeIdentifier, .numberLiteral,
        .stringLiteral, .comment, .operator, .punctuation,
        .whitespace, .unknown
    ]
    
    /// Non-whitespace token kinds (these produce decorations)
    static let nonWhitespaceTokenKinds: [TokenKind] = [
        .keyword, .identifier, .typeIdentifier, .numberLiteral,
        .stringLiteral, .comment, .operator, .punctuation, .unknown
    ]
    
    /// Generate a random token with the given range
    static func randomToken(range: Range<Int>) -> Token {
        let kind = allTokenKinds.randomElement()!
        return Token(range: range, kind: kind)
    }
    
    /// Generate a random non-whitespace token with the given range
    static func randomNonWhitespaceToken(range: Range<Int>) -> Token {
        let kind = nonWhitespaceTokenKinds.randomElement()!
        return Token(range: range, kind: kind)
    }
    
    /// Generate a list of contiguous tokens covering a range
    static func randomContiguousTokens(totalLength: Int, tokenCount: Int) -> [Token] {
        guard totalLength > 0 && tokenCount > 0 else { return [] }
        
        var tokens: [Token] = []
        
        // Generate random split points
        var splitPoints = [0]
        if totalLength > 1 {
            for _ in 1..<tokenCount {
                let point = Int.random(in: 1..<totalLength)
                splitPoints.append(point)
            }
        }
        splitPoints.append(totalLength)
        splitPoints.sort()

        let uniquePoints = Array(Set(splitPoints)).sorted()
        
        for i in 0..<(uniquePoints.count - 1) {
            let start = uniquePoints[i]
            let end = uniquePoints[i + 1]
            if start < end {
                tokens.append(randomToken(range: start..<end))
            }
        }
        
        return tokens
    }
    
    /// Generate a list of contiguous non-whitespace tokens
    static func randomContiguousNonWhitespaceTokens(totalLength: Int, tokenCount: Int) -> [Token] {
        guard totalLength > 0 && tokenCount > 0 else { return [] }
        
        var tokens: [Token] = []
        
        // Generate random split points
        var splitPoints = [0]
        if totalLength > 1 {
            for _ in 1..<tokenCount {
                let point = Int.random(in: 1..<totalLength)
                splitPoints.append(point)
            }
        }
        splitPoints.append(totalLength)
        splitPoints.sort()

        let uniquePoints = Array(Set(splitPoints)).sorted()
        
        for i in 0..<(uniquePoints.count - 1) {
            let start = uniquePoints[i]
            let end = uniquePoints[i + 1]
            if start < end {
                tokens.append(randomNonWhitespaceToken(range: start..<end))
            }
        }
        
        return tokens
    }
}

// MARK: - Property 6: Token-to-Decoration Transformation
// **Feature: code-editor, Property 6: Token-to-Decoration Transformation**
// **Validates: Requirements 3.1**
//
// For any list of tokens from the Language Engine, the Decoration Model should
// produce decorations that cover exactly the same ranges as the input tokens.

extension DecorationModelPropertyTests {
    
    @Test("Property 6: Token-to-Decoration Transformation - Decorations cover same ranges as non-whitespace tokens")
    func tokenToDecorationTransformation_coversSameRanges() {
        let model = DecorationModel()
        
        // Run 100 iterations with different random inputs
        for _ in 0..<100 {
            let totalLength = Int.random(in: 1...500)
            let tokenCount = Int.random(in: 1...20)
            let tokens = Self.randomContiguousNonWhitespaceTokens(totalLength: totalLength, tokenCount: tokenCount)
            
            guard !tokens.isEmpty else { continue }
            
            model.update(from: tokens)
            let decorations = model.decorations
            
            // All non-whitespace tokens should have corresponding decorations
            let tokenRanges = Set(tokens.map { $0.range })
            let decorationRanges = Set(decorations.map { $0.range })
            
            #expect(tokenRanges == decorationRanges,
                   "Decoration ranges should match non-whitespace token ranges. Tokens: \(tokenRanges), Decorations: \(decorationRanges)")
        }
    }
    
    @Test("Property 6: Token-to-Decoration Transformation - Whitespace tokens produce no decorations")
    func tokenToDecorationTransformation_whitespaceProducesNoDecorations() {
        let model = DecorationModel()
        
        // Run 100 iterations
        for _ in 0..<100 {
            let totalLength = Int.random(in: 1...100)

            var tokens: [Token] = []
            var offset = 0
            while offset < totalLength {
                let length = Int.random(in: 1...min(10, totalLength - offset))
                tokens.append(Token(range: offset..<(offset + length), kind: .whitespace))
                offset += length
            }
            
            model.update(from: tokens)
            
            #expect(model.decorations.isEmpty,
                   "Whitespace-only tokens should produce no decorations, got \(model.decorations.count)")
        }
    }
    
    @Test("Property 6: Token-to-Decoration Transformation - Mixed tokens filter whitespace correctly")
    func tokenToDecorationTransformation_mixedTokensFilterWhitespace() {
        let model = DecorationModel()
        
        // Run 100 iterations
        for _ in 0..<100 {
            let totalLength = Int.random(in: 10...200)
            let tokenCount = Int.random(in: 2...15)
            
            // Generate mixed tokens (some whitespace, some not)
            var tokens: [Token] = []
            var splitPoints = [0]
            for _ in 1..<tokenCount {
                splitPoints.append(Int.random(in: 1..<totalLength))
            }
            splitPoints.append(totalLength)
            splitPoints = Array(Set(splitPoints)).sorted()
            
            for i in 0..<(splitPoints.count - 1) {
                let start = splitPoints[i]
                let end = splitPoints[i + 1]
                if start < end {
                    // Randomly choose whitespace or non-whitespace
                    let kind = Self.allTokenKinds.randomElement()!
                    tokens.append(Token(range: start..<end, kind: kind))
                }
            }
            
            model.update(from: tokens)
            
            // Count expected decorations (non-whitespace tokens)
            let nonWhitespaceTokens = tokens.filter { $0.kind != .whitespace }
            let expectedRanges = Set(nonWhitespaceTokens.map { $0.range })
            let actualRanges = Set(model.decorations.map { $0.range })
            
            #expect(expectedRanges == actualRanges,
                   "Decorations should match non-whitespace tokens only")
        }
    }
    
    @Test("Property 6: Token-to-Decoration Transformation - Each decoration has syntax kind")
    func tokenToDecorationTransformation_decorationsHaveSyntaxKind() {
        let model = DecorationModel()
        
        // Run 100 iterations
        for _ in 0..<100 {
            let totalLength = Int.random(in: 1...200)
            let tokenCount = Int.random(in: 1...10)
            let tokens = Self.randomContiguousNonWhitespaceTokens(totalLength: totalLength, tokenCount: tokenCount)
            
            guard !tokens.isEmpty else { continue }
            
            model.update(from: tokens)
            
            // All decorations from tokens should be syntax decorations
            for decoration in model.decorations {
                if case .syntax = decoration.kind {
                    // Good - it's a syntax decoration
                } else {
                    Issue.record("Expected syntax decoration, got \(decoration.kind)")
                }
            }
        }
    }
    
    @Test("Property 6: Token-to-Decoration Transformation - Decoration count equals non-whitespace token count")
    func tokenToDecorationTransformation_countMatchesNonWhitespace() {
        let model = DecorationModel()
        
        // Run 100 iterations
        for _ in 0..<100 {
            let totalLength = Int.random(in: 1...300)
            let tokenCount = Int.random(in: 1...20)
            let tokens = Self.randomContiguousTokens(totalLength: totalLength, tokenCount: tokenCount)
            
            model.update(from: tokens)
            
            let nonWhitespaceCount = tokens.filter { $0.kind != .whitespace }.count
            
            #expect(model.decorations.count == nonWhitespaceCount,
                   "Decoration count \(model.decorations.count) should equal non-whitespace token count \(nonWhitespaceCount)")
        }
    }
    
    @Test("Property 6: Token-to-Decoration Transformation - Empty tokens produce empty decorations")
    func tokenToDecorationTransformation_emptyTokensProduceEmptyDecorations() {
        let model = DecorationModel()
        
        // Run 100 iterations
        for _ in 0..<100 {
            let emptyTokens: [Token] = []
            model.update(from: emptyTokens)
            
            #expect(model.decorations.isEmpty,
                   "Empty tokens should produce empty decorations")
        }
    }
    
    @Test("Property 6: Token-to-Decoration Transformation - Keywords get bold trait")
    func tokenToDecorationTransformation_keywordsGetBoldTrait() {
        let model = DecorationModel()
        
        // Run 100 iterations
        for _ in 0..<100 {
            let keywordToken = Token(range: 0..<Int.random(in: 1...20), kind: .keyword)
            
            model.update(from: [keywordToken])
            
            guard let decoration = model.decorations.first else {
                Issue.record("Expected decoration for keyword token")
                continue
            }
            
            if case .syntax(_, let traits) = decoration.kind {
                #expect(traits.contains(.bold),
                       "Keyword decoration should have bold trait")
            } else {
                Issue.record("Expected syntax decoration for keyword")
            }
        }
    }
    
    @Test("Property 6: Token-to-Decoration Transformation - Comments get italic trait")
    func tokenToDecorationTransformation_commentsGetItalicTrait() {
        let model = DecorationModel()
        
        // Run 100 iterations
        for _ in 0..<100 {
            let commentToken = Token(range: 0..<Int.random(in: 1...50), kind: .comment)
            
            model.update(from: [commentToken])
            
            guard let decoration = model.decorations.first else {
                Issue.record("Expected decoration for comment token")
                continue
            }
            
            if case .syntax(_, let traits) = decoration.kind {
                #expect(traits.contains(.italic),
                       "Comment decoration should have italic trait")
            } else {
                Issue.record("Expected syntax decoration for comment")
            }
        }
    }
    
    @Test("Property 6: Token-to-Decoration Transformation - Integration with SwiftTokenizer")
    func tokenToDecorationTransformation_integrationWithTokenizer() {
        let tokenizer = SwiftTokenizer()
        let model = DecorationModel()
        
        // Run 100 iterations with real Swift code
        for _ in 0..<100 {
            let source = SwiftTokenizerPropertyTests.randomMultilineSwift(lines: Int.random(in: 1...10))
            let tokens = tokenizer.tokenize(source: source)
            
            model.update(from: tokens)
            
            // Verify decoration ranges are within source bounds
            for decoration in model.decorations {
                #expect(decoration.range.lowerBound >= 0,
                       "Decoration range should start at or after 0")
                #expect(decoration.range.upperBound <= source.count,
                       "Decoration range should end at or before source length")
            }
            
            // Verify non-whitespace tokens have decorations
            let nonWhitespaceTokenRanges = Set(tokens.filter { $0.kind != .whitespace }.map { $0.range })
            let decorationRanges = Set(model.decorations.map { $0.range })
            
            #expect(nonWhitespaceTokenRanges == decorationRanges,
                   "Decoration ranges should match non-whitespace token ranges from tokenizer")
        }
    }
}
