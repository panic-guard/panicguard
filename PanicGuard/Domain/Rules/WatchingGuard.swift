import Foundation

protocol WatchingGuardProtocol {
    /// Returns true if an unexplained HR elevation has been sustained for >= 2 minutes.
    func isSustainedElevation(
        hrSamples: [Double],
        baseline: Double,
        stepCount: Int
    ) -> Bool
}

final class WatchingGuard: WatchingGuardProtocol {
    func isSustainedElevation(
        hrSamples: [Double],
        baseline: Double,
        stepCount: Int
    ) -> Bool {
        // TODO: implement elevation + activity check
        fatalError("not implemented")
    }
}
