import Foundation
import HealthKit

// MARK: - Mock Scenario

enum MockScenario {
    case panic    // HR: 70→160→70 cycle, stepCount: 0–5
    case exercise // HR: 80→150 rising, stepCount: 80–120
    case normal   // HR: 65–80 stable, stepCount: 0–15
}

// MARK: - Mode

enum HRMode {
    case real
    case mock(MockScenario)
}

// MARK: - Protocol

protocol HRSampling {
    func requestAuthorization() async throws
    func startSampling(handler: @escaping (Double, Int) -> Void)
    func stopSampling()
}

// MARK: - Sampler

final class HRSampler: HRSampling {

    // MARK: HealthKit
    private var activeQuery: HKAnchoredObjectQuery?
    private let healthStore = HKHealthStore()
    private var currentStepCount: Int = 0
    private var stepCountTimer: Timer?

    // MARK: Mock
    var timer: Timer?

    // MARK: Mode
    private let mode: HRMode
    private var isAuthorized = false

    init(mode: HRMode = .real) {
        self.mode = mode
    }

    // MARK: Authorization

    func requestAuthorization() async throws {

        guard HKHealthStore.isHealthDataAvailable() else {
            throw NSError(domain: "HealthKitUnavailable", code: 1)
        }

        guard
            let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate),
            let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount)
        else {
            throw NSError(domain: "HealthKitTypeUnavailable", code: 2)
        }

        let readTypes: Set<HKObjectType> = [heartRateType, stepCountType]
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)

        isAuthorized = true
        print("HealthKit authorization success")
    }

    // MARK: Start Sampling

    func startSampling(handler: @escaping (Double, Int) -> Void) {
        switch mode {
        case .real:
            guard isAuthorized else {
                print("❌ HealthKit not authorized yet")
                return
            }
            startStepCountQuery()
            startHealthKitSampling(handler: handler)
        case .mock(let scenario):
            startMockSampling(scenario: scenario, handler: handler)
        }
    }

    // MARK: Real HealthKit

    private func startHealthKitSampling(handler: @escaping (Double, Int) -> Void) {

        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!

        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.process(samples: samples, handler: handler)
        }

        query.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.process(samples: samples, handler: handler)
        }

        healthStore.execute(query)
        activeQuery = query

        print("HR Sampling started (real)")
    }

    private func startStepCountQuery() {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!

        let fetchSteps = { [weak self] in
            guard let self else { return }
            let start = Date().addingTimeInterval(-300)
            let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { [weak self] _, stats, _ in
                self?.currentStepCount = Int(stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
            }
            self.healthStore.execute(query)
        }

        fetchSteps()
        stepCountTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in fetchSteps() }
    }

    // MARK: Mock Stream

    private func startMockSampling(scenario: MockScenario, handler: @escaping (Double, Int) -> Void) {
        var fakeHR: Double

        switch scenario {
        case .panic:
            fakeHR = 70
            var rising = true
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                if rising {
                    fakeHR = min(fakeHR + Double.random(in: 2...8), 160)
                    if fakeHR >= 160 { rising = false }
                } else {
                    fakeHR = max(fakeHR - Double.random(in: 1...4), 70)
                    if fakeHR <= 70 { rising = true }
                }
                handler(fakeHR.rounded(), Int.random(in: 0...5))
                print("MOCK HR:", fakeHR.rounded(), "Steps:", Int.random(in: 0...5))
            }

        case .exercise:
            fakeHR = 80
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                fakeHR = min(fakeHR + Double.random(in: 1...4), 150)
                let steps = Int.random(in: 80...120)
                handler(fakeHR.rounded(), steps)
                print("MOCK HR:", fakeHR.rounded(), "Steps:", steps)
            }

        case .normal:
            fakeHR = 72
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                fakeHR = max(65, min(80, fakeHR + Double.random(in: -3...3)))
                let steps = Int.random(in: 0...15)
                handler(fakeHR.rounded(), steps)
                print("MOCK HR:", fakeHR.rounded(), "Steps:", steps)
            }
        }

        print("HR Sampling started (mock: \(scenario))")
    }

    // MARK: Stop

    func stopSampling() {

        timer?.invalidate()
        timer = nil

        stepCountTimer?.invalidate()
        stepCountTimer = nil

        if let query = activeQuery {
            healthStore.stop(query)
            activeQuery = nil
        }

        print("HR Sampling stopped")
    }

    // MARK: Helper

    private func process(
        samples: [HKSample]?,
        handler: @escaping (Double, Int) -> Void
    ) {
        guard let samples = samples as? [HKQuantitySample] else { return }

        for sample in samples {
            let bpm = sample.quantity.doubleValue(
                for: HKUnit.count().unitDivided(by: .minute())
            )
            handler(bpm, currentStepCount)
        }
    }
}
