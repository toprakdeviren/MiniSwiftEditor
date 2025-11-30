//
//  EditorUndoManager.swift
//  MiniSwiftEditor
//
//  Manages undo/redo history for the code editor.
//  Requirements: 7.1, 7.2, 7.3, 7.4, 7.5
//

import Foundation
import Combine

/// Represents a single text edit operation
/// Requirements: 7.1
struct TextEdit: Equatable {
    let range: Range<Int>
    let replacementText: String
    let originalText: String
    let timestamp: Date
    
    init(range: Range<Int>, replacementText: String, originalText: String) {
        self.range = range
        self.replacementText = replacementText
        self.originalText = originalText
        self.timestamp = Date()
    }
    
    static func == (lhs: TextEdit, rhs: TextEdit) -> Bool {
        return lhs.range == rhs.range &&
               lhs.replacementText == rhs.replacementText &&
               lhs.originalText == rhs.originalText
    }
}

/// Manages undo/redo history for the code editor.
/// Requirements: 7.1, 7.2, 7.3, 7.4, 7.5
final class EditorUndoManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var canUndo: Bool = false
    @Published var canRedo: Bool = false
    
    // MARK: - Private Properties
    
    private weak var document: TextDocument?
    private var undoStack: [[TextEdit]] = []
    private var redoStack: [[TextEdit]] = []
    
    private let maxStackSize = 1000
    private let groupWindow: TimeInterval = 0.3 // 300ms
    
    private var currentGroup: [TextEdit] = []
    private var lastEditTime: Date?
    
    // MARK: - Initialization
    
    init(document: TextDocument? = nil) {
        self.document = document
    }
    
    func setDocument(_ document: TextDocument) {
        self.document = document
        clear()
    }
    
    // MARK: - Edit Recording
    
    /// Register an edit operation
    /// Requirements: 7.1, 7.4, 7.5
    /// - Parameters:
    ///   - range: The range being replaced
    ///   - replacementText: The new text
    ///   - originalText: The text being replaced
    func registerEdit(range: Range<Int>, replacementText: String, originalText: String) {
        let edit = TextEdit(range: range, replacementText: replacementText, originalText: originalText)
        
        let now = Date()
        
        // Check if we should group with previous edit
        if let lastTime = lastEditTime, now.timeIntervalSince(lastTime) < groupWindow {
            currentGroup.append(edit)
        } else {
            // Push current group if not empty
            if !currentGroup.isEmpty {
                pushToUndoStack(currentGroup)
            }
            currentGroup = [edit]
        }
        
        lastEditTime = now
        
        // Clear redo stack on new edit
        redoStack.removeAll()
        updateCanUndoRedo()
    }
    
    /// Force close the current edit group
    func closeCurrentGroup() {
        if !currentGroup.isEmpty {
            pushToUndoStack(currentGroup)
            currentGroup = []
        }
        lastEditTime = nil
        updateCanUndoRedo()
    }
    
    // MARK: - Undo/Redo Operations
    
    /// Undo the last edit group
    /// Requirements: 7.2
    func undo() {
        // Close any open group first so it becomes part of the stack
        closeCurrentGroup()
        
        guard let group = undoStack.popLast(), let document = document else { return }
        
        // Apply edits in reverse order
        for edit in group.reversed() {
            // The range in the edit refers to the document state BEFORE the edit.
            // We are replacing 'replacementText' (current content) with 'originalText' (old content).
            
            let currentRange = edit.range.lowerBound..<(edit.range.lowerBound + edit.replacementText.count)
            document.replace(range: currentRange, with: edit.originalText)
        }
        
        redoStack.append(group)
        updateCanUndoRedo()
    }
    
    /// Redo the last undone edit group
    /// Requirements: 7.3
    func redo() {
        guard let group = redoStack.popLast(), let document = document else { return }
        
        // Apply edits in original order
        for edit in group {
            document.replace(range: edit.range, with: edit.replacementText)
        }
        
        undoStack.append(group)
        updateCanUndoRedo()
    }
    
    /// Clear history
    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
        currentGroup.removeAll()
        lastEditTime = nil
        updateCanUndoRedo()
    }
    
    // MARK: - Private Helpers
    
    private func pushToUndoStack(_ group: [TextEdit]) {
        undoStack.append(group)
        if undoStack.count > maxStackSize {
            undoStack.removeFirst()
        }
    }
    
    private func updateCanUndoRedo() {
        // We can undo if there is anything in the stack OR if there is a current group being built
        canUndo = !undoStack.isEmpty || !currentGroup.isEmpty
        canRedo = !redoStack.isEmpty
    }
    
    // MARK: - Testing Support
    
    #if DEBUG
    var undoStackCount: Int { undoStack.count }
    var redoStackCount: Int { redoStack.count }
    var currentGroupCount: Int { currentGroup.count }
    #endif
}
