import HealthKit

struct iPhoneHRFetcher {
    private let store = HKHealthStore()
    private let extractor = HRFeatureExtractor()

    // Returns nil if no recent HR samples exist (Watch not worn / not synced).
    // Returning nil prevents GemmaAgent from receiving a misleading 0 BPM payload.
    func fetch() async -> HRFeaturePayload? {
        let hrSamples = await fetchHRSamples()
        guard !hrSamples.isEmpty else { return nil }
        let stepCount = await fetchStepCount()
        return extractor.extract(hrSamples: hrSamples, stepCount: stepCount)
    }

    private func fetchHRSamples() async -> [Double] {
        guard HKHealthStore.isHealthDataAvailable(),
              let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)
        else { return [] }

        let start = Date().addingTimeInterval(-300)
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
}
