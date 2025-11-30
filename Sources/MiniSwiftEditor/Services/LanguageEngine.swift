//
//  LanguageEngine.swift
//  MiniSwiftEditor
//
//  Core protocol for language processing layer
//

import Foundation

// MARK: - Token Types

/// Classification of token types for syntax highlighting
public enum TokenKind: Equatable, Hashable {
    case keyword
    case identifier
    case typeIdentifier
    case numberLiteral
    case stringLiteral
    case comment
    case `operator`
    case punctuation
    case whitespace
    case unknown
}

/// Represents a single token from lexical analysis
struct Token: Equatable {
    /// Character range of the token in the document
    let range: Range<Int>
    /// Classification of the token
    let kind: TokenKind
}

// MARK: - Diagnostic Types

/// Severity level for diagnostics
enum DiagnosticSeverity: Int, Comparable {
    case hint = 0
    case info = 1
    case warning = 2
    case error = 3
    
    static func < (lhs: DiagnosticSeverity, rhs: DiagnosticSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Represents a diagnostic message (error, warning, etc.)
struct Diagnostic: Equatable {
    /// Character range where the diagnostic applies
    let range: Range<Int>
    /// Human-readable diagnostic message
    let message: String
    /// Severity level of the diagnostic
    let severity: DiagnosticSeverity
}

// MARK: - Symbol Types

/// Information about a symbol in the code
struct SymbolInfo: Equatable {
    /// Name of the symbol
    let name: String
    /// Character range of the symbol definition
    let range: Range<Int>
    /// Kind of symbol (function, variable, type, etc.)
    let kind: SymbolKind
}

/// Classification of symbol types
enum SymbolKind: Equatable {
    case function
    case variable
    case type
    case `enum`
    case `struct`
    case `class`
    case `protocol`
    case property
    case parameter
}

// MARK: - Folding Types

/// Represents a foldable code region
struct FoldableRange: Equatable {
    /// Character range that can be folded
    let range: Range<Int>
    /// Kind of foldable region
    let kind: FoldableKind
    /// Placeholder text to show when folded
    let placeholder: String
}

/// Classification of foldable region types
enum FoldableKind: Equatable {
    case function
    case type
    case block
    case comment
    case region
}

// MARK: - Analysis Result

/// Complete result from semantic analysis
struct AnalysisResult: Equatable {
    /// All tokens from lexical analysis
    let tokens: [Token]
    /// Diagnostics (errors, warnings, etc.)
    let diagnostics: [Diagnostic]
    /// Symbol information
    let symbols: [SymbolInfo]
    /// Foldable code regions
    let foldableRanges: [FoldableRange]
    
    /// Empty analysis result
    static let empty = AnalysisResult(
        tokens: [],
        diagnostics: [],
        symbols: [],
        foldableRanges: []
    )
}

// MARK: - Language Engine Protocol

/// Protocol for language processing engines.
/// Provides tokenization and semantic analysis capabilities.
/// Requirements: 2.1, 2.2, 2.3, 2.4, 2.5
protocol LanguageEngine {
    /// Tokenize the document, optionally focusing on a changed range
    /// - Parameters:
    ///   - document: The text document to tokenize
    ///   - changedRange: Optional range that changed (for incremental tokenization)
    ///   - delta: Change in length (newLength - oldLength)
    /// - Returns: Array of tokens covering the document
    func tokenize(document: TextBuffer, changedRange: Range<Int>?, delta: Int?) -> [Token]
    
    /// Perform semantic analysis on the document
    /// - Parameter document: The text document to analyze
    /// - Returns: Complete analysis result with tokens, diagnostics, symbols, and foldable ranges
    func analyze(document: TextBuffer) async -> AnalysisResult
}
