import Foundation

class Exercise: Identifiable, ObservableObject {
    let id = UUID()
    let name: String
    var videoURL: URL?
    @Published var sets: [WorkoutSet]

    init(name: String, videoURL: URL? = nil, sets: [WorkoutSet] = []) {
        self.name = name
        self.videoURL = videoURL
        self.sets = sets
    }

    /// Adds a new set, pre-filling weight from the last set if available.
    func addSet() {
        let lastWeight = sets.last?.weight ?? ""
        sets.append(WorkoutSet(weight: lastWeight, reps: 10, isDone: false))
    }
}
