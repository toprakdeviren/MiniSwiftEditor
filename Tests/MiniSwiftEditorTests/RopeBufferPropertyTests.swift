//
//  RopeBufferPropertyTests.swift
//  MiniSwiftEditorTests
//
//  Property-based tests for RopeBuffer
//

import Foundation
import Testing
@testable import MiniSwiftEditor

struct RopeBufferPropertyTests {
    
    // MARK: - Test Helpers
    
    static func randomString(length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 \n\t"
        return String((0..<length).map { _ in characters.randomElement()! })
    }
    
    static func randomMultilineString(lines: Int, maxLineLength: Int) -> String {
        (0..<lines).map { _ in
            let lineLength = Int.random(in: 0...maxLineLength)
            let chars = "abcdefghijklmnopqrstuvwxyz0123456789 "
            return String((0..<lineLength).map { _ in chars.randomElement()! })
        }.joined(separator: "\n")
    }
    
    // MARK: - Correctness Tests
    
    @Test("RopeBuffer Correctness - Insert/Delete matches String")
    func ropeBufferCorrectness() {
        for _ in 0..<50 {
            var content = Self.randomString(length: 20)
            let buffer = RopeBuffer(content)
            
            // Perform random operations
            for _ in 0..<20 {
                if Bool.random() || content.isEmpty {
                    // Insert
                    let offset = Int.random(in: 0...content.count)
                    let text = Self.randomString(length: 5)
                    
                    let index = content.index(content.startIndex, offsetBy: offset)
                    content.insert(contentsOf: text, at: index)
                    buffer.insert(text, at: offset)
                } else {
                    // Delete
                    let start = Int.random(in: 0..<content.count)
                    let end = Int.random(in: start...content.count)
                    if start == end { continue }
                    
                    let startIndex = content.index(content.startIndex, offsetBy: start)
                    let endIndex = content.index(content.startIndex, offsetBy: end)
                    content.removeSubrange(startIndex..<endIndex)
                    buffer.delete(range: start..<end)
                }
                
                #expect(buffer.content == content, "Content mismatch")
                
                // Verify line count
                // Note: String.components(separatedBy:) behaves differently for trailing newline than our definition
                // Our definition: "abc\n" -> 2 lines. String split: "abc\n" -> ["abc", ""] -> 2 lines.
                // "abc" -> 1 line. String split: "abc" -> ["abc"] -> 1 line.
                // "" -> 1 line. String split: "" -> [""] -> 1 line.
                let expectedLineCount = content.components(separatedBy: "\n").count
                #expect(buffer.lineCount == expectedLineCount, "Line count mismatch: expected \(expectedLineCount), got \(buffer.lineCount)")
            }
        }
    }
    
    // MARK: - Line Mapping Tests
    
    @Test("RopeBuffer Line Mapping - Round Trip")
    func lineOffsetMappingConsistency_roundTrip() {
        for _ in 0..<50 {
            let lineCount = Int.random(in: 1...50)
            let content = Self.randomMultilineString(lines: lineCount, maxLineLength: 80)
            let buffer = RopeBuffer(content)
            
            for lineIdx in 0..<buffer.lineCount {
                let offset = buffer.offset(for: lineIdx)
                let recoveredLineIdx = buffer.lineIndex(for: offset)
                
                #expect(recoveredLineIdx == lineIdx,
                       "Round-trip failed: lineIndex(offset(\(lineIdx))) = \(recoveredLineIdx), expected \(lineIdx)")
            }
        }
    }
    
    @Test("RopeBuffer Line Mapping - Line Range Content")
    func lineOffsetMappingConsistency_lineRangeContent() {
        for _ in 0..<50 {
            let lines = (0..<Int.random(in: 1...20)).map { _ in
                let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
                let len = Int.random(in: 0...30)
                return String((0..<len).map { _ in chars.randomElement()! })
            }
            let content = lines.joined(separator: "\n")
            let buffer = RopeBuffer(content)
            
            for (lineIdx, expectedLine) in lines.enumerated() {
                let range = buffer.lineRange(for: lineIdx)
                let startIdx = content.index(content.startIndex, offsetBy: range.lowerBound)
                let endIdx = content.index(content.startIndex, offsetBy: range.upperBound)
                var extractedLine = String(content[startIdx..<endIdx])
                
                if extractedLine.hasSuffix("\n") {
                    extractedLine.removeLast()
                }
                
                #expect(extractedLine == expectedLine,
                       "Line \(lineIdx): expected '\(expectedLine)', got '\(extractedLine)'")
            }
        }
    }
}
