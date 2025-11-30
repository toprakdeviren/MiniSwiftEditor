//
//  CodeEditorRepresentable.swift
//  MiniSwiftEditor
//
//  SwiftUI wrapper for the code editor using NSViewRepresentable
//  Requirements: 15.1
//

import SwiftUI
import AppKit

// MARK: - CodeEditorRepresentable

/// SwiftUI wrapper for CodeEditorContainerView using NSViewRepresentable.
/// Provides bidirectional binding for text content and selection.
/// Requirements: 15.1
public struct CodeEditorRepresentable: NSViewRepresentable {
    
    // MARK: - Bindings
    
    /// Binding to the text content
    @Binding public var text: String
    
    /// Binding to the current selection
    @Binding public var selection: Selection
    
    // MARK: - Configuration
    
    /// Editor configuration
    public let configuration: EditorConfiguration
    
    /// Optional decoration model for external syntax highlighting
    var decorationModel: DecorationModel?
    
    // MARK: - Initialization
    
    public init(
        text: Binding<String>,
        selection: Binding<Selection> = .constant(Selection(anchor: 0, head: 0)),
        configuration: EditorConfiguration = .default
    ) {
        self._text = text
        self._selection = selection
        self.configuration = configuration
        self.decorationModel = nil
    }
    
    // MARK: - NSViewRepresentable
    
    public func makeNSView(context: Context) -> CodeEditorContainerView {
        let container = CodeEditorContainerView()
        container.configure(with: configuration)
        container.delegate = context.coordinator
        
        // Set initial text
        container.text = text
        
        // Set decoration model if provided
        if let decorationModel = decorationModel {
            container.decorationModel = decorationModel
        }
        
        return container
    }
    
    public func updateNSView(_ nsView: CodeEditorContainerView, context: Context) {
        // Update text if changed from SwiftUI side
        if nsView.text != text {
            nsView.text = text
        }
        
        // Update selection if changed from SwiftUI side
        if nsView.selection != selection {
            nsView.selection = selection
        }
        
        // Update decoration model if provided
        if let decorationModel = decorationModel {
            nsView.decorationModel = decorationModel
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Coordinator
    
    /// Coordinator to handle delegate callbacks and update SwiftUI bindings
    public class Coordinator: NSObject, CodeEditorContainerViewDelegate {
        var parent: CodeEditorRepresentable
        
        init(_ parent: CodeEditorRepresentable) {
            self.parent = parent
        }
        
        func containerView(_ view: CodeEditorContainerView, didChangeText text: String) {
            // Update SwiftUI binding when text changes in the editor
            if parent.text != text {
                parent.text = text
            }
        }
        
        func containerView(_ view: CodeEditorContainerView, didChangeSelection selection: Selection) {
            // Update SwiftUI binding when selection changes in the editor
            if parent.selection != selection {
                parent.selection = selection
            }
        }
    }
}

// MARK: - Convenience Initializers

public extension CodeEditorRepresentable {
    static func readOnly(
        text: Binding<String>,
        configuration: EditorConfiguration = .default
    ) -> CodeEditorRepresentable {
        var config = configuration
        config.isReadOnly = true
        return CodeEditorRepresentable(
            text: text,
            configuration: config
        )
    }
    
    static func editable(
        text: Binding<String>,
        selection: Binding<Selection> = .constant(Selection(anchor: 0, head: 0)),
        configuration: EditorConfiguration = .default
    ) -> CodeEditorRepresentable {
        var config = configuration
        config.isReadOnly = false
        return CodeEditorRepresentable(
            text: text,
            selection: selection,
            configuration: config
        )
    }
}

