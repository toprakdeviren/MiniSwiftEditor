//
//  CodeEditorContainerView.swift
//  MiniSwiftEditor
//
//  Container view combining CodeEditorView and GutterView
//  Requirements: 15.1
//

import Combine
import AppKit

// MARK: - CodeEditorContainerView Delegate

/// Delegate protocol for CodeEditorContainerView events
protocol CodeEditorContainerViewDelegate: AnyObject {
    /// Called when text content changes
    func containerView(_ view: CodeEditorContainerView, didChangeText text: String)
    /// Called when selection changes
    func containerView(_ view: CodeEditorContainerView, didChangeSelection selection: Selection)
}

// MARK: - CodeEditorContainerView

/// A container view that combines the code editor with a gutter for line numbers.
/// Handles layout and synchronization between the editor and gutter.
/// Requirements: 15.1
public final class CodeEditorContainerView: NSView {
    
    // MARK: - Subviews
    
    /// The code editor view
    private(set) var editorView: CodeEditorView!
    
    /// The gutter view for line numbers
    private(set) var gutterView: GutterView!
    
    // MARK: - Properties
    
    /// Delegate for container events
    weak var delegate: CodeEditorContainerViewDelegate?
    
    /// The decoration model for syntax highlighting
    var decorationModel: DecorationModel? {
        didSet {
            editorView?.decorationModel = decorationModel
        }
    }
    
    /// Current configuration
    private var configuration: EditorConfiguration = .default
    
    /// Tokenizer for syntax highlighting
    private let tokenizer = SwiftTokenizer()
    
    /// Bracket matcher
    private let bracketMatcher = BracketMatcher()
    
    /// Folding model
    private let foldingModel = FoldingModel()
    
    /// Command handler
    private let commandHandler = CommandHandler()
    
    /// Indent handler
    private let indentHandler = IndentHandler()
    
    /// Completion engine
    private let completionEngine = CompletionEngine()
    
    /// Completion popup
    private var completionPopup: CompletionPopupView?
    
    /// Whether completion is currently active
    private var isCompletionActive: Bool = false
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Track previous bracket match positions for incremental updates
    private var previousBracketPositions: (Int, Int)? = nil
    
    /// Helper to compare optional tuple positions
    private func areBracketPositionsEqual(_ a: (Int, Int)?, _ b: (Int, Int)?) -> Bool {
        switch (a, b) {
        case (.none, .none):
            return true
        case let (.some(aVal), .some(bVal)):
            return aVal.0 == bVal.0 && aVal.1 == bVal.1
        default:
            return false
        }
    }
    
    // MARK: - Text Access
    
    /// The text content of the editor
    /// The text content of the editor
    var text: String {
        get { editorView?.string ?? "" }
        set {
            guard editorView.string != newValue else { return }
            editorView.string = newValue

            let lineCount = newValue.filter { $0 == "\n" }.count + 1
            if lineCount >= 100_000 {
                textBuffer = RopeBuffer(newValue)
            } else {
                textBuffer = StringBuffer(newValue)
            }
            
            updateGutter()
            updateSyntaxHighlighting()
        }
    }
    
    /// Text buffer for efficient line mapping
    private var textBuffer: TextBuffer = StringBuffer()
    
    /// Current selection in the editor
    var selection: Selection {
        get {
            guard let textView = editorView?.textView else {
                return Selection(anchor: 0, head: 0)
            }
            let range = textView.selectedRange()
            return Selection(anchor: range.location, head: range.location + range.length)
        }
        set {
            guard let textView = editorView?.textView else { return }
            let currentSelection = selection
            guard currentSelection != newValue else { return }
            let nsRange = NSRange(location: newValue.anchor, length: newValue.head - newValue.anchor)
            textView.setSelectedRange(nsRange)
        }
    }
    
    // MARK: - Initialization
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        wantsLayer = true

        gutterView = GutterView(frame: .zero)
        addSubview(gutterView)

        editorView = CodeEditorView(frame: .zero)
        editorView.delegate = self
        editorView.commandHandler = commandHandler
        editorView.completionDelegate = self
        addSubview(editorView)
        
        // Setup command handler
        commandHandler.delegate = self
        
        // Connect gutter to editor's text view
        gutterView.textView = editorView.textView
        gutterView.delegate = self
        gutterView.dataSource = self
        
        // Initial layout
        needsLayout = true
        
        // Setup observations
        setupObservations()
    }
    
    private func setupObservations() {
        // Observe folding model changes
        foldingModel.$foldableRanges
            .sink { [weak self] _ in
                self?.updateGutterDecorations()
            }
            .store(in: &cancellables)
            
        foldingModel.$foldedRanges
            .sink { [weak self] _ in
                self?.updateGutterDecorations()
                self?.updateHiddenDecorations()
            }
            .store(in: &cancellables)
    }
    
    /// Update hidden decorations based on folded ranges
    private func updateHiddenDecorations() {
        var hiddenDecorations: [Decoration] = []
        var affectedRanges: [Range<Int>] = []
        
        for region in foldingModel.foldedRanges {
            // Hide from start of next line to end of region
            let startLine = region.startLine
            let endLine = region.endLine
            
            guard startLine < endLine else { continue }
            
            // Get offset for start of next line
            let nextLineOffset = editorView.offset(for: startLine + 1)
            
            // Get offset for end of region
            let endOffset = region.range.upperBound
            
            if nextLineOffset < endOffset {
                let hiddenRange = nextLineOffset..<endOffset
                hiddenDecorations.append(Decoration(range: hiddenRange, kind: .hidden))
                affectedRanges.append(region.range)
            }
        }
        
        decorationModel?.update(hiddenDecorations: hiddenDecorations)
        
        // Only update affected ranges instead of full document
        if !affectedRanges.isEmpty {
            let minStart = affectedRanges.map { $0.lowerBound }.min() ?? 0
            let maxEnd = affectedRanges.map { $0.upperBound }.max() ?? text.count
            editorView.applyDecorations(in: minStart..<maxEnd)
        }
    }
    
    // MARK: - Configuration
    
    /// Configure the editor with the given configuration
    func configure(with configuration: EditorConfiguration) {
        self.configuration = configuration
        
        // Apply theme to editor
        editorView.font = configuration.font
        editorView.backgroundColor = configuration.theme.backgroundColor
        editorView.textColor = configuration.theme.textColor
        editorView.caretColor = configuration.theme.caretColor
        editorView.isReadOnly = configuration.isReadOnly
        
        // Apply syntax colors
        for (kind, color) in configuration.theme.syntaxColors {
            editorView.setSyntaxColor(color, for: kind)
        }
        
        // Apply theme to gutter
        gutterView.font = configuration.font
        gutterView.lineNumberColor = configuration.theme.lineNumberColor
        gutterView.gutterBackgroundColor = configuration.theme.gutterBackgroundColor
        gutterView.isHidden = !configuration.showGutter
        
        // Update layout
        needsLayout = true
    }
    
    // MARK: - Layout
    
    public override func layout() {
        super.layout()
        
        let gutterWidth = configuration.showGutter ? gutterView.gutterWidth : 0
        
        // Layout gutter
        gutterView.frame = NSRect(
            x: 0,
            y: 0,
            width: gutterWidth,
            height: bounds.height
        )
        
        // Layout editor
        editorView.frame = NSRect(
            x: gutterWidth,
            y: 0,
            width: bounds.width - gutterWidth,
            height: bounds.height
        )
    }
    
    // MARK: - Updates
    
    /// Update gutter line count and width
    private func updateGutter() {
        let lineCount = editorView.lineCount
        gutterView.updateLineCount(lineCount)
        
        // Re-layout if gutter width changed
        needsLayout = true
    }
    
    /// Update syntax highlighting based on current text
    /// Uses incremental updates when possible to prevent flickering
    private func updateSyntaxHighlighting(changedRange: NSRange? = nil, delta: Int? = nil) {
        let buffer = StringBuffer(text)
        
        let range: Range<Int>?
        if let changedRange = changedRange {
            range = Int(changedRange.location)..<Int(changedRange.location + changedRange.length)
        } else {
            range = nil
        }
        
        let tokens = tokenizer.tokenize(document: buffer, changedRange: range, delta: delta)

        if decorationModel == nil {
            decorationModel = DecorationModel()
        }
        decorationModel?.update(from: tokens)
        
        // Use incremental decoration application to prevent flickering
        // Only update the changed region plus some context
        if let changedRange = changedRange {
            let contextBuffer = 200
            let start = max(0, changedRange.location - contextBuffer)
            let end = min(text.count, changedRange.location + changedRange.length + contextBuffer)
            editorView.applyDecorations(in: start..<end)
        } else {
            editorView.applyDecorations()
        }
    }
    
    /// Update current line highlight in gutter
    private func updateCurrentLine() {
        guard let textView = editorView.textView else { return }
        let selectedRange = textView.selectedRange()
        let lineIndex = editorView.lineNumber(for: selectedRange.location)
        gutterView.currentLineIndex = lineIndex
    }
    
    // MARK: - Semantic Analysis
    
    /// Current diagnostics
    private var currentDiagnostics: [Diagnostic] = []
    
    /// Task for debounced analysis
    private var analysisTask: Task<Void, Never>?
    
    /// Schedule semantic analysis with debounce
    private func scheduleAnalysis() {
        analysisTask?.cancel()
        
        analysisTask = Task {
            // Debounce for 150ms
            try? await Task.sleep(nanoseconds: 150_000_000)
            
            guard !Task.isCancelled else { return }
            
            // Note: In a real app we should be careful about thread safety here.
            // Since we are on main actor (implied by UI code), accessing 'text' is safe.
            let buffer = StringBuffer(text)
            
            let result = await tokenizer.analyze(document: buffer)
            
            guard !Task.isCancelled else { return }
            
            // Update decorations on main thread
            await MainActor.run {
                self.currentDiagnostics = result.diagnostics
                decorationModel?.update(from: result.diagnostics)
                
                // Only update diagnostic ranges instead of full document
                if !result.diagnostics.isEmpty {
                    let minStart = result.diagnostics.map { $0.range.lowerBound }.min() ?? 0
                    let maxEnd = result.diagnostics.map { $0.range.upperBound }.max() ?? self.text.count
                    let contextBuffer = 100
                    let start = max(0, minStart - contextBuffer)
                    let end = min(self.text.count, maxEnd + contextBuffer)
                    editorView.applyDecorations(in: start..<end)
                }
                
                // Convert FoldableRange to FoldingRegion
                let foldingRegions = result.foldableRanges.compactMap { range -> FoldingRegion? in
                    let startLine = editorView.lineNumber(for: range.range.lowerBound)
                    let endLine = editorView.lineNumber(for: range.range.upperBound)
                    guard startLine < endLine else { return nil }
                    
                    // Map FoldableKind to FoldingRegionType
                    let type: FoldingRegionType
                    switch range.kind {
                    case .comment: type = .comment
                    case .region: type = .imports
                    default: type = .brace
                    }
                    
                    return FoldingRegion(
                        range: range.range,
                        startLine: startLine,
                        endLine: endLine,
                        type: type,
                        placeholder: range.placeholder
                    )
                }
                foldingModel.update(ranges: foldingRegions)
                
                updateGutterDecorations()
            }
        }
    }
    
    /// Update gutter decorations based on diagnostics and folding
    private func updateGutterDecorations() {
        var decorations: [LineDecoration] = []
        
        // Add diagnostics
        // We filter to keep only highest severity per line to avoid clutter, 
        // but GutterView can technically handle multiple.
        var lineDiagnostics: [Int: DiagnosticSeverity] = [:]
        for diagnostic in currentDiagnostics {
            let line = editorView.lineNumber(for: diagnostic.range.lowerBound)
            if let existing = lineDiagnostics[line] {
                if diagnostic.severity > existing {
                    lineDiagnostics[line] = diagnostic.severity
                }
            } else {
                lineDiagnostics[line] = diagnostic.severity
            }
        }
        
        for (line, severity) in lineDiagnostics {
            decorations.append(LineDecoration(lineIndex: line, kind: .diagnostic(severity)))
        }
        
        // Add fold indicators
        for range in foldingModel.foldableRanges {
            let isFolded = foldingModel.isFolded(range)
            decorations.append(LineDecoration(lineIndex: range.startLine, kind: .foldIndicator(isFolded: isFolded)))
        }
        
        gutterView.lineDecorations = decorations
    }
}

// MARK: - CodeEditorViewDelegate

extension CodeEditorContainerView: CodeEditorViewDelegate {
    func editorView(_ view: CodeEditorView, didChangeText text: String, range: NSRange, delta: Int) {
        // Update text buffer
        // range is the range in the NEW text.
        // delta = newLength - oldLength
        // So old range was: range.location ..< range.location + range.length - delta
        // We need to replace old range with new text (which is text[range])
        
        // However, TextBuffer expects insert/delete operations.
        // It's easier to map the change to delete + insert.
        
        let newLength = range.length
        let oldLength = newLength - delta
        
        // Delete old content
        if oldLength > 0 {
            let deleteRange = range.location..<(range.location + oldLength)
            textBuffer.delete(range: deleteRange)
        }
        
        // Insert new content
        if newLength > 0 {
            let startIndex = text.index(text.startIndex, offsetBy: range.location)
            let endIndex = text.index(text.startIndex, offsetBy: range.location + newLength)
            let newText = String(text[startIndex..<endIndex])
            textBuffer.insert(newText, at: range.location)
        }
        
        updateGutter()
        updateSyntaxHighlighting(changedRange: range, delta: delta)
        scheduleAnalysis()
        
        // Trigger completion
        let location = range.location + range.length
        showCompletion(at: location)
        
        delegate?.containerView(self, didChangeText: text)
    }
    
    func editorView(_ view: CodeEditorView, didChangeSelection selection: Selection) {
        updateCurrentLine()
        
        // Update selection highlight
        decorationModel?.updateSelection(selection)
        
        // Update bracket matching
        var currentBracketPositions: (Int, Int)? = nil
        
        if selection.isCollapsed {
            let offset = selection.anchor
            let matchResult = bracketMatcher.findMatch(at: offset, in: text)
            decorationModel?.update(from: matchResult)
            
            if let result = matchResult {
                currentBracketPositions = (result.openRange.lowerBound, result.closeRange.lowerBound)
            }
        } else {
            decorationModel?.update(from: nil)
        }
        
        // Only update decorations if bracket positions changed
        // This prevents unnecessary full redraws on every cursor movement
        let positionsChanged = !areBracketPositionsEqual(currentBracketPositions, previousBracketPositions)
        if positionsChanged {
            // Calculate the range that needs updating (old + new bracket positions)
            var updateRanges: [Range<Int>] = []
            
            if let (oldOpen, oldClose) = previousBracketPositions {
                updateRanges.append(oldOpen..<(oldOpen + 1))
                updateRanges.append(oldClose..<(oldClose + 1))
            }
            
            if let (newOpen, newClose) = currentBracketPositions {
                updateRanges.append(newOpen..<(newOpen + 1))
                updateRanges.append(newClose..<(newClose + 1))
            }
            
            if !updateRanges.isEmpty {
                // Find the bounding range
                let minStart = updateRanges.map { $0.lowerBound }.min() ?? 0
                let maxEnd = updateRanges.map { $0.upperBound }.max() ?? text.count
                let contextBuffer = 50
                let start = max(0, minStart - contextBuffer)
                let end = min(text.count, maxEnd + contextBuffer)
                editorView.applyDecorations(in: start..<end)
            }
            
            previousBracketPositions = currentBracketPositions
        }
        
        delegate?.containerView(self, didChangeSelection: selection)
    }
    
    func editorView(_ view: CodeEditorView, didScroll visibleRange: Range<Int>) {
        gutterView.synchronizeScroll()
    }
}

// MARK: - GutterViewDelegate

extension CodeEditorContainerView: GutterViewDelegate {
    func gutterView(_ view: GutterView, didClickLine line: Int) {
        // Check if there is a foldable range at this line
        if let range = foldingModel.foldableRange(startingAt: line) {
            foldingModel.toggleFold(for: range)
        }
    }
}

// MARK: - GutterViewDataSource

extension CodeEditorContainerView: GutterViewDataSource {
    func lineCount(in gutterView: GutterView) -> Int {
        return textBuffer.lineCount
    }
    
    func gutterView(_ gutterView: GutterView, lineNumberForCharacterIndex index: Int) -> Int {
        return textBuffer.lineIndex(for: index)
    }
    
    func gutterView(_ gutterView: GutterView, characterIndexForLineNumber line: Int) -> Int {
        return textBuffer.offset(for: line)
    }
}

// MARK: - CommandHandlerDelegate

extension CodeEditorContainerView: CommandHandlerDelegate {
    func handleCommand(_ command: EditorCommand) {
        guard let textView = editorView.textView else { return }
        
        switch command {
        case .undo:
            textView.undoManager?.undo()
        case .redo:
            textView.undoManager?.redo()
        case .cut:
            textView.cut(nil)
        case .copy:
            textView.copy(nil)
        case .paste:
            textView.paste(nil)
        case .selectAll:
            textView.selectAll(nil)
        case .indent:
            let selectedRange = textView.selectedRange()
            if selectedRange.length == 0 {
                // Insert indent at cursor
                textView.insertText(indentHandler.indentString, replacementRange: selectedRange)
            } else {
                // Indent selected lines
                let text = textView.string
                let nsRange = selectedRange
                guard let range = Range(nsRange, in: text) else { return }
                
                // Expand to full lines
                let lineRange = text.lineRange(for: range)
                let selectedText = String(text[lineRange])
                
                let indentedText = indentHandler.indent(text: selectedText)
                
                if textView.shouldChangeText(in: NSRange(lineRange, in: text), replacementString: indentedText) {
                    textView.replaceCharacters(in: NSRange(lineRange, in: text), with: indentedText)
                    textView.didChangeText()
                }
            }
            
        case .outdent:
            let selectedRange = textView.selectedRange()
            let text = textView.string
            
            // Expand to full lines (even for single line/cursor)
            let nsRange = selectedRange
            guard let range = Range(nsRange, in: text) else { return }
            
            let lineRange = text.lineRange(for: range)
            let selectedText = String(text[lineRange])
            
            let outdentedText = indentHandler.outdent(text: selectedText)
            
            if textView.shouldChangeText(in: NSRange(lineRange, in: text), replacementString: outdentedText) {
                textView.replaceCharacters(in: NSRange(lineRange, in: text), with: outdentedText)
                textView.didChangeText()
            }
            
        case .toggleComment:
            let selectedRange = textView.selectedRange()
            let text = textView.string
            
            guard let range = Range(selectedRange, in: text) else { return }
            let lineRange = text.lineRange(for: range)
            let selectedText = String(text[lineRange])
            
            let lines = selectedText.components(separatedBy: "\n")
            let commentedLines = lines.map { line -> String in
                if line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                    // Uncomment
                    if let range = line.range(of: "//") {
                        var newLine = line
                        newLine.removeSubrange(range)
                        // Remove following space if present
                        let offset = range.lowerBound.utf16Offset(in: line)
                        if newLine.count > offset && newLine[range.lowerBound] == " " {
                            newLine.remove(at: range.lowerBound)
                        }
                        return newLine
                    }
                    return line
                } else {
                    // Comment
                    if line.isEmpty { return line }
                    return "// " + line
                }
            }
            let result = commentedLines.joined(separator: "\n")
            
            if textView.shouldChangeText(in: NSRange(lineRange, in: text), replacementString: result) {
                textView.replaceCharacters(in: NSRange(lineRange, in: text), with: result)
                textView.didChangeText()
            }
        case .fold:
            let selectedRange = textView.selectedRange()
            let line = editorView.lineNumber(for: selectedRange.location)
            if let range = foldingModel.foldableRange(startingAt: line) {
                foldingModel.fold(range)
            }
        case .unfold:
            let selectedRange = textView.selectedRange()
            let line = editorView.lineNumber(for: selectedRange.location)
            if let range = foldingModel.foldableRange(startingAt: line) {
                foldingModel.unfold(range)
            }
        }
    }
}

// MARK: - Completion Logic

extension CodeEditorContainerView {
    
    func showCompletion(at location: Int) {
        // Find prefix
        let prefix = findPrefix(at: location)
        guard !prefix.isEmpty else {
            hideCompletion()
            return
        }
        
        let items = completionEngine.completions(for: prefix, at: location)
        guard !items.isEmpty else {
            hideCompletion()
            return
        }
        
        if completionPopup == nil {
            completionPopup = CompletionPopupView(frame: .zero)
            completionPopup?.delegate = self
            addSubview(completionPopup!)
        }
        
        // Update items
        completionPopup?.setItems(items)
        
        // Position popup
        if let rect = editorView.boundingRect(forLine: editorView.lineNumber(for: location)) {
            // This is a rough approximation. In a real app we'd calculate exact cursor position.
            // For now, place it below the line.
            let popupHeight: CGFloat = 200
            let popupWidth: CGFloat = 200
            
            // Adjust Y to be below the line
            // Note: NSTextView coordinates are flipped? NSView usually is not, but NSTextView is.
            // CodeEditorView is NSView, but we need to check coordinate system.
            // Assuming standard coordinates for now.
            
            let popupFrame = NSRect(
                x: rect.minX + 20, // Offset slightly
                y: rect.maxY,
                width: popupWidth,
                height: popupHeight
            )
            
            completionPopup?.frame = popupFrame
        }
        
        completionPopup?.isHidden = false
        isCompletionActive = true
    }
    
    func hideCompletion() {
        completionPopup?.isHidden = true
        isCompletionActive = false
    }
    
    private func findPrefix(at location: Int) -> String {
        let content = text
        guard location > 0 && location <= content.count else { return "" }
        
        // Search backwards for word boundary
        var start = location
        let chars = Array(content)
        
        while start > 0 {
            let char = chars[start - 1]
            if !char.isLetter && !char.isNumber && char != "_" {
                break
            }
            start -= 1
        }
        
        if start < location {
            let range = content.index(content.startIndex, offsetBy: start)..<content.index(content.startIndex, offsetBy: location)
            return String(content[range])
        }
        
        return ""
    }
    
    private func insertCompletion(_ item: CompletionItem) {
        guard let textView = editorView.textView else { return }
        
        let selectedRange = textView.selectedRange()
        let prefix = findPrefix(at: selectedRange.location)
        
        // Calculate range to replace (prefix)
        let replaceRange = NSRange(location: selectedRange.location - prefix.count, length: prefix.count)
        
        if textView.shouldChangeText(in: replaceRange, replacementString: item.insertText) {
            textView.replaceCharacters(in: replaceRange, with: item.insertText)
            textView.didChangeText()
        }
        
        hideCompletion()
    }
}

// MARK: - CodeEditorCompletionDelegate

extension CodeEditorContainerView: CodeEditorCompletionDelegate {
    func codeEditor(shouldHandleKeyEvent event: NSEvent) -> Bool {
        guard isCompletionActive, let popup = completionPopup, !popup.isHidden else {
            return false
        }
        
        let key = event.keyCode
        
        switch key {
        case 126: // Up Arrow
            popup.selectPrevious()
            return true
        case 125: // Down Arrow
            popup.selectNext()
            return true
        case 36: // Enter
            popup.confirmSelection()
            return true
        case 53: // Escape
            hideCompletion()
            return true
        default:
            return false
        }
    }
}

// MARK: - CompletionPopupDelegate

extension CodeEditorContainerView: CompletionPopupDelegate {
    func completionPopup(_ popup: CompletionPopupView, didSelectItem item: CompletionItem) {
        insertCompletion(item)
    }
}
