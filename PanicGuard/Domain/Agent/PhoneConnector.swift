import Foundation
import WatchConnectivity

/// Manages WatchConnectivity on the iPhone side.
/// Receives HR batches from the Watch and pushes the user profile to the Watch.
final class PhoneConnector: NSObject, WCSessionDelegate {
    static let shared = PhoneConnector()

    /// Called when the Watch sends an HR batch. Delivers (samples, stepCount) on the main thread.
    var onHRBatchReceived: ((_ samples: [Double], _ stepCount: Int) -> Void)?

    /// Called when the Watch sends a silentInvitation trigger.
    var onSilentInvitation: (() -> Void)?

    private let session = WCSession.default

    func activate() {
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    /// Pushes the user profile (emergency contact phone) to the paired Watch.
    func pushProfile(ecPhone: String?) {
        guard session.activationState == .activated,
              session.isPaired,
              session.isWatchAppInstalled else { return }
        var info: [String: Any] = ["type": "userProfile"]
        if let phone = ecPhone { info["ecPhone"] = phone }
        session.transferUserInfo(info)
    }

    /// Pushes iPhone state to the Watch so it mirrors watching/silentInvitation/idle.
    /// Uses sendMessage (foreground) when reachable, falls back to transferUserInfo (background).
    func pushWatchState(_ stateName: String) {
        guard session.activationState == .activated,
              session.isPaired,
              session.isWatchAppInstalled else { return }
        let payload: [String: Any] = ["type": "watchState", "state": stateName]
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        } else {
            session.transferUserInfo(payload)
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    /// Receives HR batches transferred from the Watch (background).
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let samples = userInfo["hrSamples"] as? [Double],
              let stepCount = userInfo["stepCount"] as? Int else { return }
        DispatchQueue.main.async { self.onHRBatchReceived?(samples, stepCount) }
    }

    /// Receives real-time messages from the Watch (foreground).
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let type = message["type"] as? String else { return }
        switch type {
        case "silentInvitation":
            DispatchQueue.main.async { self.onSilentInvitation?() }
        case "hrBatch":
            if let samples = message["hrSamples"] as? [Double],
               let stepCount = message["stepCount"] as? Int {
                DispatchQueue.main.async { self.onHRBatchReceived?(samples, stepCount) }
            }
        default:
            break
        }
    }
}
