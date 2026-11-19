/*
 *  AppDelegate+CodeTab.swift
 *  Quicklook Anything
 *
 *  The Code tab: text size, font, line spacing, line numbers, margin and theme mode.
 *  Based on PreviewCode, Copyright © 2026 Tony Smith (MIT License).
 */

import AppKit


extension AppDelegate {

    // MARK: - Layout

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


    // MARK: - Text

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
        let step = Constants.FONT_SIZE_STEP
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
    internal func sliderFontSize() -> Double {

        let step = Constants.FONT_SIZE_STEP
        return (self.fontSizeSlider.doubleValue / step).rounded() * step
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
            let selectedFontName = item.titleOfSelectedItem ?? Constants.DEFAULTS.FONT_NAME
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


    // MARK: - Theme Mode

    /**
     When a radio button is clicked, change the theme mode.

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction
    private func doSwitchMode(sender: Any) {

        // Set the radio buttons, labels etc.
        if self.lightRadioButton.state == .on {
            self.themeDisplayMode = Constants.DISPLAY_MODE.LIGHT
        } else if self.darkRadioButton.state == .on {
            self.themeDisplayMode = Constants.DISPLAY_MODE.DARK
        } else {
            self.themeDisplayMode = Constants.DISPLAY_MODE.AUTO
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
    internal func setThemeControls() {

        updateThemeIcons()
        switch self.themeDisplayMode {
            case Constants.DISPLAY_MODE.LIGHT:
                self.lightRadioButton.state = .on
                self.lightThemeLabel.textColor = NSColor.labelColor
                self.darkThemeLabel.textColor = NSColor.gray
                self.lightThemeIcon.isOutlined = true
                self.darkThemeIcon.isOutlined = false
                // FROM 2.3.0
                self.lightThemeListButton.isEnabled = true
                self.darkThemeListButton.isEnabled = false
                self.themeHelpLabel.stringValue = "Always use the light theme selected below"
            case Constants.DISPLAY_MODE.DARK:
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


    // MARK: - Defaults

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
        let defaults = AppSettings()
        defaults.mdFontSize = self.currentSettings.mdFontSize
        defaults.mdCodeFontSize = self.currentSettings.mdCodeFontSize
        defaults.smallPreviewScale = self.currentSettings.smallPreviewScale
        defaults.previewWindowWidth = self.currentSettings.previewWindowWidth
        defaults.previewWindowHeight = self.currentSettings.previewWindowHeight
        displaySettings(defaults)
        willShowSettingsPage()
        autosaveSettings()
    }
}
