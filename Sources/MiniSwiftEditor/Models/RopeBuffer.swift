//
//  RopeBuffer.swift
//  MiniSwiftEditor
//
//  Rope data structure implementation for efficient large file editing
//  Requirements: 14.2, 14.3, 14.4
//
//  Performance characteristics:
//  - O(log n) insert/delete operations
//  - O(log n) line index lookups
//  - O(n) content retrieval (use sparingly)
//

import Foundation

// MARK: - Rope Node

final class RopeNode {
    var left: RopeNode?
    var right: RopeNode?
    var weight: Int // Length of left subtree
    var text: String? // Only for leaf nodes
    var length: Int // Total length of this node's subtree
    var newlineCount: Int // Number of newlines in this subtree
    var height: Int // Height of subtree for balancing
    
    /// Maximum leaf size before splitting
    static let maxLeafSize = 1024
    
    /// Minimum leaf size before merging
    static let minLeafSize = 256
    
    init(text: String) {
        self.text = text
        self.length = text.count
        self.weight = text.count
        self.newlineCount = text.filter { $0 == "\n" }.count
        self.height = 1
        self.left = nil
        self.right = nil
    }
    
    init(left: RopeNode, right: RopeNode) {
        self.left = left
        self.right = right
        self.weight = left.length
        self.length = left.length + right.length
        self.newlineCount = left.newlineCount + right.newlineCount
        self.height = max(left.height, right.height) + 1
        self.text = nil
    }
    
    var isLeaf: Bool {
        return left == nil && right == nil
    }
    
    /// Balance factor for AVL-style balancing
    var balanceFactor: Int {
        let leftHeight = left?.height ?? 0
        let rightHeight = right?.height ?? 0
        return leftHeight - rightHeight
    }
}

// MARK: - Rope Buffer

final class RopeBuffer: TextBuffer {
    
    // MARK: - Properties
    
    private var root: RopeNode
    private(set) var version: Int = 0
    
    // MARK: - TextBuffer Protocol
    
    var content: String {
        collectText(node: root)
    }
    
    var lineCount: Int {
        // Line count is newlines + 1 (if not empty)
        // But if empty, it's 1 line (empty string)
        // If "abc\n", it's 2 lines?
        // StringBuffer implementation:
        // lineOffsets = [0] initially.
        // "abc" -> [0] -> count 1.
        // "abc\n" -> [0, 4] -> count 2.
        return root.newlineCount + 1
    }
    
    // MARK: - Initialization
    
    init(_ initialContent: String = "") {
        self.root = RopeNode(text: initialContent)
    }
    
    // MARK: - Methods
    
    func insert(_ text: String, at offset: Int) {
        guard offset >= 0 && offset <= root.length else { return }
        
        let (left, right) = split(node: root, at: offset)
        let middle = RopeNode(text: text)
        
        // Concatenate: left + middle + right
        let leftMiddle = concat(left, middle)
        root = concat(leftMiddle, right)
        
        version += 1
    }
    
    func delete(range: Range<Int>) {
        guard range.lowerBound >= 0 && range.upperBound <= root.length else { return }
        guard range.lowerBound < range.upperBound else { return }
        
        let (left, rightPart) = split(node: root, at: range.lowerBound)
        
        guard let rightPartNode = rightPart else {
            // Should not happen if range is valid
            return
        }
        
        let (_, right) = split(node: rightPartNode, at: range.upperBound - range.lowerBound)
        
        root = concat(left, right)
        
        version += 1
    }
    
    func lineRange(for lineIndex: Int) -> Range<Int> {
        let start = offset(for: lineIndex)
        let end: Int
        if lineIndex + 1 < lineCount {
            end = offset(for: lineIndex + 1)
        } else {
            end = root.length
        }
        return start..<end
    }
    
    func lineIndex(for offset: Int) -> Int {
        guard offset >= 0 && offset <= root.length else { return 0 }
        return findLineIndex(node: root, offset: offset)
    }
    
    func offset(for lineIndex: Int) -> Int {
        guard lineIndex >= 0 else { return 0 }
        if lineIndex >= lineCount { return root.length }
        return findOffset(node: root, lineIndex: lineIndex)
    }
    
    // MARK: - Private Helpers
    
    private func collectText(node: RopeNode) -> String {
        if let text = node.text {
            return text
        }
        var result = ""
        if let left = node.left {
            result += collectText(node: left)
        }
        if let right = node.right {
            result += collectText(node: right)
        }
        return result
    }
    
    private func concat(_ left: RopeNode?, _ right: RopeNode?) -> RopeNode {
        guard let left = left else { return right ?? RopeNode(text: "") }
        guard let right = right else { return left }

        let node = RopeNode(left: left, right: right)
        
        // Balance if needed for O(log n) operations
        return balance(node)
    }
    
    /// Balance the tree using AVL-style rotations
    /// Ensures O(log n) height for efficient operations
    /// Requirements: 14.3, 14.4
    private func balance(_ node: RopeNode) -> RopeNode {
        guard !node.isLeaf else { return node }
        
        let bf = node.balanceFactor
        
        // Left heavy
        if bf > 1 {
            if let left = node.left, left.balanceFactor < 0 {
                // Left-Right case
                node.left = rotateLeft(left)
            }
            return rotateRight(node)
        }
        
        // Right heavy
        if bf < -1 {
            if let right = node.right, right.balanceFactor > 0 {
                // Right-Left case
                node.right = rotateRight(right)
            }
            return rotateLeft(node)
        }
        
        return node
    }
    
    /// Rotate tree left
    private func rotateLeft(_ node: RopeNode) -> RopeNode {
        guard let right = node.right else { return node }
        
        node.right = right.left
        right.left = node
        
        // Update metadata
        updateNodeMetadata(node)
        updateNodeMetadata(right)
        
        return right
    }
    
    /// Rotate tree right
    private func rotateRight(_ node: RopeNode) -> RopeNode {
        guard let left = node.left else { return node }
        
        node.left = left.right
        left.right = node
        
        // Update metadata
        updateNodeMetadata(node)
        updateNodeMetadata(left)
        
        return left
    }
    
    /// Update node metadata after rotation
    private func updateNodeMetadata(_ node: RopeNode) {
        if node.isLeaf {
            node.height = 1
            return
        }
        
        let leftLength = node.left?.length ?? 0
        let rightLength = node.right?.length ?? 0
        let leftNewlines = node.left?.newlineCount ?? 0
        let rightNewlines = node.right?.newlineCount ?? 0
        let leftHeight = node.left?.height ?? 0
        let rightHeight = node.right?.height ?? 0
        
        node.weight = leftLength
        node.length = leftLength + rightLength
        node.newlineCount = leftNewlines + rightNewlines
        node.height = max(leftHeight, rightHeight) + 1
    }
    
    private func split(node: RopeNode, at index: Int) -> (RopeNode?, RopeNode?) {
        if node.isLeaf {
            let text = node.text ?? ""
            if index == 0 {
                return (nil, node)
            } else if index == text.count {
                return (node, nil)
            } else {
                let leftText = String(text.prefix(index))
                let rightText = String(text.suffix(text.count - index))
                return (RopeNode(text: leftText), RopeNode(text: rightText))
            }
        }
        
        if index < node.weight {
            // Split left
            let (leftLeft, leftRight) = split(node: node.left!, at: index)
            let right = concat(leftRight, node.right)
            return (leftLeft, right)
        } else {
            // Split right
            let (rightLeft, rightRight) = split(node: node.right!, at: index - node.weight)
            let left = concat(node.left, rightLeft)
            return (left, rightRight)
        }
    }
    
    private func findLineIndex(node: RopeNode, offset: Int) -> Int {
        if node.isLeaf {
            let text = node.text ?? ""
            let prefix = text.prefix(min(offset, text.count))
            return prefix.filter { $0 == "\n" }.count
        }
        
        if offset < node.weight {
            return findLineIndex(node: node.left!, offset: offset)
        } else {
            return node.left!.newlineCount + findLineIndex(node: node.right!, offset: offset - node.weight)
        }
    }
    
    private func findOffset(node: RopeNode, lineIndex: Int) -> Int {
        if node.isLeaf {
            let text = node.text ?? ""
            var currentLine = 0
            var offset = 0
            
            for char in text {
                if currentLine == lineIndex {
                    return offset
                }
                if char == "\n" {
                    currentLine += 1
                }
                offset += 1
            }
            return offset // Should happen only if lineIndex is out of bounds or last line
        }
        
        if lineIndex < node.left!.newlineCount {
            return findOffset(node: node.left!, lineIndex: lineIndex)
        } else {
            return node.weight + findOffset(node: node.right!, lineIndex: lineIndex - node.left!.newlineCount)
        }
    }
}
