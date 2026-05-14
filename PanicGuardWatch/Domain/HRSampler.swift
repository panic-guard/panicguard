import Foundation
import HealthKit

protocol HRSampling {
    /// Starts a background HealthKit query that delivers HR samples as they arrive.
    func startSampling(handler: @escaping (Double) -> Void)
    func stopSampling()
}

final class HRSampler: HRSampling {
    private let healthStore = HKHealthStore()

    func startSampling(handler: @escaping (Double) -> Void) {
        // TODO: configure HKAnchoredObjectQuery for heartRate
        fatalError("not implemented")
    }

    func stopSampling() {
        // TODO: invalidate active query
        fatalError("not implemented")
    }
}
