//
//  CommandHandler.swift
//  MiniSwiftEditor
//
//  Handles editor commands and key bindings
//  Requirements: 12.1, 12.2
//

import AppKit

/// Editor commands
enum EditorCommand: String, CaseIterable {
    case undo
    case redo
    case cut
    case copy
    case paste
    case selectAll
    case indent
    case outdent
    case toggleComment
    case fold
    case unfold
}

/// Delegate for handling commands
protocol CommandHandlerDelegate: AnyObject {
    func handleCommand(_ command: EditorCommand)
}

/// Manages editor commands and their execution
final class CommandHandler {
    
    // MARK: - Properties
    
    /// Delegate for command execution
    weak var delegate: CommandHandlerDelegate?
    
    // MARK: - Public Methods
    
    /// Execute a command
    /// - Parameter command: The command to execute
    func execute(_ command: EditorCommand) {
        delegate?.handleCommand(command)
    }
    
    /// Handle key event and map to command
    /// - Parameter event: The key event
    /// - Returns: True if the event was handled as a command
    func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard let command = mapEventToCommand(event) else { return false }
        execute(command)
        return true
    }
    
    // MARK: - Private Helpers
    
    private func mapEventToCommand(_ event: NSEvent) -> EditorCommand? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let key = event.charactersIgnoringModifiers ?? ""
        
        // Command + Z -> Undo
        if flags == .command && key == "z" {
            return .undo
        }
        
        // Command + Shift + Z -> Redo
        if flags == [.command, .shift] && key == "z" {
            return .redo
        }
        
        // Command + ] -> Indent
        if flags == .command && key == "]" {
            return .indent
        }
        
        // Command + [ -> Outdent
        if flags == .command && key == "[" {
            return .outdent
        }
        
        // Command + / -> Toggle Comment
        if flags == .command && key == "/" {
            return .toggleComment
        }
        
        // Command + Option + Left -> Fold
        if flags == [.command, .option] && event.keyCode == 123 { // Left Arrow
            return .fold
        }
        
        // Command + Option + Right -> Unfold
        if flags == [.command, .option] && event.keyCode == 124 { // Right Arrow
            return .unfold
        }
        
        return nil
    }
}
