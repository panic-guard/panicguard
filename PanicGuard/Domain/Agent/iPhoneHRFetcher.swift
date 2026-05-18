import HealthKit

protocol HRFetching {
    func fetch() async -> HRFeaturePayload?
}

struct iPhoneHRFetcher: HRFetching {
    private let store = HKHealthStore()
    private let extractor = HRFeatureExtractor()

    // Returns nil if no recent HR samples exist (Watch not worn / not synced).
    // Returning nil prevents GemmaAgent from receiving a misleading 0 BPM payload.
    // HR window is 30 min — Watch samples every ~5 min at rest so a 5-min window
    // often returns empty due to sync timing.
    func fetch() async -> HRFeaturePayload? {
        await requestAuthorizationIfNeeded()
        async let hrSamples = fetchHRSamples()
        async let stepCount = fetchStepCount()
        async let activeEnergy = fetchActiveEnergy()
        async let hasWorkout = fetchHasActiveWorkout()

        let samples = await hrSamples
        guard !samples.isEmpty else { return nil }
        return extractor.extract(
            hrSamples: samples,
            stepCount: await stepCount,
            activeEnergyKcal: await activeEnergy,
            hasActiveWorkout: await hasWorkout
        )
    }

    private func requestAuthorizationIfNeeded() async {
        guard HKHealthStore.isHealthDataAvailable(),
              let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate),
              let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount),
              let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        let readTypes: Set<HKObjectType> = [hrType, stepType, energyType, HKWorkoutType.workoutType()]
        try? await store.requestAuthorization(toShare: [], read: readTypes)
    }

    private func fetchHRSamples() async -> [Double] {
        guard HKHealthStore.isHealthDataAvailable(),
              let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)
        else { return [] }

        let start = Date().addingTimeInterval(-1800)  // 30 min — covers Watch's ~5-min sampling interval
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        let sortDesc = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return await withCheckedContinuation { cont in
            let query = HKSampleQuery(
                sampleType: hrType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDesc]
            ) { _, samples, _ in
                let bpms = (samples as? [HKQuantitySample])?.map {
                    $0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                } ?? []
                cont.resume(returning: bpms)
            }
            store.execute(query)
        }
    }

    private func fetchStepCount() async -> Int {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }
        let start = Date().addingTimeInterval(-300)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)

        return await withCheckedContinuation { cont in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, _ in
                cont.resume(returning: Int(stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0))
            }
            store.execute(query)
        }
    }

    private func fetchActiveEnergy() async -> Double {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0 }
        let start = Date().addingTimeInterval(-300)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)

        return await withCheckedContinuation { cont in
            let query = HKStatisticsQuery(
                quantityType: energyType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, _ in
                cont.resume(returning: stats?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0)
            }
            store.execute(query)
        }
    }

    /// Returns the 30-day average resting HR from Apple Watch, or the mean of recent HR samples as a fallback.
    /// Uses HKStatisticsQuery (.discreteAverage) — mirrors what the Health app shows as "Resting Range".
    func fetchRestingHR() async -> Double? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        let restingType = HKQuantityType(.restingHeartRate)
        try? await store.requestAuthorization(toShare: [], read: [restingType])

        let start = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)

        let resting: Double? = await withCheckedContinuation { cont in
            let query = HKStatisticsQuery(
                quantityType: restingType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, stats, _ in
                cont.resume(returning: stats?.averageQuantity()?
                    .doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
            }
            store.execute(query)
        }
        if let resting { return resting }

        let samples = await fetchHRSamples()
        guard !samples.isEmpty else { return nil }
        return samples.reduce(0, +) / Double(samples.count)
    }

    private func fetchHasActiveWorkout() async -> Bool {
        let start = Date().addingTimeInterval(-1800)  // 30 min window
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        let sortDesc = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { cont in
            let query = HKSampleQuery(
                sampleType: HKWorkoutType.workoutType(),
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDesc]
            ) { _, samples, _ in
                cont.resume(returning: !(samples ?? []).isEmpty)
            }
            store.execute(query)
        }
    }
}
