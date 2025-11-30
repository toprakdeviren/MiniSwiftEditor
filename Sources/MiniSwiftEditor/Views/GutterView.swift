//
//  GutterView.swift
//  MiniSwiftEditor
//
//  Gutter view for line numbers and decorations
//  Requirements: 5.1, 5.2
//

import AppKit

// MARK: - GutterView Delegate

/// Delegate protocol for GutterView events
protocol GutterViewDelegate: AnyObject {
    /// Called when a line number or decoration is clicked
    func gutterView(_ view: GutterView, didClickLine line: Int)
}

// MARK: - GutterView

/// Data source for GutterView to avoid expensive string parsing
protocol GutterViewDataSource: AnyObject {
    func lineCount(in gutterView: GutterView) -> Int
    func gutterView(_ gutterView: GutterView, lineNumberForCharacterIndex index: Int) -> Int
    func gutterView(_ gutterView: GutterView, characterIndexForLineNumber line: Int) -> Int
}

/// A view that displays line numbers and gutter decorations.
/// Synchronizes scroll position with the associated text view.
/// Requirements: 5.1, 5.2, 11.1
final class GutterView: NSView {
    
    // MARK: - Properties
    
    /// Delegate for gutter events
    weak var delegate: GutterViewDelegate?
    
    /// Data source for line information
    weak var dataSource: GutterViewDataSource?
    
    /// The associated text view for scroll synchronization
    weak var textView: NSTextView? {
        didSet {
            setupScrollObserver()
        }
    }
    
    /// Line decorations to display
    var lineDecorations: [LineDecoration] = [] {
        didSet {
            needsDisplay = true
        }
    }
    
    /// Font for line numbers (should match editor font)
    var font: NSFont = .monospacedSystemFont(ofSize: 13, weight: .regular) {
        didSet {
            invalidateAttributeCache()
            updateGutterWidth()
            needsDisplay = true
        }
    }
    
    /// Line number text color
    var lineNumberColor: NSColor = .secondaryLabelColor {
        didSet {
            invalidateAttributeCache()
            needsDisplay = true
        }
    }
    
    /// Gutter background color
    var gutterBackgroundColor: NSColor = NSColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0) {
        didSet {
            needsDisplay = true
        }
    }
    
    /// Current line highlight color
    var currentLineColor: NSColor = NSColor.selectedTextBackgroundColor.withAlphaComponent(0.15) {
        didSet {
            needsDisplay = true
        }
    }
    
    /// Separator line color
    var separatorColor: NSColor = NSColor.separatorColor {
        didSet {
            needsDisplay = true
        }
    }
    
    /// Current line index (0-based)
    var currentLineIndex: Int = 0 {
        didSet {
            needsDisplay = true
        }
    }
    
    /// Total number of lines
    private(set) var lineCount: Int = 1
    
    /// Calculated gutter width
    private(set) var gutterWidth: CGFloat = 40
    
    /// Minimum gutter width
    private let minimumGutterWidth: CGFloat = 32
    
    /// Padding on each side of line numbers
    private let horizontalPadding: CGFloat = 8
    
    /// Text container inset (should match editor)
    var textContainerInset: NSSize = NSSize(width: 8, height: 8)
    
    /// Scroll observer
    private var scrollObserver: NSObjectProtocol?
    
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
        layer?.backgroundColor = gutterBackgroundColor.cgColor
    }
    
    override var isFlipped: Bool {
        return true
    }
    
    deinit {
        if let observer = scrollObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Scroll Synchronization
    
    private func setupScrollObserver() {
        // Remove existing observer
        if let observer = scrollObserver {
            NotificationCenter.default.removeObserver(observer)
            scrollObserver = nil
        }
        
        guard let textView = textView,
              let scrollView = textView.enclosingScrollView else {
            return
        }
        
        let clipView = scrollView.contentView
        
        clipView.postsBoundsChangedNotifications = true
        
        scrollObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: clipView,
            queue: .main
        ) { [weak self] _ in
            self?.synchronizeScroll()
        }
    }
    
    /// Synchronize scroll position with the text view.
    /// Requirements: 5.2
    func synchronizeScroll() {
        needsDisplay = true
    }
    
    /// Synchronize with a specific scroll view
    func synchronizeScroll(with scrollView: NSScrollView) {
        needsDisplay = true
    }
    
    // MARK: - Layout
    
    /// Update the gutter width based on line count
    func updateGutterWidth() {
        let maxLineNumber = max(lineCount, 1)
        let digitCount = String(maxLineNumber).count
        
        // Calculate width needed for the widest line number
        let sampleText = String(repeating: "9", count: digitCount)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let size = (sampleText as NSString).size(withAttributes: attributes)
        
        gutterWidth = max(minimumGutterWidth, size.width + horizontalPadding * 2)
    }
    
    /// Update line count and recalculate width
    func updateLineCount(_ count: Int) {
        lineCount = max(1, count)
        updateGutterWidth()
        needsDisplay = true
    }
    
    // MARK: - Cached Drawing Resources
    
    /// Cached line number attributed strings for performance
    /// Key: line number (1-based), Value: attributed string
    private var lineNumberCache: [Int: NSAttributedString] = [:]
    
    /// Maximum cached line numbers
    private let maxCachedLineNumbers = 10000
    
    /// Cached text attributes for line numbers
    private var cachedTextAttributes: [NSAttributedString.Key: Any]?
    
    private func getTextAttributes() -> [NSAttributedString.Key: Any] {
        if let cached = cachedTextAttributes {
            return cached
        }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: lineNumberColor
        ]
        cachedTextAttributes = attrs
        return attrs
    }
    
    /// Invalidate cached attributes when font or color changes
    private func invalidateAttributeCache() {
        cachedTextAttributes = nil
        lineNumberCache.removeAll()
    }
    
    // MARK: - Drawing
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw background - only draw the dirty rect for performance
        gutterBackgroundColor.setFill()
        dirtyRect.fill()
        
        // Draw separator line - only if visible in dirty rect
        if dirtyRect.maxX >= bounds.maxX - 1 {
            separatorColor.setStroke()
            let separatorPath = NSBezierPath()
            separatorPath.move(to: NSPoint(x: bounds.maxX - 0.5, y: dirtyRect.minY))
            separatorPath.line(to: NSPoint(x: bounds.maxX - 0.5, y: dirtyRect.maxY))
            separatorPath.lineWidth = 1.0
            separatorPath.stroke()
        }
        
        // Draw line numbers - optimized for visible lines only
        drawLineNumbers(in: dirtyRect)
        
        // Draw line decorations - optimized for visible lines only
        drawLineDecorations(in: dirtyRect)
    }
    
    private func drawLineNumbers(in dirtyRect: NSRect) {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            // Fallback: draw all line numbers without scroll sync
            drawAllLineNumbers(in: dirtyRect)
            return
        }
        
        let content = textView.string
        guard !content.isEmpty else {
            drawLineNumber(1, at: textContainerInset.height)
            return
        }
        
        // Get visible rect from text view's scroll view
        guard let scrollView = textView.enclosingScrollView else {
            drawAllLineNumbers(in: dirtyRect)
            return
        }
        
        let visibleRect = scrollView.documentVisibleRect
        
        // Get the glyph range for visible rect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let startCharIndex = layoutManager.characterIndexForGlyph(at: glyphRange.location)
        let endCharIndex = layoutManager.characterIndexForGlyph(at: glyphRange.location + glyphRange.length)
        
        let firstVisibleLine = dataSource?.gutterView(self, lineNumberForCharacterIndex: startCharIndex) ?? 0
        let lastVisibleLine = dataSource?.gutterView(self, lineNumberForCharacterIndex: endCharIndex) ?? (lineCount - 1)
        
        for lineIndex in firstVisibleLine...lastVisibleLine {
            guard let startOffset = dataSource?.gutterView(self, characterIndexForLineNumber: lineIndex) else { continue }
            
            // Get end offset (start of next line, or end of text)
            let endOffset: Int
            if let nextStart = dataSource?.gutterView(self, characterIndexForLineNumber: lineIndex + 1) {
                endOffset = nextStart
            } else {
                endOffset = content.count
            }
            
            let length = max(1, endOffset - startOffset)
            // Ensure we don't go out of bounds
            let safeLength = min(length, content.count - startOffset)
            if safeLength <= 0 && content.count > 0 { continue }
            
            let nsRange = NSRange(location: startOffset, length: safeLength)
            let glyphRange = layoutManager.glyphRange(forCharacterRange: nsRange, actualCharacterRange: nil)
            
            var lineRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            lineRect.origin.y += textContainerInset.height
            lineRect.origin.y -= visibleRect.origin.y
            
            // Skip lines outside dirty rect for performance
            if lineRect.maxY < dirtyRect.minY || lineRect.minY > dirtyRect.maxY {
                continue
            }
            
            // Draw current line highlight
            if lineIndex == currentLineIndex {
                currentLineColor.setFill()
                let highlightRect = NSRect(
                    x: 0,
                    y: lineRect.origin.y,
                    width: bounds.width,
                    height: lineRect.height
                )
                highlightRect.fill()
            }
            
            // Draw line number
            drawLineNumber(lineIndex + 1, at: lineRect.origin.y)
        }
    }
    
    private func drawAllLineNumbers(in dirtyRect: NSRect) {
        let lineHeight = font.pointSize * 1.2 // Approximate line height
        
        // Calculate visible line range based on dirty rect
        let firstVisibleLine = max(0, Int((dirtyRect.minY - textContainerInset.height) / lineHeight))
        let lastVisibleLine = min(lineCount - 1, Int((dirtyRect.maxY - textContainerInset.height) / lineHeight) + 1)
        
        for lineIndex in firstVisibleLine...lastVisibleLine {
            let y = textContainerInset.height + CGFloat(lineIndex) * lineHeight
            
            // Draw current line highlight
            if lineIndex == currentLineIndex {
                currentLineColor.setFill()
                let highlightRect = NSRect(
                    x: 0,
                    y: y,
                    width: bounds.width,
                    height: lineHeight
                )
                highlightRect.fill()
            }
            
            drawLineNumber(lineIndex + 1, at: y)
        }
    }
    
    private func drawLineNumber(_ number: Int, at y: CGFloat) {
        // Use cached attributed string for better performance
        let attributedString: NSAttributedString
        if let cached = lineNumberCache[number] {
            attributedString = cached
        } else {
            let text = "\(number)"
            attributedString = NSAttributedString(string: text, attributes: getTextAttributes())
            
            // Cache if under limit
            if lineNumberCache.count < maxCachedLineNumbers {
                lineNumberCache[number] = attributedString
            }
        }
        
        let size = attributedString.size()
        let x = gutterWidth - horizontalPadding - size.width
        
        // Vertically center in line
        let lineHeight = font.pointSize * 1.2
        let yOffset = (lineHeight - size.height) / 2
        
        attributedString.draw(at: NSPoint(x: x, y: y + yOffset))
    }
    
    private func drawLineDecorations(in dirtyRect: NSRect) {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return
        }
        
        guard let scrollView = textView.enclosingScrollView else { return }
        let visibleRect = scrollView.documentVisibleRect
        
        for decoration in lineDecorations {
            guard decoration.lineIndex >= 0 && decoration.lineIndex < lineCount else { continue }
            
            // Calculate line position using dataSource
            guard let startOffset = dataSource?.gutterView(self, characterIndexForLineNumber: decoration.lineIndex) else { continue }
            
            // Get end offset
            let endOffset: Int
            if let nextStart = dataSource?.gutterView(self, characterIndexForLineNumber: decoration.lineIndex + 1) {
                endOffset = nextStart
            } else {
                endOffset = textView.string.count
            }
            
            let length = max(1, endOffset - startOffset)
            let safeLength = min(length, textView.string.count - startOffset)
            if safeLength <= 0 && textView.string.count > 0 { continue }
            
            let nsRange = NSRange(location: startOffset, length: safeLength)
            let glyphRange = layoutManager.glyphRange(forCharacterRange: nsRange, actualCharacterRange: nil)
            
            var lineRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            lineRect.origin.y += textContainerInset.height
            lineRect.origin.y -= visibleRect.origin.y
            
            // Draw decoration based on kind
            drawDecoration(decoration.kind, at: lineRect.origin.y, height: lineRect.height)
        }
    }
    
    private func drawDecoration(_ kind: LineDecorationKind, at y: CGFloat, height: CGFloat) {
        let iconSize: CGFloat = 12
        let iconX: CGFloat = 4
        let iconY = y + (height - iconSize) / 2
        
        switch kind {
        case .lineNumber:
            // Line numbers are drawn separately
            break
            
        case .breakpoint:
            // Draw breakpoint indicator (red circle)
            NSColor.systemRed.setFill()
            let rect = NSRect(x: iconX, y: iconY, width: iconSize, height: iconSize)
            let path = NSBezierPath(ovalIn: rect)
            path.fill()
            
        case .diagnostic(let severity):
            // Draw diagnostic icon based on severity
            let color: NSColor
            switch severity {
            case .error:
                color = .systemRed
            case .warning:
                color = .systemYellow
            case .info:
                color = .systemBlue
            case .hint:
                color = .systemGray
            }
            
            color.setFill()
            let rect = NSRect(x: iconX, y: iconY, width: iconSize, height: iconSize)
            
            if severity == .error {
                // Draw circle for errors
                let path = NSBezierPath(ovalIn: rect)
                path.fill()
            } else if severity == .warning {
                // Draw triangle for warnings
                let path = NSBezierPath()
                path.move(to: NSPoint(x: rect.minX, y: rect.maxY))
                path.line(to: NSPoint(x: rect.maxX, y: rect.maxY))
                path.line(to: NSPoint(x: rect.midX, y: rect.minY))
                path.close()
                path.fill()
            } else {
                // Draw small circle for info/hint
                let smallRect = rect.insetBy(dx: 2, dy: 2)
                let path = NSBezierPath(ovalIn: smallRect)
                path.fill()
            }
            
        case .foldIndicator(let isFolded):
            // Draw fold indicator (triangle)
            let color = NSColor.secondaryLabelColor
            color.setFill()
            
            let path = NSBezierPath()
            if isFolded {
                // Right-pointing triangle (collapsed)
                path.move(to: NSPoint(x: iconX, y: iconY))
                path.line(to: NSPoint(x: iconX + iconSize, y: iconY + iconSize / 2))
                path.line(to: NSPoint(x: iconX, y: iconY + iconSize))
            } else {
                // Down-pointing triangle (expanded)
                path.move(to: NSPoint(x: iconX, y: iconY))
                path.line(to: NSPoint(x: iconX + iconSize, y: iconY))
                path.line(to: NSPoint(x: iconX + iconSize / 2, y: iconY + iconSize))
            }
            path.close()
            path.fill()
        }
    }
    
    // MARK: - Mouse Events
    
    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }
        
        // Find the line index at the clicked Y position
        // We need to account for scrolling
        guard let scrollView = textView.enclosingScrollView else { return }
        let visibleRect = scrollView.documentVisibleRect
        
        // Adjust Y for scrolling
        let yInDocument = location.y + visibleRect.origin.y - textContainerInset.height
        
        // Find glyph index at this point (using x=0)
        let pointInDocument = NSPoint(x: 0, y: yInDocument)
        let glyphIndex = layoutManager.glyphIndex(for: pointInDocument, in: textContainer)
        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        
        // Calculate line number using dataSource if available
        let lineNumber: Int
        if let dataSource = dataSource {
            lineNumber = dataSource.gutterView(self, lineNumberForCharacterIndex: charIndex)
        } else {
            // Fallback to string iteration
            let content = textView.string
            var count = 0
            var currentOffset = 0
            
            for char in content {
                if currentOffset >= charIndex {
                    break
                }
                if char == "\n" {
                    count += 1
                }
                currentOffset += 1
            }
            lineNumber = count
        }
        
        delegate?.gutterView(self, didClickLine: lineNumber)
    }
    
    override func scrollWheel(with event: NSEvent) {
        textView?.enclosingScrollView?.scrollWheel(with: event)
    }
}
