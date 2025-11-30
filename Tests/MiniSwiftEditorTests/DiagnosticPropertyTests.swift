//
//  DiagnosticPropertyTests.swift
//  MiniSwiftEditorTests
//
//  Property-based tests for Diagnostics
//

import Testing
@testable import MiniSwiftEditor

@MainActor
struct DiagnosticPropertyTests {
    
    // MARK: - Test Helpers
    
    /// Generate random Swift source code with potential errors
    static func randomSourceWithErrors(length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 \n\t{}()[].,;:+-*/=<>!&|^~?@#$%\"\\"
        // Include some invalid characters for 'unknown' tokens if we want to force errors,
        // but the tokenizer treats most things as valid or unknown.
        // Let's inject some specific patterns.
        
        var source = String((0..<length).map { _ in characters.randomElement()! })
        
        // Inject TODOs
        if Bool.random() {
            source += "\n// TODO: Fix this"
        }
        
        // Inject unterminated string
        if Bool.random() {
            source += "\n\"Unterminated string"
        }
        
        return source
    }
    
    @Test("Property 5: Diagnostic Range Validity - All diagnostics have valid ranges")
    func diagnosticRangeValidity() async {
        let tokenizer = SwiftTokenizer()
        
        for _ in 0..<100 {
            let source = Self.randomSourceWithErrors(length: Int.random(in: 1...500))
            let buffer = StringBuffer(source)
            
            let result = await tokenizer.analyze(document: buffer)
            
            for diagnostic in result.diagnostics {
                // Check range bounds
                #expect(diagnostic.range.lowerBound >= 0,
                       "Diagnostic range start \(diagnostic.range.lowerBound) should be >= 0")
                
                #expect(diagnostic.range.upperBound <= source.count,
                       "Diagnostic range end \(diagnostic.range.upperBound) should be <= source length \(source.count)")
                
                #expect(diagnostic.range.lowerBound < diagnostic.range.upperBound,
                       "Diagnostic range should not be empty")
                
                // Check that the range corresponds to actual content
                // (This is implicit if bounds are valid, but good to keep in mind)
            }
        }
    }
    
    @Test("Diagnostics for unknown tokens")
    func diagnosticsForUnknownTokens() async {
        let tokenizer = SwiftTokenizer()
        // '`' backtick is valid in identifiers if escaped, but standalone might be unknown depending on tokenizer.
        // Let's use a character that is definitely unknown if not handled, e.g. maybe a control char or emoji if not supported?
        // The tokenizer supports unicode identifiers, so emojis are valid identifiers.
        // Let's look at tokenizer implementation. It has a default 'unknown' case.
        // Characters like '$' are identifiers.
        // Let's try to find something that produces .unknown.
        // In SwiftTokenizer.swift:
        // default: return .unknown
        
        // Let's use a random string and check if any .unknown token produces a diagnostic.
        
        for _ in 0..<50 {
            let source = Self.randomSourceWithErrors(length: 100)
            let buffer = StringBuffer(source)
            let result = await tokenizer.analyze(document: buffer)
            
            // Verify that every .unknown token has a corresponding error diagnostic
            let unknownTokens = result.tokens.filter { $0.kind == .unknown }
            
            for token in unknownTokens {
                let hasDiagnostic = result.diagnostics.contains { diagnostic in
                    diagnostic.range == token.range && diagnostic.severity == .error
                }
                #expect(hasDiagnostic, "Unknown token at \(token.range) should have an error diagnostic")
            }
        }
    }
    
    @Test("Diagnostics for TODO comments")
    func diagnosticsForTodoComments() async {
        let tokenizer = SwiftTokenizer()
        let source = """
        // Normal comment
        // TODO: Implement this
        /* Block comment with FIXME */
        """
        let buffer = StringBuffer(source)
        let result = await tokenizer.analyze(document: buffer)
        
        let todoDiagnostics = result.diagnostics.filter { $0.message.contains("TODO") }
        let fixmeDiagnostics = result.diagnostics.filter { $0.message.contains("FIXME") }
        
        #expect(!todoDiagnostics.isEmpty, "Should find TODO diagnostic")
        #expect(!fixmeDiagnostics.isEmpty, "Should find FIXME diagnostic")
        
        if let todo = todoDiagnostics.first {
            #expect(todo.severity == .info, "TODO should be info")
        }
        
        if let fixme = fixmeDiagnostics.first {
            #expect(fixme.severity == .warning, "FIXME should be warning")
        }
    }
    
    @Test("Diagnostics for unterminated strings")
    func diagnosticsForUnterminatedStrings() async {
        let tokenizer = SwiftTokenizer()
        let source = "let s = \"Hello world" // Missing closing quote
        let buffer = StringBuffer(source)
        let result = await tokenizer.analyze(document: buffer)
        
        let stringDiagnostics = result.diagnostics.filter { $0.message.contains("Unterminated string") }
        
        #expect(!stringDiagnostics.isEmpty, "Should find unterminated string diagnostic")
        
        if let diag = stringDiagnostics.first {
            #expect(diag.severity == .error, "Unterminated string should be error")
            #expect(diag.range.upperBound == source.count, "Diagnostic should cover the string")
        }
    }
}
