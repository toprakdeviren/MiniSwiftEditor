//
//  IndentHandlerPropertyTests.swift
//  MiniSwiftEditorTests
//
//  Property-based tests for IndentHandler
//

import Foundation
import Testing
@testable import MiniSwiftEditor

struct IndentHandlerPropertyTests {
    
    // MARK: - Helpers
    
    /// Generate random indentation string (spaces or tabs)
    static func randomIndent() -> String {
        let depth = Int.random(in: 0...5)
        let useSpaces = Bool.random()
        if useSpaces {
            return String(repeating: "    ", count: depth)
        } else {
            return String(repeating: "\t", count: depth)
        }
    }
    
    /// Generate random line content
    static func randomLineContent() -> String {
        let length = Int.random(in: 1...20)
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in chars.randomElement()! })
    }
    
    @Test("Property 16: Auto-Indent Preservation")
    func autoIndentPreservation() {
        let handler = IndentHandler()
        
        for _ in 0..<100 {
            let indent = Self.randomIndent()
            let content = Self.randomLineContent()
            let line = indent + content
            
            // Calculate indent for next line (assuming no braces)
            let nextIndent = handler.calculateIndent(forNewLineAfter: line)
            
            #expect(nextIndent == indent, "Should preserve indentation level")
        }
    }
    
    @Test("Property 17: Brace-Aware Indent Increase")
    func braceAwareIndentIncrease() {
        let handler = IndentHandler()
        let indentString = handler.indentString
        
        for _ in 0..<100 {
            let indent = Self.randomIndent()
            let content = Self.randomLineContent()
            
            // Test with {, (, [
            let braces = ["{", "(", "["]
            for brace in braces {
                let line = indent + content + " " + brace
                let nextIndent = handler.calculateIndent(forNewLineAfter: line)
                
                #expect(nextIndent == indent + indentString, "Should increase indent after \(brace)")
            }
        }
    }
    
    @Test("Property 18: Closing Brace Indent Decrease")
    func closingBraceIndentDecrease() {
        let handler = IndentHandler()
        let indentString = handler.indentString
        
        for _ in 0..<100 {
            let baseIndent = Self.randomIndent()
            let currentIndent = baseIndent + indentString
            
            // Test with }, ), ]
            let braces = ["}", ")", "]"]
            for brace in braces {
                let lineContent = brace + Self.randomLineContent()
                let adjustedIndent = handler.adjustIndentForClosingBrace(lineContent: lineContent, currentIndent: currentIndent)
                
                #expect(adjustedIndent == baseIndent, "Should decrease indent for \(brace)")
            }
        }
    }
    
    @Test("Property 19: Multi-Line Indent Operation")
    func multiLineIndent() {
        let handler = IndentHandler()
        let indentString = handler.indentString
        
        for _ in 0..<50 {
            let lines = (0..<5).map { _ in Self.randomIndent() + Self.randomLineContent() }
            let text = lines.joined(separator: "\n")
            
            let indentedText = handler.indent(text: text)
            let indentedLines = indentedText.components(separatedBy: "\n")
            
            for (original, indented) in zip(lines, indentedLines) {
                #expect(indented == indentString + original, "Should prepend indent string")
            }
        }
    }
    
    @Test("Property 20: Multi-Line Outdent Operation")
    func multiLineOutdent() {
        let handler = IndentHandler()
        let indentString = handler.indentString
        
        for _ in 0..<50 {
            let originalLines = (0..<5).map { _ in Self.randomIndent() + Self.randomLineContent() }
            let indentedLines = originalLines.map { indentString + $0 }
            let text = indentedLines.joined(separator: "\n")
            
            let outdentedText = handler.outdent(text: text)
            let outdentedLines = outdentedText.components(separatedBy: "\n")
            
            for (original, outdented) in zip(originalLines, outdentedLines) {
                #expect(outdented == original, "Should remove one level of indentation")
            }
        }
    }
    
    @Test("Property 21: Tab-to-Spaces Conversion")
    func tabToSpacesConversion() {
        let handler = IndentHandler()
        // Ensure spaces config
        handler.configuration.useSpaces = true
        handler.configuration.tabWidth = 4
        let spaces = "    "
        
        for _ in 0..<50 {
            let content = Self.randomLineContent()
            let textWithTabs = "\t" + content + "\t" + content
            
            let converted = handler.convertTabsToSpaces(in: textWithTabs)
            
            #expect(!converted.contains("\t"), "Should not contain tabs")
            #expect(converted == spaces + content + spaces + content, "Should replace tabs with spaces")
        }
    }
}
