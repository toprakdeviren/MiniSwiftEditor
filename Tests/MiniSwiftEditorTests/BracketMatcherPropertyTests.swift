//
//  BracketMatcherPropertyTests.swift
//  MiniSwiftEditorTests
//
//  Property-based tests for BracketMatcher
//

import Foundation
import Testing
@testable import MiniSwiftEditor

struct BracketMatcherPropertyTests {
    
    // MARK: - Helpers
    
    /// Generate balanced brackets string
    static func generateBalancedBrackets(depth: Int) -> String {
        if depth == 0 { return "" }
        
        let pair = ["()", "{}", "[]"].randomElement()!
        let open = String(pair.first!)
        let close = String(pair.last!)
        
        let inner = generateBalancedBrackets(depth: depth - 1)
        return open + inner + close
    }
    
    @Test("Property 22: Bracket Matching Correctness")
    func bracketMatchingCorrectness() {
        let matcher = BracketMatcher()
        
        for _ in 0..<50 {
            let depth = Int.random(in: 1...10)
            let content = Self.generateBalancedBrackets(depth: depth)
            
            // The outermost brackets should match
            let openIndex = 0
            let closeIndex = content.count - 1
            
            // Test finding match for opening bracket
            if let result = matcher.findMatch(at: openIndex, in: content) {
                #expect(result.isMatched, "Should find matched brackets")
                #expect(result.openRange.lowerBound == openIndex, "Open range should start at 0")
                #expect(result.closeRange.lowerBound == closeIndex, "Close range should start at end")
            } else {
                #expect(Bool(false), "Should find a match")
            }
            
            // Test finding match for closing bracket
            if let result = matcher.findMatch(at: closeIndex, in: content) {
                #expect(result.isMatched, "Should find matched brackets")
                #expect(result.openRange.lowerBound == openIndex, "Open range should start at 0")
                #expect(result.closeRange.lowerBound == closeIndex, "Close range should start at end")
            } else {
                #expect(Bool(false), "Should find a match")
            }
        }
    }
    
    @Test("Unbalanced Brackets")
    func unbalancedBrackets() {
        let matcher = BracketMatcher()
        
        // Test missing closing bracket
        let content1 = "((()"
        let result1 = matcher.findMatch(at: 0, in: content1)
        #expect(result1 != nil)
        #expect(!result1!.isMatched, "Should report unmatched")
        
        // Test missing opening bracket
        let content2 = "()))"
        let result2 = matcher.findMatch(at: 3, in: content2)
        #expect(result2 != nil)
        #expect(!result2!.isMatched, "Should report unmatched")
    }
}
