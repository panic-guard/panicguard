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

    func activate() {
        session.delegate = self
        session.activate()
    }

    func sendHRBatch(_ samples: [Double], stepCount: Int) {
        // TODO: session.transferUserInfo(...)
        fatalError("not implemented")
    }

    func sendSilentInvitation() {
        // TODO: session.sendMessage(...)
        fatalError("not implemented")
    }

    // MARK: - WCSessionDelegate stubs
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
}
