/*
 *  SettingsLayout.swift
 *  Quicklook Anything
 *
 *  Building blocks for the settings tabs: groups of rows, labels, sliders.
 */

import AppKit


extension AppDelegate {

    // MARK: - Groups and Rows

    /**
     An empty rounded group box, as in System Settings, added to `page`. The
     caller positions it and fills its content view.
     */
    func makeGroupBox(in page: NSView) -> NSBox {

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
        return group
    }


    /**
     A rounded group holding settings rows, with separators between them, added
     to `page`. The caller positions it.
     */
    func makeSettingsGroup(in page: NSView, rows: [NSView]) -> NSBox {

        let group = makeGroupBox(in: page)
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


    /**
     A settings row: a title on the left, controls on the right, and an optional
     note in small type below the title.
     */
    func settingsRow(_ title: String, _ controls: [NSView?], note: NSTextField? = nil) -> NSView {

        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: NSFont.systemFontSize)
        return settingsRow(label, controls, note: note)
    }


    func settingsRow(_ title: NSTextField, _ controls: [NSView?], note: NSTextField? = nil) -> NSView {

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
    func sliderControls(_ slider: NSSlider, _ readout: NSTextField, width: CGFloat) -> [NSView] {

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


    // MARK: - Labels and Fields

    func makeLabel(_ text: String, in page: NSView, size: CGFloat = NSFont.systemFontSize,
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
    func moveField(_ view: NSView, to page: NSView, width: CGFloat?) {

        view.removeFromSuperview()
        view.removeConstraints(view.constraints.filter { $0.firstAttribute == .width && $0.secondItem == nil })
        view.translatesAutoresizingMaskIntoConstraints = false
        page.addSubview(view)
        if let width {
            view.widthAnchor.constraint(equalToConstant: width).isActive = true
        }
    }
}
