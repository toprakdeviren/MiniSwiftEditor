//
//  MiniSwiftEditor.swift
//  MiniSwiftEditor
//
//  Main module file - exports public API
//

import AppKit
import SwiftUI

// Re-export public types
// Views
public typealias CodeEditor = CodeEditorRepresentable

// This file serves as the main entry point for the MiniSwiftEditor package.
// The public API consists of:
//
// Views:
// - CodeEditorRepresentable: SwiftUI wrapper for the code editor
// - EditorConfiguration: Configuration options for the editor
// - EditorTheme: Theme/color configuration
//
// Models:
// - Selection: Text selection model
// - TextDocument: Document wrapper with serialization
//
// Usage:
// ```swift
// import MiniSwiftEditor
// import SwiftUI
//
// struct ContentView: View {
//     @State private var code = "let x = 42"
//     @State private var selection = Selection(anchor: 0, head: 0)
//
//     var body: some View {
//         CodeEditorRepresentable(
//             text: $code,
//             selection: $selection,
//             configuration: .default
//         )
//     }
// }
// ```
