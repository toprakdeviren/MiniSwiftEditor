//
//  IndentHandler.swift
//  MiniSwiftEditor
//
//  Handles indentation logic for the code editor
//  Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 9.1, 9.2, 9.4
//

import Foundation

/// Configuration for indentation
public struct IndentConfiguration {
    /// Whether to use spaces instead of tabs
    public var useSpaces: Bool = true
    /// Number of spaces per tab
    public var tabWidth: Int = 4
    
    public static let `default` = IndentConfiguration()
    
    public init(useSpaces: Bool = true, tabWidth: Int = 4) {
        self.useSpaces = useSpaces
        self.tabWidth = tabWidth
    }
}

/// Handles indentation logic including auto-indent and block indentation
public final class IndentHandler {
    
    // MARK: - Properties
    
    /// Current indentation configuration
    public var configuration: IndentConfiguration
    
    // MARK: - Initialization
    
    public init(configuration: IndentConfiguration = .default) {
        self.configuration = configuration
    }
    
    // MARK: - Public Methods
    
    /// Get the string representation of a single indentation level
    var indentString: String {
        if configuration.useSpaces {
            return String(repeating: " ", count: configuration.tabWidth)
        } else {
            return "\t"
        }
    }
    
    /// Calculate the indentation for a new line based on the previous line
    /// - Parameter previousLine: The content of the previous line
    /// - Returns: The indentation string for the new line
    func calculateIndent(forNewLineAfter previousLine: String) -> String {
        let currentIndent = currentIndentation(of: previousLine)
        
        // Check if previous line ends with opening brace
        let trimmed = previousLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("{") || trimmed.hasSuffix("(") || trimmed.hasSuffix("[") {
            return currentIndent + indentString
        }
        
        // Check for control flow statements that might not have braces yet (e.g. if condition)
        // For now, we stick to brace-based indentation as per requirements 8.2
        
        return currentIndent
    }
    
    /// Calculate indentation for a line that starts with a closing brace
    /// - Parameters:
    ///   - lineContent: The content of the line being typed/formatted
    ///   - currentIndent: The current indentation of the line
    /// - Returns: The adjusted indentation string
    func adjustIndentForClosingBrace(lineContent: String, currentIndent: String) -> String {
        let trimmed = lineContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("}") || trimmed.hasPrefix(")") || trimmed.hasPrefix("]") {
            // Decrease indent
            if currentIndent.hasSuffix(indentString) {
                return String(currentIndent.dropLast(indentString.count))
            } else if currentIndent.hasSuffix("\t") {
                return String(currentIndent.dropLast())
            } else if currentIndent.hasSuffix(" ") {
                // Try to remove up to tabWidth spaces
                var newIndent = currentIndent
                for _ in 0..<configuration.tabWidth {
                    if newIndent.hasSuffix(" ") {
                        newIndent.removeLast()
                    } else {
                        break
                    }
                }
                return newIndent
            }
        }
        return currentIndent
    }
    
    /// Indent a block of text (add one level of indentation)
    /// - Parameter text: The text to indent
    /// - Returns: The indented text
    func indent(text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        let indentedLines = lines.map { line -> String in
            if line.isEmpty { return line }
            return indentString + line
        }
        return indentedLines.joined(separator: "\n")
    }
    
    /// Outdent a block of text (remove one level of indentation)
    /// - Parameter text: The text to outdent
    /// - Returns: The outdented text
    func outdent(text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        let outdentedLines = lines.map { line -> String in
            if line.hasPrefix(indentString) {
                return String(line.dropFirst(indentString.count))
            } else if line.hasPrefix("\t") {
                return String(line.dropFirst())
            } else {
                // Try to remove spaces up to tabWidth
                var newLine = line
                var spacesToRemove = configuration.tabWidth
                while spacesToRemove > 0 && newLine.hasPrefix(" ") {
                    newLine.removeFirst()
                    spacesToRemove -= 1
                }
                return newLine
            }
        }
        return outdentedLines.joined(separator: "\n")
    }
    
    /// Convert tabs to spaces in the given text
    /// - Parameter text: The text to convert
    /// - Returns: Text with tabs replaced by spaces
    func convertTabsToSpaces(in text: String) -> String {
        let spaces = String(repeating: " ", count: configuration.tabWidth)
        return text.replacingOccurrences(of: "\t", with: spaces)
    }
    
    // MARK: - Private Helpers
    
    /// Extract the indentation string from a line
    private func currentIndentation(of line: String) -> String {
        var indent = ""
        for char in line {
            if char == " " || char == "\t" {
                indent.append(char)
            } else {
                break
            }
        }
        return indent
    }
}
