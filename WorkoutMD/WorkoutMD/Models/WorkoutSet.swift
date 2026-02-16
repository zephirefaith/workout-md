import Foundation

struct WorkoutSet: Identifiable, Codable {
    var id = UUID()
    var weight: String   // e.g. "135lbs" or "bodyweight"
    var reps: Int
    var isDone: Bool

    init(weight: String = "", reps: Int = 10, isDone: Bool = false) {
        self.weight = weight
        self.reps = reps
        self.isDone = isDone
    }
}
