//
//  EditorConfiguration.swift
//  MiniSwiftEditor
//
//  Configuration and theme settings for the code editor
//  Requirements: 15.1
//

import AppKit

// MARK: - Editor Theme

/// Theme configuration for the code editor
public struct EditorTheme {
    /// Background color of the editor
    public var backgroundColor: NSColor
    /// Default text color
    public var textColor: NSColor
    /// Selection highlight color
    public var selectionColor: NSColor
    /// Caret (insertion point) color
    public var caretColor: NSColor
    /// Line number text color
    public var lineNumberColor: NSColor
    /// Gutter background color
    public var gutterBackgroundColor: NSColor
    /// Syntax colors for different token kinds
    public var syntaxColors: [TokenKind: NSColor]
    
    public init(
        backgroundColor: NSColor,
        textColor: NSColor,
        selectionColor: NSColor,
        caretColor: NSColor,
        lineNumberColor: NSColor,
        gutterBackgroundColor: NSColor,
        syntaxColors: [TokenKind: NSColor]
    ) {
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.selectionColor = selectionColor
        self.caretColor = caretColor
        self.lineNumberColor = lineNumberColor
        self.gutterBackgroundColor = gutterBackgroundColor
        self.syntaxColors = syntaxColors
    }
    
    /// Default adaptive theme
    public static let `default` = EditorTheme(
        backgroundColor: .textBackgroundColor,
        textColor: .textColor,
        selectionColor: .selectedTextBackgroundColor,
        caretColor: .textColor,
        lineNumberColor: .secondaryLabelColor,
        gutterBackgroundColor: NSColor(named: "GutterBackgroundColor") ?? NSColor.controlBackgroundColor,
        syntaxColors: [
            .keyword: NSColor.systemPink,
            .identifier: NSColor.textColor,
            .typeIdentifier: NSColor.systemPurple,
            .numberLiteral: NSColor.systemBlue,
            .stringLiteral: NSColor.systemRed,
            .comment: NSColor.systemGreen,
            .operator: NSColor.textColor,
            .punctuation: NSColor.textColor,
            .whitespace: NSColor.clear,
            .unknown: NSColor.systemRed
        ]
    )
    
    /// Dark theme
    public static let dark = EditorTheme(
        backgroundColor: NSColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0),
        textColor: NSColor(white: 0.9, alpha: 1.0),
        selectionColor: NSColor(red: 0.3, green: 0.4, blue: 0.6, alpha: 1.0),
        caretColor: NSColor(white: 0.9, alpha: 1.0),
        lineNumberColor: NSColor(white: 0.5, alpha: 1.0),
        gutterBackgroundColor: NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0),
        syntaxColors: [
            .keyword: NSColor(red: 0.99, green: 0.42, blue: 0.63, alpha: 1.0),
            .identifier: NSColor(white: 0.9, alpha: 1.0),
            .typeIdentifier: NSColor(red: 0.35, green: 0.78, blue: 0.98, alpha: 1.0),
            .numberLiteral: NSColor(red: 0.82, green: 0.68, blue: 0.47, alpha: 1.0),
            .stringLiteral: NSColor(red: 0.99, green: 0.42, blue: 0.42, alpha: 1.0),
            .comment: NSColor(red: 0.51, green: 0.58, blue: 0.55, alpha: 1.0),
            .operator: NSColor(white: 0.9, alpha: 1.0),
            .punctuation: NSColor(white: 0.9, alpha: 1.0),
            .whitespace: NSColor.clear,
            .unknown: NSColor(white: 0.9, alpha: 1.0)
        ]
    )
}

// MARK: - Editor Configuration

/// Configuration options for the code editor
public struct EditorConfiguration {
    /// Font for the editor text
    public var font: NSFont
    /// Theme for colors and styling
    public var theme: EditorTheme
    /// Number of spaces per tab
    public var tabWidth: Int
    /// Whether to use spaces instead of tabs
    public var useSpaces: Bool
    /// Whether to show line numbers in the gutter
    public var showLineNumbers: Bool
    /// Whether to show the gutter
    public var showGutter: Bool
    /// Whether to enable auto-indentation
    public var autoIndent: Bool
    /// Whether to enable bracket matching
    public var bracketMatching: Bool
    /// Whether to enable code folding
    public var codeFolding: Bool
    /// Whether the editor is read-only
    public var isReadOnly: Bool
    
    public init(
        font: NSFont = .monospacedSystemFont(ofSize: 13, weight: .regular),
        theme: EditorTheme = .default,
        tabWidth: Int = 4,
        useSpaces: Bool = true,
        showLineNumbers: Bool = true,
        showGutter: Bool = true,
        autoIndent: Bool = true,
        bracketMatching: Bool = true,
        codeFolding: Bool = true,
        isReadOnly: Bool = false
    ) {
        self.font = font
        self.theme = theme
        self.tabWidth = tabWidth
        self.useSpaces = useSpaces
        self.showLineNumbers = showLineNumbers
        self.showGutter = showGutter
        self.autoIndent = autoIndent
        self.bracketMatching = bracketMatching
        self.codeFolding = codeFolding
        self.isReadOnly = isReadOnly
    }
    
    /// Default configuration (editable)
    public static let `default` = EditorConfiguration(
        font: .monospacedSystemFont(ofSize: 13, weight: .regular),
        theme: .default,
        tabWidth: 4,
        useSpaces: true,
        showLineNumbers: true,
        showGutter: true,
        autoIndent: true,
        bracketMatching: true,
        codeFolding: true,
        isReadOnly: false
    )
    
    /// Read-only configuration
    public static let readOnly = EditorConfiguration(
        font: .monospacedSystemFont(ofSize: 13, weight: .regular),
        theme: .default,
        tabWidth: 4,
        useSpaces: true,
        showLineNumbers: true,
        showGutter: true,
        autoIndent: false,
        bracketMatching: true,
        codeFolding: true,
        isReadOnly: true
    )
}
