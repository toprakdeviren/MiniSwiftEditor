//
//  SwiftTokenizer.swift
//  MiniSwiftEditor
//
//  Basic Swift tokenizer implementing LanguageEngine protocol
//

import Foundation

// MARK: - Swift Tokenizer

/// Basic Swift tokenizer for syntax highlighting.
/// Implements LanguageEngine protocol for tokenization.
/// Requirements: 2.1, 2.2
final class SwiftTokenizer: LanguageEngine {
    
    // MARK: - Swift Keywords
    
    private static let keywords: Set<String> = [
        // Declarations
        "class", "struct", "enum", "protocol", "extension", "func", "var", "let",
        "typealias", "associatedtype", "init", "deinit", "subscript", "operator",
        "precedencegroup", "import", "actor", "macro",
        // Statements
        "if", "else", "guard", "switch", "case", "default", "for", "while",
        "repeat", "do", "break", "continue", "fallthrough", "return", "throw",
        "defer", "where",
        // Expressions
        "try", "catch", "as", "is", "in", "self", "Self", "super", "nil",
        "true", "false", "async", "await", "some", "any",
        // Modifiers
        "public", "private", "fileprivate", "internal", "open", "static",
        "final", "override", "mutating", "nonmutating", "lazy", "weak",
        "unowned", "inout", "throws", "rethrows", "convenience", "required",
        "dynamic", "optional", "indirect", "nonisolated", "isolated"
    ]
    
    private static let typeKeywords: Set<String> = [
        "Int", "String", "Bool", "Double", "Float", "Array", "Dictionary",
        "Set", "Optional", "Any", "AnyObject", "Void", "Never", "Error",
        "Codable", "Hashable", "Equatable", "Comparable", "Identifiable",
        "Sendable", "Result", "UUID", "Data", "Date", "URL"
    ]
    
    private static let operators: Set<Character> = [
        "+", "-", "*", "/", "%", "=", "<", ">", "!", "&", "|", "^", "~", "?"
    ]
    
    private static let punctuation: Set<Character> = [
        "(", ")", "{", "}", "[", "]", ",", ".", ":", ";", "@", "#", "$", "\\"
    ]

    
    // MARK: - LanguageEngine Protocol
    
    // MARK: - State
    
    private var cachedTokens: [Token] = []
    private var cachedDocumentVersion: Int = -1
    
    // MARK: - LanguageEngine Protocol
    
    /// Tokenize document with incremental optimization.
    /// Uses cached tokens when possible for <16ms keystroke latency.
    /// Requirements: 14.4
    func tokenize(document: TextBuffer, changedRange: Range<Int>?, delta: Int?) -> [Token] {
        let content = document.content
        
        // If no change info or no cache, full re-tokenize
        guard let changedRange = changedRange, let _ = delta, !cachedTokens.isEmpty else {
            let tokens = tokenize(source: content)
            cachedTokens = tokens
            cachedDocumentVersion = document.version
            return tokens
        }
        
        // Skip if document hasn't changed
        if document.version == cachedDocumentVersion {
            return cachedTokens
        }
        
        // Incremental update
        let changeStart = changedRange.lowerBound
        
        // Use binary search to find first affected token for O(log n) lookup
        var firstAffectedTokenIndex = binarySearchTokenIndex(for: changeStart)
        
        // Backtrack one token to handle boundary cases
        if firstAffectedTokenIndex > 0 {
            firstAffectedTokenIndex -= 1
        }
        
        // Reuse tokens before the change
        let reuseStartTokens = Array(cachedTokens[0..<firstAffectedTokenIndex])
        
        // Calculate where to start re-tokenizing
        let retokenizeStart = reuseStartTokens.last?.range.upperBound ?? 0
        
        // Re-tokenize from retokenizeStart to the end
        // Note: Suffix reuse is complex and can cause issues with token boundaries.
        // For correctness, we re-tokenize from the affected point to the end.
        // This is still much faster than full re-tokenization for edits near the start.
        if retokenizeStart < content.count {
            let suffixIndex = content.index(content.startIndex, offsetBy: retokenizeStart)
            let suffix = String(content[suffixIndex...])
            let newTokens = tokenize(source: suffix, startOffset: retokenizeStart)
            
            let result = reuseStartTokens + newTokens
            cachedTokens = result
            cachedDocumentVersion = document.version
            return result
        } else {
            // Change happened at the very end or after
            cachedTokens = reuseStartTokens
            cachedDocumentVersion = document.version
            return reuseStartTokens
        }
    }
    
    /// Binary search to find the token index containing or after the given offset
    /// O(log n) performance for large token arrays
    private func binarySearchTokenIndex(for offset: Int) -> Int {
        var low = 0
        var high = cachedTokens.count
        
        while low < high {
            let mid = (low + high) / 2
            if cachedTokens[mid].range.upperBound <= offset {
                low = mid + 1
            } else {
                high = mid
            }
        }
        
        return low
    }
    
    func analyze(document: TextBuffer) async -> AnalysisResult {
        // Ensure we have up-to-date tokens
        // Note: In a real implementation, we might want to share the tokenization result
        // from the main thread to avoid re-tokenizing.
        let tokens = tokenize(document: document, changedRange: nil, delta: nil)
        var diagnostics: [Diagnostic] = []
        
        let content = document.content
        
        for token in tokens {
            // Check for unknown tokens
            if token.kind == .unknown {
                diagnostics.append(Diagnostic(
                    range: token.range,
                    message: "Unexpected character",
                    severity: .error
                ))
            }
            
            // Check for TODOs in comments
            if token.kind == .comment {
                let startIndex = content.index(content.startIndex, offsetBy: token.range.lowerBound)
                let endIndex = content.index(content.startIndex, offsetBy: token.range.upperBound)
                let commentText = content[startIndex..<endIndex]
                
                if commentText.contains("TODO") {
                    diagnostics.append(Diagnostic(
                        range: token.range,
                        message: "TODO: Pending task",
                        severity: .info
                    ))
                }
                
                if commentText.contains("FIXME") {
                    diagnostics.append(Diagnostic(
                        range: token.range,
                        message: "FIXME: Broken code",
                        severity: .warning
                    ))
                }
            }
            
            // Check for unterminated string literals
            if token.kind == .stringLiteral {
                let startIndex = content.index(content.startIndex, offsetBy: token.range.lowerBound)
                let endIndex = content.index(content.startIndex, offsetBy: token.range.upperBound)
                let text = content[startIndex..<endIndex]
                
                // A valid string literal must start and end with " (or """)
                // Simple check for single line string: must end with " and length >= 2
                // (This is a simplification, doesn't handle multiline strings perfectly yet)
                if text.hasPrefix("\"") {
                    if text.count == 1 || !text.hasSuffix("\"") || (text.hasSuffix("\\\"") && !text.hasSuffix("\\\\\"")) {
                         // It's unterminated if it's just " or doesn't end with " or ends with escaped "
                         // Note: The tokenizer stops at newline for strings, so if it doesn't end with ", it's unterminated.
                         if !text.hasSuffix("\"") {
                             diagnostics.append(Diagnostic(
                                 range: token.range,
                                 message: "Unterminated string literal",
                                 severity: .error
                             ))
                         }
                    }
                }
            }
        }
        
        return AnalysisResult(
            tokens: tokens,
            diagnostics: diagnostics,
            symbols: [],
            foldableRanges: []
        )
    }
    
    // MARK: - Tokenization
    
    /// Tokenize source code into tokens with an offset adjustment
    private func tokenize(source: String, startOffset: Int) -> [Token] {
        let tokens = tokenize(source: source)
        return tokens.map { token in
            Token(range: (token.range.lowerBound + startOffset)..<(token.range.upperBound + startOffset), kind: token.kind)
        }
    }
    
    // MARK: - Tokenization
    
    /// Tokenize source code into tokens
    /// - Parameter source: Swift source code
    /// - Returns: Array of tokens covering the entire source
    func tokenize(source: String) -> [Token] {
        var tokens: [Token] = []
        var index = source.startIndex
        
        while index < source.endIndex {
            let startOffset = source.distance(from: source.startIndex, to: index)
            
            // Skip whitespace
            if source[index].isWhitespace {
                let endIndex = skipWhitespace(from: index, in: source)
                let endOffset = source.distance(from: source.startIndex, to: endIndex)
                tokens.append(Token(range: startOffset..<endOffset, kind: .whitespace))
                index = endIndex
                continue
            }
            
            // Single-line comment
            if source[index] == "/" && source.index(after: index) < source.endIndex && source[source.index(after: index)] == "/" {
                let endIndex = skipLineComment(from: index, in: source)
                let endOffset = source.distance(from: source.startIndex, to: endIndex)
                tokens.append(Token(range: startOffset..<endOffset, kind: .comment))
                index = endIndex
                continue
            }
            
            // Multi-line comment
            if source[index] == "/" && source.index(after: index) < source.endIndex && source[source.index(after: index)] == "*" {
                let endIndex = skipBlockComment(from: index, in: source)
                let endOffset = source.distance(from: source.startIndex, to: endIndex)
                tokens.append(Token(range: startOffset..<endOffset, kind: .comment))
                index = endIndex
                continue
            }
            
            // String literal
            if source[index] == "\"" {
                let endIndex = skipStringLiteral(from: index, in: source)
                let endOffset = source.distance(from: source.startIndex, to: endIndex)
                tokens.append(Token(range: startOffset..<endOffset, kind: .stringLiteral))
                index = endIndex
                continue
            }
            
            // Number literal
            let nextIndex = source.index(after: index)
            if source[index].isNumber || (source[index] == "." && nextIndex < source.endIndex && source[nextIndex].isNumber) {
                let endIndex = skipNumber(from: index, in: source)
                let endOffset = source.distance(from: source.startIndex, to: endIndex)
                tokens.append(Token(range: startOffset..<endOffset, kind: .numberLiteral))
                index = endIndex
                continue
            }
            
            // Identifier or keyword
            if source[index].isLetter || source[index] == "_" {
                let endIndex = skipIdentifier(from: index, in: source)
                let word = String(source[index..<endIndex])
                let endOffset = source.distance(from: source.startIndex, to: endIndex)
                
                let kind: TokenKind
                if Self.keywords.contains(word) {
                    kind = .keyword
                } else if Self.typeKeywords.contains(word) {
                    kind = .typeIdentifier
                } else {
                    kind = .identifier
                }
                
                tokens.append(Token(range: startOffset..<endOffset, kind: kind))
                index = endIndex
                continue
            }
            
            // Operator
            if Self.operators.contains(source[index]) {
                let endIndex = skipOperator(from: index, in: source)
                let endOffset = source.distance(from: source.startIndex, to: endIndex)
                tokens.append(Token(range: startOffset..<endOffset, kind: .operator))
                index = endIndex
                continue
            }
            
            // Punctuation
            if Self.punctuation.contains(source[index]) {
                let endOffset = startOffset + 1
                tokens.append(Token(range: startOffset..<endOffset, kind: .punctuation))
                index = source.index(after: index)
                continue
            }
            
            // Unknown character
            let endOffset = startOffset + 1
            tokens.append(Token(range: startOffset..<endOffset, kind: .unknown))
            index = source.index(after: index)
        }
        
        return tokens
    }
    
    // MARK: - Skip Helpers
    
    private func skipWhitespace(from start: String.Index, in source: String) -> String.Index {
        var index = start
        while index < source.endIndex && source[index].isWhitespace {
            index = source.index(after: index)
        }
        return index
    }
    
    private func skipLineComment(from start: String.Index, in source: String) -> String.Index {
        var index = start
        while index < source.endIndex && source[index] != "\n" {
            index = source.index(after: index)
        }
        return index
    }
    
    private func skipBlockComment(from start: String.Index, in source: String) -> String.Index {
        var index = source.index(start, offsetBy: 2, limitedBy: source.endIndex) ?? source.endIndex
        while index < source.endIndex {
            if source[index] == "*" {
                let next = source.index(after: index)
                if next < source.endIndex && source[next] == "/" {
                    return source.index(after: next)
                }
            }
            index = source.index(after: index)
        }
        return source.endIndex
    }
    
    private func skipStringLiteral(from start: String.Index, in source: String) -> String.Index {
        var index = source.index(after: start)
        var escaped = false
        
        while index < source.endIndex {
            let char = source[index]
            if escaped {
                escaped = false
            } else if char == "\\" {
                escaped = true
            } else if char == "\"" {
                return source.index(after: index)
            } else if char == "\n" {
                // Unterminated string
                return index
            }
            index = source.index(after: index)
        }
        return source.endIndex
    }
    
    private func skipNumber(from start: String.Index, in source: String) -> String.Index {
        var index = start
        var hasDecimal = false
        var hasExponent = false
        
        while index < source.endIndex {
            let char = source[index]
            if char.isNumber {
                index = source.index(after: index)
            } else if char == "." && !hasDecimal && !hasExponent {
                hasDecimal = true
                index = source.index(after: index)
            } else if (char == "e" || char == "E") && !hasExponent {
                hasExponent = true
                index = source.index(after: index)
                // Handle optional sign after exponent
                if index < source.endIndex && (source[index] == "+" || source[index] == "-") {
                    index = source.index(after: index)
                }
            } else if char == "_" {
                // Swift allows underscores in numbers
                index = source.index(after: index)
            } else {
                break
            }
        }
        return index
    }
    
    private func skipIdentifier(from start: String.Index, in source: String) -> String.Index {
        var index = start
        while index < source.endIndex {
            let char = source[index]
            if char.isLetter || char.isNumber || char == "_" {
                index = source.index(after: index)
            } else {
                break
            }
        }
        return index
    }
    
    private func skipOperator(from start: String.Index, in source: String) -> String.Index {
        var index = start
        while index < source.endIndex && Self.operators.contains(source[index]) {
            index = source.index(after: index)
        }
        return index
    }
}
