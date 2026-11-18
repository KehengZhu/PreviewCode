/*
 *  WebViewPool.swift
 *  Markdown Previewer (LOCAL)
 *
 *  Keeps renderer web views loaded between previews. Loading the page (a new
 *  WebContent process plus about 3 MB of JavaScript) costs about 100 ms, so
 *  each preview takes an already loaded view and a replacement starts loading
 *  in the background for the next one.
 */

import AppKit
import WebKit
import UniformTypeIdentifiers
import os


let mdLog = Logger(subsystem: "com.bps.PreviewCode.Markdown-Previewer", category: "preview")

func uptimeMs() -> Double {
    Double(clock_gettime_nsec_np(CLOCK_UPTIME_RAW)) / 1e6
}


// MARK: - Renderer web view

/**
 A web view with the renderer page (`Web/index.html`) loaded or loading.
 */
@MainActor
final class RendererWebView: WKWebView, WKNavigationDelegate {

    private(set) var isLoaded = false
    private(set) var isBroken = false
    private var loadWaiters: [CheckedContinuation<Void, Never>] = []
    private let created = uptimeMs()


    init() {

        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(AssetSchemeHandler.shared, forURLScheme: AssetSchemeHandler.scheme)
        super.init(frame: NSRect(x: 0, y: 0, width: 1000, height: 800), configuration: config)
        self.navigationDelegate = self
        self.allowsMagnification = true
        load(URLRequest(url: URL(string: "\(AssetSchemeHandler.scheme)://app/index.html")!))
    }


    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }


    /**
     Wait for the renderer page to finish loading.

     - Returns: `true` if the page is ready to render.
     */
    func waitUntilLoaded() async -> Bool {

        if !isLoaded && !isBroken {
            await withCheckedContinuation { loadWaiters.append($0) }
        }

        return isLoaded && !isBroken
    }


    private func finishLoading(ok: Bool) {

        isLoaded = ok
        isBroken = !ok
        mdLog.debug("Renderer page \(ok ? "loaded" : "failed") in \(uptimeMs() - self.created, format: .fixed(precision: 1)) ms")
        let waiters = loadWaiters
        loadWaiters = []
        waiters.forEach { $0.resume() }
    }


    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {

        finishLoading(ok: true)
    }


    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {

        finishLoading(ok: false)
    }


    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {

        finishLoading(ok: false)
    }


    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {

        isBroken = true
    }


    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {

        guard let url = navigationAction.request.url else {
            return .cancel
        }

        // The renderer page itself
        if !isLoaded && url.scheme == AssetSchemeHandler.scheme {
            return .allow
        }

        // Jumps within the note (footnotes, heading anchors)
        if let current = self.url, url.fragment != nil,
           url.absoluteString.hasPrefix(current.absoluteString.components(separatedBy: "#")[0]) {
            return .allow
        }

        // Never leave the renderer page. Clicked web links open in the browser.
        if navigationAction.navigationType == .linkActivated,
           let scheme = url.scheme?.lowercased(), ["http", "https", "mailto"].contains(scheme) {
            NSWorkspace.shared.open(url)
        }

        return .cancel
    }
}


// MARK: - Pool

@MainActor
final class WebViewPool {

    static let shared = WebViewPool()

    // Loaded or loading views waiting for a preview. Each holds a WebContent
    // process (about 35-75 MB), so keep one: Quick Look renders the neighboring
    // files ahead of time, which hides the cost of loading any extra view.
    private var spares: [RendererWebView] = []
    private let maxSpares = 1


    /**
     Make sure a renderer view is loading, so the next preview finds it ready.
     */
    func warmUp() {

        spares.removeAll { $0.isBroken }
        if spares.isEmpty {
            spares.append(RendererWebView())
        }
    }


    /**
     Take a renderer view for a preview, preferring one that has finished loading.
     */
    func acquire() -> RendererWebView {

        spares.removeAll { $0.isBroken }
        let view: RendererWebView
        if let index = spares.firstIndex(where: { $0.isLoaded }) {
            view = spares.remove(at: index)
        } else if !spares.isEmpty {
            view = spares.removeFirst()
        } else {
            view = RendererWebView()
        }

        // Quick Look prefetches the neighboring files, so have the next view ready
        // soon, but start it after this preview has had the CPU
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.warmUp()
        }

        return view
    }


    /**
     Return a renderer view once its preview has gone.
     */
    func release(_ view: RendererWebView) {

        view.removeFromSuperview()
        guard !view.isBroken, view.isLoaded, spares.count < maxSpares else {
            return
        }

        // Free the old note's DOM now rather than when the view is next used
        view.evaluateJavaScript("qlClear()")
        spares.append(view)
    }
}


// MARK: - qlmd: scheme

/**
 Serves the renderer page (`qlmd://app/...`) and images a note refers to
 (`qlmd://asset/?name=...&from=<note path>`).

 Images are looked up as Obsidian does: relative to the note, relative to the
 vault root, then by file name anywhere in the vault. Reading outside the
 previewed file relies on the sandbox exception in the entitlements, which
 covers Obsidian's iCloud folder only; elsewhere an image may fail to load and
 the page shows its name instead.
 */
final class AssetSchemeHandler: NSObject, WKURLSchemeHandler, @unchecked Sendable {

    static let scheme = "qlmd"
    static let shared = AssetSchemeHandler()

    private let webDir: URL = Bundle.main.resourceURL!.appendingPathComponent("Web", isDirectory: true)
    private let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "svg", "webp", "bmp", "avif", "tif", "tiff", "heic"]

    // Lookup state, used on `queue` only
    private let queue = DispatchQueue(label: "com.bps.previewcode.markdown.assets")
    private var vaultRoots: [String: URL?] = [:]
    private var vaultIndexes: [URL: (built: Date, files: [String: [URL]])] = [:]

    // Tasks WebKit has not stopped; touched on the main thread only
    private var activeTasks = Set<ObjectIdentifier>()


    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {

        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }

        if url.host == "app" {
            // Renderer files: small, in our bundle, so read them right away
            let file = webDir.appendingPathComponent(url.path).standardizedFileURL
            guard file.path.hasPrefix(webDir.path), let data = try? Data(contentsOf: file) else {
                urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
                return
            }

            respond(urlSchemeTask, url: url, file: file, data: data)
            return
        }

        // Attachments: resolve and read off the main thread
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let name = items.first { $0.name == "name" }?.value ?? ""
        let from = items.first { $0.name == "from" }?.value ?? ""
        let id = ObjectIdentifier(urlSchemeTask)
        activeTasks.insert(id)
        queue.async {
            let file = self.resolve(name, from: from)
            let data = file.flatMap { try? Data(contentsOf: $0) }
            if data == nil {
                mdLog.debug("Attachment \(name, privacy: .public) not \(file == nil ? "found" : "readable")")
            }
            DispatchQueue.main.async {
                guard self.activeTasks.remove(id) != nil else { return }
                if let file, let data {
                    self.respond(urlSchemeTask, url: url, file: file, data: data)
                } else {
                    urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
                }
            }
        }
    }


    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {

        activeTasks.remove(ObjectIdentifier(urlSchemeTask))
    }


    private func respond(_ task: WKURLSchemeTask, url: URL, file: URL, data: Data) {

        let mime = UTType(filenameExtension: file.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        task.didReceive(URLResponse(url: url, mimeType: mime, expectedContentLength: data.count, textEncodingName: nil))
        task.didReceive(data)
        task.didFinish()
    }


    // MARK: Attachment lookup (on `queue`)

    private func resolve(_ name: String, from notePath: String) -> URL? {

        let fm = FileManager.default
        let name = name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, imageExtensions.contains((name as NSString).pathExtension.lowercased()) else {
            return nil
        }

        let isFile = { (url: URL) -> Bool in
            var isDir: ObjCBool = false
            return fm.fileExists(atPath: url.path, isDirectory: &isDir) && !isDir.boolValue
        }

        if name.hasPrefix("/") {
            let url = URL(fileURLWithPath: name)
            return isFile(url) ? url : nil
        }

        let noteDir = URL(fileURLWithPath: notePath).deletingLastPathComponent()
        let relative = noteDir.appendingPathComponent(name).standardizedFileURL
        if isFile(relative) {
            return relative
        }

        guard let vault = vaultRoot(for: noteDir) else {
            return nil
        }

        let fromVault = vault.appendingPathComponent(name).standardizedFileURL
        if isFile(fromVault) {
            return fromVault
        }

        // By file name anywhere in the vault; rebuild a stale index once on a miss
        let key = (name as NSString).lastPathComponent.lowercased()
        var candidates = vaultIndex(vault, rebuildIfOlderThan: nil)[key] ?? []
        if candidates.isEmpty {
            candidates = vaultIndex(vault, rebuildIfOlderThan: 5)[key] ?? []
        }

        // Prefer a match on the whole given path, then the file nearest the note
        let suffix = "/" + name.lowercased()
        let matching = candidates.filter { $0.path.lowercased().hasSuffix(suffix) }
        let pool = matching.isEmpty ? candidates : matching
        return pool.max { sharedPrefix($0.path, noteDir.path) < sharedPrefix($1.path, noteDir.path) }
    }


    private func vaultRoot(for dir: URL) -> URL? {

        if let cached = vaultRoots[dir.path] {
            return cached
        }

        var root: URL? = nil
        var current = dir
        while current.path != "/" {
            if FileManager.default.fileExists(atPath: current.appendingPathComponent(".obsidian").path) {
                root = current
                break
            }
            current = current.deletingLastPathComponent()
        }

        vaultRoots[dir.path] = root
        return root
    }


    private func vaultIndex(_ vault: URL, rebuildIfOlderThan age: TimeInterval?) -> [String: [URL]] {

        if let index = vaultIndexes[vault] {
            guard let age, Date().timeIntervalSince(index.built) > age else {
                return index.files
            }
        }

        let start = uptimeMs()
        var files: [String: [URL]] = [:]
        let keys: [URLResourceKey] = [.isRegularFileKey]
        if let walker = FileManager.default.enumerator(at: vault, includingPropertiesForKeys: keys,
                                                       options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
            for case let url as URL in walker where imageExtensions.contains(url.pathExtension.lowercased()) {
                files[url.lastPathComponent.lowercased(), default: []].append(url)
            }
        }

        vaultIndexes[vault] = (Date(), files)
        mdLog.debug("Indexed \(files.count) attachments in \(uptimeMs() - start, format: .fixed(precision: 1)) ms")
        return files
    }


    private func sharedPrefix(_ a: String, _ b: String) -> Int {

        zip(a, b).prefix { $0 == $1 }.count
    }
}
