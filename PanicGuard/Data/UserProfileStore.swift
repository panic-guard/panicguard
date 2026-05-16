import Foundation

struct UserProfile: Codable, Equatable {
    let age: Int
    let baselineHR: Double              // established during onboarding
    let emergencyContactEnabled: Bool   // opt-in during onboarding; gates contact sheet in InterventionView
}

protocol UserProfileStoring {
    func save(_ profile: UserProfile) throws
    func load() throws -> UserProfile
}

final class UserProfileStore: UserProfileStoring {
    func save(_ profile: UserProfile) throws {
        // TODO: persist via UserDefaults or Core Data
        fatalError("not implemented")
    }

    func load() throws -> UserProfile {
        // TODO: load persisted profile
        fatalError("not implemented")
    }
}
