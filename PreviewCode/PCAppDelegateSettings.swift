/*
 *  PCAppDelegateSettings.swift
 *  PreviewCode
 *
 *  Created by Tony Smith on 18/07/2025.
 *  Copyright © 2026 Tony Smith. All rights reserved.
 */

import AppKit
import Highlighter


extension AppDelegate {

    // MARK: - Operational Functions
    
    /**
     Initialise UI elements.

     FROM 2.0.0
     */
    internal func initialiseSettings() {

        self.darkThemeIcon.toolTip = "The dark theme you have selected"
        self.darkThemeLabel.toolTip = self.darkThemeIcon.toolTip
        self.lightThemeIcon.toolTip = "The light theme you have selected"
        self.lightThemeLabel.toolTip = self.lightThemeIcon.toolTip
        self.themeHelpLabel.toolTip = "Which theme mode Quicklook Anything will apply"
        self.settingsHelpButton.toolTip = "Get online help for this page"
        self.defaultsButton.toolTip = "Restore default settings"
        // FROM 2.3.0
        self.darkThemeListButton.toolTip = "If enabled, click to select a dark mode theme"
        self.lightThemeListButton.toolTip = "If enabled, click to select a light mode theme"
    }


    /**
     Update UI when we are about to switch to it.

     FROM 2.0.0
     */
    internal func willShowSettingsPage() {

        // Set the themes table's contents store, once per runtime
        // NOTE We do this on all tab entry points, but will likely
        //      not be necessary here
        loadThemeList()

        // FROM 2.3.0
        // Update the UI
        setThemeControls()

        // FROM 2.2.6
        // Fix track colour on macOS 26
        if #available(macOS 26.0, *) {
            self.fontSizeSlider.tintProminence = .secondary
        }

        // FROM 2.3.0
        // Disable this advanced switch below 26.1
        if #available(macOS 26.1, *) {
            self.tintThumbnailsAdvancedLabel.isEnabled = true
            self.tintThumbnailsAdvancedSwitch.isEnabled = true
        } else {
            self.tintThumbnailsAdvancedLabel.isEnabled = false
            self.tintThumbnailsAdvancedSwitch.isEnabled = false
        }

        // Make the table the first responder
        self.window.makeFirstResponder(self)
    }


    // MARK: - User Action Functions
    
    /**
     When the font size slider is moved and released, this function updates the font size readout.

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction
    private func doMoveSlider(sender: Any) {

        // LOCAL: the slider value is the font size itself, in 0.5pt steps
        self.fontSizeLabel.stringValue = fontSizeText(sliderFontSize())
        updateSmallScaleLabel()

        // LOCAL: save the change
        autosaveSettings()
    }


    override func keyDown(with event: NSEvent) {

        // LOCAL: arrow keys move the font size by one 0.5pt step, on the Settings tab
        guard let item = self.mainTabView.selectedTabViewItem,
              self.mainTabView.indexOfTabViewItem(item) == 1 else { return }
        let step = BUFFOON_CONSTANTS.FONT_SIZE_STEP
        if event.keyCode == 126 || event.keyCode == 124 {
            self.fontSizeSlider.doubleValue = min(sliderFontSize() + step, self.fontSizeSlider.maxValue)
            doMoveSlider(sender: self)
        }

        if event.keyCode == 125 || event.keyCode == 123 {
            self.fontSizeSlider.doubleValue = max(sliderFontSize() - step, self.fontSizeSlider.minValue)
            doMoveSlider(sender: self)
        }
    }


    /**
     The font size selected by the slider, snapped to the nearest 0.5pt.

     LOCAL
     */
    private func sliderFontSize() -> Double {

        let step = BUFFOON_CONSTANTS.FONT_SIZE_STEP
        return (self.fontSizeSlider.doubleValue / step).rounded() * step
    }


    /**
     Format a font size for the readout, eg. `13pt` or `13.5pt`.

     LOCAL
     */
    private func fontSizeText(_ size: Double) -> String {

        return size == size.rounded() ? String(format: "%.0fpt", size) : String(format: "%.1fpt", size)
    }


    /**
     Called when the user selects a font from either list.

     FROM 1.1.0

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction
    private func doUpdateFonts(sender: Any) {

        // From 1.2.1
        // If the user re-selects the current font family,
        // only update the style popup if a different family
        // has been selected
        guard let item = sender as? NSPopUpButton else { return }
        if item == self.fontNamePopup {
            let currentFontPSName = self.currentSettings.fontName
            let selectedFontName = item.titleOfSelectedItem ?? BUFFOON_CONSTANTS.DEFAULTS.FONT_NAME
            if !currentFontPSName.contains(selectedFontName) {
                // Update the menu of available styles
                // because a different font has been selected
                setStylePopup(self.fontFacePopup.titleOfSelectedItem ?? "Regular")

                // LOCAL: save the change
                autosaveSettings()
                return
            }
        }

        // LOCAL: save the change
        autosaveSettings()
    }


    /**
     Handler for controls whose values are read.

     FROM 2.0.0

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction
    internal func doChangeValue(sender: Any) {

        // LOCAL: save the change
        autosaveSettings()
    }


    /**
     When a radio button is clicked, change the theme mode.

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction
    private func doSwitchMode(sender: Any) {

        // Set the radio buttons, labels etc.
        if self.lightRadioButton.state == .on {
            self.themeDisplayMode = BUFFOON_CONSTANTS.DISPLAY_MODE.LIGHT
        } else if self.darkRadioButton.state == .on {
            self.themeDisplayMode = BUFFOON_CONSTANTS.DISPLAY_MODE.DARK
        } else {
            self.themeDisplayMode = BUFFOON_CONSTANTS.DISPLAY_MODE.AUTO
        }

        // Update the UI
        setThemeControls()

        // LOCAL: save the change
        autosaveSettings()
    }


    /**
     Set the theme controls: radio buttons, labels, graphics, etc.

     FROM 2.0.0
     */
    private func setThemeControls() {

        switch self.themeDisplayMode {
            case BUFFOON_CONSTANTS.DISPLAY_MODE.LIGHT:
                self.lightRadioButton.state = .on
                self.lightThemeLabel.textColor = NSColor.labelColor
                self.darkThemeLabel.textColor = NSColor.gray
                self.lightThemeIcon.isOutlined = true
                self.darkThemeIcon.isOutlined = false
                // FROM 2.3.0
                self.lightThemeListButton.isEnabled = true
                self.darkThemeListButton.isEnabled = false
                self.themeHelpLabel.stringValue = "Always use the light theme selected below"
            case BUFFOON_CONSTANTS.DISPLAY_MODE.DARK:
                self.darkRadioButton.state = .on
                self.lightThemeLabel.textColor = NSColor.gray
                self.darkThemeLabel.textColor = NSColor.labelColor
                self.lightThemeIcon.isOutlined = false
                self.darkThemeIcon.isOutlined = true
                // FROM 2.3.0
                self.lightThemeListButton.isEnabled = false
                self.darkThemeListButton.isEnabled = true
                self.themeHelpLabel.stringValue = "Always use the dark theme selected below"
            default:
                self.autoRadioButton.state = .on
                self.lightThemeLabel.textColor = NSColor.labelColor
                self.darkThemeLabel.textColor = NSColor.labelColor
                self.darkThemeIcon.isOutlined = true
                self.lightThemeIcon.isOutlined = true
                // FROM 2.3.0
                self.lightThemeListButton.isEnabled = true
                self.darkThemeListButton.isEnabled = true
                self.themeHelpLabel.stringValue = "Use the themes selected below that match macOS’ current mode"
        }
    }


    /**
     The user has clicked on the `Apply` button.

     FROM 2.0.0

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction
    internal func doApplyCurrentSettings(sender: Any) {

        // First, make sure changes have been made
        if checkSettingsOnQuit() {
            // Changes are present, so save them.
            // NOTE This call updates the current settings values from the Settings tab UI.
            saveSettings()
            willShowSettingsPage()
        }
    }


    /**
     The user has clicked on the `Defaults` button.

     NOTE This does not save the settings, it only updates Settings tab UI state.

     FROM 2.0.0

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction
    internal func doApplyDefaultSettings(sender: Any) {

        // LOCAL: reset the Code tab only, keeping the other tabs' values, and save
        let defaults = PCSettings()
        defaults.mdFontSize = self.currentSettings.mdFontSize
        defaults.mdCodeFontSize = self.currentSettings.mdCodeFontSize
        defaults.smallPreviewScale = self.currentSettings.smallPreviewScale
        defaults.previewWindowWidth = self.currentSettings.previewWindowWidth
        defaults.previewWindowHeight = self.currentSettings.previewWindowHeight
        displaySettings(defaults)
        willShowSettingsPage()
        autosaveSettings()
    }


    // MARK: - Settings Maintenance Functions

    /**
     Update the UI with the supplied settings.

     FROM 2.0.0

     - Parameters:
        - settings: An instance holding the settings to show in the UI.
     */
    internal func displaySettings(_ settings: PCSettings) {

        // Set the font size slider
        // LOCAL: the slider holds the font size directly (10-28pt in 0.5pt steps)
        self.fontSizeSlider.doubleValue = Double(settings.fontSize)
        self.fontSizeLabel.stringValue = fontSizeText(sliderFontSize())

        // FROM 1.1.0
        // Set the font name popup
        // List the current system's monospace fonts
        self.fontNamePopup.removeAllItems()
        for font in self.fonts {
            self.fontNamePopup.addItem(withTitle: font.displayName)
        }

        // Set the style popup
        self.fontFacePopup.isEnabled = false
        selectFontByPostScriptName(settings.fontName)

        // Set the themes table's contents store, once per runtime
        loadThemeList()

        // Use the loaded theme names to find and set the human-reabable name in the UI
        for i in 0..<self.themes.count {
            let theme = self.themes[i]
            let codedName = codedName(i)

            if settings.lightThemeName == codedName {
                self.lightThemeLabel.stringValue = theme["name"] as? String ?? BUFFOON_CONSTANTS.DEFAULTS.LIGHT_THEME
            }

            if settings.darkThemeName == codedName {
                self.darkThemeLabel.stringValue = theme["name"] as? String ?? BUFFOON_CONSTANTS.DEFAULTS.DARK_THEME
            }
        }

        // Load the table with themes
        //loadTable(settings)

        // FROM 1.3.0
        // Set the mode control
        self.themeDisplayMode = settings.themeDisplayMode
        setThemeControls()

        // FROM 1.3.0
        // Set the line spacing selector
        switch(round(settings.lineSpacing * 100) / 100.0) {
            case 1.15:
                self.lineSpacingPopup.selectItem(at: 1)
            case 1.5:
                self.lineSpacingPopup.selectItem(at: 2)
            case 2.0:
                self.lineSpacingPopup.selectItem(at: 3)
            default:
                self.lineSpacingPopup.selectItem(at: 0)
        }

        // FROM 2.0.0
        self.showLineNumbersSwitch.state = settings.doShowLineNumbers ? .on : .off

        // LOCAL: preview window size in points
        self.previewWidthAdvancedText.stringValue = String(format: "%.0f", settings.previewWindowWidth)
        self.previewHeightAdvancedText.stringValue = String(format: "%.0f", settings.previewWindowHeight)
        self.previewMarginSizeText.stringValue = String(format:"%.1f", settings.previewMarginWidth)
        self.tintThumbnailsAdvancedSwitch.state = settings.thumbnailMatchFinderMode ? .on : .off

        // LOCAL: Markdown tab
        if self.mdFontSizeSlider != nil {
            self.mdFontSizeSlider.doubleValue = Double(settings.mdFontSize)
            self.mdCodeSizeSlider.doubleValue = Double(settings.mdCodeFontSize)
            updateMarkdownLabels()
        }

        // LOCAL: General tab
        if self.smallScaleSlider != nil {
            self.smallScaleSlider.doubleValue = Double(settings.smallPreviewScale) * 100
            updateSmallScaleLabel()
        }
    }


    /**
     Generate a set of settings derived from the state of the UI - except for the colour values,
     as these are stored directly in the current settings store. THIS WILL CHANGE

     FROM 2.0.0

     - Returns A settings instance.
     */
    internal func settingsFromDisplay() -> PCSettings {

        let displayedSettings = PCSettings()
        displayedSettings.fontSize = CGFloat(sliderFontSize())
        displayedSettings.fontName = getPostScriptName() ?? BUFFOON_CONSTANTS.DEFAULTS.FONT

        if self.lightRadioButton.state == .on {
            displayedSettings.themeDisplayMode = BUFFOON_CONSTANTS.DISPLAY_MODE.LIGHT
        } else if self.darkRadioButton.state == .on {
            displayedSettings.themeDisplayMode = BUFFOON_CONSTANTS.DISPLAY_MODE.DARK
        } else {
            displayedSettings.themeDisplayMode = BUFFOON_CONSTANTS.DISPLAY_MODE.AUTO
        }

        displayedSettings.darkThemeName = codedName(self.darkThemeIndex)
        displayedSettings.lightThemeName = codedName(self.lightThemeIndex)

        let linespacingValues: [CGFloat] = [1.0, 1.15, 1.5, 2.0]
        assert(self.lineSpacingPopup.indexOfSelectedItem < linespacingValues.count)
        displayedSettings.lineSpacing = linespacingValues[self.lineSpacingPopup.indexOfSelectedItem]

        // FROM 2.0.0
        displayedSettings.doShowLineNumbers = self.showLineNumbersSwitch.state == .on

        // FROM 2.3.0
        // Advanced Settings
        displayedSettings.thumbnailMatchFinderMode = self.tintThumbnailsAdvancedSwitch.state == .on
        // LOCAL: preview window size in points (validated by `advancedValuesGood()`)
        displayedSettings.previewWindowWidth = CGFloat(Double(self.previewWidthAdvancedText.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
                                                       ?? BUFFOON_CONSTANTS.PREVIEW_WINDOW.WIDTH)
        displayedSettings.previewWindowHeight = CGFloat(Double(self.previewHeightAdvancedText.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
                                                        ?? BUFFOON_CONSTANTS.PREVIEW_WINDOW.HEIGHT)

        displayedSettings.previewMarginWidth = Double(self.previewMarginSizeText.stringValue) ?? BUFFOON_CONSTANTS.PREVIEW_SIZE.MARGIN_WIDTH

        // LOCAL: Markdown tab
        if self.mdFontSizeSlider != nil {
            displayedSettings.mdFontSize = CGFloat(snappedSize(self.mdFontSizeSlider))
            displayedSettings.mdCodeFontSize = CGFloat(snappedSize(self.mdCodeSizeSlider))
        }

        if self.smallScaleSlider != nil {
            displayedSettings.smallPreviewScale = CGFloat(smallScalePercent()) / 100
        }

        return displayedSettings
    }


    /**
     Populate the current settings value with those read from disk.

     FROM 2.0.0
     */
    internal func loadSettings() {

        // Get the settings off the disk
        self.currentSettings.loadSettings(self.appSuiteName)
        self.themeDisplayMode = self.currentSettings.themeDisplayMode

        // Set subsidiary (unrecorded) values
        if let index = getFullListIndex(of: self.currentSettings.darkThemeName) {
            self.darkThemeIndex = index
        }

        if let index = getFullListIndex(of: self.currentSettings.lightThemeName) {
            self.lightThemeIndex = index
        }

        // Use the loaded settings to update the Settings UI
        displaySettings(self.currentSettings)
        self.settingsLoaded = true
    }


    /**
     Write Settings page state values to disk, but only those that have been changed.
     If this happens, also update the current settings store.
     */
    internal func saveSettings() {

        // Update the current settings store with values from the UI
        // NOTE We need to preserve the `displayColours` values, so copy them to
        //      the temporary store first.
        let displayedSettings = settingsFromDisplay()
        self.currentSettings = displayedSettings
        self.currentSettings.saveSettings(self.appSuiteName)
    }


    /**
     Compare the current Settings page values to those we have stored in `currentSettings`.
     If any are different, we need to warn the user.

     FROM 2.0.0

     - Returns:
        `true` if one or more settings has changed, otherwise `false`.
     */
    internal func checkSettingsOnQuit() -> Bool {

        let displayedSettings = settingsFromDisplay()
        var settingsHaveChanged = self.currentSettings.fontSize != displayedSettings.fontSize

        if !settingsHaveChanged {
            settingsHaveChanged = self.currentSettings.fontName != displayedSettings.fontName
        }

        if !settingsHaveChanged {
            settingsHaveChanged = !self.currentSettings.lineSpacing.isClose(to: displayedSettings.lineSpacing)
        }

        if !settingsHaveChanged {
            settingsHaveChanged = self.currentSettings.themeDisplayMode != displayedSettings.themeDisplayMode
        }

        if !settingsHaveChanged {
            settingsHaveChanged = self.currentSettings.darkThemeName != displayedSettings.darkThemeName
        }

        if !settingsHaveChanged {
            settingsHaveChanged = self.currentSettings.lightThemeName != displayedSettings.lightThemeName
        }

        // FROM 2.0.0
        if !settingsHaveChanged {
            settingsHaveChanged = self.currentSettings.doShowLineNumbers != displayedSettings.doShowLineNumbers
        }

        // FROM 2.3.0
        if !settingsHaveChanged {
            settingsHaveChanged = self.currentSettings.thumbnailMatchFinderMode != displayedSettings.thumbnailMatchFinderMode
        }

        // LOCAL
        if !settingsHaveChanged {
            settingsHaveChanged = self.currentSettings.previewWindowWidth != displayedSettings.previewWindowWidth ||
                                  self.currentSettings.previewWindowHeight != displayedSettings.previewWindowHeight
        }

        if !settingsHaveChanged {
            settingsHaveChanged = (self.currentSettings.previewMarginWidth != displayedSettings.previewMarginWidth) &&
                                   !(displayedSettings.previewMarginWidth.isClose(to: self.currentSettings.previewMarginWidth))
        }

        // LOCAL
        if !settingsHaveChanged {
            settingsHaveChanged = self.currentSettings.mdFontSize != displayedSettings.mdFontSize ||
                                  self.currentSettings.mdCodeFontSize != displayedSettings.mdCodeFontSize ||
                                  !self.currentSettings.smallPreviewScale.isClose(to: displayedSettings.smallPreviewScale)
        }

        return settingsHaveChanged
    }


    // MARK: - Advanced Settings

    @IBAction
    internal func doShowAdvancedSettings(sender: Any) {

        self.window.beginSheet(self.advancedSettingsSheet)
    }


    @IBAction
    internal func doCloseAdvancedSettings(sender: Any) {

        if advancedValuesGood() {
            self.window.endSheet(self.advancedSettingsSheet)
            willShowSettingsPage()
            // LOCAL: save the change
            autosaveSettings()
        }
    }


    /**
     Check that advanced settings textfield values are of the right type
     and within range, presenting a warning if they are not.

     FROM 2.0.3

     - Returns: `true` if the values are good, otherwise `false`.
     */
    internal func advancedValuesGood() -> Bool {

        // LOCAL: check the preview window size first
        if let sizeWarning = windowSizeWarning() {
            Task { @MainActor in
                let alert = makeAlert("Something’s not right!", sizeWarning)
                _ = await alert.beginSheetModal(for: self.advancedSettingsSheet)
            }

            return false
        }

        let warningMessage: String
        if let previewMargin = Float(self.previewMarginSizeText.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) {
            if previewMargin >= 0.0 && previewMargin <= 256.0 {
                return true
            }

            warningMessage = "The preview margin value is outside the range \(BUFFOON_CONSTANTS.PREVIEW_SIZE.MARGIN_WIDTH_MIN)-\(BUFFOON_CONSTANTS.PREVIEW_SIZE.MARGIN_WIDTH_MAX)"
        } else {
            warningMessage = "The preview margin value must be a number in the range \(BUFFOON_CONSTANTS.PREVIEW_SIZE.MARGIN_WIDTH_MIN)-\(BUFFOON_CONSTANTS.PREVIEW_SIZE.MARGIN_WIDTH_MAX)"
        }

        Task { @MainActor in
            let alert = makeAlert("Something’s not right!", warningMessage)
            _ = await alert.beginSheetModal(for: self.advancedSettingsSheet)
        }

        return false
    }


    /**
     Check the preview window width and height fields.

     LOCAL

     - Returns: A warning message if either value is not a number in range, otherwise `nil`.
     */
    private func windowSizeWarning() -> String? {

        let limits = BUFFOON_CONSTANTS.PREVIEW_WINDOW.self
        let fields: [(String, NSTextField, Double, Double)] = [
            ("width", self.previewWidthAdvancedText, limits.WIDTH_MIN, limits.WIDTH_MAX),
            ("height", self.previewHeightAdvancedText, limits.HEIGHT_MIN, limits.HEIGHT_MAX)
        ]

        for (name, field, minimum, maximum) in fields {
            let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let value = Double(text), value >= minimum, value <= maximum else {
                return "The preview window \(name) must be a number in the range \(Int(minimum))-\(Int(maximum)) points"
            }
        }

        return nil
    }


    // MARK: - Table Data Functions

    /**
     Generate a selection index for the displayed table.
     
     Bases the selection on whether the full data set is being displayed
     or only a subset.

     UPDATED 2.3.0

     - Parameters:
        - indexInFullThemeList: the selected row's reference to an entry in the main list of themes.
     
     - Returns: The row to select
     */
    private func getSelectionIndex(_ indexInFullThemeList: Int) -> IndexSet? {

        if self.themeDisplayMode == BUFFOON_CONSTANTS.DISPLAY_MODE.DARK {
            return getSubIndex(self.darkThemes, indexInFullThemeList)
        } else if self.themeDisplayMode == BUFFOON_CONSTANTS.DISPLAY_MODE.LIGHT {
            return getSubIndex(self.lightThemes, indexInFullThemeList)
        } else {
            if let button = self.buttonClicked {
                if button == self.darkThemeListButton {
                    return getSubIndex(self.darkThemes, indexInFullThemeList)
                } else {
                    return getSubIndex(self.lightThemes, indexInFullThemeList)
                }
            }

            // Should never be triggered
            return IndexSet(integer: indexInFullThemeList)
        }
    }


    /**
     Convert the index of on item in the primary list (eg. themes) into the index
     of the same item in a subset list (eg. dark themes).

     - Parameters:
        - list:  A subset list.
        - index: The index of the item in the primary list.

     - Returns: The index of the item in the subset list, or `nil` on error.

     */
    private func getSubIndex(_ list: [Int], _ index: Int) -> IndexSet? {

        for i in 0..<list.count {
            if list[i] == index {
                return IndexSet(integer: i)
            }
        }

        return nil
    }


    /**
     Generate a row index for the displayed table.
     
     Bases the selection on whether the full data set is being displayed
     or only a subset.
     
     - Parameters:
        - indexInFullThemeList: the selected row's reference to an entry in the main list of themes.
     
     - Returns: The row to select
     */
    private func getRowIndex(_ indexInFullThemeList: Int) -> Int {
        
        // Assume we're showing all themes as the default
        var returnIndex = indexInFullThemeList

        // But check if we're actually viewing a subset
        if self.themeDisplayMode == BUFFOON_CONSTANTS.DISPLAY_MODE.DARK {
            returnIndex = 0
            for i in 0..<self.darkThemes.count {
                if self.darkThemes[i] == indexInFullThemeList {
                    returnIndex = i
                    break
                }
            }
        } else if self.themeDisplayMode == BUFFOON_CONSTANTS.DISPLAY_MODE.LIGHT {
            returnIndex = 0
            for i in 0..<self.lightThemes.count {
                if self.lightThemes[i] == indexInFullThemeList {
                    returnIndex = i
                    break
                }
            }
        }
        
        return returnIndex
    }


    /**
     Calculate a primary list index from a subset list index.
     If the mode is AUTO, just return the passed value.

     UPDATED 2.3.0

     - Parameters:
        - subListIndex: The sub-list row index.
     
     - Returns: The full theme list index.
     */
    private func getBaseIndex(_ subListIndex: Int) -> Int {

        if self.themeDisplayMode == BUFFOON_CONSTANTS.DISPLAY_MODE.DARK {
            return self.darkThemes[subListIndex]
        } else if self.themeDisplayMode == BUFFOON_CONSTANTS.DISPLAY_MODE.LIGHT {
            return self.lightThemes[subListIndex]
        } else {
            if let button = self.buttonClicked {
                if button == self.darkThemeListButton {
                    return self.darkThemes[subListIndex]
                } else {
                    return self.lightThemes[subListIndex]
                }
            }

            return subListIndex
        }
    }


    /**
     Return the index of the specified theme name from the full list
     of themes.

     - Parameters:
        - themeName The name of the theme to find.

     - Returns The index of the theme in the main list.
     */
    private func getFullListIndex(of themeName: String) -> Int? {

        // Populate (if not already done) the full theme list
        loadThemeList()

        // Find the required theme in the list
        for i in 0..<self.themes.count {
            if themeName == codedName(i) {
                return i
            }
        }

        // ERROR: Theme not found
        return nil
    }


    /**
     Get the theme name for a given main list index.

     FROM 2.0.0

     - Parameters:
        - for The index in the main array.

     - Returns The theme name as a string.
     */
    private func themeName(for: Int) -> String {

        let theme = self.themes[`for`]
        return theme["name"] as! String
    }


    /**
     Get the 'coded' name of a theme, eg. 'agate-dark' -> 'dark.agate-dark'.

     - Parameters:
        - index: The theme's index in the array.

     - Returns: The coded name as a string.
     */

    private func codedName(_ index: Int) -> String {

        let theme = self.themes[index]
        let isDark = theme["dark"] as! Bool
        let cssName = theme["css"] as! String
        return (isDark ? "dark." : "light.") + cssName
    }


    // MARK: - Theme Loading Functions

    /**
     Read the list of themes from the file in the bundle into an array property.
     
     We also create two subset arrays, one for dark themes, the other for light ones.
     
     Should only be called once per run.
     */
    internal func loadThemeList() {

        // FROM 2.0.0
        // Ensure we're not already done; bail if we are
        guard self.themes.count == 0 else {
            return
        }

        // Load in the current theme list
        guard let themesString = loadBundleFile(BUFFOON_CONSTANTS.FILE_THEME_LIST) else {
            // NOTE Error already posted by 'loadBundleFile()'
            return
        }
        
        // FROM 1.1.0
        // Theme list is now a JSON file
        var themeMap: ThemeRecord? = nil
        if let data = themesString.data(using: .utf8) {
            themeMap = try? JSONSerialization.jsonObject(with: data,  options: []) as? [String: Any]
        }
        
        // Set the theme selection
        // Remember this called only one per run
        if let tm = themeMap {
            self.themes = tm["themes"] as! [ThemeRecord]
            for i in 0..<self.themes.count {
                // Record themes by type: these subset arrays
                // record indices from from the main array
                let theme = self.themes[i]
                let isDark = theme["dark"] as! Bool
                if isDark {
                    self.darkThemes.append(i)
                } else {
                    self.lightThemes.append(i)
                }

#if DEBUG
                print("\(i + 1) \(theme["name"] as! String) " + (isDark ? "[D]" : "[L]"))
#endif
            }
        } else {
            // ERROR - Could not load or process app's interior JSON file
        }
    }


    /**
     Load a known text file from the app bundle.
     
     - Parameters:
        - file: The name of the text file without its extension.
     
     - Returns: The contents of the loaded file
     */
    private func loadBundleFile(_ fileName: String, ofType type: String = "json") -> String? {

        // Load the required resource and return its contents
        guard let filePath = Bundle.main.path(forResource: fileName, ofType: type)
        else {
            // TODO Post error
            return nil
        }
        
        do {
            let fileContents = try String(contentsOf: URL(fileURLWithPath: filePath))
            return fileContents
        } catch {
            // TODO Post error
        }
        
        return nil
    }


    /**
     Render all the themes as 512 x 268 PNG files.

     Run this from the **Help** menu in debug sessions.

     DEBUG ONLY

     - Parameters:
        - sender: The object that triggered the action
     */
    @IBAction
    private func doRenderThemes(_ sender: Any) {

        // FROM 2.3.1 -- bump size to @2x
        let renderFrame = NSMakeRect(0, 0, 512, 268)
        let fm = FileManager.default
        let homeFolder = fm.homeDirectoryForCurrentUser.path
        guard let common = Common(forThumbnail: false) else { return }

        // Load in the code sample we'll preview the themes with
        guard let loadedCode = loadBundleFile(BUFFOON_CONSTANTS.FILE_CODE_SAMPLE, ofType: "txt") else { return }
        print("IMAGE FOLDER: \(homeFolder)")

#if RENDER_HS_THEMES // Set in Build Settings > Active Compilation Condition
        let hltr = Highlighter()
        let nativeThemes = hltr!.availableThemes()
        print("THEME COUNT: \(nativeThemes.count)")
        for theme in nativeThemes {
            hltr!.setTheme(theme)
            if let pas = hltr!.highlight(loadedCode, as: "swift") {
                let ptv = PCTextView(frame: renderFrame)
                ptv.isSelectable = false

                if let renderTextStorage = ptv.textStorage {
                    renderTextStorage.beginEditing()
                    renderTextStorage.setAttributedString(pas)
                    renderTextStorage.endEditing()
                    ptv.backgroundColor = hltr!.theme.themeBackgroundColour
                }

                if let imageRep = ptv.bitmapImageRepForCachingDisplay(in: renderFrame) {
                    ptv.cacheDisplay(in: renderFrame, to: imageRep)
                    let sizes = [NSMakeSize(256, 134), NSMakeSize(512, 268), NSMakeSize(768, 402)]
                    for (i, size) in sizes.enumerated() {
                        if let scaledImage = imageRep.resize(to: size) {
                            if let data = scaledImage.representation(using: .png, properties: [:]) {
                                do {
                                    var sizeFactor = ""
                                    if i > 0 {
                                        sizeFactor = "@\(i + 1)x"
                                    }
                                    let path = homeFolder + "/native-" + theme + sizeFactor + ".png"
                                    try data.write(to: URL(fileURLWithPath: path))
                                } catch {
                                    // NOP
                                }
                            }
                        }
                    }
                }
            }
        }

        return
#else
        loadThemeList()
        for i in 0..<self.themes.count {
            let name = codedName(i)
            common.updateTheme(name)
            let pas = common.getAttributedString(loadedCode, "swift")
            let ptv = NSTextView(frame: renderFrame)
            ptv.isSelectable = false

            if let renderTextStorage = ptv.textStorage {
                renderTextStorage.beginEditing()
                renderTextStorage.setAttributedString(pas)
                renderTextStorage.endEditing()
                ptv.backgroundColor = common.themeBackgroundColour
            }

            if let imageRep = ptv.bitmapImageRepForCachingDisplay(in: renderFrame) {
                ptv.cacheDisplay(in: renderFrame, to: imageRep)
                let sizes = [NSMakeSize(256, 134), NSMakeSize(512, 268), NSMakeSize(768, 402)]
                for (j, size) in sizes.enumerated() {
                    if let scaledImage = imageRep.resize(to: size) {
                        if let data = scaledImage.representation(using: .png, properties: [:]) {
                            do {
                                var sizeFactor = ""
                                if j > 0 {
                                    sizeFactor = "@\(j + 1)x"
                                }

                                let theme = self.themes[i]
                                let filename = theme["css"] as! String
                                let path = homeFolder + "/" + filename + sizeFactor + ".png"
                                try data.write(to: URL(fileURLWithPath: path))
                            } catch {
                                // NOP
                            }
                        }
                    }
                }
            }
        }
#endif
    }


    // MARK: - NSTableView Data Source / Delegate Functions
    
    func numberOfRows(in tableView: NSTableView) -> Int {

        // Just return the number of themes available, using the
        // three lists prepare of dark, light and all themes, and
        // the current preferred mode
        switch self.themeDisplayMode {
            case BUFFOON_CONSTANTS.DISPLAY_MODE.DARK:
                return self.darkThemes.count
            case BUFFOON_CONSTANTS.DISPLAY_MODE.LIGHT:
                return self.lightThemes.count
            default:
                // Both popovers are available so issue a row-count
                // according to the specific popover selected (determined
                // by which parent button was clicked)
                if tableView == self.nuThemeTable {
                    if let button = self.buttonClicked {
                        if button == self.darkThemeListButton {
                            return self.darkThemes.count
                        } else {
                            return self.lightThemes.count
                        }
                    }
                }

                return self.themes.count
        }
    }


    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

        // Assemble the table cell view
        let cellID = NSUserInterfaceItemIdentifier(rawValue: "previewcode-theme-cell")
        guard let cell = tableView.makeView(withIdentifier: cellID,
                                            owner: self) as? PCThemeTableCellView else { return nil }

        // Get the index in the the main theme list,
        // and thus the theme from that list
        let index = getBaseIndex(row)
        let theme = self.themes[index]
        let themeCSS = theme["css"] as! String

        // Populate cell
        cell.themePreviewTitle.stringValue = theme["name"] as! String
        cell.themeIndex = index

        // FROM 1.1.0
        // Use images rather then JIT-rendered NSTextViews (too slow)
        if let themePreview = NSImage(named: themeCSS) {
            let imv = NSImageView(image: themePreview)
            imv.frame = tableView == self.nuThemeTable ? NSMakeRect(8, 8, 256, 134) : NSMakeRect(0, 0, 128, 67)
            cell.addSubview(imv)
        }

        return cell
    }


    func tableViewSelectionDidChange(_ notification: Notification) {

        /* Get the clicked NSTableCellView and use it to get the table row
         * that we need to select.
         */

        // Make sure the table has a selection (it may not on first run)
        let tv = notification.object as! NSTableView
        guard tv.selectedRow != -1 else { return }

        // FROM 1.3.0
        // Make the changes according to the currently selected mode
        switch self.themeDisplayMode {
            case BUFFOON_CONSTANTS.DISPLAY_MODE.LIGHT:
                self.lightThemeIndex = getBaseIndex(tv.selectedRow)
                self.lightThemeLabel.stringValue = themeName(for: self.lightThemeIndex)
            case BUFFOON_CONSTANTS.DISPLAY_MODE.DARK:
                self.darkThemeIndex = getBaseIndex(tv.selectedRow)
                self.darkThemeLabel.stringValue = themeName(for: self.darkThemeIndex)
            default:
                if let button = self.buttonClicked {
                    if button == self.darkThemeListButton {
                        self.darkThemeIndex = getBaseIndex(tv.selectedRow)
                        self.darkThemeLabel.stringValue = themeName(for: self.darkThemeIndex)
                    } else {
                        self.lightThemeIndex = getBaseIndex(tv.selectedRow)
                        self.lightThemeLabel.stringValue = themeName(for: self.lightThemeIndex)
                    }
                }
        }

        // FROM 2.2.1
        // LOCAL: save the change
        autosaveSettings()
    }


    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {

        let rowMax: Int
        if tableView == self.nuThemeTable {
            switch self.themeDisplayMode {
                case BUFFOON_CONSTANTS.DISPLAY_MODE.DARK:
                    rowMax = self.darkThemes.count
                case BUFFOON_CONSTANTS.DISPLAY_MODE.LIGHT:
                    rowMax = self.lightThemes.count
                default:
                    if let button = self.buttonClicked {
                        if button == self.darkThemeListButton {
                            rowMax = self.darkThemes.count
                        } else {
                            rowMax = self.lightThemes.count
                        }
                    } else {
                        rowMax = self.themes.count
                    }
            }
        } else {
            rowMax = self.themes.count
        }

        return row >= 0 && row < rowMax
    }


    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {

        return tableView == self.nuThemeTable ? 150.0 : 68.0
    }


    // MARK: - NSTextFieldDelegate Functions

    /**
     Verify input values.

     FROM 2.3.0
    */
    func controlTextDidEndEditing(_ obj: Notification) {

        // LOCAL: the preview window size fields (General tab): restore the stored
        // values when the new ones are out of range, then save
        let field = obj.object as? NSTextField
        if field === self.previewWidthAdvancedText || field === self.previewHeightAdvancedText {
            if windowSizeWarning() != nil {
                NSSound.beep()
                self.previewWidthAdvancedText.stringValue = String(format: "%.0f", self.currentSettings.previewWindowWidth)
                self.previewHeightAdvancedText.stringValue = String(format: "%.0f", self.currentSettings.previewWindowHeight)
            }
            autosaveSettings()
            return
        }

        clampMarginField()
        autosaveSettings()
    }


    /**
     Keep the preview margin field's value within range.
     */
    private func clampMarginField() {

        if let doubleValue = Double(self.previewMarginSizeText.stringValue) {
            let min = Double(BUFFOON_CONSTANTS.PREVIEW_SIZE.MARGIN_WIDTH_MIN).rounded(.towardZero)
            let max = Double(BUFFOON_CONSTANTS.PREVIEW_SIZE.MARGIN_WIDTH_MAX).rounded(.towardZero)

            if doubleValue > min && doubleValue <= max {
                // Value within supported range, so write the formatted value back from where it will later be read
                self.previewMarginSizeText.stringValue = String(format:"%.1f", doubleValue)
                return
            }

            // Erroneous value: numeric but out of range
            // Set value to either end
            if doubleValue < min {
                self.previewMarginSizeText.stringValue = String(format:"%.1f", min)
            } else if doubleValue > max {
                self.previewMarginSizeText.stringValue = String(format:"%.1f", max)
            }
        } else {
            // Erroneous value: not numeric
            self.previewMarginSizeText.stringValue = String(format:"%.1f", self.currentSettings.previewMarginWidth)
        }

        // Warn the user
        NSSound.beep()
    }


    // MARK: - NSResponder Functions

    override func keyUp(with event: NSEvent) {
        
        /* Check for alpha key presses so the Preferences theme table
         * can jump to the theme with the closest initial. Go on to the next
         * character if the is no theme with that initial, ie. if the user
         * hits `q` and there is no theme beginning with `q`, try `r` and
         * so on.
         */
        
        if let chars = event.charactersIgnoringModifiers {
            // Get the tapped character -- should be only one
            var char = String(chars.first!)
            if char.isEmpty || char.range(of: "[a-z]", options: .regularExpression) == nil {
                return
            }
            
            // Find a the first theme with that character
            while true {
                for i in 0..<self.themes.count {
                    let theme = self.themes[i]
                    let cssName = theme["css"] as! String

                    if cssName.starts(with: char) {
                        // Matched key to theme name initial:
                        // Select the row, scroll to it and exit
                        self.nuThemeTable.scrollRowToVisible(getRowIndex(i))
                        //self.preferencesWindow.makeFirstResponder(self.themeTable)
                        return
                    }
                }
                
                // Reached the end without a selection?
                // Select the last item on the list and exit
                if char == "z" {
                    if let idx = getSelectionIndex(self.themes.count - 1) {
                        self.nuThemeTable.selectRowIndexes(idx, byExtendingSelection: false)
                        self.nuThemeTable.scrollRowToVisible(getRowIndex(self.themes.count - 1))
                        //self.preferencesWindow.makeFirstResponder(self.themeTable)
                        return
                    }
                }
                
                // Move to the next character in the alphabet and try it
                let scalars = char.unicodeScalars
                let val = scalars[scalars.startIndex].value
                char = String(Character(UnicodeScalar(val + 1) ?? "z"))
            }
        }
    }


    override func scrollWheel(with event: NSEvent) {
        
        // Relay scroll events to the NSScrollView
        
        //self.themeScrollView.scrollWheel(with: event)
    }


    // MARK: - Popover Functions

    /**
     Assemble the popover and its components if it hasn't been assembled yet.
     */
    private func makePopover() {

        if self.themePopover == nil {
            self.themePopover = NSPopover()

            // Define a scroll view with a table as its content§...
            let scrollListView = NSScrollView()
            scrollListView.hasVerticalScroller = true
            scrollListView.autohidesScrollers = true
            scrollListView.borderType = .noBorder
            scrollListView.documentView = self.nuThemeTable

            // ...and a view controller to manage it
            let pvc = NSViewController()
            pvc.view = scrollListView
            pvc.view.frame = NSMakeRect(0.0, 0.0, 500.0, 900.0)

            // Set up the popover
            self.themePopover!.contentViewController = pvc
            self.themePopover!.contentSize = CGSize(width: 500.0, height: 900.0)
            self.themePopover!.behavior = NSPopover.Behavior.transient
            self.themePopover!.delegate = self
        }
    }


    @IBAction
    private func doShowThemeList(_ sender: Any) {

        // Determine the button that was clicked...
        self.buttonClicked = nil
        if let theSender = sender as? NSButton {
            self.buttonClicked = theSender
        }

        // ...and make sure one was!
        guard self.buttonClicked != nil else { return }

        // Assemble the popover if needed
        makePopover()

        // Update the table - reload for appropriate button
        self.nuThemeTable.reloadData()

        // Select the current theme and show the popover
        if self.buttonClicked! == self.darkThemeListButton {
            showPopover(self.darkThemeIndex, self.darkThemeListButton)
        } else {
            showPopover(self.lightThemeIndex, self.lightThemeListButton)
        }
    }


    /**
     Present a theme-list popover.

     - Parameters:
        - index:  The index of a list item to select.
        - button: The triggering button, for popover positioning.
     */
    private func showPopover(_ index: Int, _ button: NSButton) {

        if let idx = getSelectionIndex(index) {
            // We can use '.min()' because 'idx' should contain only one value
            let row = idx.min() ?? 0
            self.nuThemeTable.selectRowIndexes(idx, byExtendingSelection: false)
            self.nuThemeTable.scrollRowToVisible(row)
        } else {
            // Scroll to the top
            self.nuThemeTable.scrollRowToVisible(0)
        }

        // Present the popover
        self.themePopover!.show(relativeTo: button.bounds,
                                of: button,
                                preferredEdge: NSRectEdge.maxY)

    }

}


// MARK: - Autosave and the Markdown Tab (LOCAL)

extension AppDelegate {

    /**
     Save the settings shown in the UI if they differ from the stored ones.
     Settings save as they change, so there is no Apply button. Nothing is
     saved before the stored settings have been loaded into the UI.
     */
    internal func autosaveSettings() {

        guard self.settingsLoaded else { return }
        if checkSettingsOnQuit() {
            saveSettings()
        }
    }


    /**
     Build the Markdown tab: text sizes for Markdown notes and Jupyter notebooks,
     in one group like the other tabs. It replaces the Feedback tab, whose
     controls are hidden but kept, because their outlets are still referenced.
     */
    internal func buildMarkdownPage() {

        guard self.mainTabView.numberOfTabViewItems > 2,
              let page = self.mainTabView.tabViewItem(at: 2).view else { return }
        // Hidden views still take part in layout: drop their constraints, so the
        // old fixed-width controls cannot widen the window
        page.removeConstraints(page.constraints)
        for view in page.subviews {
            view.isHidden = true
            view.translatesAutoresizingMaskIntoConstraints = true
        }

        func sizeSlider() -> NSSlider {
            let slider = NSSlider(value: BUFFOON_CONSTANTS.DEFAULTS.MD_FONT_SIZE,
                                  minValue: Double(BUFFOON_CONSTANTS.FONT_SIZE_MIN),
                                  maxValue: Double(BUFFOON_CONSTANTS.FONT_SIZE_MAX),
                                  target: self, action: #selector(doMoveMarkdownSlider(_:)))
            slider.isContinuous = true
            return slider
        }

        self.mdFontSizeSlider = sizeSlider()
        self.mdFontSizeLabel = NSTextField(labelWithString: "")
        self.mdCodeSizeSlider = sizeSlider()
        self.mdCodeSizeLabel = NSTextField(labelWithString: "")

        let header = makeLabel("Text", in: page, weight: .semibold)
        let fileTypes = makeLabel(".md notes and .ipynb notebooks", in: page, size: NSFont.smallSystemFontSize)
        fileTypes.textColor = .secondaryLabelColor
        let group = makeSettingsGroup(in: page, rows: [
            settingsRow("Text Size", sliderControls(self.mdFontSizeSlider, self.mdFontSizeLabel, width: 260)),
            settingsRow("Code Block Text Size", sliderControls(self.mdCodeSizeSlider, self.mdCodeSizeLabel, width: 260)),
        ])
        let note = NSTextField(wrappingLabelWithString: "The code block size also sets notebook code cells and outputs. "
                               + "Markdown notes and notebooks follow macOS light or dark mode; source code files use the Code tab.")
        note.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        note.textColor = .secondaryLabelColor
        note.preferredMaxLayoutWidth = 600
        note.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        note.translatesAutoresizingMaskIntoConstraints = false
        page.addSubview(note)

        let defaultsButton = NSButton(title: "Defaults", target: self, action: #selector(doApplyMarkdownDefaults(_:)))
        defaultsButton.toolTip = "Restore the default Markdown text sizes"
        defaultsButton.translatesAutoresizingMaskIntoConstraints = false
        page.addSubview(defaultsButton)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: page.topAnchor, constant: 6),
            header.leadingAnchor.constraint(equalTo: page.leadingAnchor, constant: 22),
            fileTypes.firstBaselineAnchor.constraint(equalTo: header.firstBaselineAnchor),
            fileTypes.trailingAnchor.constraint(equalTo: page.trailingAnchor, constant: -22),
            group.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 6),
            group.leadingAnchor.constraint(equalTo: page.leadingAnchor, constant: 20),
            group.trailingAnchor.constraint(equalTo: page.trailingAnchor, constant: -20),
            note.topAnchor.constraint(equalTo: group.bottomAnchor, constant: 8),
            note.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            note.trailingAnchor.constraint(equalTo: page.trailingAnchor, constant: -22),
            defaultsButton.leadingAnchor.constraint(equalTo: page.leadingAnchor, constant: 20),
            defaultsButton.bottomAnchor.constraint(equalTo: page.bottomAnchor, constant: -12),
        ])

        self.mdFontSizeSlider.doubleValue = BUFFOON_CONSTANTS.DEFAULTS.MD_FONT_SIZE
        self.mdCodeSizeSlider.doubleValue = BUFFOON_CONSTANTS.DEFAULTS.MD_CODE_FONT_SIZE
        updateMarkdownLabels()
    }


    /**
     A text size slider's value, snapped to the nearest 0.5pt.
     */
    internal func snappedSize(_ slider: NSSlider) -> Double {

        let step = BUFFOON_CONSTANTS.FONT_SIZE_STEP
        return (slider.doubleValue / step).rounded() * step
    }


    internal func updateMarkdownLabels() {

        self.mdFontSizeLabel.stringValue = fontSizeText(snappedSize(self.mdFontSizeSlider))
        self.mdCodeSizeLabel.stringValue = fontSizeText(snappedSize(self.mdCodeSizeSlider))
    }


    @objc
    private func doMoveMarkdownSlider(_ sender: NSSlider) {

        updateMarkdownLabels()
        updateSmallScaleLabel()
        autosaveSettings()
    }


    @objc
    private func doApplyMarkdownDefaults(_ sender: Any) {

        self.mdFontSizeSlider.doubleValue = BUFFOON_CONSTANTS.DEFAULTS.MD_FONT_SIZE
        self.mdCodeSizeSlider.doubleValue = BUFFOON_CONSTANTS.DEFAULTS.MD_CODE_FONT_SIZE
        updateMarkdownLabels()
        updateSmallScaleLabel()
        autosaveSettings()
    }
}


// MARK: - Tab Bar, General Tab and Code Tab Layout (LOCAL)

extension AppDelegate {

    /**
     Replace the round tab icons with a settings toolbar, as in Apple's own apps:
     General, Code and Markdown & Notebook, each an icon with a label. The window
     title names the selected tab.
     */
    internal func buildTabBar() {

        guard let content = self.window.contentView else { return }
        for button in [self.infoButton, self.settingsButton, self.feedbackButton] {
            button?.isHidden = true
        }

        // The tabs start right below the toolbar, where the header was
        NSLayoutConstraint.deactivate(content.constraints.filter {
            ($0.firstItem === self.mainTabView && $0.firstAttribute == .top) ||
            ($0.secondItem === self.mainTabView && $0.secondAttribute == .top)
        })
        self.mainTabView.topAnchor.constraint(equalTo: content.topAnchor, constant: 8).isActive = true

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


    /**
     The General tab (formerly About), laid out like System Settings: the app's
     description and version, then one group of settings rows (the Quick Look
     window size, the text size in small previews, the Quick Look extensions),
     each with its control on the right and a short note below, above the credits.
     */
    internal func buildGeneralPage() {

        guard let page = self.mainTabView.tabViewItem(at: 0).view,
              let width = self.previewWidthAdvancedText,
              let height = self.previewHeightAdvancedText else { return }

        // The settings rows and the version say what the old help text did
        self.infoLabel?.isHidden = true

        let group = NSBox()
        group.boxType = .custom
        group.titlePosition = .noTitle
        group.cornerRadius = 8
        group.borderWidth = 1
        group.borderColor = .separatorColor
        group.fillColor = NSColor.labelColor.withAlphaComponent(0.03)
        group.contentViewMargins = .zero
        group.translatesAutoresizingMaskIntoConstraints = false
        page.addSubview(group)
        guard let box = group.contentView else { return }

        // Window size: two fields
        moveField(width, to: box, width: 60)
        moveField(height, to: box, width: 60)
        width.delegate = self
        height.delegate = self
        let times = makeLabel("×", in: box)
        let points = makeLabel("points", in: box)
        let sizeRow = addGeneralRow(to: box, below: nil, title: "Quick Look Window Size",
                                    note: "Every preview uses it, from the next time Quick Look opens.",
                                    control: width)
        NSLayoutConstraint.activate([
            points.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -14),
            points.firstBaselineAnchor.constraint(equalTo: width.firstBaselineAnchor),
            height.trailingAnchor.constraint(equalTo: points.leadingAnchor, constant: -6),
            height.firstBaselineAnchor.constraint(equalTo: width.firstBaselineAnchor),
            times.trailingAnchor.constraint(equalTo: height.leadingAnchor, constant: -6),
            times.firstBaselineAnchor.constraint(equalTo: width.firstBaselineAnchor),
            width.trailingAnchor.constraint(equalTo: times.leadingAnchor, constant: -6),
        ])

        // Text size in small previews: a share of the normal sizes, for code and Markdown
        let slider = NSSlider(value: BUFFOON_CONSTANTS.DEFAULTS.SMALL_PREVIEW_SCALE * 100, minValue: 40, maxValue: 100,
                              target: self, action: #selector(doMoveSmallScaleSlider(_:)))
        slider.numberOfTickMarks = 13
        slider.allowsTickMarkValuesOnly = true
        slider.isContinuous = true
        if #available(macOS 26.0, *) {
            slider.tintProminence = .secondary
        }
        slider.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(slider)
        let smallA = makeLabel("A", in: box, size: NSFont.smallSystemFontSize)
        let largeA = makeLabel("A", in: box, size: 17)
        let percent = makeLabel("70%", in: box)
        percent.alignment = .right
        percent.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let smallRow = addGeneralRow(to: box, below: sizeRow.separatorAnchor, title: "Text Size in Small Previews",
                                     note: "", control: slider)
        NSLayoutConstraint.activate([
            percent.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -14),
            percent.widthAnchor.constraint(equalToConstant: 40),
            percent.centerYAnchor.constraint(equalTo: slider.centerYAnchor),
            largeA.trailingAnchor.constraint(equalTo: percent.leadingAnchor, constant: -10),
            largeA.centerYAnchor.constraint(equalTo: slider.centerYAnchor),
            slider.trailingAnchor.constraint(equalTo: largeA.leadingAnchor, constant: -8),
            slider.widthAnchor.constraint(equalToConstant: 160),
            smallA.trailingAnchor.constraint(equalTo: slider.leadingAnchor, constant: -8),
            smallA.centerYAnchor.constraint(equalTo: slider.centerYAnchor),
        ])

        // The Quick Look extensions
        let extensionsButton = NSButton(title: "Open System Settings…", target: self,
                                        action: NSSelectorFromString("doOpenSysPrefsWithSender:"))
        extensionsButton.toolTip = "System Settings > General > Login Items & Extensions > Quick Look"
        extensionsButton.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(extensionsButton)
        let extensionsRow = addGeneralRow(to: box, below: smallRow.separatorAnchor, title: "Quick Look Extensions",
                                          note: "If previews stop appearing, run the install command again.",
                                          control: extensionsButton)
        extensionsButton.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -14).isActive = true

        // Updates: the project page and a check for a newer release
        let updateButton = NSButton(title: "Check for Updates…", target: self, action: #selector(doCheckForUpdates(_:)))
        updateButton.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(updateButton)
        let githubButton = NSButton(title: "GitHub", target: self, action: #selector(doOpenGitHub(_:)))
        githubButton.toolTip = BUFFOON_CONSTANTS.MAIN_URL
        githubButton.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(githubButton)
        let updatesRow = addGeneralRow(to: box, below: extensionsRow.separatorAnchor, title: "Updates",
                                       note: "Check GitHub for a newer release; upgrading keeps your settings.",
                                       control: updateButton, separator: false)
        NSLayoutConstraint.activate([
            updateButton.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -14),
            githubButton.trailingAnchor.constraint(equalTo: updateButton.leadingAnchor, constant: -8),
            githubButton.centerYAnchor.constraint(equalTo: updateButton.centerYAnchor),
        ])
        self.updateNote = updatesRow.note
        self.updateButton = updateButton

        NSLayoutConstraint.activate([
            group.topAnchor.constraint(equalTo: self.versionLabel.bottomAnchor, constant: 16),
            group.leadingAnchor.constraint(equalTo: page.leadingAnchor, constant: 20),
            group.trailingAnchor.constraint(equalTo: page.trailingAnchor, constant: -20),
            box.bottomAnchor.constraint(equalTo: updatesRow.bottom),
        ])

        self.smallScaleSlider = slider
        self.smallScaleLabel = percent
        self.smallScaleNote = smallRow.note
        updateSmallScaleLabel()
    }


    /**
     Add a settings row to the General tab's group: a title and a short note on
     the left, `control` on the right (the caller sets its trailing edge), and a
     separator below unless it is the last row.

     - Returns: The note, and where the next row starts.
     */
    private func addGeneralRow(to box: NSView, below anchor: NSLayoutYAxisAnchor?, title: String, note: String,
                               control: NSView, separator: Bool = true)
                               -> (note: NSTextField, separatorAnchor: NSLayoutYAxisAnchor, bottom: NSLayoutYAxisAnchor) {

        let titleLabel = makeLabel(title, in: box)
        let noteLabel = makeLabel(note, in: box, size: NSFont.smallSystemFontSize)
        noteLabel.textColor = .secondaryLabelColor
        noteLabel.lineBreakMode = .byTruncatingTail
        noteLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let guide = NSLayoutGuide()
        box.addLayoutGuide(guide)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: anchor ?? box.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 14),
            noteLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            noteLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            noteLabel.trailingAnchor.constraint(lessThanOrEqualTo: box.trailingAnchor, constant: -14),
            guide.topAnchor.constraint(equalTo: titleLabel.topAnchor),
            guide.bottomAnchor.constraint(equalTo: noteLabel.bottomAnchor),
            control.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor, constant: 0),
        ])

        let bottom = noteLabel.bottomAnchor
        guard separator else {
            let end = NSLayoutGuide()
            box.addLayoutGuide(end)
            end.topAnchor.constraint(equalTo: noteLabel.bottomAnchor, constant: 10).isActive = true
            return (noteLabel, end.topAnchor, end.topAnchor)
        }

        let line = NSBox()
        line.boxType = .separator
        line.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(line)
        NSLayoutConstraint.activate([
            line.topAnchor.constraint(equalTo: bottom, constant: 10),
            line.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 14),
            line.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -14),
        ])
        return (noteLabel, line.bottomAnchor, line.bottomAnchor)
    }


    /**
     The small-preview slider's value in percent, snapped to 5% steps.
     */
    internal func smallScalePercent() -> Double {

        return (self.smallScaleSlider.doubleValue / 5).rounded() * 5
    }


    /**
     Show the share, and in the row's note what it makes of the current sizes.
     */
    internal func updateSmallScaleLabel() {

        guard let label = self.smallScaleLabel, self.smallScaleSlider != nil else { return }
        let share = smallScalePercent() / 100
        let code = sliderFontSize() * share
        let markdown = (self.mdFontSizeSlider != nil ? snappedSize(self.mdFontSizeSlider) : BUFFOON_CONSTANTS.DEFAULTS.MD_FONT_SIZE) * share
        func points(_ size: Double) -> String {
            let rounded = (size * 2).rounded() / 2
            return rounded == rounded.rounded() ? String(format: "%.0f pt", rounded) : String(format: "%.1f pt", rounded)
        }
        label.stringValue = "\(Int(smallScalePercent()))%"
        self.smallScaleNote?.stringValue = "Column and gallery views, Get Info: code \(points(code)), Markdown \(points(markdown))"
    }


    @objc
    private func doMoveSmallScaleSlider(_ sender: NSSlider) {

        updateSmallScaleLabel()
        autosaveSettings()
    }


    /**
     Lay out the Code tab in two groups, one above the other: Text (size, font,
     style, line spacing, line numbers, margin) and Theme (appearance, the dark
     and light themes, thumbnails), with Defaults below. The controls are the
     xib's, moved here, so their outlets and actions are unchanged; the xib's
     own labels and the Advanced button are hidden.
     */
    internal func rearrangeCodePage() {

        guard let page = self.mainTabView.tabViewItem(at: 1).view,
              let margin = self.previewMarginSizeText,
              let tintSwitch = self.tintThumbnailsAdvancedSwitch,
              let tintLabel = self.tintThumbnailsAdvancedLabel else { return }

        let moved: [NSView?] = [self.fontSizeSlider, self.fontSizeLabel, self.fontNamePopup, self.fontFacePopup,
                                self.lineSpacingPopup, self.showLineNumbersSwitch,
                                self.lightRadioButton, self.darkRadioButton, self.autoRadioButton, self.themeHelpLabel,
                                self.darkThemeIcon, self.darkThemeLabel, self.darkThemeListButton,
                                self.lightThemeIcon, self.lightThemeLabel, self.lightThemeListButton,
                                self.defaultsButton, self.settingsHelpButton, margin, tintSwitch, tintLabel]
        for case let view? in moved {
            view.removeFromSuperview()
            view.translatesAutoresizingMaskIntoConstraints = false
        }
        // Their fixed widths came from the old layout
        for case let view? in [self.fontSizeSlider, self.fontSizeLabel, self.fontNamePopup, self.fontFacePopup,
                               self.lineSpacingPopup, margin, self.darkThemeLabel, self.lightThemeLabel, self.themeHelpLabel] as [NSView?] {
            view.removeConstraints(view.constraints.filter { $0.firstAttribute == .width && $0.secondItem == nil })
        }
        self.themeHelpLabel.removeConstraints(self.themeHelpLabel.constraints.filter { $0.firstAttribute == .height && $0.secondItem == nil })
        for view in page.subviews {
            view.isHidden = true
        }

        // A compact slider: the readout and the snapping do the work of the tick marks
        self.fontSizeSlider.numberOfTickMarks = 0
        self.fontSizeSlider.allowsTickMarkValuesOnly = false
        for popup in [self.fontNamePopup, self.fontFacePopup, self.lineSpacingPopup] {
            popup?.widthAnchor.constraint(equalToConstant: 180).isActive = true
        }
        margin.widthAnchor.constraint(equalToConstant: 52).isActive = true
        for label in [self.darkThemeLabel, self.lightThemeLabel] {
            label?.widthAnchor.constraint(equalToConstant: 150).isActive = true
            label?.lineBreakMode = .byTruncatingTail
        }
        tintLabel.stringValue = "Thumbnails Follow Light or Dark Mode"
        tintLabel.font = .systemFont(ofSize: NSFont.systemFontSize)
        tintLabel.toolTip = "Needs macOS 26.1 or later"
        self.themeHelpLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        self.themeHelpLabel.textColor = .secondaryLabelColor
        self.themeHelpLabel.lineBreakMode = .byTruncatingTail
        self.themeHelpLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let pointsLabel = NSTextField(labelWithString: "points")

        let textHeader = makeLabel("Text", in: page, weight: .semibold)
        let fileTypes = makeLabel(".py .js .c .sh .swift and more than 50 languages", in: page, size: NSFont.smallSystemFontSize)
        fileTypes.textColor = .secondaryLabelColor
        let textGroup = makeSettingsGroup(in: page, rows: [
            settingsRow("Size", sliderControls(self.fontSizeSlider, self.fontSizeLabel, width: 200)),
            settingsRow("Font", [self.fontNamePopup]),
            settingsRow("Style", [self.fontFacePopup]),
            settingsRow("Line Spacing", [self.lineSpacingPopup]),
            settingsRow("Line Numbers", [self.showLineNumbersSwitch]),
            settingsRow("Margin", [margin, pointsLabel]),
        ])

        let themeHeader = makeLabel("Theme", in: page, weight: .semibold)
        let themeGroup = makeSettingsGroup(in: page, rows: [
            settingsRow("Appearance", [self.lightRadioButton, self.darkRadioButton, self.autoRadioButton],
                        note: self.themeHelpLabel),
            settingsRow("Dark", [self.darkThemeIcon, self.darkThemeLabel, self.darkThemeListButton]),
            settingsRow("Light", [self.lightThemeIcon, self.lightThemeLabel, self.lightThemeListButton]),
            settingsRow(tintLabel, [tintSwitch]),
        ])

        page.addSubview(self.defaultsButton)
        page.addSubview(self.settingsHelpButton)

        NSLayoutConstraint.activate([
            textHeader.topAnchor.constraint(equalTo: page.topAnchor, constant: 6),
            textHeader.leadingAnchor.constraint(equalTo: page.leadingAnchor, constant: 22),
            fileTypes.firstBaselineAnchor.constraint(equalTo: textHeader.firstBaselineAnchor),
            fileTypes.trailingAnchor.constraint(equalTo: page.trailingAnchor, constant: -22),
            textGroup.topAnchor.constraint(equalTo: textHeader.bottomAnchor, constant: 6),
            textGroup.leadingAnchor.constraint(equalTo: page.leadingAnchor, constant: 20),
            textGroup.trailingAnchor.constraint(equalTo: page.trailingAnchor, constant: -20),
            themeHeader.topAnchor.constraint(equalTo: textGroup.bottomAnchor, constant: 10),
            themeHeader.leadingAnchor.constraint(equalTo: textHeader.leadingAnchor),
            themeGroup.topAnchor.constraint(equalTo: themeHeader.bottomAnchor, constant: 6),
            themeGroup.leadingAnchor.constraint(equalTo: textGroup.leadingAnchor),
            themeGroup.trailingAnchor.constraint(equalTo: textGroup.trailingAnchor),
            self.defaultsButton.leadingAnchor.constraint(equalTo: page.leadingAnchor, constant: 20),
            self.defaultsButton.bottomAnchor.constraint(equalTo: page.bottomAnchor, constant: -12),
            self.settingsHelpButton.leadingAnchor.constraint(equalTo: self.defaultsButton.trailingAnchor, constant: 10),
            self.settingsHelpButton.centerYAnchor.constraint(equalTo: self.defaultsButton.centerYAnchor),
        ])
    }


    /**
     A settings row: a title on the left, controls on the right, and an optional
     note in small type below the title.
     */
    private func settingsRow(_ title: String, _ controls: [NSView?], note: NSTextField? = nil) -> NSView {

        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: NSFont.systemFontSize)
        return settingsRow(label, controls, note: note)
    }


    private func settingsRow(_ title: NSTextField, _ controls: [NSView?], note: NSTextField? = nil) -> NSView {

        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false
        title.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(title)

        let stack = NSStackView(views: controls.compactMap { $0 })
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(stack)

        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: title.trailingAnchor, constant: 12),
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 28),
            stack.topAnchor.constraint(greaterThanOrEqualTo: row.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: row.bottomAnchor, constant: -4),
        ])

        if let note {
            note.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(note)
            NSLayoutConstraint.activate([
                title.topAnchor.constraint(equalTo: row.topAnchor, constant: 5),
                stack.centerYAnchor.constraint(equalTo: title.centerYAnchor),
                note.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 2),
                note.leadingAnchor.constraint(equalTo: title.leadingAnchor),
                note.trailingAnchor.constraint(lessThanOrEqualTo: row.trailingAnchor, constant: -12),
                note.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -5),
            ])
        } else {
            NSLayoutConstraint.activate([
                title.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                stack.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            ])
        }
        return row
    }


    /**
     A size slider's controls for a settings row: small A, slider, large A, readout.
     */
    private func sliderControls(_ slider: NSSlider, _ readout: NSTextField, width: CGFloat) -> [NSView] {

        let smallA = NSTextField(labelWithString: "A")
        smallA.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        let largeA = NSTextField(labelWithString: "A")
        largeA.font = .systemFont(ofSize: 17)
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: width).isActive = true
        if #available(macOS 26.0, *) {
            slider.tintProminence = .secondary
        }
        readout.alignment = .right
        readout.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        readout.translatesAutoresizingMaskIntoConstraints = false
        readout.widthAnchor.constraint(equalToConstant: 44).isActive = true
        return [smallA, slider, largeA, readout]
    }


    /**
     A rounded group holding settings rows, with separators between them, added
     to `page`. The caller positions it.
     */
    private func makeSettingsGroup(in page: NSView, rows: [NSView]) -> NSBox {

        let group = NSBox()
        group.boxType = .custom
        group.titlePosition = .noTitle
        group.cornerRadius = 8
        group.borderWidth = 1
        group.borderColor = .separatorColor
        group.fillColor = NSColor.labelColor.withAlphaComponent(0.03)
        group.contentViewMargins = .zero
        group.translatesAutoresizingMaskIntoConstraints = false
        page.addSubview(group)
        guard let box = group.contentView else { return group }

        var previous: NSLayoutYAxisAnchor = box.topAnchor
        for (index, row) in rows.enumerated() {
            box.addSubview(row)
            NSLayoutConstraint.activate([
                row.topAnchor.constraint(equalTo: previous),
                row.leadingAnchor.constraint(equalTo: box.leadingAnchor),
                row.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            ])
            previous = row.bottomAnchor
            if index < rows.count - 1 {
                let line = NSBox()
                line.boxType = .separator
                line.translatesAutoresizingMaskIntoConstraints = false
                box.addSubview(line)
                NSLayoutConstraint.activate([
                    line.topAnchor.constraint(equalTo: previous),
                    line.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 12),
                    line.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -12),
                ])
                previous = line.bottomAnchor
            }
        }
        previous.constraint(equalTo: box.bottomAnchor).isActive = true
        return group
    }


    private func makeLabel(_ text: String, in page: NSView, size: CGFloat = NSFont.systemFontSize,
                           weight: NSFont.Weight = .regular) -> NSTextField {

        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: size, weight: weight)
        label.translatesAutoresizingMaskIntoConstraints = false
        page.addSubview(label)
        return label
    }


    /**
     Move a control from the old Advanced sheet to a tab, dropping its old
     layout. Its outlet keeps pointing at it.
     */
    private func moveField(_ view: NSView, to page: NSView, width: CGFloat?) {

        view.removeFromSuperview()
        view.removeConstraints(view.constraints.filter { $0.firstAttribute == .width && $0.secondItem == nil })
        view.translatesAutoresizingMaskIntoConstraints = false
        page.addSubview(view)
        if let width {
            view.widthAnchor.constraint(equalToConstant: width).isActive = true
        }
    }
}


// MARK: - Settings Toolbar (LOCAL)

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


// MARK: - Updates (LOCAL)

extension AppDelegate {

    @objc
    internal func doOpenGitHub(_ sender: Any) {

        if let url = URL(string: BUFFOON_CONSTANTS.MAIN_URL) {
            NSWorkspace.shared.open(url)
        }
    }


    /**
     Ask GitHub for the latest release and compare it with this version. A newer
     release is installed with the one-line installer, which the alert copies.
     */
    @objc
    internal func doCheckForUpdates(_ sender: Any) {

        guard let url = URL(string: BUFFOON_CONSTANTS.LATEST_RELEASE_API) else { return }
        let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        self.updateButton?.isEnabled = false
        self.updateNote?.stringValue = "Checking…"

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { data, response, error in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            var latest: String? = nil
            var page = BUFFOON_CONSTANTS.MAIN_URL + "/releases/latest"
            if status == 200, let data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let tag = json["tag_name"] as? String {
                latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
                page = json["html_url"] as? String ?? page
            }
            DispatchQueue.main.async {
                self.updateButton?.isEnabled = true
                self.showUpdateResult(current: current, latest: latest, page: page,
                                      problem: error?.localizedDescription ?? (status == 200 ? nil : "GitHub answered with status \(status)."))
            }
        }.resume()
    }


    private func showUpdateResult(current: String, latest: String?, page: String, problem: String?) {

        let alert = NSAlert()
        guard let latest else {
            self.updateNote?.stringValue = "The check for updates did not complete."
            alert.alertStyle = .warning
            alert.messageText = "Could Not Check for Updates"
            alert.informativeText = (problem ?? "The latest release could not be read.") + " Try again later, or see the releases on GitHub."
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Open GitHub")
            if alert.runModal() == .alertSecondButtonReturn, let url = URL(string: page) {
                NSWorkspace.shared.open(url)
            }
            return
        }

        guard isVersion(latest, newerThan: current) else {
            self.updateNote?.stringValue = "Version \(current) is the latest."
            alert.messageText = "You’re Up to Date"
            alert.informativeText = "Quicklook Anything \(current) is the latest version."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        self.updateNote?.stringValue = "Version \(latest) is available; you have \(current)."
        alert.messageText = "Quicklook Anything \(latest) Is Available"
        alert.informativeText = "You have \(current). Install Update runs the install command in Terminal, "
            + "then reopens the app. Your settings are kept."
        alert.addButton(withTitle: "Install Update")
        alert.addButton(withTitle: "What’s New")
        alert.addButton(withTitle: "Later")
        switch alert.runModal() {
            case .alertFirstButtonReturn:
                installUpdateInTerminal()
            case .alertSecondButtonReturn:
                if let url = URL(string: page) {
                    NSWorkspace.shared.open(url)
                }
            default:
                break
        }
    }


    /**
     Run the one-line installer in Terminal, which quits this app, upgrades it and
     opens it again. The app is sandboxed, so it cannot run the installer itself.
     If Terminal cannot be asked (eg. the user declined Automation), copy the
     command instead.
     */
    private func installUpdateInTerminal() {

        let bundleID = Bundle.main.bundleIdentifier ?? "io.github.kehengzhu.QuicklookAnything"
        let command = BUFFOON_CONSTANTS.INSTALL_COMMAND + " && open -b " + bundleID
        let quoted = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
            tell application "Terminal"
                activate
                do script "\(quoted)"
            end tell
            """
        var error: NSDictionary? = nil
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        guard let error else {
            self.updateNote?.stringValue = "Installing in Terminal…"
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(BUFFOON_CONSTANTS.INSTALL_COMMAND, forType: .string)
        self.updateNote?.stringValue = "Install command copied: paste it in Terminal."
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Could Not Open Terminal"
        alert.informativeText = "The install command is copied. Open Terminal, paste it and press Return. "
            + "To let the app open Terminal itself, allow it in System Settings > Privacy & Security > Automation."
            + "\n\n(\(error[NSAppleScript.errorMessage] as? String ?? "Unknown error"))"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }


    /**
     Compare dotted version numbers, eg. 1.10.0 is newer than 1.9.2.
     */
    private func isVersion(_ a: String, newerThan b: String) -> Bool {

        let x = a.split(separator: ".").map { Int($0) ?? 0 }
        let y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let p = i < x.count ? x[i] : 0, q = i < y.count ? y[i] : 0
            if p != q { return p > q }
        }
        return false
    }
}
