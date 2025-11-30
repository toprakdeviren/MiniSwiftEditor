//
//  DiagnosticPriorityTests.swift
//  MiniSwiftEditorTests
//
//  Tests for diagnostic severity priority
//

import Testing
@testable import MiniSwiftEditor

struct DiagnosticPriorityTests {
    
    @Test("Diagnostic Severity Comparison")
    func severityComparison() {
        #expect(DiagnosticSeverity.error > .warning)
        #expect(DiagnosticSeverity.warning > .info)
        #expect(DiagnosticSeverity.info > .hint)
        #expect(DiagnosticSeverity.error > .hint)
    }
    
    @Test("Highest severity selection logic")
    func highestSeveritySelection() {
        // Simulate the logic used in CodeEditorContainerView
        
        func getHighestSeverity(for diagnostics: [Diagnostic]) -> DiagnosticSeverity? {
            var highest: DiagnosticSeverity?
            for diagnostic in diagnostics {
                if let current = highest {
                    if diagnostic.severity > current {
                        highest = diagnostic.severity
                    }
                } else {
                    highest = diagnostic.severity
                }
            }
            return highest
        }
        
        // Case 1: Error and Warning -> Error
        let mixed1 = [
            Diagnostic(range: 0..<1, message: "W", severity: .warning),
            Diagnostic(range: 0..<1, message: "E", severity: .error)
        ]
        #expect(getHighestSeverity(for: mixed1) == .error)
        
        // Case 2: Info and Warning -> Warning
        let mixed2 = [
            Diagnostic(range: 0..<1, message: "I", severity: .info),
            Diagnostic(range: 0..<1, message: "W", severity: .warning)
        ]
        #expect(getHighestSeverity(for: mixed2) == .warning)
        
        // Case 3: Multiple Errors -> Error
        let mixed3 = [
            Diagnostic(range: 0..<1, message: "E1", severity: .error),
            Diagnostic(range: 0..<1, message: "E2", severity: .error)
        ]
        #expect(getHighestSeverity(for: mixed3) == .error)
    }
}
