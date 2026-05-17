import Foundation
import WatchConnectivity

protocol WatchConnecting {
    /// Sends a batch of HR samples to the paired iPhone.
    func sendHRBatch(_ samples: [Double], stepCount: Int)
    /// Sends the silent invitation trigger to the phone.
    func sendSilentInvitation()
}

final class WatchConnector: NSObject, WatchConnecting, WCSessionDelegate {
    private let session = WCSession.default

    /// Called when the phone syncs the user profile (emergency contact phone).
    var onProfileReceived: ((_ ecPhone: String?) -> Void)?

    func activate() {
        session.delegate = self
        session.activate()
    }

    func sendHRBatch(_ samples: [Double], stepCount: Int) {
        guard session.activationState == .activated else { return }
        session.transferUserInfo(["hrSamples": samples, "stepCount": stepCount])
    }

    func sendSilentInvitation() {
        guard session.isReachable else { return }
        session.sendMessage(["type": "silentInvitation"], replyHandler: nil, errorHandler: nil)
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    /// Receives user profile pushed from the iPhone (background transfer).
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let type = userInfo["type"] as? String, type == "userProfile" else { return }
        let ecPhone = userInfo["ecPhone"] as? String
        DispatchQueue.main.async { self.onProfileReceived?(ecPhone) }
    }

    /// Receives real-time messages from the iPhone.
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let type = message["type"] as? String, type == "userProfile" else { return }
        let ecPhone = message["ecPhone"] as? String
        DispatchQueue.main.async { self.onProfileReceived?(ecPhone) }
    }
}
