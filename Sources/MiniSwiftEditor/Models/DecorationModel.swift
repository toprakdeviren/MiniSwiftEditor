//
//  DecorationModel.swift
//  MiniSwiftEditor
//
//  Decoration and layout model for syntax highlighting and visual decorations
//

import Foundation
import AppKit
import Combine

// MARK: - Font Traits

/// Font style traits for text decorations
struct FontTraits: OptionSet, Equatable, Hashable {
    let rawValue: Int
    
    static let bold = FontTraits(rawValue: 1 << 0)
    static let italic = FontTraits(rawValue: 1 << 1)
}

// MARK: - Underline Style

/// Style of underline decoration
enum UnderlineStyle: Equatable, Hashable {
    case solid
    case squiggly
}

// MARK: - Decoration Kind

/// Classification of decoration types for visual rendering
/// Requirements: 3.1, 3.2
enum DecorationKind: Equatable, Hashable {
    /// Syntax highlighting with color and font traits
    case syntax(color: NSColor, traits: FontTraits)
    /// Underline decoration (for diagnostics)
    case underline(color: NSColor, style: UnderlineStyle)
    /// Background highlight
    case background(color: NSColor)
    /// Bracket matching highlight
    case bracket(isMatched: Bool)
    /// Fold placeholder
    case foldPlaceholder
    /// Hidden text (for folding)
    case hidden
}

// MARK: - Decoration

/// Represents a visual decoration applied to a text range
/// Requirements: 3.1
struct Decoration: Equatable {
    /// Character range where the decoration applies
    let range: Range<Int>
    /// Type of decoration
    let kind: DecorationKind
    /// Priority for overlapping decorations (higher wins)
    let priority: Int
    /// Optional tooltip text
    let tooltip: String?
    
    init(range: Range<Int>, kind: DecorationKind, priority: Int = 0, tooltip: String? = nil) {
        self.range = range
        self.kind = kind
        self.priority = priority
        self.tooltip = tooltip
    }
}

// MARK: - Line Decoration Kind

/// Classification of line-level decorations
enum LineDecorationKind: Equatable {
    case lineNumber(String)
    case breakpoint
    case diagnostic(DiagnosticSeverity)
    case foldIndicator(isFolded: Bool)
}

// MARK: - Line Decoration

/// Represents a decoration applied to a specific line
struct LineDecoration: Equatable {
    /// Zero-based line index
    let lineIndex: Int
    /// Type of line decoration
    let kind: LineDecorationKind
}

// MARK: - Decoration Model

/// Manages visual decorations for the code editor.
/// Converts tokens and diagnostics to platform-agnostic decoration objects.
/// Requirements: 3.1, 3.2, 3.3, 3.4, 3.5
final class DecorationModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// All text decorations
    @Published private(set) var decorations: [Decoration] = []
    
    /// Line-level decorations
    @Published private(set) var lineDecorations: [LineDecoration] = []
    
    // MARK: - Theme Colors
    
    /// Default syntax colors for token kinds
    private let syntaxColors: [TokenKind: NSColor] = [
        .keyword: NSColor(red: 0.78, green: 0.18, blue: 0.53, alpha: 1.0),      // Pink/magenta
        .identifier: NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),       // Black
        .typeIdentifier: NSColor(red: 0.11, green: 0.43, blue: 0.55, alpha: 1.0), // Teal
        .numberLiteral: NSColor(red: 0.11, green: 0.0, blue: 0.81, alpha: 1.0),  // Blue
        .stringLiteral: NSColor(red: 0.77, green: 0.1, blue: 0.09, alpha: 1.0),  // Red
        .comment: NSColor(red: 0.42, green: 0.47, blue: 0.46, alpha: 1.0),       // Gray
        .operator: NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),         // Black
        .punctuation: NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),      // Black
        .whitespace: NSColor.clear,
        .unknown: NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)           // Black
    ]
    
    /// Diagnostic severity colors
    private let diagnosticColors: [DiagnosticSeverity: NSColor] = [
        .error: NSColor.systemRed,
        .warning: NSColor.systemYellow,
        .info: NSColor.systemBlue,
        .hint: NSColor.systemGray
    ]
    
    // MARK: - Initialization
    
    // MARK: - Private Properties
    
    private var syntaxDecorations: [Decoration] = []
    private var diagnosticDecorations: [Decoration] = []
    private var selectionDecorations: [Decoration] = []
    private var bracketDecorations: [Decoration] = []
    private var hiddenDecorations: [Decoration] = []
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Token to Decoration Conversion
    
    /// Update decorations from tokens received from Language Engine.
    /// Converts tokens to platform-agnostic decoration objects.
    /// Requirements: 3.1
    /// - Parameter tokens: Array of tokens from tokenization
    func update(from tokens: [Token]) {
        syntaxDecorations = tokens.compactMap { token -> Decoration? in
            // Skip whitespace tokens - they don't need visual decoration
            guard token.kind != .whitespace else { return nil }
            
            let color = syntaxColors[token.kind] ?? NSColor.black
            let traits = fontTraits(for: token.kind)
            
            return Decoration(
                range: token.range,
                kind: .syntax(color: color, traits: traits),
                priority: 0
            )
        }
        rebuildDecorations()
    }
    
    /// - Parameter diagnostics: Array of diagnostics from semantic analysis
    func update(from diagnostics: [Diagnostic]) {
        diagnosticDecorations = diagnostics.map { diagnostic -> Decoration in
            let color = diagnosticColors[diagnostic.severity] ?? NSColor.systemRed
            return Decoration(
                range: diagnostic.range,
                kind: .underline(color: color, style: .squiggly),
                priority: 10, // Higher priority than syntax highlighting
                tooltip: diagnostic.message
            )
        }
        rebuildDecorations()
    }
    
    /// Update selection and caret decorations.
    /// Requirements: 3.3
    /// - Parameter selection: Current selection state
    func updateSelection(_ selection: Selection) {
        selectionDecorations = []
        
        // Add selection highlight if not collapsed
        if !selection.isCollapsed {
            let selectionDecoration = Decoration(
                range: selection.range,
                kind: .background(color: NSColor.selectedTextBackgroundColor),
                priority: -1 // Lower priority than syntax
            )
            selectionDecorations.append(selectionDecoration)
        }
        rebuildDecorations()
    }
    
    /// Update bracket matching decorations.
    /// Requirements: 3.3, 10.2, 10.3
    /// - Parameter matchResult: Result from BracketMatcher
    func update(from matchResult: BracketMatchResult?) {
        bracketDecorations = []
        
        guard let result = matchResult else {
            rebuildDecorations()
            return
        }
        
        // Add open bracket decoration
        let openBracket = Decoration(
            range: result.openRange,
            kind: .bracket(isMatched: result.isMatched),
            priority: 5
        )
        bracketDecorations.append(openBracket)
        
        // Add close bracket decoration
        // If unmatched, closeRange might point to same location as openRange (self-pointer error),
        // but we should check if they are different to avoid duplicate decoration on same range if logic changes.
        // In current BracketMatcher, unmatched returns self-pointer.
        if result.openRange != result.closeRange {
            let closeBracket = Decoration(
                range: result.closeRange,
                kind: .bracket(isMatched: result.isMatched),
                priority: 5
            )
            bracketDecorations.append(closeBracket)
        }
        
        rebuildDecorations()
    }
    
    /// Update hidden decorations (for folding).
    /// Requirements: 11.2
    /// - Parameter hiddenDecorations: Array of hidden decorations
    func update(hiddenDecorations: [Decoration]) {
        self.hiddenDecorations = hiddenDecorations
        rebuildDecorations()
    }
    
    // MARK: - Query Methods
    
    /// Get decorations that intersect with the given range.
    /// Optimized for performance with early termination and minimal allocations.
    /// Requirements: 14.3 (60fps scroll performance)
    /// - Parameter range: Character range to query
    /// - Returns: Array of decorations in the range, sorted by priority
    func decorations(in range: Range<Int>) -> [Decoration] {
        // Pre-allocate with estimated capacity to reduce allocations
        var result: [Decoration] = []
        result.reserveCapacity(min(decorations.count, 100))
        
        for decoration in decorations {
            // Early termination: if decoration starts after range ends, skip
            // (only works if decorations are sorted by start position)
            if decoration.range.lowerBound >= range.upperBound {
                continue
            }
            // Skip if decoration ends before range starts
            if decoration.range.upperBound <= range.lowerBound {
                continue
            }
            result.append(decoration)
        }
        
        // Sort by priority (higher priority first)
        result.sort { $0.priority > $1.priority }
        return result
    }
    
    /// Get line decorations for a specific line.
    /// - Parameter lineIndex: Zero-based line index
    /// - Returns: Array of line decorations for the line
    func lineDecorations(for lineIndex: Int) -> [LineDecoration] {
        lineDecorations.filter { $0.lineIndex == lineIndex }
    }
    
    // MARK: - Private Helpers
    
    private func rebuildDecorations() {
        decorations = syntaxDecorations + diagnosticDecorations + selectionDecorations + bracketDecorations + hiddenDecorations
    }
    
    /// Get font traits for a token kind
    private func fontTraits(for kind: TokenKind) -> FontTraits {
        switch kind {
        case .keyword:
            return .bold
        case .comment:
            return .italic
        default:
            return []
        }
    }
}
