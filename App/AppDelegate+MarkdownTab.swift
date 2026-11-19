/*
 *  AppDelegate+MarkdownTab.swift
 *  Quicklook Anything
 *
 *  The Markdown & Notebook tab: text sizes for Markdown notes and Jupyter notebooks.
 */

import AppKit


extension AppDelegate {

    // MARK: - Layout

    /**
     Build the Markdown tab, whose page is empty in MainMenu.xib: text sizes for
     Markdown notes and Jupyter notebooks, in one group like the other tabs.
     */
    internal func buildMarkdownPage() {

        guard self.mainTabView.numberOfTabViewItems > 2,
              let page = self.mainTabView.tabViewItem(at: 2).view else { return }

        func sizeSlider() -> NSSlider {
            let slider = NSSlider(value: Constants.DEFAULTS.MD_FONT_SIZE,
                                  minValue: Double(Constants.FONT_SIZE_MIN),
                                  maxValue: Double(Constants.FONT_SIZE_MAX),
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

        self.mdFontSizeSlider.doubleValue = Constants.DEFAULTS.MD_FONT_SIZE
        self.mdCodeSizeSlider.doubleValue = Constants.DEFAULTS.MD_CODE_FONT_SIZE
        updateMarkdownLabels()
    }


    // MARK: - Text Sizes

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

        self.mdFontSizeSlider.doubleValue = Constants.DEFAULTS.MD_FONT_SIZE
        self.mdCodeSizeSlider.doubleValue = Constants.DEFAULTS.MD_CODE_FONT_SIZE
        updateMarkdownLabels()
        updateSmallScaleLabel()
        autosaveSettings()
    }
}
