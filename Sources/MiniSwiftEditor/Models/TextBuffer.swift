//
//  TextBuffer.swift
//  MiniSwiftEditor
//
//  Core protocol for text storage layer
//

import Foundation

/// Protocol defining the interface for text buffer implementations.
/// Supports both simple StringBuffer and optimized RopeBuffer for large files.
/// Requirements: 1.1, 1.3, 1.4
protocol TextBuffer: AnyObject {
    /// The complete text content of the buffer
    var content: String { get }
    
    /// Total number of lines in the buffer
    var lineCount: Int { get }
    
    /// Version counter for incremental parsing coordination
    /// Increments after each edit operation
    var version: Int { get }
    
    /// Insert text at the specified offset
    /// - Parameters:
    ///   - text: The text to insert
    ///   - offset: The character offset where insertion should occur
    func insert(_ text: String, at offset: Int)
    
    /// Delete text in the specified range
    /// - Parameter range: The range of characters to delete
    func delete(range: Range<Int>)
    
    /// Get the character range for a specific line
    /// - Parameter lineIndex: Zero-based line index
    /// - Returns: The character range for the line
    func lineRange(for lineIndex: Int) -> Range<Int>
    
    /// Get the line index for a specific character offset
    /// - Parameter offset: Character offset in the document
    /// - Returns: Zero-based line index containing the offset
    func lineIndex(for offset: Int) -> Int
    
    /// Get the starting character offset for a specific line
    /// - Parameter lineIndex: Zero-based line index
    /// - Returns: Character offset where the line begins
    func offset(for lineIndex: Int) -> Int
}
