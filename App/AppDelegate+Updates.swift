/*
 *  AppDelegate+Updates.swift
 *  Quicklook Anything
 *
 *  Updates: check GitHub for a newer release and install it with the install command.
 */

import AppKit


extension AppDelegate {

    @objc
    internal func doOpenGitHub(_ sender: Any) {

        if let url = URL(string: Constants.MAIN_URL) {
            NSWorkspace.shared.open(url)
        }
    }


    /**
     Ask GitHub for the latest release and compare it with this version. A newer
     release is installed with the one-line installer, which the alert copies.
     */
    @objc
    internal func doCheckForUpdates(_ sender: Any) {

        guard let url = URL(string: Constants.LATEST_RELEASE_API) else { return }
        let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        self.updateButton?.isEnabled = false
        self.updateNote?.stringValue = "Checking…"

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { data, response, error in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            var latest: String? = nil
            var page = Constants.MAIN_URL + "/releases/latest"
            if status == 200, let data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let tag = json["tag_name"] as? String {
                latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
                page = json["html_url"] as? String ?? page
            }
            DispatchQueue.main.async {
                self.updateButton?.isEnabled = true
                self.showUpdateResult(current: current, latest: latest, page: page,
                                      problem: error?.localizedDescription ?? (status == 200 ? nil : "GitHub answered with status \(status)."))
            }
        }.resume()
    }


    private func showUpdateResult(current: String, latest: String?, page: String, problem: String?) {

        let alert = NSAlert()
        guard let latest else {
            self.updateNote?.stringValue = "The check for updates did not complete."
            alert.alertStyle = .warning
            alert.messageText = "Could Not Check for Updates"
            alert.informativeText = (problem ?? "The latest release could not be read.") + " Try again later, or see the releases on GitHub."
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Open GitHub")
            if alert.runModal() == .alertSecondButtonReturn, let url = URL(string: page) {
                NSWorkspace.shared.open(url)
            }
            return
        }

        guard isVersion(latest, newerThan: current) else {
            self.updateNote?.stringValue = "Version \(current) is the latest."
            alert.messageText = "You’re Up to Date"
            alert.informativeText = "Quicklook Anything \(current) is the latest version."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        self.updateNote?.stringValue = "Version \(latest) is available; you have \(current)."
        alert.messageText = "Quicklook Anything \(latest) Is Available"
        alert.informativeText = "You have \(current). Install Update runs the install command in Terminal, "
            + "then reopens the app. Your settings are kept."
        alert.addButton(withTitle: "Install Update")
        alert.addButton(withTitle: "What’s New")
        alert.addButton(withTitle: "Later")
        switch alert.runModal() {
            case .alertFirstButtonReturn:
                installUpdateInTerminal()
            case .alertSecondButtonReturn:
                if let url = URL(string: page) {
                    NSWorkspace.shared.open(url)
                }
            default:
                break
        }
    }


    /**
     Run the one-line installer in Terminal, which quits this app, upgrades it and
     opens it again. The app is sandboxed, so it cannot run the installer itself.
     If Terminal cannot be asked (eg. the user declined Automation), copy the
     command instead.
     */
    private func installUpdateInTerminal() {

        let bundleID = Bundle.main.bundleIdentifier ?? "io.github.kehengzhu.QuicklookAnything"
        let command = Constants.INSTALL_COMMAND + " && open -b " + bundleID
        let quoted = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
            tell application "Terminal"
                activate
                do script "\(quoted)"
            end tell
            """
        var error: NSDictionary? = nil
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        guard let error else {
            self.updateNote?.stringValue = "Installing in Terminal…"
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(Constants.INSTALL_COMMAND, forType: .string)
        self.updateNote?.stringValue = "Install command copied: paste it in Terminal."
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Could Not Open Terminal"
        alert.informativeText = "The install command is copied. Open Terminal, paste it and press Return. "
            + "To let the app open Terminal itself, allow it in System Settings > Privacy & Security > Automation."
            + "\n\n(\(error[NSAppleScript.errorMessage] as? String ?? "Unknown error"))"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }


    /**
     Compare dotted version numbers, eg. 1.10.0 is newer than 1.9.2.
     */
    private func isVersion(_ a: String, newerThan b: String) -> Bool {

        let x = a.split(separator: ".").map { Int($0) ?? 0 }
        let y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let p = i < x.count ? x[i] : 0, q = i < y.count ? y[i] : 0
            if p != q { return p > q }
        }
        return false
    }
}
