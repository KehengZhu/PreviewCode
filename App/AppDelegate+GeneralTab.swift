/*
 *  AppDelegate+GeneralTab.swift
 *  Quicklook Anything
 *
 *  The General tab: the Quick Look window size, small previews, the extensions, updates.
 */

import AppKit


extension AppDelegate {

    // MARK: - Layout

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

        let group = makeGroupBox(in: page)
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
        let slider = NSSlider(value: Constants.DEFAULTS.SMALL_PREVIEW_SCALE * 100, minValue: 40, maxValue: 100,
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
        githubButton.toolTip = Constants.MAIN_URL
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


    // MARK: - Text Size in Small Previews

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
        let markdown = (self.mdFontSizeSlider != nil ? snappedSize(self.mdFontSizeSlider) : Constants.DEFAULTS.MD_FONT_SIZE) * share
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
}
