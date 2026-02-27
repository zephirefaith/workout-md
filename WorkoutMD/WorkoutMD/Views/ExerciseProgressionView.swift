import SwiftUI
import Charts

struct ExerciseDataPoint: Identifiable {
    var id = UUID()
    var date: Date
    var maxWeight: Double?  // nil = bodyweight session
    var maxReps: Int
}

struct ExerciseProgressionView: View {
    let exerciseName: String
    @EnvironmentObject var vaultService: VaultService
    @State private var dataPoints: [ExerciseDataPoint] = []
    @State private var isLoading = true

    /// True when no session has a numeric weight — chart switches to reps axis.
    private var usesReps: Bool {
        !dataPoints.contains { $0.maxWeight != nil }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if dataPoints.isEmpty {
                ContentUnavailableView(
                    "No data yet",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Complete a session with this exercise to see progression.")
                )
            } else if usesReps {
                Chart(dataPoints) { pt in
                    LineMark(
                        x: .value("Date", pt.date),
                        y: .value("Reps", pt.maxReps)
                    )
                    PointMark(
                        x: .value("Date", pt.date),
                        y: .value("Reps", pt.maxReps)
                    )
                }
                .chartYAxisLabel("Reps")
                .padding()
            } else {
                Chart(dataPoints.filter { $0.maxWeight != nil }) { pt in
                    LineMark(
                        x: .value("Date", pt.date),
                        y: .value("Weight", pt.maxWeight!)
                    )
                    PointMark(
                        x: .value("Date", pt.date),
                        y: .value("Weight", pt.maxWeight!)
                    )
                }
                .chartYAxisLabel("Weight")
                .padding()
            }
        }
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @MainActor
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        let folder = vaultService.workoutsFolder
        guard let files = try? vaultService.listFiles(inFolder: folder, matching: { $0.hasSuffix(".md") }) else { return }
        let parser = MarkdownParser()
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        var points: [ExerciseDataPoint] = []
        for fileName in files {
            guard fileName.count > 10,
                  let date = dateFmt.date(from: String(fileName.prefix(10))),
                  let text = try? vaultService.readFile(relativePath: "\(folder)/\(fileName)") else { continue }
            let sets = parser.parseSets(from: text, forExercise: exerciseName)
            guard !sets.isEmpty else { continue }
            let maxWeight = sets.compactMap { $0.weight }.max()
            let maxReps = sets.map { $0.reps }.max() ?? 0
            points.append(ExerciseDataPoint(date: date, maxWeight: maxWeight, maxReps: maxReps))
        }
        dataPoints = points.sorted { $0.date < $1.date }
    }
}
