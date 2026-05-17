import Foundation

struct UserProfile: Codable, Equatable {
    let age: Int
    let baselineHR: Double
    let baselineVocalMetrics: VocalMetrics?
    let emergencyContactEnabled: Bool
    let emergencyContactPhone: String?

    init(
        age: Int,
        baselineHR: Double,
        baselineVocalMetrics: VocalMetrics? = nil,
        emergencyContactEnabled: Bool = false,
        emergencyContactPhone: String? = nil
    ) {
        self.age = age
        self.baselineHR = baselineHR
        self.baselineVocalMetrics = baselineVocalMetrics
        self.emergencyContactEnabled = emergencyContactEnabled
        self.emergencyContactPhone = emergencyContactPhone
    }

    // Provides defaults for emergencyContact fields absent in older saved data.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        age = try c.decode(Int.self, forKey: .age)
        baselineHR = try c.decode(Double.self, forKey: .baselineHR)
        baselineVocalMetrics = try c.decodeIfPresent(VocalMetrics.self, forKey: .baselineVocalMetrics)
        emergencyContactEnabled = (try? c.decode(Bool.self, forKey: .emergencyContactEnabled)) ?? false
        emergencyContactPhone = try? c.decode(String.self, forKey: .emergencyContactPhone)
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
