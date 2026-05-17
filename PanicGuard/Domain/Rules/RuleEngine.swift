import Foundation

/// Step 3: deterministic mapping from TriageResult → InterventionAction.
/// No LLM involved. This must remain pure and easily testable.
enum InterventionAction: String, Codable, Equatable {
    case breathingGuide
    case groundingExercise
    case emergencyContact
    case medicalAlert
    case none
}

final class RuleEngine: RuleEngineProtocol {
    func selectIntervention(for result: TriageResult) -> InterventionAction {
        // Physical anomaly check runs first — unexplained high HR that isn't panic
        // should not be treated with breathing exercises.
        if result.likelihoodPhysicalAnomaly > 0.70 && result.likelihoodPanic < 0.40 {
            return .medicalAlert
        }
        // Emergency contact only at near-certain panic AND high model confidence.
        // Medium/low confidence at this severity falls through to .breathingGuide.
        if result.likelihoodPanic >= 0.90 && result.confidence == .high {
            return .emergencyContact
        }
        if result.likelihoodPanic >= 0.75 {
            return .breathingGuide
        }
        if result.likelihoodPanic >= 0.40 {
            return .groundingExercise
        }
        return .none
    }
}
