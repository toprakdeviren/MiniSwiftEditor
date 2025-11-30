//
//  EditorUndoManagerPropertyTests.swift
//  MiniSwiftEditorTests
//
//  Property-based tests for EditorUndoManager
//  Requirements: 7.2, 7.3, 7.5
//

import Foundation
import Testing
@testable import MiniSwiftEditor

struct EditorUndoManagerPropertyTests {
    
    // MARK: - Test Helpers
    
    static func randomString(length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 "
        return String((0..<length).map { _ in characters.randomElement()! })
    }
    
    enum Operation {
        case insert(String, Int)
        case delete(Range<Int>)
        case replace(Range<Int>, String)
    }
    
    // MARK: - Property 14: Undo/Redo Round-Trip
    // **Feature: code-editor, Property 14: Undo/Redo Round-Trip**
    // **Validates: Requirements 7.2, 7.3**
    //
    // For any sequence of edits, undoing all of them should restore the document
    // to its initial state, and redoing them should restore the final state.
    
    @Test("Property 14: Undo/Redo Round-Trip - Restores state correctly")
    func undoRedo_roundTrip() {
        for _ in 0..<50 {
            // Setup
            let initialContent = Self.randomString(length: Int.random(in: 0...50))
            let document = TextDocument(initialContent)
            let undoManager = EditorUndoManager(document: document)
            
            // Perform a sequence of random edits
            var operations: [Operation] = []
            let operationCount = Int.random(in: 1...20)
            
            for _ in 0..<operationCount {
                let currentContent = document.content
                let contentLength = currentContent.count
                
                let opType = Int.random(in: 0...2)
                
                if opType == 0 || contentLength == 0 { // Insert
                    let text = Self.randomString(length: Int.random(in: 1...10))
                    let offset = Int.random(in: 0...contentLength)
                    
                    undoManager.registerEdit(range: offset..<offset, replacementText: text, originalText: "")
                    document.insert(text, at: offset)
                    
                    operations.append(.insert(text, offset))
                    
                } else if opType == 1 { // Delete
                    let start = Int.random(in: 0..<contentLength)
                    let length = Int.random(in: 1...min(10, contentLength - start))
                    let end = start + length
                    let range = start..<end
                    
                    let originalText = try! document.text(in: range)
                    
                    undoManager.registerEdit(range: range, replacementText: "", originalText: originalText)
                    document.delete(range: range)
                    
                    operations.append(.delete(range))
                    
                } else { // Replace
                    let start = Int.random(in: 0..<contentLength)
                    let length = Int.random(in: 1...min(10, contentLength - start))
                    let end = start + length
                    let range = start..<end
                    let text = Self.randomString(length: Int.random(in: 1...10))
                    
                    let originalText = try! document.text(in: range)
                    
                    undoManager.registerEdit(range: range, replacementText: text, originalText: originalText)
                    document.replace(range: range, with: text)
                    
                    operations.append(.replace(range, text))
                }
                
                // Force close group occasionally to ensure stack population
                if Bool.random() {
                    undoManager.closeCurrentGroup()
                }
            }
            
            // Capture final state
            let finalContent = document.content
            
            // Undo all operations
            while undoManager.canUndo {
                undoManager.undo()
            }
            
            // Verify initial state
            #expect(document.content == initialContent,
                   "Document content should match initial content after undoing all operations")
            
            // Redo all operations
            while undoManager.canRedo {
                undoManager.redo()
            }
            
            // Verify final state
            #expect(document.content == finalContent,
                   "Document content should match final content after redoing all operations")
        }
    }
    
    // MARK: - Property 15: Undo Stack Size Invariant
    // **Feature: code-editor, Property 15: Undo Stack Size Invariant**
    // **Validates: Requirements 7.5**
    //
    // The undo stack size should never exceed the maximum limit (1000).
    
    @Test("Property 15: Undo Stack Size Invariant - Respects maximum limit")
    func undoStack_respectsLimit() {
        let document = TextDocument("")
        let undoManager = EditorUndoManager(document: document)
        
        // The limit is 1000. We'll add 1100 edits.
        // We need to ensure they are not grouped, so we'll close the group after each edit.
        
        for i in 0..<1100 {
            let text = "a"
            let offset = document.content.count
            
            undoManager.registerEdit(range: offset..<offset, replacementText: text, originalText: "")
            document.insert(text, at: offset)
            
            undoManager.closeCurrentGroup()
            
            // Check invariant periodically
            if i % 100 == 0 {
                #expect(undoManager.undoStackCount <= 1000,
                       "Undo stack count should not exceed 1000")
            }
        }
        
        // Final check
        #expect(undoManager.undoStackCount == 1000,
               "Undo stack count should be exactly 1000 after >1000 edits")
        
        // Verify we can undo the most recent 1000 edits
        for _ in 0..<1000 {
            #expect(undoManager.canUndo, "Should be able to undo")
            undoManager.undo()
        }
        
        // Should not be able to undo anymore (the first 100 edits were dropped)
        #expect(!undoManager.canUndo, "Should not be able to undo anymore")
        
        // The document should NOT be empty, it should contain the first 100 "a"s
        #expect(document.content.count == 100,
               "Document should contain remaining 100 characters")
    }
}
