//
//  FoldingModel.swift
//  MiniSwiftEditor
//
//  Manages code folding state and ranges
//  Requirements: 11.1, 11.4
//

import Foundation
import Combine

/// Type of foldable region
enum FoldingRegionType: Equatable, Hashable {
    case brace
    case comment
    case imports
}

/// Represents a region of text that can be folded (View Model)
struct FoldingRegion: Equatable, Hashable, Identifiable {
    var id: String { "\(range.lowerBound)-\(range.upperBound)" }
    
    /// The character range of the foldable content
    let range: Range<Int>
    /// The start line index
    let startLine: Int
    /// The end line index
    let endLine: Int
    /// The type of content
    let type: FoldingRegionType
    /// The placeholder text to show when folded
    let placeholder: String
}

/// Manages code folding state
final class FoldingModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// All available foldable regions
    @Published private(set) var foldableRanges: [FoldingRegion] = []
    
    /// Set of currently folded regions
    @Published private(set) var foldedRanges: Set<FoldingRegion> = []
    
    // MARK: - Public Methods
    
    /// Update the list of foldable regions
    /// - Parameter ranges: New list of foldable regions
    func update(ranges: [FoldingRegion]) {
        // Try to preserve folded state for ranges that still exist
        let newRangesSet = Set(ranges)
        let preservedFoldedRanges = foldedRanges.intersection(newRangesSet)
        
        foldableRanges = ranges
        foldedRanges = preservedFoldedRanges
    }
    
    /// Toggle fold state for a specific region
    /// - Parameter range: The region to toggle
    func toggleFold(for range: FoldingRegion) {
        if foldedRanges.contains(range) {
            foldedRanges.remove(range)
        } else {
            foldedRanges.insert(range)
        }
    }
    
    /// Fold a specific region
    func fold(_ range: FoldingRegion) {
        foldedRanges.insert(range)
    }
    
    /// Unfold a specific region
    func unfold(_ range: FoldingRegion) {
        foldedRanges.remove(range)
    }
    
    /// Unfold all regions
    func unfoldAll() {
        foldedRanges.removeAll()
    }
    
    /// Check if a line is hidden (inside a folded region)
    /// - Parameter line: The line index to check
    /// - Returns: True if the line is hidden
    func isLineHidden(_ line: Int) -> Bool {
        for range in foldedRanges {
            // The start line is visible (contains the fold indicator), subsequent lines are hidden
            if line > range.startLine && line <= range.endLine {
                return true
            }
        }
        return false
    }
    
    /// Get the foldable region starting at the given line, if any
    /// - Parameter line: The line index
    /// - Returns: The foldable region starting at this line
    func foldableRange(startingAt line: Int) -> FoldingRegion? {
        foldableRanges.first { $0.startLine == line }
    }
    
    /// Check if a region is currently folded
    func isFolded(_ range: FoldingRegion) -> Bool {
        foldedRanges.contains(range)
    }
}
