import Foundation

protocol WatchingGuardProtocol {
    func isSustainedElevation(
        hrSamples: [Double],
        baseline: Double,
        stepCount: Int,
        activeEnergyKcal: Double,
        hasActiveWorkout: Bool
    ) -> Bool
}

extension WatchingGuardProtocol {
    func isSustainedElevation(
        hrSamples: [Double],
        baseline: Double,
        stepCount: Int
    ) -> Bool {
        isSustainedElevation(
            hrSamples: hrSamples,
            baseline: baseline,
            stepCount: stepCount,
            activeEnergyKcal: 0,
            hasActiveWorkout: false
        )
    }
}

final class WatchingGuard: WatchingGuardProtocol {
    func isSustainedElevation(
        hrSamples: [Double],
        baseline: Double,
        stepCount: Int,
        activeEnergyKcal: Double,
        hasActiveWorkout: Bool
    ) -> Bool {
        guard !hrSamples.isEmpty else { return false }
        let meanHR = hrSamples.reduce(0, +) / Double(hrSamples.count)
        let isElevated = meanHR >= baseline * 1.20
        let isMoving = stepCount >= 30 || activeEnergyKcal >= 3.0 || hasActiveWorkout
        return isElevated && !isMoving
    }
}
