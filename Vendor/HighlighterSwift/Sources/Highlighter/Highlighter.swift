/*
 *  Highlighter.swift
 *  Copyright 2026, Tony Smith
 *  Copyright 2016, Juan-Pablo Illanes
 *
 *  Licence: MIT
 */

import JavaScriptCore
#if os(OSX)
import AppKit
#else
import UIKit
#endif


/**
    Wrapper class for generating a highlighted NSAttributedString from a code string.
 */
open class Highlighter {

    // MARK: - Public Properties
    
    open var theme: Theme! {
        didSet {
            themeChanged?(theme)
        }
    }

    // This block will be called every time the theme changes.
    open var themeChanged: ((Theme) -> Void)?

    // When `true`, forces highlighting to finish even if illegal syntax is detected.
    open var ignoreIllegals = false

    // FROM 3.1.1
    public var loggingOptions: LoggingOptions = LoggingOptions()


    // MARK: - Private Properties
    
    private let hljs: JSValue
    private let bundle: Bundle
    private let htmlStart: String = "<"
    private let spanStart: String = "span class=\""
    private let spanStartClose: String = "\">"
    private let spanEnd: String = "/span>"
    private let htmlEscape: NSRegularExpression = try! NSRegularExpression(pattern: "&#?[a-zA-Z0-9]+?;", options: .caseInsensitive)


    // MARK: - Constructor

    /**
     The default initialiser.
     
     Returns `nil` on failure to load or evaluate `highlight.min.js`,
     or to load the default theme (`Default`)
    */
    public init?(_ loggingOptions: LoggingOptions? = nil) {

        // Get the library's bundle based on how it's
        // being included in the host app
#if SWIFT_PACKAGE
        let bundle = Bundle.module
#else
        let bundle = Bundle(for: Highlighter.self)
#endif

        // FROM 3.1.1
        // Retain the logging options if any are passed in
        if let lo = loggingOptions {
            self.loggingOptions = lo
        }

        // Load the highlight.js code from the bundle or fail
        guard let highlightPath: String = bundle.path(forResource: "highlight.min", ofType: "js") else {
            if self.loggingOptions.highlighter.showInitErrors {
                self.loggingOptions.logger.critical("Could not load Highlight.js file")
            }

            return nil
        }

        // Check the JavaScript or fail
        do {
            guard let context = JSContext() else {
                if self.loggingOptions.highlighter.showInitErrors {
                    self.loggingOptions.logger.critical("Could not create JavaScript context")
                }

                return nil
            }

            let highlightJs: String = try String(contentsOfFile: highlightPath)
            let _ = context.evaluateScript(highlightJs)

            guard let hljs = context.globalObject.objectForKeyedSubscript("hljs") else {
                if self.loggingOptions.highlighter.showInitErrors {
                    self.loggingOptions.logger.critical("Could not get hljs object")
                }

                return nil
            }

            // Store the results for later
            self.hljs = hljs
            self.bundle = bundle
        } catch {
            if self.loggingOptions.highlighter.showInitErrors {
                self.loggingOptions.logger.critical("Could not load or evaluate JavaScript")
            }

            return nil
        }

        // Check and set applying a theme or fail
        // NOTE 'setTheme()' depends on 'self.bundle'
        guard setTheme("default-light") else {
            if self.loggingOptions.highlighter.showInitErrors {
                self.loggingOptions.logger.critical("Could not instantiate initial theme")
            }

            return nil
        }
    }


    // MARK: - Primary Functions

    /**
     Highlight the supplied code in the specified language.

     - Parameters:
        - code:         The source code to highlight.
        - languageName: The language in which the code is written.
        - doFastRender: Should fast rendering be used? Default: `true`.

     - Returns: The highlighted code as an NSAttributedString, or `nil`
    */
    public func highlight(_ code: String, as languageName: String? = nil, doFastRender: Bool = true) -> NSAttributedString? {

        return highlight(code, as: languageName, doFastRender: doFastRender, lineNumbering: nil)
    }


    /**
     Highlight the supplied code in the specified language.
    
     - Parameters:
        - code:          The source code to highlight.
        - languageName:  The language in which the code is written.
        - doFastRender:  Should fast rendering be used? Default: `true`.
        - lineNumbering: Structure containing line numbering information, or `nil` for no line numbering.

     - Returns: The highlighted code as an NSAttributedString, or `nil`
    */
    public func highlight(_ code: String, as languageName: String? = nil, doFastRender: Bool = true, lineNumbering: LineNumberData? = nil) -> NSAttributedString? {

        let returnValue: JSValue
        
        if let language = languageName {
            // Use the specified language
            // NOTE Will return 'undefined' (trapped below) if it's a unknown language
            let options: [String: Any] = ["language": language, "ignoreIllegals": self.ignoreIllegals]
            returnValue = hljs.invokeMethod("highlight",
                                            withArguments: [code, options])
        } else {
            // Use language auto detection
            returnValue = hljs.invokeMethod("highlightAuto",
                                            withArguments: [code])
        }
        
        // Check we got a valid string back - fail if we didn't
        guard let renderedHTMLValue = returnValue.objectForKeyedSubscript("value") else {
            return nil
        }

        // Trap 'undefined' output as this is effectively an error condition
        // and should not be returned as a valid result -- it's actually a fail
        guard var renderedHTMLString = renderedHTMLValue.toString(), renderedHTMLString != "undefined" else {
            return nil
        }
        
        // Convert the HTML received from Highlight.js to an NSAttributedString or nil
        var returnAttrString: NSAttributedString? = nil
        
        if doFastRender {
            // Use fast rendering -- the default
            returnAttrString = processHTMLString(renderedHTMLString)!
        } else {
            // Use NSAttributedString's own not-so-fast rendering
            renderedHTMLString = "<style>" + self.theme.lightTheme + "</style><pre><code class=\"hljs\">" + renderedHTMLString + "</code></pre>"
            let data = renderedHTMLString.data(using: String.Encoding.utf8)!
            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ]

            returnAttrString = try? NSMutableAttributedString(data:data, options: options, documentAttributes:nil)
        }

        // FROM 1.2.0
        // Add line numbers if the user has passed in a data structure
        if let lnd = lineNumbering, let ras = returnAttrString {
            returnAttrString = addLineNumbers(ras, lnd)
        }

        return returnAttrString
    }


    /**
     Set the Highligt.js theme to use for highlighting.
    
     - Parameters:
        - themeName:      The Highlight.js theme's name.
        - withFont:       The name of the font to use. Default: Courier.
        - ofSize:         The size of the font. Default: 14pt.

     - Returns: Whether the theme was successfully applied (`true`) or not (`false`)
    */
    @discardableResult
    public func setTheme(_ themeName: String, withFont: String? = nil, ofSize: CGFloat? = nil) -> Bool {

        // Make sure we can load the theme's CSS file -- or fail
        guard let themePath = self.bundle.path(forResource: themeName, ofType: "css") else {
            if self.loggingOptions.highlighter.showCSSErrors {
                self.loggingOptions.logger.error("Could not load CSS for theme \(themeName)")
            }

            return false
        }
        
        // Create the required font
        // If this fails ('font' == nil), we use the defaults
        var font: HSFont? = nil
        if let fontName = withFont {
            var size: CGFloat = 14.0
            if ofSize != nil {
                size = ofSize!
            }
            
            font = HSFont(name: fontName, size: size)
        }
        
        // Get the theme CSS and instantiate a Theme object
        let themeString = try! String(contentsOfFile: themePath)
        self.theme = Theme(withTheme: themeString, usingFont: font)
        self.theme.name = themeName
        // FROM 3.1.1
        self.theme.loggingOptions = self.loggingOptions

        return true
    }


    /**
     Get a list of available Highlight.js themes.
     
     Just lists what CSS files are in the bundle.
    
     - Returns: The list of themes as an array of strings.
    */
    public func availableThemes() -> [String] {

        let paths = bundle.paths(forResourcesOfType: "css", inDirectory: nil) as [NSString]
        var result = [String]()
        for path in paths {
            result.append(path.lastPathComponent.replacingOccurrences(of: ".css", with: ""))
        }

        return result
    }


    /**
     Get a list of languages supported by Highlight.js.
    
     - Returns: The list of languages as an array of strings.
    */
    public func supportedLanguages() -> [String] {

        guard let res: JSValue = hljs.invokeMethod("listLanguages", withArguments: []) else { return [] }
        return res.toArray() as? [String] ?? []
    }


    // MARK: - Fast HTML Rendering Function

    /**
     Generate an NSAttributedString from HTML source.
    
     - Parameters:
        - htmlString: The HTML to be converted.
     
     - Returns: The rendered HTML as an NSAttibutedString, or `nil` if an error occurred.
    */
    private func processHTMLString(_ htmlString: String) -> NSAttributedString? {

        // LOCAL: single pass over the UTF-8 bytes of Highlight.js's output. Text is
        // copied out with the five entities Highlight.js emits decoded inline, and
        // each run of text is recorded with its span-class stack. The attributes for
        // each distinct stack are computed once, and applied per run at the end.
        // The upstream version scanned with `Scanner`, built one attributed string
        // per token and then ran a regex pass for entities (10x+ slower).
        let openTag = Array("<span class=\"".utf8)
        let closeTag = Array("</span>".utf8)
        var styleCache: [String: [NSAttributedString.Key: Any]] = [:]
        var stack: [String] = ["hljs"]
        var stackKey = "hljs"
        var runs: [(start: Int, end: Int, key: String)] = []
        var runStart = 0
        var utf16Length = 0
        var text: [UInt8] = []
        text.reserveCapacity(htmlString.utf8.count)

        func attributes(for key: String) -> [NSAttributedString.Key: Any] {
            if let cached = styleCache[key] {
                return cached
            }

            let styled = self.theme.applyStyleToString(" ", styleList: stack)
            let attrs = styled.length > 0 ? styled.attributes(at: 0, effectiveRange: nil) : [:]
            styleCache[key] = attrs
            return attrs
        }

        // Base style, computed while the stack holds only "hljs"
        let baseKey = "hljs"
        let baseAttributes = attributes(for: baseKey)

        func stackChanged() {
            let key = stack.joined(separator: "\u{1}")
            if key != stackKey {
                if utf16Length > runStart {
                    runs.append((runStart, utf16Length, stackKey))
                }

                runStart = utf16Length
                stackKey = key
                _ = attributes(for: key)
            }
        }

        var html = htmlString
        html.withUTF8 { bytes in
            let count = bytes.count

            func matches(_ pattern: [UInt8], at index: Int) -> Bool {
                guard index + pattern.count <= count else { return false }
                for offset in 0..<pattern.count where bytes[index + offset] != pattern[offset] {
                    return false
                }
                return true
            }

            func entity(at index: Int) -> (byte: UInt8, length: Int)? {
                let entities: [([UInt8], UInt8)] = [
                    (Array("&amp;".utf8), 0x26), (Array("&lt;".utf8), 0x3C), (Array("&gt;".utf8), 0x3E),
                    (Array("&quot;".utf8), 0x22), (Array("&#x27;".utf8), 0x27), (Array("&#39;".utf8), 0x27)
                ]
                for (pattern, byte) in entities where matches(pattern, at: index) {
                    return (byte, pattern.count)
                }
                return nil
            }

            var index = 0
            while index < count {
                let byte = bytes[index]
                if byte == 0x3C && matches(openTag, at: index) {
                    // <span class="...">: push the class list
                    var end = index + openTag.count
                    while end < count && bytes[end] != 0x22 {
                        end += 1
                    }

                    let classes = String(decoding: UnsafeBufferPointer(rebasing: bytes[(index + openTag.count)..<end]), as: UTF8.self)
                    if !classes.isEmpty {
                        stack.append(classes)
                        stackChanged()
                    }

                    index = min(end + 2, count)
                } else if byte == 0x3C && matches(closeTag, at: index) {
                    // </span>: pop the class list
                    if stack.count > 1 {
                        stack.removeLast()
                        stackChanged()
                    }

                    index += closeTag.count
                } else if byte == 0x26, let decoded = entity(at: index) {
                    text.append(decoded.byte)
                    utf16Length += 1
                    index += decoded.length
                } else {
                    // Copy the byte; count UTF-16 units from UTF-8 lead bytes
                    text.append(byte)
                    if byte < 0x80 || (byte >= 0xC0 && byte < 0xF0) {
                        utf16Length += 1
                    } else if byte >= 0xF0 {
                        utf16Length += 2
                    }

                    index += 1
                }
            }
        }

        if utf16Length > runStart {
            runs.append((runStart, utf16Length, stackKey))
        }

        let result = NSMutableAttributedString(string: String(decoding: text, as: UTF8.self),
                                               attributes: baseAttributes)
        result.beginEditing()
        for run in runs where run.key != baseKey {
            if let attrs = styleCache[run.key] {
                result.setAttributes(attrs, range: NSRange(location: run.start, length: run.end - run.start))
            }
        }
        result.endEditing()

        return result
    }


    /**
     The attributes the current theme gives unhighlighted code (its base `.hljs` style).

     LOCAL: used to show not-yet-highlighted text in the same font and colors.

     - Returns: The attributes as a dictionary.
     */
    public func plainTextAttributes() -> [NSAttributedString.Key: Any] {

        let styled = self.theme.applyStyleToString(" ", styleList: ["hljs"])
        return styled.length > 0 ? styled.attributes(at: 0, effectiveRange: nil) : [:]
    }


    // MARK: - Line Numbering Functions

    /**
     Add line numbers to each line within the specified NSAttributedString.

     Numbers are zero padded to the number of digits in the highest line number.

     FROM 1.2.0

     - Parameters:
        - renderedCode  The already-styled NSAttributedString, ie. the code.
        - withSeparator An extra separator string placed between number and line.

     - Returns A new optional NSAttributedString containing the line numbers

     */
    private func addLineNumbers(_ renderedCode: NSAttributedString, _ lineNumberingData: LineNumberData) -> NSAttributedString? {

        let linedCode = NSMutableAttributedString()
        let lines = renderedCode.components(separatedBy: lineNumberingData.lineBreak)

        // Determine the maximum digit-width of the line number field
        var formatCount = lineNumberingData.minWidth
        var lineIndex = lineNumberingData.numberStart > 1 ? lineNumberingData.numberStart - 1 : 0
        var lineCount: Int = lines.count + lineIndex
        while lineCount > 99 {
            formatCount += 1
            lineCount = lineCount / 100
        }

        // Determine the colour according to the usage mode
        let colour: HSColor = lineNumberingData.usingDarkTheme ? .white : .black

        // Set the line number attributes - keep it low key
        let lineAtts: [NSAttributedString.Key : Any] = [.foregroundColor: colour.withAlphaComponent(0.2),
                                                        .font: HSFont.monospacedSystemFont(ofSize: lineNumberingData.fontSize, weight: .ultraLight)]

        // Iterate over the rendered lines, prepending the line number
        let formatString = "%0\(formatCount)i"

        for line in lines {
            // Add the line number
            lineIndex += 1
            linedCode.append(NSAttributedString(string: String(format: formatString, lineIndex), attributes: lineAtts))

            // Add a separator
            linedCode.append(NSAttributedString(string: lineNumberingData.separator, attributes: lineAtts))

            // Add the line itself and restore the line break
            linedCode.append(line)
            linedCode.append(NSAttributedString(string: lineNumberingData.lineBreak, attributes: lineAtts))
        }

        return linedCode
    }
}
