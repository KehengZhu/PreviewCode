/*
 *  MarkdownPreviewController.swift
 *  Markdown Previewer (LOCAL)
 *
 *  Quick Look previews of Markdown notes (Obsidian flavored, with KaTeX math)
 *  and Jupyter notebooks, rendered in a reused web view. Replaces Obsidian's own Quick Look extension,
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
        var data = try Data(contentsOf: url)
        let isNotebook = url.pathExtension.lowercased() == "ipynb"

        // The page reads UTF-8; notebooks always are, notes nearly always
        if !isNotebook, String(data: data, encoding: .utf8) == nil,
           let text = String(data: data, encoding: .utf16) {
            data = Data(text.utf8)
        }

        // The Quick Look window size (Advanced Settings) and text sizes (Markdown tab)
        let settings = AppSettings()
        settings.loadSettings(Constants.TEAM_ID + Constants.SUITE_NAME)
        self.preferredContentSize = NSSize(width: settings.previewWindowWidth, height: settings.previewWindowHeight)

        let renderer = WebViewPool.shared.acquire()
        let wasLoaded = renderer.isLoaded
        self.webView = renderer
        renderer.frame = self.view.bounds
        renderer.autoresizingMask = [.width, .height]
        self.view.addSubview(renderer)

        guard await renderer.waitUntilLoaded() else {
            throw NSError(domain: "io.github.kehengzhu.QuicklookAnything.Markdown-Previewer", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "The Markdown renderer failed to load"])
        }

        let loaded = uptimeMs()
        let docURL = AssetSchemeHandler.shared.publish(data)
        defer { AssetSchemeHandler.shared.unpublish(docURL) }
        let result: Any?
        do {
            result = try await renderer.callAsyncJavaScript("return await qlRender(url, path, kind, fontSize, codeFontSize, smallScale)",
                                                            arguments: ["url": docURL, "path": url.path,
                                                                        "kind": isNotebook ? "notebook" : "markdown",
                                                                        "fontSize": Double(settings.mdFontSize),
                                                                        "codeFontSize": Double(settings.mdCodeFontSize),
                                                                        "smallScale": Double(settings.smallPreviewScale)],
                                                            in: nil,
                                                            contentWorld: .page)
        } catch {
            mdLog.error("Rendering \(url.lastPathComponent, privacy: .public) failed: \(error, privacy: .public)")
            throw error
        }

        let timings = (result as? [String: Any]) ?? [:]
        mdLog.debug("""
            Rendered \(url.lastPathComponent, privacy: .public) (\(data.count) B): \
            total \(uptimeMs() - start, format: .fixed(precision: 1)) ms, \
            wait for page \(loaded - start, format: .fixed(precision: 1)) ms (warm: \(wasLoaded)), \
            fetch \(timings["fetch"] as? Int ?? -1) ms, parse \(timings["parse"] as? Int ?? -1) ms, DOM \(timings["dom"] as? Int ?? -1) ms, fonts \(timings["fonts"] as? Int ?? -1) ms, \
            chunks \(timings["chunks"] as? Int ?? 1)
            """)
    }
}
