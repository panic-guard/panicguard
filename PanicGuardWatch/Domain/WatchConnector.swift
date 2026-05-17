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

    /// Called when the iPhone pushes a state name ("watching", "silentInvitation", "idle").
    var onWatchStateReceived: ((_ stateName: String) -> Void)?

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

    /// Receives background transfers from the iPhone (userProfile or watchState fallback).
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let type = userInfo["type"] as? String else { return }
        switch type {
        case "userProfile":
            let ecPhone = userInfo["ecPhone"] as? String
            DispatchQueue.main.async { self.onProfileReceived?(ecPhone) }
        case "watchState":
            guard let stateName = userInfo["state"] as? String else { return }
            DispatchQueue.main.async { self.onWatchStateReceived?(stateName) }
        default:
            break
        }
    }

    /// Receives real-time messages from the iPhone.
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let type = message["type"] as? String else { return }
        switch type {
        case "userProfile":
            let ecPhone = message["ecPhone"] as? String
            DispatchQueue.main.async { self.onProfileReceived?(ecPhone) }
        case "watchState":
            guard let stateName = message["state"] as? String else { return }
            DispatchQueue.main.async { self.onWatchStateReceived?(stateName) }
        default:
            break
        }
    }
}
