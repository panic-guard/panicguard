import Foundation

final class HRFeatureExtractor: HRFeatureExtracting {

    private static let sampleIntervalSeconds = 5.0  // assumed HealthKit HR sampling interval

    func extract(hrSamples: [Double], stepCount: Int) -> HRFeaturePayload {
        let mean = hrSamples.isEmpty ? 0 : hrSamples.reduce(0, +) / Double(hrSamples.count)
        let slope = Self.linearSlopeBPMPerMin(hrSamples)
        return HRFeaturePayload(
            currentHRMetrics: .init(meanBPM: mean, slopeBPMPerMin: slope),
            context: .init(isMoving: stepCount > 30, stepsLast5Min: stepCount)
        )
    }

    private static func linearSlopeBPMPerMin(_ samples: [Double]) -> Double {
        let n = Double(samples.count)
        guard n >= 2 else { return 0 }
        let dtMin = sampleIntervalSeconds / 60.0
        let xs = (0..<samples.count).map { Double($0) * dtMin }
        let xMean = xs.reduce(0, +) / n
        let yMean = samples.reduce(0, +) / n
        let numerator = zip(xs, samples).reduce(0.0) { $0 + ($1.0 - xMean) * ($1.1 - yMean) }
        let denominator = xs.reduce(0.0) { $0 + ($1 - xMean) * ($1 - xMean) }
        guard denominator > 1e-12 else { return 0 }
        return numerator / denominator
    }
}
