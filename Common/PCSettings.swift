/*
 *  PCSettings.swift
 *  PreviewCode
 *
 *  Created by Tony Smith on 08/10/2024.
 *  Copyright © 2026 Tony Smith. All rights reserved.
 */

import Foundation


/**
 Internal settings record structure.
 Values are pre-set to the app defaults.
 */

final class PCSettings {

    // MARK: Public Properties

    public var fontName: String                    = BUFFOON_CONSTANTS.DEFAULTS.FONT
    public var fontSize: CGFloat                   = CGFloat(BUFFOON_CONSTANTS.DEFAULTS.FONT_SIZE)
    public var lineSpacing: CGFloat                = BUFFOON_CONSTANTS.DEFAULTS.LINE_SPACING
    public var darkThemeName: String               = BUFFOON_CONSTANTS.DEFAULTS.DARK_THEME
    public var lightThemeName: String              = BUFFOON_CONSTANTS.DEFAULTS.LIGHT_THEME
    public var themeDisplayMode: Int               = BUFFOON_CONSTANTS.DISPLAY_MODE.AUTO
    public var doShowLineNumbers: Bool             = false
    // FROM 2.2.3
    public var doShowMargin: Bool                  = false                                                  // Advanced DEPRECATED
    public var previewMarginWidth: CGFloat         = BUFFOON_CONSTANTS.PREVIEW_SIZE.MARGIN_WIDTH    // Advanced
    // LOCAL: Quick Look window size in points, replacing `previewWindowScale`
    public var previewWindowWidth: CGFloat         = BUFFOON_CONSTANTS.PREVIEW_WINDOW.WIDTH                 // Advanced
    public var previewWindowHeight: CGFloat        = BUFFOON_CONSTANTS.PREVIEW_WINDOW.HEIGHT                // Advanced
    public var thumbnailMatchFinderMode: Bool      = false                                                  // Advanced
    // LOCAL: Markdown and notebook previews
    public var mdFontSize: CGFloat                 = CGFloat(BUFFOON_CONSTANTS.DEFAULTS.MD_FONT_SIZE)
    public var mdCodeFontSize: CGFloat             = CGFloat(BUFFOON_CONSTANTS.DEFAULTS.MD_CODE_FONT_SIZE)
    // LOCAL: text scale in small previews (Finder's column view pane), for code and Markdown
    public var smallPreviewScale: CGFloat          = CGFloat(BUFFOON_CONSTANTS.DEFAULTS.SMALL_PREVIEW_SCALE)


    // MARK: Retrieve and Persist Functions

    /**
     Populate the current settings value with those read from disk.

     - Parameters:
        - suite The App Suite name under which the defaults are recorded.
     */
    public func loadSettings(_ suite: String) {

        // The suite name is the app group name, set in each extension's entitlements, and the host app's
        if let defaults = UserDefaults(suiteName: suite) {
            // LOCAL: keep each default until its key has been written. The extensions
            // read settings without `registerSettings()`, so right after installation,
            // before the app has been opened, there are no keys at all.
            let ids = BUFFOON_CONSTANTS.PREFS_IDS.self
            func number(_ key: String) -> CGFloat? {
                (defaults.object(forKey: key) as? NSNumber).map { CGFloat($0.doubleValue) }
            }

            self.fontName = defaults.string(forKey: ids.PREVIEW_FONT_NAME) ?? self.fontName
            self.fontSize = number(ids.PREVIEW_FONT_SIZE) ?? self.fontSize
            self.lineSpacing = number(ids.PREVIEW_LINE_SPACING) ?? self.lineSpacing
            self.darkThemeName = defaults.string(forKey: ids.PREVIEW_DARK_NAME) ?? self.darkThemeName
            self.lightThemeName = defaults.string(forKey: ids.PREVIEW_LIGHT_NAME) ?? self.lightThemeName
            self.themeDisplayMode = (defaults.object(forKey: ids.PREVIEW_THEME_MODE) as? Int) ?? self.themeDisplayMode
            self.doShowLineNumbers = defaults.bool(forKey: ids.PREVIEW_SHOW_LINE_NUMBERS)
            // FROM 2.2.3
            self.doShowMargin = defaults.bool(forKey: ids.PREVIEW_SHOW_MARGIN)
            self.previewMarginWidth = number(ids.PREVIEW_MARGIN) ?? self.previewMarginWidth
            self.thumbnailMatchFinderMode = defaults.bool(forKey: ids.THUMB_MATCH_MODE)
            self.mdFontSize = number(ids.MD_FONT_SIZE) ?? self.mdFontSize
            self.mdCodeFontSize = number(ids.MD_CODE_FONT_SIZE) ?? self.mdCodeFontSize
            self.smallPreviewScale = number(ids.SMALL_PREVIEW_SCALE) ?? self.smallPreviewScale

            // LOCAL: keep the defaults when the keys have not been written yet
            // (the extensions read settings without calling `registerSettings()`)
            if let width = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_WINDOW_WIDTH) as? Double {
                self.previewWindowWidth = CGFloat(width)
            }

            if let height = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_WINDOW_HEIGHT) as? Double {
                self.previewWindowHeight = CGFloat(height)
            }

            // FROM 2.3.1
            // Apply corrections for theme name changes
            if self.lightThemeName == "light.vs" {
                self.lightThemeName = "light.vs-light"
                defaults.setValue(self.lightThemeName, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LIGHT_NAME)
            }
        }
    }


    /**
     Write Settings page state values to disk, but only those that have been changed.
     If this happens, also update the current settings store

     - Parameters:
        - suite The App Suite name under which the defaults are recorded.
     */
    public func saveSettings(_ suite: String) {

        if let defaults = UserDefaults(suiteName: suite) {
            defaults.setValue(self.fontName, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_FONT_NAME)
            defaults.setValue(self.fontSize, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_FONT_SIZE)
            defaults.setValue(self.lineSpacing, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LINE_SPACING)
            defaults.setValue(self.darkThemeName, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_DARK_NAME)
            defaults.setValue(self.lightThemeName, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LIGHT_NAME)
            defaults.setValue(self.themeDisplayMode, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_THEME_MODE)
            defaults.setValue(self.doShowLineNumbers, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SHOW_LINE_NUMBERS)
            // FROM 2.2.3
            defaults.setValue(self.doShowMargin, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SHOW_MARGIN)
            defaults.setValue(self.previewMarginWidth, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_MARGIN)
            defaults.setValue(self.thumbnailMatchFinderMode, forKey: BUFFOON_CONSTANTS.PREFS_IDS.THUMB_MATCH_MODE)
            // LOCAL
            defaults.setValue(self.previewWindowWidth, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_WINDOW_WIDTH)
            defaults.setValue(self.previewWindowHeight, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_WINDOW_HEIGHT)
            defaults.setValue(self.mdFontSize, forKey: BUFFOON_CONSTANTS.PREFS_IDS.MD_FONT_SIZE)
            defaults.setValue(self.mdCodeFontSize, forKey: BUFFOON_CONSTANTS.PREFS_IDS.MD_CODE_FONT_SIZE)
            defaults.setValue(self.smallPreviewScale, forKey: BUFFOON_CONSTANTS.PREFS_IDS.SMALL_PREVIEW_SCALE)
        }
    }


    /**
     Called by the app at launch to register its initial defaults.

     MOVED HERE 2.2.3

     - Parameters:
        - suite: The app suite name.
     */
    public func registerSettings(_ suite: String) {

        if let defaults = UserDefaults(suiteName: suite) {
            // Check if each preference value exists -- set if it doesn't
            // Preview body font size, stored as a CGFloat
            // Default: 13.0
            let codeFontSizeDefault: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_FONT_SIZE)
            if codeFontSizeDefault == nil {
                defaults.setValue(CGFloat(BUFFOON_CONSTANTS.DEFAULTS.FONT_SIZE),
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_FONT_SIZE)
            }
            
            // Font for previews and thumbnails
            // Default: Menlo
            let codeFontName: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_FONT_NAME)
            if codeFontName == nil {
                defaults.setValue(BUFFOON_CONSTANTS.DEFAULTS.FONT,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_FONT_NAME)
            }
            
            // FROM 1.3.0
            // Line spacing
            // Default: 1.0
            let lineSpacing: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LINE_SPACING)
            if lineSpacing == nil {
                defaults.setValue(BUFFOON_CONSTANTS.DEFAULTS.LINE_SPACING,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LINE_SPACING)
            }
            
            // FROM 1.3.0
            // Establish new defaults to store light and dark theme names.
            // But check for an existing one so the user's choice is at least
            // partially maintained, ie. if they selected a dark theme before, that
            // will become the chosen dark them now
            let newDarkThemeName: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_DARK_NAME)
            if newDarkThemeName == nil {
                defaults.setValue(BUFFOON_CONSTANTS.DEFAULTS.DARK_THEME,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_DARK_NAME)
            }
            
            let newLightThemeName: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LIGHT_NAME)
            if newLightThemeName == nil {
                defaults.setValue(BUFFOON_CONSTANTS.DEFAULTS.LIGHT_THEME,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LIGHT_NAME)
            }
            
            let defaultDisplayMode: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_THEME_MODE)
            if defaultDisplayMode == nil {
                defaults.setValue(BUFFOON_CONSTANTS.DISPLAY_MODE.AUTO,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_THEME_MODE)
            }
            
            // FROM 2.0.0
            // Do we show line numbers on previews?
            // Default: No
            let showLineNumbers: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SHOW_LINE_NUMBERS)
            if showLineNumbers == nil {
                defaults.setValue(false,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SHOW_LINE_NUMBERS)
            }
            
            // FROM 2.2.3
            // Thumbnail should match macOS mode
            if defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.THUMB_MATCH_MODE) == nil {
                defaults.setValue(false, forKey: BUFFOON_CONSTANTS.PREFS_IDS.THUMB_MATCH_MODE)
            }
            
            // LOCAL: Preview window size in points
            if defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_WINDOW_WIDTH) == nil {
                defaults.setValue(BUFFOON_CONSTANTS.PREVIEW_WINDOW.WIDTH, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_WINDOW_WIDTH)
            }

            if defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_WINDOW_HEIGHT) == nil {
                defaults.setValue(BUFFOON_CONSTANTS.PREVIEW_WINDOW.HEIGHT, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_WINDOW_HEIGHT)
            }

            // Preview inset margin width
            if defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SHOW_MARGIN) == nil {
                defaults.setValue(false, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SHOW_MARGIN)
            }

            // Preview inset margin width
            if defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_MARGIN) == nil {
                defaults.setValue(BUFFOON_CONSTANTS.PREVIEW_SIZE.MARGIN_WIDTH, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_MARGIN)
            }
        }
    }
}
