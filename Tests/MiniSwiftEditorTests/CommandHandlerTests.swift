//
//  CommandHandlerTests.swift
//  MiniSwiftEditorTests
//
//  Tests for CommandHandler
//

import AppKit
import Testing
@testable import MiniSwiftEditor

class MockCommandDelegate: CommandHandlerDelegate {
    var lastCommand: EditorCommand?
    
    func handleCommand(_ command: EditorCommand) {
        lastCommand = command
    }
}

struct CommandHandlerTests {
    
    @Test("Command Execution")
    func commandExecution() {
        let handler = CommandHandler()
        let delegate = MockCommandDelegate()
        handler.delegate = delegate
        
        handler.execute(.undo)
        #expect(delegate.lastCommand == .undo)
        
        handler.execute(.indent)
        #expect(delegate.lastCommand == .indent)
    }
    
    // Note: Testing handleKeyEvent with NSEvent is difficult in unit tests without a window server connection
    // or complex mocking. We focus on the execution logic here.
}
