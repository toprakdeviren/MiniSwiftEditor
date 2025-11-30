//
//  CompletionPopupView.swift
//  MiniSwiftEditor
//
//  Popup view for code completion suggestions
//  Requirements: 12.2, 12.3, 12.4
//

import AppKit

protocol CompletionPopupDelegate: AnyObject {
    func completionPopup(_ popup: CompletionPopupView, didSelectItem item: CompletionItem)
}

final class CompletionPopupView: NSView {
    
    // MARK: - Properties
    
    weak var delegate: CompletionPopupDelegate?
    
    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    
    private var items: [CompletionItem] = []
    
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
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        
        // Setup ScrollView
        scrollView.frame = bounds
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        addSubview(scrollView)
        
        // Setup TableView
        tableView.frame = scrollView.bounds
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.style = .plain
        tableView.intercellSpacing = NSSize(width: 0, height: 4)
        
        // Add column
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("MainColumn"))
        column.width = bounds.width
        tableView.addTableColumn(column)
        
        scrollView.documentView = tableView
    }
    
    // MARK: - Public Methods
    
    func setItems(_ newItems: [CompletionItem]) {
        items = newItems
        tableView.reloadData()
        if !items.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }
    
    func selectNext() {
        let row = tableView.selectedRow
        if row < items.count - 1 {
            tableView.selectRowIndexes(IndexSet(integer: row + 1), byExtendingSelection: false)
            tableView.scrollRowToVisible(row + 1)
        }
    }
    
    func selectPrevious() {
        let row = tableView.selectedRow
        if row > 0 {
            tableView.selectRowIndexes(IndexSet(integer: row - 1), byExtendingSelection: false)
            tableView.scrollRowToVisible(row - 1)
        }
    }
    
    func confirmSelection() {
        let row = tableView.selectedRow
        if row >= 0 && row < items.count {
            delegate?.completionPopup(self, didSelectItem: items[row])
        }
    }
}

// MARK: - NSTableViewDataSource & Delegate

extension CompletionPopupView: NSTableViewDataSource, NSTableViewDelegate {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = items[row]
        let cellIdentifier = NSUserInterfaceItemIdentifier("CompletionCell")
        
        var view = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView
        if view == nil {
            view = NSTableCellView()
            view?.identifier = cellIdentifier
            
            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            view?.addSubview(textField)
            view?.textField = textField
            
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: view!.leadingAnchor, constant: 8),
                textField.centerYAnchor.constraint(equalTo: view!.centerYAnchor)
            ])
        }
        
        view?.textField?.stringValue = item.label
        // TODO: Add icon/kind
        
        return view
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 24
    }
}
