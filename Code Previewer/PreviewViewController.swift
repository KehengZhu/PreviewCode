/*
 *  PreviewViewController.swift
 *  PreviewCode
 *
 *  Created by Tony Smith on 30/05/2021.
 *  Copyright © 2026 Tony Smith. All rights reserved.
 */

import AppKit
import Quartz
import os


// LOCAL: debug-level messages (not kept on disk unless debug logging is enabled)
private let previewLog = Logger(subsystem: "com.bps.PreviewCode.Code-Previewer", category: "preview")


class PreviewViewController: NSViewController,
                             QLPreviewingController {

    // MARK: - Class UI Properties

    @IBOutlet var renderTextView: NSTextView!
    @IBOutlet var renderTextScrollView: NSScrollView!


    // MARK: - Public Properties

    override var nibName: NSNib.Name? {
        return NSNib.Name("PreviewViewController")
    }


    // MARK: - Lifecycle Functions

    // LOCAL: start loading the shared highlighter while Quick Look sets up the view
    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {

        SharedHighlighter.shared.warmUp()
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }


    required init?(coder: NSCoder) {

        SharedHighlighter.shared.warmUp()
        super.init(coder: coder)
    }


    // MARK: - QLPreviewingController Required Functions

    // FROM 2.2.0
    // Update to use Swift Concurrency
    func preparePreviewOfFile(at url: URL) async throws {

        /*
         * This is the main entry point for macOS' preview system
         */

        let start = Double(clock_gettime_nsec_np(CLOCK_UPTIME_RAW)) / 1e6

        // Get the file contents as a string
        guard let data = try? Data(contentsOf: url, options: [.uncached]) else {
            throw makeError(BUFFOON_CONSTANTS.ERRORS.CODES.FILE_WONT_OPEN)
        }

        // LOCAL: most code is UTF-8, so only guess the encoding when it is not
        let utf8Code = String(bytes: data, encoding: .utf8)
        let encoding: String.Encoding = utf8Code != nil ? .utf8 : (data.stringEncoding ?? .utf8)
        guard let code = utf8Code ?? String(data: data, encoding: encoding) else {
            // FROM 1.2.2
            // We couldn't convert to data to a valid encoding
            throw makeError(BUFFOON_CONSTANTS.ERRORS.CODES.BAD_ENC_STRING, "unexpected encoding: \(encoding)")
        }

        /*
         * Instantiate the common code within the closure
         */
        guard let common = Common(forThumbnail: false, sharedHighlighter: true) else {
            throw makeError(BUFFOON_CONSTANTS.ERRORS.CODES.BAD_HIGHLIGHTER)
        }

        /*
         * Attributed string acquisition
         */

        // Set the language
        let language = common.getLanguage(url.path)
        var attributedCode: NSAttributedString
        var highlightRestLater = false
        if language == "psion" {
            // Special case for psion files, which may contain binary data
            if url.pathExtension.lowercased() == "opl" {
                attributedCode = common.getAttributedString(common.processPsionFile(data, encoding), "scala")
            } else {
                attributedCode = common.getAttributedString(code, "scala")
            }
        } else if let split = firstScreensEnd(code, common.settings) {
            // LOCAL: large file: highlight the first screens now and show the rest as
            // plain text; the whole file is highlighted in the background (see below)
            let partial = NSMutableAttributedString(attributedString: common.getAttributedString(String(code[..<split]), language))
            partial.append(NSAttributedString(string: String(code[split...]), attributes: common.plainTextAttributes()))
            attributedCode = partial
            highlightRestLater = true
        } else {
            // Highlight the code
            attributedCode = common.getAttributedString(code, language)
        }

        /*
         * Window and mode configuration
         */

        // FROM 2.2.0
        // Set the parent window's size
        setPreviewWindowSize(common.settings)

        // FROM 2.3.0
        // The force-light-mode-preview-in-dark-mode setting is now a general
        // preview-colours-should-be-opposite-the-mode setting.
        let renderPreviewLight = !common.isThemeDark

        // Update the view mode
        // LOCAL: light themes get a pure white background instead of the theme's
        // own tint (e.g. #fafafa for atom-one-light); dark themes keep theirs.
        self.renderTextView.backgroundColor = renderPreviewLight ? .white : common.themeBackgroundColour
        self.renderTextScrollView.scrollerKnobStyle = renderPreviewLight ? .dark : .light
        self.view.appearance = renderPreviewLight ? NSAppearance(named: .aqua) : NSAppearance(named: .darkAqua)

        // FROM 2.0.0
        // Add a small margin around the preview
        if common.settings.previewMarginWidth > 0.0 {
            self.renderTextView.textContainerInset = NSSize(width: common.settings.previewMarginWidth,
                                                            height: common.settings.previewMarginWidth)
        }

        /*
         * Attributed String Presentation
         */

        guard let renderTextStorage = self.renderTextView.textStorage else {
            throw makeError(BUFFOON_CONSTANTS.ERRORS.CODES.BAD_TS_STRING)
        }

        /*
         * NSTextStorage subclasses that return true from the fixesAttributesLazily
         * method should avoid directly calling fixAttributes(in:) or else bracket
         * such calls with beginEditing() and endEditing() messages.
         */
        renderTextStorage.beginEditing()
        renderTextStorage.setAttributedString(attributedCode)
        renderTextStorage.endEditing()

        // LOCAL: restyle a partially highlighted large file once the full highlight is ready
        if highlightRestLater {
            common.getAttributedStringInBackground(code, language) { [weak self] fullCode in
                DispatchQueue.main.async {
                    self?.applyHighlighting(fullCode, since: start)
                }
            }
        }

        previewLog.debug("""
            Previewed \(url.lastPathComponent, privacy: .public) (\(data.count) B, \(language, privacy: .public)): \
            \(Double(clock_gettime_nsec_np(CLOCK_UPTIME_RAW)) / 1e6 - start, format: .fixed(precision: 1)) ms\
            \(highlightRestLater ? ", first screens only" : "", privacy: .public)
            """)
    }


    // MARK: - Large File Functions

    /**
     Find where the first screens of a large file end.

     LOCAL. Files with at least `PROGRESSIVE.MIN_LINES` lines are highlighted in two
     steps: the first `PROGRESSIVE.FIRST_LINES` lines before the preview is shown,
     the whole file afterwards. Not used with line numbers, which are added to the
     text itself and so cannot be restyled in place.

     - Parameters:
        - code:     The source code.
        - settings: The preview settings.

     - Returns: The index just after the last line of the first part, or `nil` if the
                file should be highlighted in one go.
     */
    private func firstScreensEnd(_ code: String, _ settings: PCSettings) -> String.Index? {

        guard !settings.doShowLineNumbers else { return nil }

        let utf8 = code.utf8
        var lineCount = 0
        var split: String.Index? = nil
        for index in utf8.indices where utf8[index] == 0x0A {
            lineCount += 1
            if lineCount == BUFFOON_CONSTANTS.PROGRESSIVE.FIRST_LINES {
                split = utf8.index(after: index)
            }

            if lineCount >= BUFFOON_CONSTANTS.PROGRESSIVE.MIN_LINES {
                return split
            }
        }

        return nil
    }


    /**
     Apply the full highlight's styles to the partially highlighted text in place.

     LOCAL. The characters are the same, so only attributes change: the scroll
     position stays put. Skipped if the text differs (eg. highlighting failed).

     - Parameters:
        - fullCode: The whole file, highlighted.
        - start:    When the preview started (uptime, ms), for the log.
     */
    private func applyHighlighting(_ fullCode: NSAttributedString, since start: Double) {

        guard let renderTextStorage = self.renderTextView?.textStorage,
              renderTextStorage.length == fullCode.length,
              renderTextStorage.string == fullCode.string else {
            previewLog.debug("Full highlight skipped: text differs")
            return
        }

        renderTextStorage.beginEditing()
        fullCode.enumerateAttributes(in: NSRange(location: 0, length: fullCode.length)) { attributes, range, _ in
            renderTextStorage.setAttributes(attributes, range: range)
        }
        renderTextStorage.endEditing()
        previewLog.debug("""
            Full highlight applied to \(fullCode.length) characters, \
            \(Double(clock_gettime_nsec_np(CLOCK_UPTIME_RAW)) / 1e6 - start, format: .fixed(precision: 1)) ms after the preview started
            """)
    }


    // MARK: - Utility Functions

    /**
     Generate an NSError for an internal error, specified by its code.

     Codes are listed in `Constants.swift`

     - Parameters:
        - code:  The internal error code.
        - extra: Additional text for specific errors

     - Returns: The described error as an NSError.
     */
    func makeError(_ code: Int, _ extra: String = "") -> NSError {

        // NSError generation function

        var errDesc: String

        switch(code) {
            case BUFFOON_CONSTANTS.ERRORS.CODES.FILE_INACCESSIBLE:
                errDesc = BUFFOON_CONSTANTS.ERRORS.MESSAGES.FILE_INACCESSIBLE
            case BUFFOON_CONSTANTS.ERRORS.CODES.FILE_WONT_OPEN:
                errDesc = BUFFOON_CONSTANTS.ERRORS.MESSAGES.FILE_WONT_OPEN
            case BUFFOON_CONSTANTS.ERRORS.CODES.BAD_TS_STRING:
                errDesc = BUFFOON_CONSTANTS.ERRORS.MESSAGES.BAD_TS_STRING
            case BUFFOON_CONSTANTS.ERRORS.CODES.BAD_ENC_STRING:
                errDesc = BUFFOON_CONSTANTS.ERRORS.MESSAGES.BAD_ENC_STRING + " \(extra)"
            case BUFFOON_CONSTANTS.ERRORS.CODES.BAD_HIGHLIGHTER:
                errDesc = BUFFOON_CONSTANTS.ERRORS.MESSAGES.BAD_HIGHLIGHTER
            default:
                errDesc = "UNKNOWN ERROR"
        }

        return NSError(domain: BUFFOON_CONSTANTS.APP_CODE_PREVIEWER,
                       code: code,
                       userInfo: [NSLocalizedDescriptionKey: errDesc])
    }


    /**
     Specify the content size of the parent view.

     FROM 2.2.4
    */
    private func setPreviewWindowSize(_ settings: PCSettings) {

        // LOCAL: the width and height (in points) set in Advanced Settings; the
        // original code scaled the window to a fraction of the screen
        self.preferredContentSize = NSSize(width: settings.previewWindowWidth,
                                           height: settings.previewWindowHeight)
    }
}
