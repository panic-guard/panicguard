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
        guard !hrSamples.isEmpty else { return false }
        let meanHR = hrSamples.reduce(0, +) / Double(hrSamples.count)
        let isElevated = meanHR >= baseline * 1.20
        let isMoving = stepCount >= 30
        return isElevated && !isMoving
    }
}
