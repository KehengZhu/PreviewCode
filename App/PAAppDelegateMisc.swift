/*
 *  PAAppDelegateMisc.swift
 *  PreviewApps
 *
 *  Created by Tony Smith on 18/06/20214.
 *  Copyright © 2026 Tony Smith. All rights reserved.
 */

import AppKit


extension AppDelegate {

    // MARK: - Alert Handler Functions

    /**
     Generic alert generator.

     - Parameters:
        - head:        The alert's title.
        - message:     The alert's message.
        - addOkButton: Should we add an OK button?
        - isCritical:  Should we make this a crirical alert

     - Returns: The NSAlert.
     */
    internal func makeAlert(_ head: String, _ message: String, _ addOkButton: Bool = true, _ isCritical: Bool = false) -> NSAlert {

        let alert = NSAlert()
        alert.messageText = head
        alert.informativeText = message
        if addOkButton { alert.addButton(withTitle: "OK") }
        if isCritical { alert.alertStyle = .critical }
        return alert
    }


    // MARK: - Support Functions

    func applicationSupportsSecureRestorableState() -> Bool {

        return true
    }


    // MARK: - NSWindowDelegate Functions

    /**
      Catch when the user clicks on the window's red close button.
     */
    public func windowShouldClose(_ sender: NSWindow) -> Bool {

        if !checkSettingsOnQuit() {
            // No unsaved settings, so we're good to close
            return true
        }

        // Close manually: there are settings changes, so this asks first
        doClose(self)
        return false
    }

}
