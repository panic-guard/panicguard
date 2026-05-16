import Foundation

struct UserProfile: Codable, Equatable {
    let age: Int
    let baselineHR: Double
    let baselineVocalMetrics: VocalMetrics?

    init(age: Int, baselineHR: Double, baselineVocalMetrics: VocalMetrics? = nil) {
        self.age = age
        self.baselineHR = baselineHR
        self.baselineVocalMetrics = baselineVocalMetrics
    }
}

enum UserProfileStoreError: Error, Equatable {
    case notFound
}

protocol UserProfileStoring {
    func save(_ profile: UserProfile) throws
    func load() throws -> UserProfile
}

final class UserProfileStore: UserProfileStoring {
    private let defaults: UserDefaults
    private let key = "com.panicguard.userProfile"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(_ profile: UserProfile) throws {
        let data = try JSONEncoder().encode(profile)
        defaults.set(data, forKey: key)
    }

    func load() throws -> UserProfile {
        guard let data = defaults.data(forKey: key) else {
            throw UserProfileStoreError.notFound
        }
        return try JSONDecoder().decode(UserProfile.self, from: data)
    }
}
