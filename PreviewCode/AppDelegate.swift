/*
 *  AppDelegate.swift
 *  PreviewCode
 *
 *  Created by Tony Smith on 30/05/2021.
 *  Copyright © 2026 Tony Smith. All rights reserved.
 */

import Cocoa
import Highlighter


typealias ThemeRecord = [String: Any]


@main
@MainActor
final class AppDelegate: NSResponder,
                         NSApplicationDelegate,
                         NSTableViewDelegate,
                         NSTableViewDataSource,
                         NSTextViewDelegate,
                         NSControlTextEditingDelegate,
                         NSTextFieldDelegate,
                         NSPopoverDelegate,
                         NSWindowDelegate {

    // MARK: - Class UI Properies
    
    // Menu Items
    @IBOutlet var helpMenuOnlineHelp: NSMenuItem!
    @IBOutlet var helpMenuAcknowledgments: NSMenuItem!
    @IBOutlet var helpMenuHighlightr: NSMenuItem!
    @IBOutlet var helpMenuHighlightjs: NSMenuItem!
    @IBOutlet var helpMenuHighlighterSwift: NSMenuItem!
    @IBOutlet var helpMenuRenderThemes: NSMenuItem!
    @IBOutlet var helpMenuReportBug: NSMenuItem!

    // Main Window: one tab per toolbar item (General, Code, Markdown & Notebook)
    @IBOutlet var window: NSWindow!
    @IBOutlet weak var mainTabView: NSTabView!

    // Window > General Tab Items
    @IBOutlet var versionLabel: NSTextField!

    // Window > Settings Tab Items
    @IBOutlet weak var fontSizeSlider: NSSlider!
    @IBOutlet weak var fontSizeLabel: NSTextField!
    @IBOutlet weak var fontNamePopup: NSPopUpButton!
    @IBOutlet weak var fontFacePopup: NSPopUpButton!
    @IBOutlet weak var darkRadioButton: NSButton!
    @IBOutlet weak var lightRadioButton: NSButton!
    @IBOutlet weak var autoRadioButton: NSButton!
    @IBOutlet weak var darkThemeLabel: NSTextField!
    @IBOutlet weak var lightThemeLabel: NSTextField!
    @IBOutlet weak var darkThemeIcon: PCImageView!
    @IBOutlet weak var lightThemeIcon: PCImageView!
    @IBOutlet weak var themeHelpLabel: NSTextField!
    @IBOutlet weak var lineSpacingPopup: NSPopUpButton!
    @IBOutlet weak var settingsHelpButton: NSButton!
    @IBOutlet weak var defaultsButton: NSButton!
    // FROM 2.3.0
    @IBOutlet weak var lightThemeListButton: NSButton!
    @IBOutlet weak var darkThemeListButton: NSButton!
    @IBOutlet weak var nuThemeTable: NSTableView!
    @IBOutlet weak var showLineNumbersSwitch: NSSwitch!

    // LOCAL: formerly in the Advanced Settings sheet. The Quick Look window
    // size fields are on the General tab, the others on the Code tab.
    @IBOutlet weak var previewWidthAdvancedText: NSTextField!
    @IBOutlet weak var previewHeightAdvancedText: NSTextField!
    @IBOutlet weak var tintThumbnailsAdvancedSwitch: NSSwitch!
    @IBOutlet weak var tintThumbnailsAdvancedLabel: NSTextField!
    @IBOutlet weak var previewMarginSizeText: NSTextField!


    // MARK: - Private Properies

    internal var currentSettings: PCSettings    = PCSettings()
    internal let defaultSettings: PCSettings    = PCSettings()
    internal var fonts: [PAFont]                = []
    internal var themes: [ThemeRecord]          = []
    internal var darkThemes: [Int]              = []
    internal var lightThemes: [Int]             = []
    internal var themeDisplayMode: Int          = BUFFOON_CONSTANTS.DISPLAY_MODE.AUTO
    internal var darkThemeIndex: Int            = 30    // atom-one-dark
    internal var lightThemeIndex: Int           = 29    // atom-one-light
    // FROM 2.2.4
    internal var oldMag: CGFloat                = 0.0
    internal var timer: Timer?                  = nil
    // FROM 2.3.0
    internal var themePopover: NSPopover?       = nil
    internal var buttonClicked: NSButton?       = nil
    // LOCAL: the Markdown tab's controls, built in code by `buildMarkdownPage()`
    internal var mdFontSizeSlider: NSSlider!    = nil
    internal var mdFontSizeLabel: NSTextField!  = nil
    internal var mdCodeSizeSlider: NSSlider!    = nil
    internal var mdCodeSizeLabel: NSTextField!  = nil
    // LOCAL: settings save as they change, but only once they have been loaded
    internal var settingsLoaded: Bool           = false
    // LOCAL: the General tab's controls, built in code by `buildGeneralPage()`
    internal var smallScaleSlider: NSSlider!    = nil
    internal var smallScaleLabel: NSTextField!  = nil
    internal var smallScaleNote: NSTextField?   = nil
    internal var updateNote: NSTextField?       = nil
    internal var updateButton: NSButton?        = nil

    /*
     Replace the following string with your own team ID. This is used to
     identify the app suite and so share preferences set by the main app with
     the previewer and thumbnailer extensions.
     */
    internal var appSuiteName: String = MNU_SECRETS.PID + BUFFOON_CONSTANTS.SUITE_NAME


    // MARK: - Class Lifecycle Functions

    func applicationDidFinishLaunching(_ notification: Notification) {

        // Pre-load fonts in a separate thread
        // NOTE This ultimately calls `AppDelegateSettings.loadSettings()`
        //      which we delay until after the fonts have loaded asynchronously
        //      because they reference loaded fonts.
        // FROM 2.4.1 - Upgrade to Swift Concurrency
        Task {
            asyncGetFonts()
        }

        // Set application group-level defaults
        self.defaultSettings.registerSettings(self.appSuiteName)

        // Disable the Help menu Spotlight features
        NSApplication.shared.helpMenu = NSMenu(title: "Dummy")

        // LOCAL: the tabs are laid out in code. Settings save as they change,
        // so there is no Apply button.
        buildMarkdownPage()
        buildGeneralPage()
        rearrangeCodePage()
        buildToolbar()

        // Set the `Settings` tab's tooltips
        initialiseSettings()

        // FROM 2.3.0
        self.previewMarginSizeText.delegate = self

        localApplicationDidFinishLaunching()

        // LOCAL: no `What's New` panel after an update; the changes are in the
        // release notes on GitHub

        // Center the main window and display
        setversionText(self.versionLabel)
        self.window.delegate = self
        // LOCAL: a fixed 5:4 window, toolbar included; the tabs lay out to fit it
        let windowSize = NSSize(width: 680, height: 544)
        self.window.contentMinSize = NSSize(width: 100, height: 100)
        self.window.contentMaxSize = NSSize(width: 4000, height: 4000)
        self.window.setContentSize(windowSize)
        let chrome = self.window.frame.height - (self.window.contentView?.frame.height ?? windowSize.height)
        let contentSize = NSSize(width: windowSize.width, height: windowSize.height - chrome)
        self.window.contentMinSize = contentSize
        self.window.contentMaxSize = contentSize
        self.window.setContentSize(contentSize)
        self.window.center()
        self.window.makeKeyAndOrderFront(self)

        // LOCAL: open on the General tab, with no field selected
        showTab(0)
        self.window.makeFirstResponder(nil)
    }


    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {

        // When the main window closed, shut down the app
        return true
    }


    // MARK: - Action Functions

    /**
     Called from the File menu's Close item and the various Quit controls.
     
     - Parameters:
        - sender: The source of the action.
     */
    @IBAction
    internal func doClose(_ sender: Any) {

        Task { @MainActor in
            await closeSettings()
        }
    }


    /**
     Handle a settings-change call to action, if there is one, and either bail (to allow the user
     to save the settings) or close the main window, which quits the app.

     FROM 2.0.0
     */
    internal func closeSettings() async {

        // Are there any unsaved changes to the settings?
        if checkSettingsOnQuit() {
            let alert = makeAlert("You have unsaved settings",
                                  "Do you wish to cancel and save or change them, or quit the app anyway?",
                                  false)
            alert.addButton(withTitle: "Quit")
            alert.addButton(withTitle: "Cancel")

            let response = await alert.beginSheetModal(for: self.window)
            if response != .alertFirstButtonReturn {
                // The user clicked 'Cancel'
                return
            }
        }

        self.window.close()
    }


    /**
     Called from the Help menu's items to open various websites.
     
     - Parameters:
        - sender: The source of the action.
     */
    @objc
    @IBAction
    private func doShowSites(sender: Any) {
        
        // Open the websites for contributors, help and suc
        guard let item = sender as? NSMenuItem else { return }
        var path = BUFFOON_CONSTANTS.MAIN_URL

        // Depending on the menu selected, set the load path
        if item == self.helpMenuOnlineHelp {
            path += "#usage"
        } else if item == self.helpMenuAcknowledgments {
            path += "#credits"
        } else if item == self.helpMenuReportBug {
            path += "/issues"
        } else if item == self.helpMenuHighlightr {
            path = "https://github.com/raspu/Highlightr"
        } else if item == self.helpMenuHighlightjs {
            path = "https://github.com/highlightjs/highlight.js"
        } else if item == self.helpMenuHighlighterSwift {
            path = "https://github.com/smittytone/HighlighterSwift"
        }
        
        // Open the selected website
        // FROM 2.2.3 -- more safely
        if let url = URL(string: path) {
            NSWorkspace.shared.open(url)
        }
    }


    /**
     Alternative route to help.
     */
    @IBAction
    private func doShowPrefsHelp(sender: Any) {
        
        if let url = URL(string: BUFFOON_CONSTANTS.MAIN_URL + "#settings") {
            NSWorkspace.shared.open(url)
        }
    }


    /**
     Open the System Preferences app at the Extensions pane.
     */
    @objc
    @IBAction
    private func doOpenSysPrefs(sender: Any) {

        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Extensions.prefPane"))
    }


    @IBAction
    private func doShowSettings(sender: Any) {

        showTab(0)
        self.window.makeKeyAndOrderFront(self)
    }


    /**
     Show a tab and select its toolbar item.

     LOCAL: 0 General, 1 Code, 2 Markdown & Notebook
     */
    internal func showTab(_ index: Int) {

        guard index >= 0, index < SettingsTab.all.count else { return }
        if index == 1 {
            willShowSettingsPage()
        }

        self.mainTabView.selectTabViewItem(at: index)
        self.window.toolbar?.selectedItemIdentifier = SettingsTab.all[index].id
        self.window.title = SettingsTab.all[index].label
    }


    // MARK: - Window Set Up Functions

    /**
     Add the app's version number to the UI.
     */
    private func setversionText(_ text: NSTextField) {

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        // LOCAL: the version alone, without the build number
        text.stringValue = "Version \(version)"
    }

}
