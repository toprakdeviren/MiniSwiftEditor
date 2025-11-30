//
//  FoldingModelPropertyTests.swift
//  MiniSwiftEditorTests
//
//  Property-based tests for FoldingModel
//

import Foundation
import Testing
@testable import MiniSwiftEditor

struct FoldingModelPropertyTests {
    
    // MARK: - Helpers
    
    static func randomRange() -> FoldingRegion {
        let start = Int.random(in: 0...1000)
        let length = Int.random(in: 10...100)
        let startLine = Int.random(in: 0...100)
        let endLine = startLine + Int.random(in: 1...10)
        
        return FoldingRegion(
            range: start..<(start + length),
            startLine: startLine,
            endLine: endLine,
            type: .brace,
            placeholder: "{ ... }"
        )
    }
    
    @Test("Property 23: Fold/Unfold Round-Trip")
    func foldUnfoldRoundTrip() {
        let model = FoldingModel()
        
        for _ in 0..<50 {
            let range = Self.randomRange()
            model.update(ranges: [range])
            
            // Initially unfolded
            #expect(!model.isFolded(range), "Should be initially unfolded")
            
            // Fold
            model.fold(range)
            #expect(model.isFolded(range), "Should be folded")
            
            // Unfold
            model.unfold(range)
            #expect(!model.isFolded(range), "Should be unfolded")
            
            // Toggle
            model.toggleFold(for: range)
            #expect(model.isFolded(range), "Should be folded after toggle")
            
            model.toggleFold(for: range)
            #expect(!model.isFolded(range), "Should be unfolded after second toggle")
        }
    }
    
    @Test("Property 24: Folded State Persistence")
    func foldedStatePersistence() {
        let model = FoldingModel()
        
        for _ in 0..<50 {
            let range1 = Self.randomRange()
            var range2 = Self.randomRange()
            
            // Ensure distinct ranges
            while range2 == range1 {
                range2 = Self.randomRange()
            }
            
            model.update(ranges: [range1, range2])
            
            // Fold range1
            model.fold(range1)
            
            // Update with same ranges (simulating re-analysis)
            model.update(ranges: [range1, range2])
            
            #expect(model.isFolded(range1), "Range1 should remain folded")
            #expect(!model.isFolded(range2), "Range2 should remain unfolded")
            
            // Update with only range2 (range1 deleted)
            model.update(ranges: [range2])
            
            #expect(!model.isFolded(range1), "Range1 should be removed from folded set (implicitly)")
            #expect(model.foldedRanges.count == 0, "Folded set should be empty")
            
            // Update with range1 again (re-added)
            model.update(ranges: [range1, range2])
            #expect(!model.isFolded(range1), "Range1 should be unfolded (state lost when removed)")
        }
    }
    
    @Test("Line Hiding Logic")
    func lineHidingLogic() {
        let model = FoldingModel()
        let range = FoldingRegion(
            range: 0..<100,
            startLine: 10,
            endLine: 20,
            type: .brace,
            placeholder: "{ ... }"
        )
        
        model.update(ranges: [range])
        model.fold(range)
        
        // Start line is visible
        #expect(!model.isLineHidden(10), "Start line should be visible")
        
        // Inside lines are hidden
        #expect(model.isLineHidden(11), "Line 11 should be hidden")
        #expect(model.isLineHidden(15), "Line 15 should be hidden")
        #expect(model.isLineHidden(20), "End line should be hidden")
        
        // Outside lines are visible
        #expect(!model.isLineHidden(9), "Line 9 should be visible")
        #expect(!model.isLineHidden(21), "Line 21 should be visible")
    }
}
