# MiniSwiftEditor

A lightweight, high-performance Swift code editor component for macOS applications.

## Features

- Syntax highlighting for Swift
- Full editing support with undo/redo
- Line numbers with gutter
- Bracket matching
- Code folding
- Optimized for large files (100K+ lines)
- SwiftUI integration via `NSViewRepresentable`

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/toprakdeviren/MiniSwiftEditor.git", from: "1.0.0")
]
```

Or in Xcode: File → Add Package Dependencies → Enter the repository URL.

## Usage

### Basic SwiftUI Integration

```swift
import SwiftUI
import MiniSwiftEditor

struct ContentView: View {
    @State private var code = """
    import Foundation
    
    func greet(name: String) -> String {
        return "Hello, \\(name)!"
    }
    """
    @State private var selection = Selection(anchor: 0, head: 0)
    
    var body: some View {
        CodeEditorRepresentable(
            text: $code,
            selection: $selection,
            configuration: .default
        )
    }
}
```

### Custom Configuration

```swift
let config = EditorConfiguration(
    font: .monospacedSystemFont(ofSize: 14, weight: .regular),
    theme: .dark,
    tabWidth: 2,
    useSpaces: true,
    showLineNumbers: true,
    showGutter: true,
    autoIndent: true,
    bracketMatching: true,
    codeFolding: true,
    isReadOnly: false
)

CodeEditorRepresentable(
    text: $code,
    configuration: config
)
```

### Read-Only Mode

```swift
CodeEditorRepresentable.readOnly(
    text: $code,
    configuration: .default
)
```

## Requirements

- macOS 13.0+
- Swift 5.9+

## Architecture

The editor is built with a layered architecture:

1. **Text Storage Layer** - Efficient text storage with `StringBuffer` (small files) and `RopeBuffer` (large files)
2. **Language Engine Layer** - Tokenization and semantic analysis
3. **Decoration Model** - Platform-agnostic visual decorations
4. **Rendering Layer** - TextKit 2 based rendering
5. **Integration Layer** - SwiftUI bridge

## Performance

- **60fps scroll performance** - Virtualized rendering for visible lines only
- **<16ms keystroke latency** - Incremental tokenization and decoration updates
- **Large file support** - Rope data structure for files with 100K+ lines

## License

MIT License
