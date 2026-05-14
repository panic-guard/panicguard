import Foundation

/// Step 3: deterministic mapping from TriageResult → InterventionAction.
/// No LLM involved. This must remain pure and easily testable.
enum InterventionAction: String, Codable, Equatable {
    case breathingGuide
    case groundingExercise
    case emergencyContact
    case none
}

final class RuleEngine: RuleEngineProtocol {
    func selectIntervention(for result: TriageResult) -> InterventionAction {
        // TODO: implement threshold-based decision table
        fatalError("not implemented")
    }
}
