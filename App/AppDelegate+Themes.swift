/*
 *  AppDelegate+Themes.swift
 *  Quicklook Anything
 *
 *  Code themes: the list of themes, their previews, and the popover to pick one.
 *  Based on PreviewCode, Copyright © 2026 Tony Smith (MIT License).
 */

import AppKit


extension AppDelegate {

    // MARK: - Theme List

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
        guard let themesString = loadBundleFile(Constants.FILE_THEME_LIST) else {
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
    internal func codedName(_ index: Int) -> String {

        let theme = self.themes[index]
        let isDark = theme["dark"] as! Bool
        let cssName = theme["css"] as! String
        return (isDark ? "dark." : "light.") + cssName
    }


    /**
     Return the index of the specified theme name from the full list
     of themes.

     - Parameters:
        - themeName The name of the theme to find.

     - Returns The index of the theme in the main list.
     */
    internal func getFullListIndex(of themeName: String) -> Int? {

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
     Calculate a primary list index from a subset list index.
     If the mode is AUTO, just return the passed value.

     UPDATED 2.3.0

     - Parameters:
        - subListIndex: The sub-list row index.
     
     - Returns: The full theme list index.
     */
    private func getBaseIndex(_ subListIndex: Int) -> Int {

        if self.themeDisplayMode == Constants.DISPLAY_MODE.DARK {
            return self.darkThemes[subListIndex]
        } else if self.themeDisplayMode == Constants.DISPLAY_MODE.LIGHT {
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
        if self.themeDisplayMode == Constants.DISPLAY_MODE.DARK {
            returnIndex = 0
            for i in 0..<self.darkThemes.count {
                if self.darkThemes[i] == indexInFullThemeList {
                    returnIndex = i
                    break
                }
            }
        } else if self.themeDisplayMode == Constants.DISPLAY_MODE.LIGHT {
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
     Generate a selection index for the displayed table.
     
     Bases the selection on whether the full data set is being displayed
     or only a subset.

     UPDATED 2.3.0

     - Parameters:
        - indexInFullThemeList: the selected row's reference to an entry in the main list of themes.
     
     - Returns: The row to select
     */
    private func getSelectionIndex(_ indexInFullThemeList: Int) -> IndexSet? {

        if self.themeDisplayMode == Constants.DISPLAY_MODE.DARK {
            return getSubIndex(self.darkThemes, indexInFullThemeList)
        } else if self.themeDisplayMode == Constants.DISPLAY_MODE.LIGHT {
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


    // MARK: - Theme Previews

    /**
     A theme's preview: the sample code (code-sample.txt) highlighted in the
     theme, 256 x 134 points. Each theme is drawn once, when first shown.

     LOCAL: replaces the original app's prerendered images, which are not in
     this repository

     - Parameters:
        - index: The theme's index in `themes`.

     - Returns: The preview, or `nil` if it can't be drawn.
     */
    internal func themePreview(_ index: Int) -> NSImage? {

        if let image = self.themePreviews[index] {
            return image
        }

        guard index >= 0 && index < self.themes.count else { return nil }
        if self.themeRenderer == nil {
            self.themeRenderer = CodeRenderer(forThumbnail: false)
        }

        if self.themeSample == nil {
            self.themeSample = loadBundleFile(Constants.FILE_CODE_SAMPLE, ofType: "txt")
        }

        guard let renderer = self.themeRenderer, let sample = self.themeSample else { return nil }

        // Draw at twice the size, with the code's own font size, then show it at half
        renderer.updateTheme(codedName(index))
        let frame = NSMakeRect(0, 0, 512, 268)
        let textView = NSTextView(frame: frame)
        textView.textContainerInset = NSMakeSize(10, 10)
        textView.textStorage?.setAttributedString(renderer.getAttributedString(sample, "swift"))
        textView.backgroundColor = renderer.themeBackgroundColour
        guard let rep = textView.bitmapImageRepForCachingDisplay(in: frame) else { return nil }
        textView.cacheDisplay(in: frame, to: rep)

        let image = NSImage(size: NSMakeSize(256, 134))
        image.addRepresentation(rep)
        self.themePreviews[index] = image
        return image
    }


    /**
     Show the selected dark and light themes' previews next to their names.

     LOCAL
     */
    internal func updateThemeIcons() {

        guard !self.themes.isEmpty else { return }
        self.darkThemeIcon.imageScaling = .scaleAxesIndependently
        self.lightThemeIcon.imageScaling = .scaleAxesIndependently
        self.darkThemeIcon.image = themePreview(self.darkThemeIndex)
        self.lightThemeIcon.image = themePreview(self.lightThemeIndex)
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
        guard let common = CodeRenderer(forThumbnail: false) else { return }

        // Load in the code sample we'll preview the themes with
        guard let loadedCode = loadBundleFile(Constants.FILE_CODE_SAMPLE, ofType: "txt") else { return }
        print("IMAGE FOLDER: \(homeFolder)")

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
    }


    // MARK: - Popover

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


    // MARK: - NSTableView Data Source and Delegate

    func numberOfRows(in tableView: NSTableView) -> Int {

        // Just return the number of themes available, using the
        // three lists prepare of dark, light and all themes, and
        // the current preferred mode
        switch self.themeDisplayMode {
            case Constants.DISPLAY_MODE.DARK:
                return self.darkThemes.count
            case Constants.DISPLAY_MODE.LIGHT:
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
                                            owner: self) as? ThemeTableCellView else { return nil }

        // Get the index in the the main theme list,
        // and thus the theme from that list
        let index = getBaseIndex(row)
        let theme = self.themes[index]

        // Populate cell
        cell.themePreviewTitle.stringValue = theme["name"] as! String
        cell.themeIndex = index

        // LOCAL: the preview, drawn the first time the theme is shown. Cells are
        // reused, so the image view is added once per cell.
        let previewID = NSUserInterfaceItemIdentifier("theme-preview")
        let preview = cell.subviews.first { $0.identifier == previewID } as? NSImageView ?? {
            let view = NSImageView(frame: NSMakeRect(8, 8, 256, 134))
            view.identifier = previewID
            view.imageScaling = .scaleAxesIndependently
            view.wantsLayer = true
            view.layer?.cornerRadius = 6
            view.layer?.masksToBounds = true
            cell.addSubview(view)
            return view
        }()
        preview.image = themePreview(index)

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
            case Constants.DISPLAY_MODE.LIGHT:
                self.lightThemeIndex = getBaseIndex(tv.selectedRow)
                self.lightThemeLabel.stringValue = themeName(for: self.lightThemeIndex)
            case Constants.DISPLAY_MODE.DARK:
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

        updateThemeIcons()

        // FROM 2.2.1
        // LOCAL: save the change
        autosaveSettings()
    }


    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {

        let rowMax: Int
        if tableView == self.nuThemeTable {
            switch self.themeDisplayMode {
                case Constants.DISPLAY_MODE.DARK:
                    rowMax = self.darkThemes.count
                case Constants.DISPLAY_MODE.LIGHT:
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


    // MARK: - Keyboard

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
}
