//
//  BracketMatcher.swift
//  MiniSwiftEditor
//
//  Handles bracket matching logic
//  Requirements: 10.1
//

import Foundation

/// Represents a pair of matching brackets
public struct BracketPair {
    public let open: Character
    public let close: Character
}

/// Result of a bracket match operation
public struct BracketMatchResult {
    /// The range of the opening bracket
    public let openRange: Range<Int>
    /// The range of the closing bracket
    public let closeRange: Range<Int>
    /// Whether the brackets are correctly matched (balanced)
    public let isMatched: Bool
}

/// Handles finding matching brackets in text
public final class BracketMatcher {
    
    // MARK: - Properties
    
    /// Supported bracket pairs
    private let pairs: [BracketPair] = [
        BracketPair(open: "{", close: "}"),
        BracketPair(open: "(", close: ")"),
        BracketPair(open: "[", close: "]")
    ]
    
    public init() {}
    
    // MARK: - Public Methods
    
    /// Find the matching bracket for the bracket at the given offset
    /// - Parameters:
    ///   - offset: The character offset of the bracket to match
    ///   - content: The text content to search in
    /// - Returns: A BracketMatchResult if a match is found, nil otherwise
    public func findMatch(at offset: Int, in content: String) -> BracketMatchResult? {
        guard offset >= 0 && offset < content.count else { return nil }
        
        let index = content.index(content.startIndex, offsetBy: offset)
        let char = content[index]
        
        // Check if character is a bracket
        if let pair = pairs.first(where: { $0.open == char }) {
            // It's an opening bracket, search forward
            return findClosingMatch(for: pair, startingAt: offset, in: content)
        } else if let pair = pairs.first(where: { $0.close == char }) {
            // It's a closing bracket, search backward
            return findOpeningMatch(for: pair, startingAt: offset, in: content)
        }
        
        return nil
    }
    
    // MARK: - Private Helpers
    
    private func findClosingMatch(for pair: BracketPair, startingAt startOffset: Int, in content: String) -> BracketMatchResult? {
        var nestingLevel = 0
        var currentOffset = startOffset + 1
        
        while currentOffset < content.count {
            let index = content.index(content.startIndex, offsetBy: currentOffset)
            let char = content[index]
            
            if char == pair.open {
                nestingLevel += 1
            } else if char == pair.close {
                if nestingLevel == 0 {
                    // Found match
                    return BracketMatchResult(
                        openRange: startOffset..<(startOffset + 1),
                        closeRange: currentOffset..<(currentOffset + 1),
                        isMatched: true
                    )
                } else {
                    nestingLevel -= 1
                }
            }
            
            currentOffset += 1
        }
        
        // No match found (unbalanced)
        return BracketMatchResult(
            openRange: startOffset..<(startOffset + 1),
            closeRange: startOffset..<(startOffset + 1), // Point to self to indicate error
            isMatched: false
        )
    }
    
    private func findOpeningMatch(for pair: BracketPair, startingAt startOffset: Int, in content: String) -> BracketMatchResult? {
        var nestingLevel = 0
        var currentOffset = startOffset - 1
        
        while currentOffset >= 0 {
            let index = content.index(content.startIndex, offsetBy: currentOffset)
            let char = content[index]
            
            if char == pair.close {
                nestingLevel += 1
            } else if char == pair.open {
                if nestingLevel == 0 {
                    // Found match
                    return BracketMatchResult(
                        openRange: currentOffset..<(currentOffset + 1),
                        closeRange: startOffset..<(startOffset + 1),
                        isMatched: true
                    )
                } else {
                    nestingLevel -= 1
                }
            }
            
            currentOffset -= 1
        }
        
        // No match found (unbalanced)
        return BracketMatchResult(
            openRange: startOffset..<(startOffset + 1), // Point to self
            closeRange: startOffset..<(startOffset + 1),
            isMatched: false
        )
    }
}
