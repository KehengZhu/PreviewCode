/*
 *  AppDelegate+Toolbar.swift
 *  Quicklook Anything
 *
 *  The settings toolbar: General, Code, and Markdown & Notebook.
 */

import AppKit


extension AppDelegate {

    // MARK: - Toolbar

    /**
     The settings toolbar, as in Apple's own apps: General, Code and
     Markdown & Notebook, each an icon with a label. The window title names
     the selected tab.
     */
    internal func buildToolbar() {

        let toolbar = NSToolbar(identifier: "io.github.kehengzhu.QuicklookAnything.settings")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        toolbar.allowsUserCustomization = false
        self.window.titleVisibility = .visible
        self.window.titlebarAppearsTransparent = false
        self.window.toolbar = toolbar
        self.window.toolbarStyle = .preference
        toolbar.selectedItemIdentifier = SettingsTab.all[0].id
        self.window.title = SettingsTab.all[0].label
    }
}


/**
 The settings window's tabs, in toolbar order.
 */
struct SettingsTab {

    let id: NSToolbarItem.Identifier
    let label: String
    let symbol: String
    let toolTip: String

    static let all: [SettingsTab] = [
        SettingsTab(id: .init("general"), label: "General", symbol: "gearshape",
                    toolTip: "Quick Look window size, small previews and extensions"),
        SettingsTab(id: .init("code"), label: "Code", symbol: "chevron.left.forwardslash.chevron.right",
                    toolTip: "Source code and data files: .py .js .c .sh .swift and more than 50 languages"),
        SettingsTab(id: .init("markdown"), label: "Markdown & Notebook", symbol: "doc.richtext",
                    toolTip: "Markdown notes (.md) and Jupyter notebooks (.ipynb)"),
    ]
}


extension AppDelegate: NSToolbarDelegate {

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        SettingsTab.all.map(\.id)
    }


    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        SettingsTab.all.map(\.id)
    }


    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        SettingsTab.all.map(\.id)
    }


    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {

        guard let tab = SettingsTab.all.first(where: { $0.id == itemIdentifier }) else { return nil }
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = tab.label
        item.toolTip = tab.toolTip
        item.image = NSImage(systemSymbolName: tab.symbol, accessibilityDescription: tab.label)
        item.target = self
        item.action = #selector(doSelectToolbarTab(_:))
        return item
    }


    @objc
    private func doSelectToolbarTab(_ sender: NSToolbarItem) {

        guard let index = SettingsTab.all.firstIndex(where: { $0.id == sender.itemIdentifier }) else { return }
        // Leave a text field so its value is checked and saved first
        self.window.makeFirstResponder(nil)
        showTab(index)
    }
}
