/*
 *  MarkdownPreviewController.swift
 *  Markdown Previewer (LOCAL)
 *
 *  Quick Look previews of Markdown notes (Obsidian flavored, with KaTeX math)
 *  rendered in a reused web view. Replaces Obsidian's own Quick Look extension,
 *  which loads a new web view and renders math with MathJax on every preview.
 */

import AppKit
import Quartz
import WebKit


final class MarkdownPreviewController: NSViewController, QLPreviewingController {

    private var webView: RendererWebView?


    // MARK: - Lifecycle Functions

    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {

        super.init(nibName: nil, bundle: nil)
        WebViewPool.shared.warmUp()
    }


    required init?(coder: NSCoder) {

        super.init(coder: coder)
        WebViewPool.shared.warmUp()
    }


    deinit {

        if let view = webView {
            Task { @MainActor in
                WebViewPool.shared.release(view)
            }
        }
    }


    override func loadView() {

        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 800))
        self.view.autoresizesSubviews = true
    }


    // MARK: - QLPreviewingController Required Functions

    func preparePreviewOfFile(at url: URL) async throws {

        let start = uptimeMs()
        let data = try Data(contentsOf: url)
        let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .utf16)
            ?? String(decoding: data, as: UTF8.self)

        // The Quick Look window size set in PreviewCode's Advanced Settings
        let settings = PCSettings()
        settings.loadSettings(MNU_SECRETS.PID + BUFFOON_CONSTANTS.SUITE_NAME)
        self.preferredContentSize = NSSize(width: settings.previewWindowWidth, height: settings.previewWindowHeight)

        let renderer = WebViewPool.shared.acquire()
        let wasLoaded = renderer.isLoaded
        self.webView = renderer
        renderer.frame = self.view.bounds
        renderer.autoresizingMask = [.width, .height]
        self.view.addSubview(renderer)

        guard await renderer.waitUntilLoaded() else {
            throw NSError(domain: "com.bps.PreviewCode.Markdown-Previewer", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "The Markdown renderer failed to load"])
        }

        let loaded = uptimeMs()
        let result = try await renderer.callAsyncJavaScript("return await qlRender(text, path)",
                                                           arguments: ["text": text, "path": url.path],
                                                           in: nil,
                                                           contentWorld: .page)
        let timings = (result as? [String: Any]) ?? [:]
        mdLog.debug("""
            Rendered \(url.lastPathComponent, privacy: .public) (\(data.count) B): \
            total \(uptimeMs() - start, format: .fixed(precision: 1)) ms, \
            wait for page \(loaded - start, format: .fixed(precision: 1)) ms (warm: \(wasLoaded)), \
            parse \(timings["parse"] as? Int ?? -1) ms, DOM \(timings["dom"] as? Int ?? -1) ms, fonts \(timings["fonts"] as? Int ?? -1) ms
            """)
    }
}
