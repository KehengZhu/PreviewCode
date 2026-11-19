/*
 *  AppDelegate+Settings.swift
 *  Quicklook Anything
 *
 *  Settings: show them in the window, read them back, save them as they change.
 *  Based on PreviewCode, Copyright © 2026 Tony Smith (MIT License).
 */

import AppKit


extension AppDelegate {

    // MARK: - Show and Save Settings

    /**
     Update the UI with the supplied settings.

     FROM 2.0.0

     - Parameters:
        - settings: An instance holding the settings to show in the UI.
     */
    internal func displaySettings(_ settings: AppSettings) {

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
                self.lightThemeLabel.stringValue = theme["name"] as? String ?? Constants.DEFAULTS.LIGHT_THEME
            }

            if settings.darkThemeName == codedName {
                self.darkThemeLabel.stringValue = theme["name"] as? String ?? Constants.DEFAULTS.DARK_THEME
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
    internal func settingsFromDisplay() -> AppSettings {

        let displayedSettings = AppSettings()
        displayedSettings.fontSize = CGFloat(sliderFontSize())
        displayedSettings.fontName = getPostScriptName() ?? Constants.DEFAULTS.FONT

        if self.lightRadioButton.state == .on {
            displayedSettings.themeDisplayMode = Constants.DISPLAY_MODE.LIGHT
        } else if self.darkRadioButton.state == .on {
            displayedSettings.themeDisplayMode = Constants.DISPLAY_MODE.DARK
        } else {
            displayedSettings.themeDisplayMode = Constants.DISPLAY_MODE.AUTO
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
        // LOCAL: preview window size in points (checked by `windowSizeWarning()`)
        displayedSettings.previewWindowWidth = CGFloat(Double(self.previewWidthAdvancedText.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
                                                       ?? Constants.PREVIEW_WINDOW.WIDTH)
        displayedSettings.previewWindowHeight = CGFloat(Double(self.previewHeightAdvancedText.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
                                                        ?? Constants.PREVIEW_WINDOW.HEIGHT)

        displayedSettings.previewMarginWidth = Double(self.previewMarginSizeText.stringValue) ?? Constants.PREVIEW_SIZE.MARGIN_WIDTH

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


    // MARK: - Text Sizes

    /**
     Format a font size for the readout, eg. `13pt` or `13.5pt`.

     LOCAL
     */
    internal func fontSizeText(_ size: Double) -> String {

        return size == size.rounded() ? String(format: "%.0fpt", size) : String(format: "%.1fpt", size)
    }


    /**
     A text size slider's value, snapped to the nearest 0.5pt.
     */
    internal func snappedSize(_ slider: NSSlider) -> Double {

        let step = Constants.FONT_SIZE_STEP
        return (slider.doubleValue / step).rounded() * step
    }


    // MARK: - Text Fields

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
     Check the preview window width and height fields.

     LOCAL

     - Returns: A warning message if either value is not a number in range, otherwise `nil`.
     */
    private func windowSizeWarning() -> String? {

        let limits = Constants.PREVIEW_WINDOW.self
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


    /**
     Keep the preview margin field's value within range.
     */
    private func clampMarginField() {

        if let doubleValue = Double(self.previewMarginSizeText.stringValue) {
            let min = Double(Constants.PREVIEW_SIZE.MARGIN_WIDTH_MIN).rounded(.towardZero)
            let max = Double(Constants.PREVIEW_SIZE.MARGIN_WIDTH_MAX).rounded(.towardZero)

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
}
