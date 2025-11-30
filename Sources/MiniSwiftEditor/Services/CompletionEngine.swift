//
//  CompletionEngine.swift
//  MiniSwiftEditor
//
//  Handles code completion suggestions
//  Requirements: 12.1, 12.2
//

import Foundation

/// Kind of completion item
enum CompletionKind: Equatable, Hashable {
    case keyword
    case function
    case variable
    case type
    case snippet
}

/// Represents a completion suggestion
struct CompletionItem: Equatable, Hashable, Identifiable {
    var id: String { label }
    
    /// The label to display in the list
    let label: String
    /// The kind of item (icon)
    let kind: CompletionKind
    /// Additional details (e.g. type signature)
    let detail: String?
    /// The text to insert (defaults to label)
    let insertText: String
    
    init(label: String, kind: CompletionKind, detail: String? = nil, insertText: String? = nil) {
        self.label = label
        self.kind = kind
        self.detail = detail
        self.insertText = insertText ?? label
    }
}

/// Manages code completion
final class CompletionEngine {
    
    // MARK: - Properties
    
    /// Standard Swift keywords
    private let keywords: [String] = [
        "func", "var", "let", "if", "else", "guard", "return",
        "class", "struct", "enum", "protocol", "extension",
        "import", "public", "private", "fileprivate", "internal",
        "init", "deinit", "self", "super", "try", "catch", "throw"
    ]
    
    /// Standard types
    private let types: [String] = [
        "String", "Int", "Double", "Float", "Bool", "Array", "Dictionary", "Set", "Optional"
    ]
    
    // MARK: - Public Methods
    
    /// Get completions for a given prefix
    /// - Parameters:
    ///   - prefix: The text prefix to match
    ///   - location: The cursor location (unused for now, but useful for context)
    /// - Returns: List of matching completion items
    func completions(for prefix: String, at location: Int) -> [CompletionItem] {
        guard !prefix.isEmpty else { return [] }
        
        var items: [CompletionItem] = []
        
        // Add keywords
        let matchingKeywords = keywords.filter { $0.hasPrefix(prefix) }
        items.append(contentsOf: matchingKeywords.map {
            CompletionItem(label: $0, kind: .keyword)
        })
        
        // Add types
        let matchingTypes = types.filter { $0.hasPrefix(prefix) }
        items.append(contentsOf: matchingTypes.map {
            CompletionItem(label: $0, kind: .type)
        })
        
        // TODO: Add symbols from LanguageEngine/SymbolTable
        
        return items.sorted { $0.label < $1.label }
    }
}
