import SwiftUI

struct OverviewView: View {
    @EnvironmentObject var vaultService: VaultService
    @State private var workouts: [PastWorkout] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                ContentUnavailableView(
                    "Could not load workouts",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if workouts.isEmpty {
                ContentUnavailableView(
                    "No workouts yet",
                    systemImage: "calendar.badge.plus",
                    description: Text("Complete a workout to see your history here.")
                )
            } else {
                List {
                    ForEach(grouped, id: \.month) { section in
                        Section(section.month) {
                            ForEach(section.items) { workout in
                                WorkoutHistoryRow(workout: workout)
                            }
                        }
                    }
                    Section {
                        Text(freshnessLabel)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 2)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Overview")
        .task { await load() }
        .refreshable { await load() }
    }

    // MARK: - Grouping

    private var grouped: [(month: String, items: [PastWorkout])] {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        var result: [(month: String, items: [PastWorkout])] = []
        for w in workouts {
            let m = fmt.string(from: w.date)
            if let idx = result.firstIndex(where: { $0.month == m }) {
                result[idx].items.append(w)
            } else {
                result.append((month: m, items: [w]))
            }
        }
        return result
    }

    // MARK: - Freshness

    private var freshnessLabel: String {
        // For each muscle, find its most recent workout (workouts is newest-first)
        var lastSeen: [String: (date: Date, effort: Int?)] = [:]
        for w in workouts {
            for muscle in w.muscles where lastSeen[muscle] == nil {
                lastSeen[muscle] = (w.date, w.effort)
            }
        }

        let calendar = Calendar.current
        let now = Date()
        let fresh = lastSeen.keys.sorted().filter { muscle in
            let (date, effort) = lastSeen[muscle]!
            let restDays = (effort ?? 0) > 6 ? 3 : 2
            let daysSince = calendar.dateComponents([.day], from: date, to: now).day ?? 0
            return daysSince >= restDays
        }

        if fresh.isEmpty { return "All muscle groups trained recently." }
        return "Fresh today: " + fresh.map { $0.capitalized }.joined(separator: " · ")
    }

    // MARK: - Loading

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let folder = vaultService.workoutsFolder
            let files = try vaultService.listFiles(inFolder: folder) { $0.hasSuffix(".md") }
            let dateFmt = DateFormatter()
            dateFmt.dateFormat = "yyyy-MM-dd"
            workouts = files.compactMap { fileName in
                guard fileName.count > 10 else { return nil }
                let dateStr = String(fileName.prefix(10))
                guard let date = dateFmt.date(from: dateStr) else { return nil }
                let (effort, muscles) = parseFrontmatter(fileName: fileName, folder: folder)
                return PastWorkout(
                    date: date,
                    displayName: workoutDisplayName(from: fileName),
                    effort: effort,
                    muscles: muscles,
                    fileName: fileName
                )
            }
            .sorted { $0.date > $1.date }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func workoutDisplayName(from fileName: String) -> String {
        var s = fileName
        if s.hasSuffix(".md") { s = String(s.dropLast(3)) }
        guard s.count > 11 else { return s }
        s = String(s.dropFirst(11)) // drop "yyyy-MM-dd-"
        return s.split(separator: "-")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    private func parseFrontmatter(fileName: String, folder: String) -> (effort: Int?, muscles: [String]) {
        guard let text = try? vaultService.readFile(relativePath: "\(folder)/\(fileName)") else {
            return (nil, [])
        }
        var inFrontmatter = false
        var inMuscles = false
        var effort: Int? = nil
        var muscles: [String] = []

        for line in text.components(separatedBy: "\n") {
            if line == "---" {
                if !inFrontmatter { inFrontmatter = true } else { break }
                continue
            }
            guard inFrontmatter else { continue }

            if line.hasPrefix("effort:") {
                inMuscles = false
                let val = line.dropFirst("effort:".count).trimmingCharacters(in: .whitespaces)
                effort = Int(val)
            } else if line.hasPrefix("muscles:") {
                inMuscles = true
            } else if inMuscles {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("- ") {
                    let raw = trimmed.dropFirst(2).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                    if raw.hasPrefix("[[") && raw.hasSuffix("]]") {
                        muscles.append(String(raw.dropFirst(2).dropLast(2)))
                    }
                } else {
                    inMuscles = false
                }
            }
        }
        return (effort, muscles)
    }
}

// MARK: - History row

private struct WorkoutHistoryRow: View {
    let workout: PastWorkout

    private var dayString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE, MMM d"
        return fmt.string(from: workout.date)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.displayName)
                    .font(.body)
                Text(dayString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let effort = workout.effort {
                Text("\(effort)/10")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(effortColor(effort), in: Capsule())
            }
        }
        .padding(.vertical, 2)
    }

    private func effortColor(_ effort: Int) -> Color {
        switch effort {
        case 0...4: return .green
        case 5...7: return .orange
        default:    return .red
        }
    }
}

// MARK: - Model

private struct PastWorkout: Identifiable {
    let id = UUID()
    let date: Date
    let displayName: String
    let effort: Int?
    let muscles: [String]
    let fileName: String
}
