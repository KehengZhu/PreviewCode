/*
 *  AppDelegate.swift
 *  PreviewCode
 *
 *  Created by Tony Smith on 30/05/2021.
 *  Copyright © 2026 Tony Smith. All rights reserved.
 */

import Cocoa
import CoreServices
import WebKit
import Highlighter


typealias ThemeRecord = [String: Any]


@main
@MainActor
final class AppDelegate: NSResponder,
                         NSApplicationDelegate,
                         WKNavigationDelegate,
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
    @IBOutlet var helpMenuAppStoreRating: NSMenuItem!
    @IBOutlet var helpMenuHighlightr: NSMenuItem!
    @IBOutlet var helpMenuHighlightjs: NSMenuItem!
    @IBOutlet var helpMenuHighlighterSwift: NSMenuItem!
    @IBOutlet var helpMenuOthersPreviewMarkdown: NSMenuItem!
    @IBOutlet var helpMenuOthersPreviewJson: NSMenuItem!
    @IBOutlet var helpMenuRenderThemes: NSMenuItem!
    // FROM 1.2.5
    @IBOutlet var helpMenuWhatsNew: NSMenuItem!
    @IBOutlet var helpMenuReportBug: NSMenuItem!
    @IBOutlet var mainMenuSettings: NSMenuItem!
    
    // Main Window
    @IBOutlet var window: NSWindow!
    @IBOutlet weak var infoButton: NSButton!
    @IBOutlet weak var settingsButton: NSButton!
    @IBOutlet weak var feedbackButton: NSButton!
    @IBOutlet weak var mainTabView: NSTabView!

    // Window > Info Tab Items
    @IBOutlet var versionLabel: NSTextField!
    @IBOutlet var infoLabel: NSTextField!

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
    @IBOutlet weak var applyButton: NSButton!
    // FROM 2.0.0
    //@IBOutlet weak var showLineNumbersCheckbox: NSButton!
    @IBOutlet weak var settingsHelpButton: NSButton!
    @IBOutlet weak var defaultsButton: NSButton!
    // FROM 2.3.0
    @IBOutlet weak var lightThemeListButton: NSButton!
    @IBOutlet weak var darkThemeListButton: NSButton!
    @IBOutlet weak var nuThemeTable: NSTableView!
    @IBOutlet weak var showLineNumbersSwitch: NSSwitch!

    // Window > Feedback Tab Items
    @IBOutlet weak var feedbackText: NSTextField!
    @IBOutlet weak var connectionProgress: NSProgressIndicator!
    @IBOutlet weak var messageSizeLabel: NSTextField!
    @IBOutlet weak var messageSendButton: NSButton!

    // What's New Sheet
    @IBOutlet var whatsNewWindow: NSWindow!
    @IBOutlet var whatsNewWebView: WKWebView!

    // FROM 2.3.0
    // Advanced Settings Sheet
    @IBOutlet weak var advancedSettingsSheet: NSWindow!
    @IBOutlet weak var applyAdvancedButton: NSButton!
    // LOCAL: window width and height fields replace the Small/Medium/Large popup
    @IBOutlet weak var previewWidthAdvancedText: NSTextField!
    @IBOutlet weak var previewHeightAdvancedText: NSTextField!
    @IBOutlet weak var tintThumbnailsAdvancedSwitch: NSSwitch!
    @IBOutlet weak var tintThumbnailsAdvancedLabel: NSTextField!
    @IBOutlet weak var previewMarginSizeText: NSTextField!
    @IBOutlet weak var previewMarginRangeText: NSTextField!
    @IBOutlet weak var advancedHelpButton: NSButton!


    // MARK: - Private Properies

    internal var currentSettings: PCSettings    = PCSettings()
    internal let defaultSettings: PCSettings    = PCSettings()
    internal var whatsNewNav: WKNavigation?     = nil
    internal var fonts: [PAFont]                = []
    internal var themes: [ThemeRecord]          = []
    internal var darkThemes: [Int]              = []
    internal var lightThemes: [Int]             = []
    internal var themeDisplayMode: Int          = BUFFOON_CONSTANTS.DISPLAY_MODE.AUTO
    internal var darkThemeIndex: Int            = 30    // atom-one-dark
    internal var lightThemeIndex: Int           = 29    // atom-one-light
    // FROM 2.0.0
    private  var tabManager: PATabManager       = PATabManager()
    internal var hasSentFeedback: Bool          = false
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
    // LOCAL: the tab bar: General, Code, Markdown & Notebook
    internal var tabBar: NSSegmentedControl!    = nil
    internal var smallScaleSlider: NSSlider!    = nil
    internal var smallScaleLabel: NSTextField!  = nil
    internal var smallScaleNote: NSTextField?   = nil

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
        self.defaultSettings.registerSettings(self.appSuiteName, getVersion())

        // Disable the Help menu Spotlight features
        NSApplication.shared.helpMenu = NSMenu(title: "Dummy")

        self.infoButton.toolTip = "About \(BUFFOON_CONSTANTS.APP_NAME)"
        self.settingsButton.toolTip = "Set preview styles and content"
        self.feedbackButton.toolTip = "Set Markdown and notebook text sizes"
        self.infoButton.alphaValue = 1.0
        self.settingsButton.alphaValue = 1.0
        self.feedbackButton.alphaValue = 1.0

        // LOCAL: the third tab, formerly Feedback (there is no feedback server),
        // holds the Markdown and notebook settings. Settings save as they change,
        // so there is no Apply button.
        buildMarkdownPage()
        self.applyButton.isHidden = true
        buildGeneralPage()
        rearrangeCodePage()
        buildTabBar()

        // FROM 2.0.0
        // Configure the tab manager
        self.tabManager.parent = self
        self.tabManager.buttons.append(self.infoButton)
        self.tabManager.buttons.append(self.settingsButton)
        self.tabManager.buttons.append(self.feedbackButton)
        // Add callback closures, one per tab, to the tab manager
        self.tabManager.callbacks.append(nil)   // Info tab
        self.tabManager.callbacks.append { self.willShowSettingsPage() }
        self.tabManager.callbacks.append(nil)   // Markdown tab

        // Clear the `Feedback` tab
        // NOTE Don't initialise the Settings tab here too:
        //      It must happen after we've got a list of fonts
        initialiseFeedback()

        // Set the `Settings` tab's tooltips
        initialiseSettings()

        // FROM 2.3.0
        self.previewMarginSizeText.delegate = self
        self.previewMarginRangeText.stringValue = "Valid range \(BUFFOON_CONSTANTS.PREVIEW_SIZE.MARGIN_WIDTH_MIN)-\(BUFFOON_CONSTANTS.PREVIEW_SIZE.MARGIN_WIDTH_MAX)"

        localApplicationDidFinishLaunching()

        // Show the `What's New` panel if we need to
        // NOTE Has to take place at the end of the function
        doShowWhatsNew(nil)

        // Centre the main window and display
        setInfoText(self.infoLabel)
        setversionText(self.versionLabel)
        self.window.delegate = self
        self.window.center()
        self.window.makeKeyAndOrderFront(self)

        // LOCAL: open on the General tab
        showTab(0)
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
            await closeBasics()
            await closeSettings()
        }
    }


    /**
     Close sheets and perform other general close-related tasks.

     FROM 2.0.0
     */
    internal func closeBasics() async {

        // Close the What's New sheet if it's open
        if self.whatsNewWindow.isVisible {
            self.whatsNewWindow.close()
        }
    }


    /**
     Handle a settings-change call to action, if there is one, and either bail (to allow the user
     to save the settings) or move on to the feedback check.

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

        // Move on to the next phase: the feedback check
        await closeFeedback()
    }


    /**
     Handle a feedback-unsent call to action, if one is needed, and either bail (to all the user
     to send the feedback) or close the main window.

     FROM 2.0.0
     */
    internal func closeFeedback() async {

        // Does the feeback page contain text? If so let the user know
        if self.feedbackText.stringValue.count > 0 && !self.hasSentFeedback {
            let alert = makeAlert("You have unsent feedback",
                                  "Do you wish to cancel and send it, or quit the app anyway?",
                                  false)
            alert.addButton(withTitle: "Quit")
            alert.addButton(withTitle: "Cancel")

            let response = await alert.beginSheetModal(for: self.window)
            if response != .alertFirstButtonReturn {
                // The user clicked 'Cancel'
                return
            }
        }

        // No feedback text to send/ignore so close the window which will trigger an app closure
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
        } else if item == self.helpMenuAppStoreRating {
            path = BUFFOON_CONSTANTS.APP_STORE + "?action=write-review"
        } else if item == self.helpMenuHighlightr {
            path = "https://github.com/raspu/Highlightr"
        } else if item == self.helpMenuHighlightjs {
            path = "https://github.com/highlightjs/highlight.js"
        } else if item == self.helpMenuHighlighterSwift {
            path = "https://github.com/smittytone/HighlighterSwift"
        } else if item == self.helpMenuOthersPreviewMarkdown {
            path = BUFFOON_CONSTANTS.APP_URLS.PM
        } else if item == self.helpMenuOthersPreviewJson {
            path = BUFFOON_CONSTANTS.APP_URLS.PJ
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
        
        let path: String
        if sender as? NSButton == self.advancedHelpButton {
            path = BUFFOON_CONSTANTS.MAIN_URL + "#settings"
        } else {
            path = BUFFOON_CONSTANTS.MAIN_URL + "#settings"
        }

        // Open the selected website
        // FROM 2.2.3 -- more safely
        if let url = URL(string: path) {
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
    private func doSwitchTab(sender: NSButton) {

        // FROM 2.0.0
        self.tabManager.buttonClicked(sender)
    }


    @IBAction
    private func doShowSettings(sender: Any) {

        // FROM 2.0.0
        showTab(0)
    }


    @IBAction
    private func doShowFeedback(sender: Any) {

        // FROM 2.0.0
        self.tabManager.programmaticallyClickButton(at: 2)
    }


    /**
     Show a tab and select it in the tab bar.

     LOCAL: 0 General, 1 Code, 2 Markdown & Notebook
     */
    internal func showTab(_ index: Int) {

        self.tabManager.programmaticallyClickButton(at: index)
        self.tabBar?.selectedSegment = index
    }


    @objc
    internal func doSelectTab(_ sender: NSSegmentedControl) {

        // Leave a text field so its value is checked and saved first
        self.window.makeFirstResponder(nil)
        showTab(sender.selectedSegment)
    }


    // MARK: - Window Set Up Functions

    /**
     Create and display the information text label. This is done programmatically
     because we're using an NSAttributedString rather than a plain string.
     */
    private func setInfoText(_ text: NSTextField) {

        // Set the attributes
        let bodyAtts: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13.0),
            .foregroundColor: NSColor.labelColor
        ]

        let boldAtts : [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13.0, weight: .bold),
            .foregroundColor: NSColor.labelColor
        ]

        let infoText = NSMutableAttributedString(string: "Select a file in Finder and press Space to preview it. Changes save as you make them. Turn the extensions off and on in ", attributes: bodyAtts)
        let boldText = NSAttributedString(string: "System Settings > General > Login Items & Extensions > Quick Look", attributes: boldAtts)
        infoText.append(boldText)
        infoText.append(NSAttributedString(string: "; if previews stop appearing, run the install command again.", attributes: bodyAtts))
        text.attributedStringValue = infoText
    }


    /**
     Add the app's version number to the UI.
     */
    private func setversionText(_ text: NSTextField) {

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        text.stringValue = "Version \(version) (\(build))"
    }

}
