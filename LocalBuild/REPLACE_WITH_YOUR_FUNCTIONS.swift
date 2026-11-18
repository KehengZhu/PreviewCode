/*
 *  Local replacement for the author's private feedback function.
 *  Feedback goes to the author's server in the App Store build; a local build
 *  has no server, so sending feedback always reports a connection failure.
 */

import Foundation

extension AppDelegate {

    internal func nuSendFeedback(_ feedback: String) async -> FeedbackError {
        return FeedbackError(code: .badSession, text: nil)
    }
}
