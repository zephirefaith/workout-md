import Foundation

// MARK: - LastWeight

/// Stores the last-used weight and reps for a single exercise.
/// Persisted to `.obsidian/last-weights.json` in the vault.
struct LastWeight: Codable {
    var weight: String      // e.g. "135lbs" or "bodyweight"
    var reps: Int           // e.g. 10
    var updatedAt: String   // ISO date string e.g. "2026-02-18"
}

// MARK: - LastWeightsStore

typealias LastWeightsStore = [String: LastWeight]   // keyed by exercise name
