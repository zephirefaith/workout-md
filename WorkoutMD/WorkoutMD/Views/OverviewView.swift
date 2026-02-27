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
                    ForEach(grouped, id: \.label) { section in
                        Section(section.label) {
                            ForEach(section.items) { workout in
                                NavigationLink(destination: WorkoutDetailView(
                                    fileName: workout.fileName,
                                    displayName: workout.displayName,
                                    date: workout.date
                                )) {
                                    WorkoutHistoryRow(workout: workout)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Overview")
        .task { await load() }
        .refreshable { await load() }
    }

    // MARK: - Grouping (ISO weeks, Mon–Sun)

    private var grouped: [(label: String, items: [PastWorkout])] {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2 // Monday
        var result: [(label: String, weekStart: Date, items: [PastWorkout])] = []
        for w in workouts { // sorted newest-first
            guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: w.date)?.start else { continue }
            if let idx = result.firstIndex(where: { $0.weekStart == weekStart }) {
                result[idx].items.append(w)
            } else {
                result.append((label: weekLabel(for: w.date, calendar: calendar), weekStart: weekStart, items: [w]))
            }
        }
        return result.map { (label: $0.label, items: $0.items) }
    }

    private func weekLabel(for date: Date, calendar: Calendar) -> String {
        guard
            let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start,
            let dateWeekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start
        else { return "" }

        let weeks = calendar.dateComponents([.weekOfYear], from: dateWeekStart, to: currentWeekStart).weekOfYear ?? 0
        switch weeks {
        case 0:  return "This week"
        case 1:  return "Last week"
        default: return "\(weeks) weeks ago"
        }
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
                let (effort, isRecovery) = parseSessionMeta(fileName: fileName, folder: folder)
                return PastWorkout(
                    date: date,
                    displayName: workoutDisplayName(from: fileName),
                    effort: effort,
                    isRecovery: isRecovery,
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

    private func parseSessionMeta(fileName: String, folder: String) -> (effort: Int?, isRecovery: Bool) {
        guard let text = try? vaultService.readFile(relativePath: "\(folder)/\(fileName)") else { return (nil, false) }
        var inFrontmatter = false
        var effort: Int? = nil
        var isRecovery = false
        for line in text.components(separatedBy: "\n") {
            if line == "---" {
                if !inFrontmatter { inFrontmatter = true } else { break }
                continue
            }
            guard inFrontmatter else { continue }
            if line.hasPrefix("effort:") {
                effort = Int(line.dropFirst("effort:".count).trimmingCharacters(in: .whitespaces))
            } else if line == "type: recovery" {
                isRecovery = true
            }
        }
        return (effort, isRecovery)
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
            if workout.isRecovery {
                Text("Recovery")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.purple, in: Capsule())
            } else if let effort = workout.effort {
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
        case 0...3: return .green
        case 4...6: return .orange
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
    let isRecovery: Bool
    let fileName: String
}
