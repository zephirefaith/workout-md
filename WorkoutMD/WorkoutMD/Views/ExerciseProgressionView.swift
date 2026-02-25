import SwiftUI
import Charts

struct ExerciseDataPoint: Identifiable {
    var id = UUID()
    var date: Date
    var maxWeight: Double
}

struct ExerciseProgressionView: View {
    let exerciseName: String
    @EnvironmentObject var vaultService: VaultService
    @State private var dataPoints: [ExerciseDataPoint] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if dataPoints.isEmpty {
                ContentUnavailableView(
                    "No weight data",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Complete a session with numeric weights to see progression.")
                )
            } else {
                Chart(dataPoints) { pt in
                    LineMark(
                        x: .value("Date", pt.date),
                        y: .value("Weight", pt.maxWeight)
                    )
                    PointMark(
                        x: .value("Date", pt.date),
                        y: .value("Weight", pt.maxWeight)
                    )
                }
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
            let weights = parser.parseSets(from: text, forExercise: exerciseName).compactMap { $0.weight }
            guard let maxWeight = weights.max() else { continue }
            points.append(ExerciseDataPoint(date: date, maxWeight: maxWeight))
        }
        dataPoints = points.sorted { $0.date < $1.date }
    }
}
