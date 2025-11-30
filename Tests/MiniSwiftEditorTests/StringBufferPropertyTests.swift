//
//  StringBufferPropertyTests.swift
//  MiniSwiftEditorTests
//
//  Property-based tests for StringBuffer
//

import Testing
@testable import MiniSwiftEditor

/// Property-based tests for StringBuffer implementation
/// Uses randomized inputs to verify correctness properties
struct StringBufferPropertyTests {
    
    // MARK: - Test Helpers
    
    /// Generate random strings for testing
    static func randomString(length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 \n\t"
        return String((0..<length).map { _ in characters.randomElement()! })
    }
    
    /// Generate random multi-line strings
    static func randomMultilineString(lines: Int, maxLineLength: Int) -> String {
        (0..<lines).map { _ in
            let lineLength = Int.random(in: 0...maxLineLength)
            let chars = "abcdefghijklmnopqrstuvwxyz0123456789 "
            return String((0..<lineLength).map { _ in chars.randomElement()! })
        }.joined(separator: "\n")
    }
    
    // MARK: - Property 1: Line-Offset Mapping Consistency
    // **Feature: code-editor, Property 1: Line-Offset Mapping Consistency**
    // **Validates: Requirements 1.3**
    //
    // For any TextBuffer and any sequence of edit operations, the line-to-offset
    // mapping should remain consistent such that lineIndex(offset(lineIndex)) == lineIndex
    // for all valid line indices.
    
    @Test("Property 1: Line-Offset Mapping Consistency - Round trip for all lines")
    func lineOffsetMappingConsistency_roundTrip() {
        // Run 100 iterations with different random inputs
        for _ in 0..<100 {
            let lineCount = Int.random(in: 1...50)
            let content = Self.randomMultilineString(lines: lineCount, maxLineLength: 80)
            let buffer = StringBuffer(content)
            
            // For every valid line index, verify round-trip consistency
            for lineIdx in 0..<buffer.lineCount {
                let offset = buffer.offset(for: lineIdx)
                let recoveredLineIdx = buffer.lineIndex(for: offset)
                
                #expect(recoveredLineIdx == lineIdx,
                       "Round-trip failed: lineIndex(offset(\(lineIdx))) = \(recoveredLineIdx), expected \(lineIdx)")
            }
        }
    }

    
    @Test("Property 1: Line-Offset Mapping Consistency - After insertions")
    func lineOffsetMappingConsistency_afterInsertions() {
        for _ in 0..<100 {
            let initialContent = Self.randomMultilineString(lines: Int.random(in: 1...20), maxLineLength: 40)
            let buffer = StringBuffer(initialContent)
            
            // Perform random insertions
            let insertCount = Int.random(in: 1...5)
            for _ in 0..<insertCount {
                let insertOffset = Int.random(in: 0...buffer.content.count)
                let insertText = Self.randomString(length: Int.random(in: 1...20))
                buffer.insert(insertText, at: insertOffset)
            }
            
            // Verify consistency after insertions
            for lineIdx in 0..<buffer.lineCount {
                let offset = buffer.offset(for: lineIdx)
                let recoveredLineIdx = buffer.lineIndex(for: offset)
                
                #expect(recoveredLineIdx == lineIdx,
                       "After insertions: lineIndex(offset(\(lineIdx))) = \(recoveredLineIdx)")
            }
        }
    }
    
    @Test("Property 1: Line-Offset Mapping Consistency - After deletions")
    func lineOffsetMappingConsistency_afterDeletions() {
        for _ in 0..<100 {
            let initialContent = Self.randomMultilineString(lines: Int.random(in: 5...30), maxLineLength: 50)
            let buffer = StringBuffer(initialContent)
            
            // Perform random deletions (if content is long enough)
            if buffer.content.count > 10 {
                let deleteCount = Int.random(in: 1...3)
                for _ in 0..<deleteCount {
                    if buffer.content.count > 2 {
                        let start = Int.random(in: 0..<buffer.content.count - 1)
                        let maxEnd = min(start + 10, buffer.content.count)
                        let end = Int.random(in: (start + 1)...maxEnd)
                        buffer.delete(range: start..<end)
                    }
                }
            }
            
            // Verify consistency after deletions
            for lineIdx in 0..<buffer.lineCount {
                let offset = buffer.offset(for: lineIdx)
                let recoveredLineIdx = buffer.lineIndex(for: offset)
                
                #expect(recoveredLineIdx == lineIdx,
                       "After deletions: lineIndex(offset(\(lineIdx))) = \(recoveredLineIdx)")
            }
        }
    }
    
    @Test("Property 1: Line-Offset Mapping Consistency - lineRange covers correct content")
    func lineOffsetMappingConsistency_lineRangeContent() {
        for _ in 0..<100 {
            let lines = (0..<Int.random(in: 1...20)).map { _ in
                let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
                let len = Int.random(in: 0...30)
                return String((0..<len).map { _ in chars.randomElement()! })
            }
            let content = lines.joined(separator: "\n")
            let buffer = StringBuffer(content)
            
            // Verify each line's range extracts the correct content
            for (lineIdx, expectedLine) in lines.enumerated() {
                let range = buffer.lineRange(for: lineIdx)
                let startIdx = content.index(content.startIndex, offsetBy: range.lowerBound)
                let endIdx = content.index(content.startIndex, offsetBy: range.upperBound)
                var extractedLine = String(content[startIdx..<endIdx])
                
                // Remove trailing newline if present (except for last line)
                if extractedLine.hasSuffix("\n") {
                    extractedLine.removeLast()
                }
                
                #expect(extractedLine == expectedLine,
                       "Line \(lineIdx): expected '\(expectedLine)', got '\(extractedLine)'")
            }
        }
    }
}


// MARK: - Property 2: Version Monotonicity
// **Feature: code-editor, Property 2: Version Monotonicity**
// **Validates: Requirements 1.4**
//
// For any TextDocument and any sequence of edit operations, the version counter
// should be strictly monotonically increasing after each edit.

extension StringBufferPropertyTests {
    
    @Test("Property 2: Version Monotonicity - Insert operations increment version")
    func versionMonotonicity_insertOperations() {
        for _ in 0..<100 {
            let buffer = StringBuffer(Self.randomString(length: Int.random(in: 0...100)))
            var previousVersion = buffer.version
            
            // Perform random insertions and verify version increases
            let insertCount = Int.random(in: 1...20)
            for _ in 0..<insertCount {
                let insertOffset = Int.random(in: 0...buffer.content.count)
                let insertText = Self.randomString(length: Int.random(in: 1...10))
                
                buffer.insert(insertText, at: insertOffset)
                
                #expect(buffer.version > previousVersion,
                       "Version should increase after insert: was \(previousVersion), now \(buffer.version)")
                previousVersion = buffer.version
            }
        }
    }
    
    @Test("Property 2: Version Monotonicity - Delete operations increment version")
    func versionMonotonicity_deleteOperations() {
        for _ in 0..<100 {
            // Start with enough content to delete from
            let buffer = StringBuffer(Self.randomString(length: Int.random(in: 50...200)))
            var previousVersion = buffer.version
            
            // Perform random deletions and verify version increases
            let deleteCount = Int.random(in: 1...10)
            for _ in 0..<deleteCount {
                if buffer.content.count > 1 {
                    let start = Int.random(in: 0..<buffer.content.count - 1)
                    let maxEnd = min(start + 10, buffer.content.count)
                    let end = Int.random(in: (start + 1)...maxEnd)
                    
                    buffer.delete(range: start..<end)
                    
                    #expect(buffer.version > previousVersion,
                           "Version should increase after delete: was \(previousVersion), now \(buffer.version)")
                    previousVersion = buffer.version
                }
            }
        }
    }
    
    @Test("Property 2: Version Monotonicity - Mixed operations maintain strict ordering")
    func versionMonotonicity_mixedOperations() {
        for _ in 0..<100 {
            let buffer = StringBuffer(Self.randomString(length: Int.random(in: 20...100)))
            var versions: [Int] = [buffer.version]
            
            // Perform random mix of insertions and deletions
            let operationCount = Int.random(in: 5...30)
            for _ in 0..<operationCount {
                let doInsert = Bool.random() || buffer.content.count < 5
                
                if doInsert {
                    let offset = Int.random(in: 0...buffer.content.count)
                    buffer.insert(Self.randomString(length: Int.random(in: 1...5)), at: offset)
                } else if buffer.content.count > 1 {
                    let start = Int.random(in: 0..<buffer.content.count - 1)
                    let end = Int.random(in: (start + 1)...min(start + 5, buffer.content.count))
                    buffer.delete(range: start..<end)
                }
                
                versions.append(buffer.version)
            }
            
            // Verify strict monotonicity: each version > previous version
            for i in 1..<versions.count {
                #expect(versions[i] > versions[i-1],
                       "Version sequence not strictly increasing at index \(i): \(versions[i-1]) -> \(versions[i])")
            }
        }
    }
    
    @Test("Property 2: Version Monotonicity - Version starts at 0")
    func versionMonotonicity_initialVersion() {
        for _ in 0..<100 {
            let content = Self.randomString(length: Int.random(in: 0...100))
            let buffer = StringBuffer(content)
            
            #expect(buffer.version == 0,
                   "Initial version should be 0, got \(buffer.version)")
        }
    }
}
