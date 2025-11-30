//
//  DecorationModelTests.swift
//  MiniSwiftEditorTests
//
//  Tests for DecorationModel
//

import Testing
import AppKit
@testable import MiniSwiftEditor

@MainActor
struct DecorationModelTests {
    
    @Test("Diagnostic to Decoration Mapping")
    func diagnosticToDecorationMapping() {
        let model = DecorationModel()
        
        let diagnostics = [
            Diagnostic(range: 0..<5, message: "Error", severity: .error),
            Diagnostic(range: 10..<15, message: "Warning", severity: .warning),
            Diagnostic(range: 20..<25, message: "Info", severity: .info)
        ]
        
        model.update(from: diagnostics)
        
        let decorations = model.decorations(in: 0..<30)
        
        // Check count
        #expect(decorations.count == 3, "Should have 3 decorations")
        
        // Check Error decoration
        let errorDec = decorations.first { $0.range == 0..<5 }
        #expect(errorDec != nil)
        if let dec = errorDec {
            if case .underline(let color, let style) = dec.kind {
                #expect(color == NSColor.systemRed)
                #expect(style == .squiggly)
            } else {
                Issue.record("Expected underline decoration for error")
            }
            #expect(dec.priority == 10)
        }
        
        // Check Warning decoration
        let warningDec = decorations.first { $0.range == 10..<15 }
        #expect(warningDec != nil)
        if let dec = warningDec {
            if case .underline(let color, _) = dec.kind {
                #expect(color == NSColor.systemYellow)
            } else {
                Issue.record("Expected underline decoration for warning")
            }
        }
    }
    
    @Test("Decorations are merged correctly")
    func decorationsMerge() {
        let model = DecorationModel()
        
        // Add syntax tokens
        let tokens = [
            Token(range: 0..<5, kind: .keyword),
            Token(range: 6..<10, kind: .identifier)
        ]
        model.update(from: tokens)
        
        // Add diagnostics
        let diagnostics = [
            Diagnostic(range: 6..<10, message: "Unknown identifier", severity: .error)
        ]
        model.update(from: diagnostics)
        
        // Add selection
        let selection = Selection(anchor: 0, head: 5)
        model.updateSelection(selection)
        
        let allDecorations = model.decorations(in: 0..<20)
        
        // Should have: 2 syntax + 1 diagnostic + 1 selection = 4
        #expect(allDecorations.count == 4)
        
        // Verify types
        let syntaxCount = allDecorations.filter { if case .syntax = $0.kind { return true } else { return false } }.count
        let diagnosticCount = allDecorations.filter { if case .underline = $0.kind { return true } else { return false } }.count
        let selectionCount = allDecorations.filter { if case .background = $0.kind { return true } else { return false } }.count
        
        #expect(syntaxCount == 2)
        #expect(diagnosticCount == 1)
        #expect(selectionCount == 1)
    }
}
