//
//  CodeEditorView.swift
//  MiniSwiftEditor
//
//  NSTextView-based code editor with TextKit 2 support
//  Requirements: 4.2
//

import AppKit
import Combine

// MARK: - CodeEditorView Delegate

/// Delegate protocol for CodeEditorView events
protocol CodeEditorViewDelegate: AnyObject {
    /// Called when text content changes
    func editorView(_ view: CodeEditorView, didChangeText text: String, range: NSRange, delta: Int)
    /// Called when selection changes
    func editorView(_ view: CodeEditorView, didChangeSelection selection: Selection)
    /// Called when the view scrolls
    func editorView(_ view: CodeEditorView, didScroll visibleRange: Range<Int>)
}

// MARK: - EditorTextView

class EditorTextView: NSTextView {
    weak var commandHandler: CommandHandler?
    weak var completionDelegate: CodeEditorCompletionDelegate?
    
    override func keyDown(with event: NSEvent) {
        // Check if completion delegate wants to handle the event
        if let delegate = completionDelegate, delegate.codeEditor(shouldHandleKeyEvent: event) {
            return
        }
        
        if let handler = commandHandler, handler.handleKeyEvent(event) {
            return
        }
        super.keyDown(with: event)
    }
}

/// Delegate for handling completion-related key events
protocol CodeEditorCompletionDelegate: AnyObject {
    /// Ask delegate if it wants to handle the key event (e.g. for completion list navigation)
    func codeEditor(shouldHandleKeyEvent event: NSEvent) -> Bool
}

// MARK: - CodeEditorView

/// A code editor view built on NSTextView with TextKit 2.
/// Supports syntax highlighting through DecorationModel.
/// Requirements: 4.2
final class CodeEditorView: NSView, NSTextStorageDelegate, NSTextViewDelegate {
    
    // MARK: - TextKit Components
    
    /// The underlying text view
    private(set) var textView: EditorTextView!
    

    
    /// Text storage for the content
    private var textStorage: NSTextStorage!
    
    /// Layout manager for text layout
    private var layoutManager: NSLayoutManager!
    
    /// Text container for layout bounds
    private var textContainer: NSTextContainer!
    
    /// Scroll view containing the text view
    private(set) var scrollView: NSScrollView!
    
    // MARK: - Properties
    
    /// Delegate for editor events
    weak var delegate: CodeEditorViewDelegate?
    
    /// The decoration model for syntax highlighting
    var decorationModel: DecorationModel? {
        didSet {
            applyDecorations()
        }
    }
    
    /// Whether the editor is in read-only mode
    var isReadOnly: Bool = false {
        didSet {
            textView?.isEditable = !isReadOnly
        }
    }
    
    /// The text content of the editor
    var string: String {
        get { textView?.string ?? "" }
        set {
            textView?.string = newValue
            applyDecorations()
        }
    }
    
    /// Editor font
    var font: NSFont = .monospacedSystemFont(ofSize: 13, weight: .regular) {
        didSet {
            invalidateAttributeCache()
            textView?.font = font
            applyDecorations()
        }
    }
    
    /// Line height multiplier
    var lineHeightMultiple: CGFloat = 1.2
    
    // MARK: - Theme Colors
    
    /// Background color
    var backgroundColor: NSColor = NSColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0) {
        didSet {
            textView?.backgroundColor = backgroundColor
        }
    }
    
    /// Text color
    var textColor: NSColor = .textColor {
        didSet {
            invalidateAttributeCache()
            textView?.textColor = textColor
        }
    }
    
    /// Selection color
    var selectionColor: NSColor = .selectedTextBackgroundColor
    
    /// Caret color
    var caretColor: NSColor = .textColor {
        didSet {
            textView?.insertionPointColor = caretColor
        }
    }
    
    /// Command handler for key bindings
    var commandHandler: CommandHandler? {
        didSet {
            textView?.commandHandler = commandHandler
        }
    }
    
    /// Completion delegate
    weak var completionDelegate: CodeEditorCompletionDelegate? {
        didSet {
            textView?.completionDelegate = completionDelegate
        }
    }
    

    
    // MARK: - Syntax Colors
    
    /// Colors for different token kinds
    private var syntaxColors: [TokenKind: NSColor] = [
        .keyword: NSColor(red: 0.78, green: 0.18, blue: 0.53, alpha: 1.0),
        .identifier: NSColor.textColor,
        .typeIdentifier: NSColor(red: 0.11, green: 0.43, blue: 0.55, alpha: 1.0),
        .numberLiteral: NSColor(red: 0.11, green: 0.0, blue: 0.81, alpha: 1.0),
        .stringLiteral: NSColor(red: 0.77, green: 0.1, blue: 0.09, alpha: 1.0),
        .comment: NSColor(red: 0.42, green: 0.47, blue: 0.46, alpha: 1.0),
        .operator: NSColor.textColor,
        .punctuation: NSColor.textColor,
        .whitespace: NSColor.clear,
        .unknown: NSColor.textColor
    ]
    
    // MARK: - Initialization
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTextView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTextView()
    }
    
    // MARK: - Setup
    
    private func setupTextView() {
        textStorage = NSTextStorage()
        textStorage.delegate = self

        layoutManager = NSLayoutManager()
        layoutManager.allowsNonContiguousLayout = true
        textStorage.addLayoutManager(layoutManager)

        textContainer = NSTextContainer()
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false
        layoutManager.addTextContainer(textContainer)

        textView = EditorTextView(frame: bounds, textContainer: textContainer)
        textView.commandHandler = commandHandler
        textView.completionDelegate = completionDelegate
        textView.delegate = self // Set delegate
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 8, height: 8)

        textView.font = font
        textView.backgroundColor = backgroundColor
        textView.textColor = textColor
        textView.insertionPointColor = caretColor
        textView.isEditable = !isReadOnly
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        
        scrollView = NSScrollView(frame: bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.documentView = textView
        
        addSubview(scrollView)
        
        // Set up notifications
        setupNotifications()
    }
    
    private func setupNotifications() {
        // We use textStorage delegate for text changes now
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(selectionDidChange(_:)),
            name: NSTextView.didChangeSelectionNotification,
            object: textView
        )
        
        // Observe scroll changes
        let clipView = scrollView.contentView
        clipView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scrollViewDidScroll(_:)),
            name: NSView.boundsDidChangeNotification,
            object: clipView
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - NSTextStorageDelegate
    
    func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
        // Only notify if characters changed (not just attributes)
        if editedMask.contains(.editedCharacters) {
            delegate?.editorView(self, didChangeText: string, range: editedRange, delta: delta)
        }
    }
    
    // MARK: - NSTextViewDelegate
    
    func textView(_ view: NSTextView, stringForToolTipAt point: NSPoint, userData: UnsafeMutableRawPointer?) -> String? {
        guard let layoutManager = view.layoutManager,
              let textContainer = view.textContainer else { return nil }
        
        // Convert point to glyph index
        var fraction: CGFloat = 0
        let glyphIndex = layoutManager.glyphIndex(for: point, in: textContainer, fractionOfDistanceThroughGlyph: &fraction)
        
        // Convert to character index
        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        
        // Check if point is actually within the glyph bounds
        let boundingRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: textContainer)
        guard boundingRect.contains(point) else { return nil }
        
        // Query decoration model for diagnostics
        guard let decorationModel = decorationModel else { return nil }
        
        let decorations = decorationModel.decorations(in: charIndex..<(charIndex + 1))
        
        // Find decoration with tooltip
        for decoration in decorations {
            if let tooltip = decoration.tooltip {
                return tooltip
            }
        }
        
        return nil
    }
    
    // MARK: - Layout
    
    override func layout() {
        super.layout()
        scrollView.frame = bounds
    }
    
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        
        // Refresh colors that might depend on appearance
        textView?.backgroundColor = backgroundColor
        textView?.textColor = textColor
        textView?.insertionPointColor = caretColor
        
        // Re-apply decorations to update syntax colors if they are dynamic
        applyDecorations()
    }
    
    // MARK: - Decoration Application
    
    /// Cached default attributes for performance
    private var cachedDefaultAttributes: [NSAttributedString.Key: Any]?
    
    /// Track the last applied decoration range to enable incremental updates
    private var lastAppliedRange: Range<Int>?
    
    private func getDefaultAttributes() -> [NSAttributedString.Key: Any] {
        if let cached = cachedDefaultAttributes {
            return cached
        }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]
        cachedDefaultAttributes = attrs
        return attrs
    }
    
    /// Invalidate cached attributes when font or color changes
    private func invalidateAttributeCache() {
        cachedDefaultAttributes = nil
        lastAppliedRange = nil
    }
    
    /// Apply decorations from the DecorationModel to the text view.
    /// Converts decoration objects to NSAttributedString attributes.
    /// Optimized for performance with batched updates and visible-range focus.
    /// Requirements: 4.2, 14.3 (60fps scroll), 14.4 (<16ms keystroke)
    func applyDecorations() {
        applyDecorations(in: nil)
    }
    
    /// Apply decorations incrementally to a specific range.
    /// If range is nil, applies to the entire document.
    /// This prevents flickering by only updating the changed region.
    /// - Parameter changedRange: The range that changed, or nil for full update
    func applyDecorations(in changedRange: Range<Int>?) {
        guard let textStorage = textStorage else { return }
        guard textStorage.length > 0 else { return }
        
        // Determine the range to update
        let updateRange: Range<Int>
        if let changedRange = changedRange {
            // Expand the changed range to include surrounding context
            // This ensures we catch any tokens that might span the change boundary
            let contextBuffer = 100
            let start = max(0, changedRange.lowerBound - contextBuffer)
            let end = min(textStorage.length, changedRange.upperBound + contextBuffer)
            updateRange = start..<end
        } else {
            // Full document update
            updateRange = 0..<textStorage.length
        }
        
        let nsUpdateRange = NSRange(location: updateRange.lowerBound, length: updateRange.count)
        
        // Begin editing - batches all changes for better performance
        textStorage.beginEditing()
        
        // Reset only the update range to default attributes
        textStorage.setAttributes(getDefaultAttributes(), range: nsUpdateRange)
        
        // Apply decorations if available
        if let decorationModel = decorationModel {
            let decorations = decorationModel.decorations(in: updateRange)
            
            // Sort by priority (lower priority first, so higher priority overwrites)
            let sortedDecorations = decorations.sorted { $0.priority < $1.priority }
            
            for decoration in sortedDecorations {
                // Only apply decorations that intersect with our update range
                let decorationStart = max(updateRange.lowerBound, decoration.range.lowerBound)
                let decorationEnd = min(updateRange.upperBound, decoration.range.upperBound)
                
                if decorationStart < decorationEnd {
                    let clippedDecoration = Decoration(
                        range: decorationStart..<decorationEnd,
                        kind: decoration.kind,
                        priority: decoration.priority,
                        tooltip: decoration.tooltip
                    )
                    applyDecoration(clippedDecoration, to: textStorage)
                }
            }
        }
        
        // End editing - triggers single layout pass
        textStorage.endEditing()
        
        lastAppliedRange = updateRange
    }
    
    /// Apply a single decoration to the text storage
    private func applyDecoration(_ decoration: Decoration, to storage: NSTextStorage) {
        // Validate range
        let maxLength = storage.length
        let start = max(0, decoration.range.lowerBound)
        let end = min(maxLength, decoration.range.upperBound)
        
        guard start < end else { return }
        
        let nsRange = NSRange(location: start, length: end - start)
        
        switch decoration.kind {
        case .syntax(let color, let traits):
            // Apply foreground color
            storage.addAttribute(.foregroundColor, value: color, range: nsRange)
            
            // Apply font traits
            if !traits.isEmpty {
                var fontDescriptor = font.fontDescriptor
                var symbolicTraits = fontDescriptor.symbolicTraits
                
                if traits.contains(.bold) {
                    symbolicTraits.insert(.bold)
                }
                if traits.contains(.italic) {
                    symbolicTraits.insert(.italic)
                }
                
                fontDescriptor = fontDescriptor.withSymbolicTraits(symbolicTraits)
                if let styledFont = NSFont(descriptor: fontDescriptor, size: font.pointSize) {
                    storage.addAttribute(.font, value: styledFont, range: nsRange)
                }
            }
            
        case .underline(let color, let style):
            // Apply underline
            let underlineStyle: NSUnderlineStyle = style == .squiggly ? [.single, .patternDot] : .single
            storage.addAttribute(.underlineStyle, value: underlineStyle.rawValue, range: nsRange)
            storage.addAttribute(.underlineColor, value: color, range: nsRange)
            
        case .background(let color):
            // Apply background color
            storage.addAttribute(.backgroundColor, value: color, range: nsRange)
            
        case .bracket(let isMatched):
            // Apply bracket highlighting
            let bgColor = isMatched 
                ? NSColor.systemGray.withAlphaComponent(0.3)
                : NSColor.systemRed.withAlphaComponent(0.3)
            storage.addAttribute(.backgroundColor, value: bgColor, range: nsRange)
            
        case .foldPlaceholder:
            // Fold placeholder styling
            storage.addAttribute(.backgroundColor, value: NSColor.systemGray.withAlphaComponent(0.2), range: nsRange)
            
        case .hidden:
            // Hide text
            // We use a very small font and clear color to effectively hide it
            // A better approach would be custom NSLayoutManager, but this is a simple workaround
            if let hiddenFont = NSFont(name: font.fontName, size: 0.1) {
                storage.addAttribute(.font, value: hiddenFont, range: nsRange)
            }
            storage.addAttribute(.foregroundColor, value: NSColor.clear, range: nsRange)
        }
    }
    
    // MARK: - Notifications
    
    @objc private func selectionDidChange(_ notification: Notification) {
        guard let textView = textView else { return }
        let selectedRange = textView.selectedRange()
        let selection = Selection(
            anchor: selectedRange.location,
            head: selectedRange.location + selectedRange.length
        )
        delegate?.editorView(self, didChangeSelection: selection)
    }
    
    @objc private func scrollViewDidScroll(_ notification: Notification) {
        guard textView != nil else { return }
        
        // Calculate visible character range
        let visibleRect = scrollView.documentVisibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        
        let visibleRange = charRange.location..<(charRange.location + charRange.length)
        delegate?.editorView(self, didScroll: visibleRange)
    }
    
    // MARK: - Public Methods
    
    /// Get the visible line range
    func visibleLineRange() -> Range<Int>? {
        guard textView != nil else { return nil }
        
        let visibleRect = scrollView.documentVisibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        
        let content = string
        guard !content.isEmpty else { return 0..<1 }
        
        // Calculate line numbers
        let startLine = lineNumber(for: charRange.location)
        let endLine = lineNumber(for: charRange.location + charRange.length)
        
        return startLine..<(endLine + 1)
    }
    
    /// Get line number for a character offset
    func lineNumber(for offset: Int) -> Int {
        let content = string
        guard offset >= 0 && offset <= content.count else { return 0 }
        
        var lineNumber = 0
        var currentOffset = 0
        
        for char in content {
            if currentOffset >= offset {
                break
            }
            if char == "\n" {
                lineNumber += 1
            }
            currentOffset += 1
        }
        
        return lineNumber
    }
    
    /// Get the starting character offset for a specific line
    func offset(for lineIndex: Int) -> Int {
        let content = string
        let lines = content.components(separatedBy: "\n")
        
        guard lineIndex >= 0 else { return 0 }
        if lineIndex >= lines.count { return content.count }
        
        var offset = 0
        for i in 0..<lineIndex {
            offset += lines[i].count + 1 // +1 for newline
        }
        return offset
    }
    
    /// Get the total number of lines
    var lineCount: Int {
        let content = string
        guard !content.isEmpty else { return 1 }
        return content.components(separatedBy: "\n").count
    }
    
    /// Get the bounding rect for a line
    func boundingRect(forLine lineIndex: Int) -> NSRect? {
        guard let layoutManager = layoutManager,
              let textContainer = textContainer else { return nil }
        
        let content = string
        let lines = content.components(separatedBy: "\n")
        
        guard lineIndex >= 0 && lineIndex < lines.count else { return nil }
        
        // Calculate character offset for the line
        var offset = 0
        for i in 0..<lineIndex {
            offset += lines[i].count + 1 // +1 for newline
        }
        
        let lineLength = lines[lineIndex].count
        let nsRange = NSRange(location: offset, length: max(1, lineLength))
        
        let glyphRange = layoutManager.glyphRange(forCharacterRange: nsRange, actualCharacterRange: nil)
        let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        
        return boundingRect
    }
    
    /// Scroll to make a line visible
    func scrollToLine(_ lineIndex: Int) {
        guard let rect = boundingRect(forLine: lineIndex) else { return }
        textView?.scrollToVisible(rect)
    }
    
    /// Set syntax colors for token kinds
    func setSyntaxColor(_ color: NSColor, for kind: TokenKind) {
        syntaxColors[kind] = color
        applyDecorations()
    }
}
