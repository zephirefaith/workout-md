import SwiftUI

struct WorkoutDetailView: View {
    let fileName: String
    let displayName: String
    let date: Date

    @EnvironmentObject var vaultService: VaultService
    @State private var exercises: [PastExercise] = []
    @State private var selectedExercise: SelectedExerciseName? = nil
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if exercises.isEmpty {
                ContentUnavailableView(
                    "No exercises found",
                    systemImage: "doc.text",
                    description: Text("This file has no logged exercises.")
                )
            } else {
                List {
                    ForEach(exercises) { ex in
                        Section {
                            ForEach(ex.sets, id: \.self) { setLine in
                                Text(setLine)
                                    .font(.body)
                            }
                        } header: {
                            Button {
                                selectedExercise = SelectedExerciseName(name: ex.name)
                            } label: {
                                Text(ex.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .textCase(nil)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedExercise) { sel in
            NavigationStack {
                ExerciseProgressionView(exerciseName: sel.name)
            }
        }
        .task { await load() }
    }

    @MainActor
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        let folder = vaultService.workoutsFolder
        guard let text = try? vaultService.readFile(relativePath: "\(folder)/\(fileName)") else { return }
        exercises = parseExercises(from: text)
    }

    private func parseExercises(from text: String) -> [PastExercise] {
        var result: [PastExercise] = []
        var currentName: String? = nil
        var currentSets: [String] = []

        func flush() {
            if let name = currentName {
                result.append(PastExercise(name: name, sets: currentSets))
            }
        }

        for line in text.components(separatedBy: "\n") {
            if line.hasPrefix("### ") {
                flush()
                currentName = String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                currentSets = []
            } else if line.hasPrefix("## ") {
                flush()
                currentName = nil
                currentSets = []
            } else if currentName != nil, line.hasPrefix("- [") {
                guard let bracketOpen = line.firstIndex(of: "["),
                      let bracketClose = line.firstIndex(of: "]"),
                      line.index(after: bracketClose) < line.endIndex else { continue }
                let isDone = line[line.index(after: bracketOpen)] == "x"
                let content = String(line[line.index(bracketClose, offsetBy: 2)...]).trimmingCharacters(in: .whitespaces)
                currentSets.append(isDone ? "\(content) ✓" : content)
            }
        }
        flush()
        return result
    }
}

// MARK: - Local models

private struct PastExercise: Identifiable {
    let id = UUID()
    let name: String
    let sets: [String]
}

private struct SelectedExerciseName: Identifiable {
    let id = UUID()
    let name: String
}
