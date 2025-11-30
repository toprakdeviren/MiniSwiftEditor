//
//  CodeEditorBindingTests.swift
//  MiniSwiftEditorTests
//
//  Tests for SwiftUI binding synchronization
//

import Testing
import SwiftUI
@testable import MiniSwiftEditor

@MainActor
struct CodeEditorBindingTests {
    
    @Test("Binding synchronization - View to Binding")
    func viewToBinding() {
        var text = "Initial"
        let binding = Binding(get: { text }, set: { text = $0 })
        
        let representable = CodeEditorRepresentable(text: binding)
        let coordinator = representable.makeCoordinator()
        
        let containerView = CodeEditorContainerView()
        
        // Simulate text change in view
        let newText = "Updated"
        coordinator.containerView(containerView, didChangeText: newText)
        
        #expect(text == newText, "Binding should be updated when view changes text")
    }
    
    @Test("Binding synchronization - Selection View to Binding")
    func selectionViewToBinding() {
        var selection = Selection(anchor: 0, head: 0)
        let binding = Binding(get: { selection }, set: { selection = $0 })
        
        let representable = CodeEditorRepresentable(text: .constant(""), selection: binding)
        let coordinator = representable.makeCoordinator()
        
        let containerView = CodeEditorContainerView()
        
        // Simulate selection change in view
        let newSelection = Selection(anchor: 5, head: 10)
        coordinator.containerView(containerView, didChangeSelection: newSelection)
        
        #expect(selection == newSelection, "Binding should be updated when view changes selection")
    }
    
    @Test("CodeEditorContainerView updates editor text")
    func containerViewUpdatesEditor() {
        let container = CodeEditorContainerView()
        let newText = "Hello"
        container.text = newText
        
        #expect(container.editorView.string == newText)
    }
}
