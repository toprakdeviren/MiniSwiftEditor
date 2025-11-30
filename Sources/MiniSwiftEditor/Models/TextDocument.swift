//
//  TextDocument.swift
//  MiniSwiftEditor
//
//  TextDocument wrapper providing ObservableObject interface for SwiftUI
//  Requirements: 1.1, 1.5, 1.6
//

import Foundation
import Combine

/// Errors that can occur during text document operations
enum TextDocumentError: Error, Equatable {
    case invalidOffset(Int)
    case invalidRange(Range<Int>)
    case encodingFailed(String)
    case decodingFailed(String)
}

/// Codable representation of TextDocument for serialization
struct TextDocumentData: Codable, Equatable {
    let content: String
    let version: Int
    
    init(content: String, version: Int) {
        self.content = content
        self.version = version
    }
}

/// TextDocument wraps a TextBuffer and provides ObservableObject interface
/// for SwiftUI integration. Handles serialization/deserialization of document state.
/// Requirements: 1.1, 1.5, 1.6
final class TextDocument: ObservableObject {
    
    // MARK: - Private Properties
    
    /// The underlying text buffer
    private var buffer: TextBuffer
    
    // MARK: - Published Properties
    
    /// Current version of the document (increments on each edit)
    @Published private(set) var version: Int
    
    // MARK: - Computed Properties
    
    /// The complete text content of the document
    var content: String {
        buffer.content
    }
    
    /// Total number of lines in the document
    var lineCount: Int {
        buffer.lineCount
    }
    
    // MARK: - Initialization
    
    /// Initialize with an optional initial content
    /// - Parameter initialContent: The initial text content (defaults to empty string)
    init(_ initialContent: String = "") {
        // Check line count to decide buffer type
        // Requirements: 14.2
        let lineCount = initialContent.filter { $0 == "\n" }.count + 1
        
        if lineCount >= 100_000 {
            let ropeBuffer = RopeBuffer(initialContent)
            self.buffer = ropeBuffer
            self.version = ropeBuffer.version
        } else {
            let stringBuffer = StringBuffer(initialContent)
            self.buffer = stringBuffer
            self.version = stringBuffer.version
        }
    }
    
    /// Initialize with an existing TextBuffer
    /// - Parameter buffer: The text buffer to wrap
    init(buffer: TextBuffer) {
        self.buffer = buffer
        self.version = buffer.version
    }
    
    // MARK: - Text Access Methods
    
    /// Get text content within a specific range
    /// - Parameter range: The character range to extract
    /// - Returns: The text within the specified range
    /// - Throws: TextDocumentError.invalidRange if range is out of bounds
    func text(in range: Range<Int>) throws -> String {
        guard range.lowerBound >= 0 && range.upperBound <= content.count else {
            throw TextDocumentError.invalidRange(range)
        }
        guard range.lowerBound <= range.upperBound else {
            throw TextDocumentError.invalidRange(range)
        }
        
        let startIndex = content.index(content.startIndex, offsetBy: range.lowerBound)
        let endIndex = content.index(content.startIndex, offsetBy: range.upperBound)
        return String(content[startIndex..<endIndex])
    }
    
    /// Get the character range for a specific line
    /// - Parameter lineIndex: Zero-based line index
    /// - Returns: The character range for the line
    func lineRange(for lineIndex: Int) -> Range<Int> {
        buffer.lineRange(for: lineIndex)
    }
    
    /// Get the line index for a specific character offset
    /// - Parameter offset: Character offset in the document
    /// - Returns: Zero-based line index containing the offset
    func lineIndex(for offset: Int) -> Int {
        buffer.lineIndex(for: offset)
    }
    
    /// Get the starting character offset for a specific line
    /// - Parameter lineIndex: Zero-based line index
    /// - Returns: Character offset where the line begins
    func offset(for lineIndex: Int) -> Int {
        buffer.offset(for: lineIndex)
    }

    
    // MARK: - Edit Operations
    
    /// Insert text at the specified offset
    /// - Parameters:
    ///   - text: The text to insert
    ///   - offset: The character offset where insertion should occur
    func insert(_ text: String, at offset: Int) {
        buffer.insert(text, at: offset)
        version = buffer.version
    }
    
    /// Delete text in the specified range
    /// - Parameter range: The range of characters to delete
    func delete(range: Range<Int>) {
        buffer.delete(range: range)
        version = buffer.version
    }
    
    /// Replace text in the specified range with new text
    /// - Parameters:
    ///   - range: The range of characters to replace
    ///   - newText: The replacement text
    func replace(range: Range<Int>, with newText: String) {
        buffer.delete(range: range)
        buffer.insert(newText, at: range.lowerBound)
        version = buffer.version
    }
    
    // MARK: - Serialization
    
    /// Serialize the document to JSON data
    /// - Returns: JSON encoded data representing the document
    /// - Throws: TextDocumentError.encodingFailed if encoding fails
    func serialize() throws -> Data {
        let documentData = TextDocumentData(content: content, version: version)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            return try encoder.encode(documentData)
        } catch {
            throw TextDocumentError.encodingFailed(error.localizedDescription)
        }
    }
    
    /// Serialize the document to a JSON string
    /// - Returns: JSON string representing the document
    /// - Throws: TextDocumentError.encodingFailed if encoding fails
    func serializeToString() throws -> String {
        let data = try serialize()
        guard let string = String(data: data, encoding: .utf8) else {
            throw TextDocumentError.encodingFailed("Failed to convert data to UTF-8 string")
        }
        return string
    }
    
    // MARK: - Deserialization

    /// - Parameter data: JSON encoded document data
    /// - Returns: A new TextDocument instance
    /// - Throws: TextDocumentError.decodingFailed if decoding fails
    static func deserialize(from data: Data) throws -> TextDocument {
        do {
            let decoder = JSONDecoder()
            let documentData = try decoder.decode(TextDocumentData.self, from: data)
            return TextDocument(documentData.content)
        } catch {
            throw TextDocumentError.decodingFailed(error.localizedDescription)
        }
    }

    /// - Parameter string: JSON string representing the document
    /// - Returns: A new TextDocument instance
    /// - Throws: TextDocumentError.decodingFailed if decoding fails
    static func deserialize(from string: String) throws -> TextDocument {
        guard let data = string.data(using: .utf8) else {
            throw TextDocumentError.decodingFailed("Failed to convert string to UTF-8 data")
        }
        return try deserialize(from: data)
    }
    
    /// Get the serializable data representation
    /// - Returns: TextDocumentData for the current state
    func toDocumentData() -> TextDocumentData {
        TextDocumentData(content: content, version: version)
    }
}
