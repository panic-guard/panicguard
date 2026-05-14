import XCTest
@testable import PanicGuard

final class WatchingGuardTests: XCTestCase {

    // MARK: - Sustained elevation

    func test_elevatedHR_noMovement_returnsSustained() {
        // TODO: mean HR 40 BPM over baseline, stepCount < threshold → true
    }

    func test_elevatedHR_withMovement_returnsNotSustained() {
        // TODO: high HR but steps > threshold → false (exercise, not panic)
    }

    // MARK: - Below threshold

    func test_normalHR_returnsFalse() {
        // TODO: HR within 1 SD of baseline → false
    }

    func test_mildElevation_returnsFalse() {
        // TODO: HR 10 BPM above baseline → false (below detection threshold)
    }
}
