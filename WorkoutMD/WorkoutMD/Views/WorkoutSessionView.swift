import SwiftUI

struct WorkoutSessionView: View {
    let templates: [WorkoutTemplate]
    @EnvironmentObject var vaultService: VaultService

    @State private var exercises: [Exercise] = []
    @State private var isSaving = false
    @State private var saveError: String? = nil
    @State private var saveSuccess = false
    @State private var showingEffortSheet = false
    @State private var showingElapsedSheet = false
    @State private var effortValue: Int = 7

    // MARK: - Timers
    @Environment(\.scenePhase) private var scenePhase
    @State private var elapsed: Int = 0
    @State private var restRemaining: Int = 0
    @State private var sessionStart = Date()
    @State private var restStart: Date? = nil
    private let restDuration = 90
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var sessionName: String {
        templates.map(\.displayName).joined(separator: " + ")
    }

    var body: some View {
        List {
            ForEach(exercises) { exercise in
                ExerciseCardView(exercise: exercise, onRemove: {
                    exercises.removeAll { $0.id == exercise.id }
                }, onSetDone: {
                    restStart = Date()
                    restRemaining = restDuration
                })
            }
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            if restRemaining > 0 {
                HStack {
                    Image(systemName: "timer")
                    Text("Rest  ·  \(formatRest(restRemaining))")
                        .font(.headline.monospacedDigit())
                    Spacer()
                    Button("Skip") { restStart = nil; restRemaining = 0 }
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal).padding(.bottom, 8)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
            }
        }
        .navigationTitle(sessionName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showingElapsedSheet = true
                } label: {
                    Label(formatElapsed(elapsed), systemImage: "timer")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingEffortSheet = true
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Save").bold()
                    }
                }
                .disabled(isSaving)
            }
        }
        .onReceive(ticker) { _ in
            updateTimers()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active { updateTimers() }
        }
        .sheet(isPresented: $showingEffortSheet) {
            EffortSheetView(title: sessionName, effort: $effortValue) {
                showingEffortSheet = false
                Task { await saveWorkout() }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingElapsedSheet) {
            ElapsedTimerView(elapsed: elapsed, sessionName: sessionName)
                .presentationDetents([.medium])
        }
        .alert("Save Error", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
        .overlay {
            if saveSuccess {
                SaveSuccessBanner()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            exercises = templates.flatMap(\.exercises)
            let lastWeights = vaultService.readLastWeights()
            for exercise in exercises where exercise.sets.isEmpty {
                if let last = lastWeights[exercise.name] {
                    // Pre-seed the first set with last-used weight & reps
                    let seededSet = WorkoutSet(weight: last.weight, reps: last.reps, isDone: false)
                    exercise.sets.append(seededSet)
                } else {
                    exercise.addSet()
                }
            }
        }
        .animation(.easeInOut, value: saveSuccess)
    }

    // MARK: - Timer logic

    private func updateTimers() {
        elapsed = Int(Date().timeIntervalSince(sessionStart))
        if let start = restStart {
            let remaining = restDuration - Int(Date().timeIntervalSince(start))
            restRemaining = max(0, remaining)
            if restRemaining == 0 { restStart = nil }
        }
    }

    private func formatElapsed(_ s: Int) -> String {
        "\(s / 60):\(String(format: "%02d", s % 60))"
    }

    private func formatRest(_ s: Int) -> String {
        "\(s / 60):\(String(format: "%02d", s % 60))"
    }

    // MARK: - Save

    @MainActor
    private func saveWorkout() async {
        isSaving = true
        defer { isSaving = false }

        let writer  = MarkdownWriter()
        let today   = Date()
        let muscles = writer.muscleGroups(from: sessionName)
        let durationMinutes = max(1, elapsed / 60)

        // Capture all values needed inside the background closure
        let workoutFileName   = writer.workoutFilename(sessionName: sessionName, date: today)
        let workoutsFolder    = vaultService.workoutsFolder
        let journalsFolder    = vaultService.journalsFolder
        let templatesFolder   = vaultService.templatesFolder
        let dailyNoteFilename = writer.dailyNoteFilename(for: today)
        // Capture last-used weights from completed sets for persistence
        let updatedLastWeights: LastWeightsStore = {
            let today = ISO8601DateFormatter().string(from: Date()).prefix(10).description
            var store = vaultService.readLastWeights()
            for exercise in exercises {
                // Use the last completed set, fall back to last set if none marked done
                let completedSets = exercise.sets.filter { $0.isDone }
                if let last = completedSets.last ?? exercise.sets.last,
                   !last.weight.trimmingCharacters(in: .whitespaces).isEmpty {
                    store[exercise.name] = LastWeight(
                        weight: last.weight,
                        reps: last.reps,
                        updatedAt: today
                    )
                }
            }
            return store
        }()

        let workoutContent   = writer.workoutFrontmatter(
                                   sessionName: sessionName,
                                   muscles: muscles,
                                   effort: effortValue,
                                   date: today,
                                   duration: durationMinutes
                               ) + "\n" + writer.serializeWorkout(
                                   templateName: sessionName,
                                   exercises: exercises,
                                   date: today,
                                   duration: durationMinutes
                               )

        do {
            // All file I/O on a background thread via withVaultURL
            try await vaultService.withVaultURL { vault in
                // 1. Write workout file
                let workoutURL = vault
                    .appendingPathComponent(workoutsFolder, isDirectory: true)
                    .appendingPathComponent(workoutFileName)
                try FileManager.default.createDirectory(
                    at: workoutURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try workoutContent.write(to: workoutURL, atomically: true, encoding: .utf8)

                // 2. Read or create daily note content
                let dailyNoteURL = vault
                    .appendingPathComponent(journalsFolder, isDirectory: true)
                    .appendingPathComponent(dailyNoteFilename)
                let tmplURL = vault
                    .appendingPathComponent(templatesFolder, isDirectory: true)
                    .appendingPathComponent("journal-t.md")
                let noteContent = (try? String(contentsOf: dailyNoteURL, encoding: .utf8))
                    ?? (try? String(contentsOf: tmplURL, encoding: .utf8))
                    ?? ""

                // 3. Append embed and write daily note
                let updated = writer.appendEmbedIfNeeded(
                    to: noteContent,
                    workoutsFolder: workoutsFolder,
                    workoutFilename: workoutFileName
                )
                try FileManager.default.createDirectory(
                    at: dailyNoteURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try updated.write(to: dailyNoteURL, atomically: true, encoding: .utf8)

                // 4. Persist last-used weights for next session pre-fill
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let weightsData = try encoder.encode(updatedLastWeights)
                let weightsContent = String(data: weightsData, encoding: .utf8) ?? "{}"
                let weightsURL = vault.appendingPathComponent("_app_data/last-weights.json")
                try FileManager.default.createDirectory(
                    at: weightsURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try weightsContent.write(to: weightsURL, atomically: true, encoding: .utf8)
            }

            saveSuccess = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saveSuccess = false }
        } catch {
            saveError = error.localizedDescription
        }
    }
}

// MARK: - Effort Sheet

struct EffortSheetView: View {
    let title: String
    @Binding var effort: Int
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 6) {
                Text("Rate Your Effort")
                    .font(.headline)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 24)

            Text("\(effort) / 10")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()

            Slider(
                value: Binding(get: { Double(effort) }, set: { effort = Int($0.rounded()) }),
                in: 0...10,
                step: 1
            )
            .padding(.horizontal, 32)

            Button("Log Workout") {
                onSave()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
    }
}

// MARK: - Elapsed Timer Sheet

struct ElapsedTimerView: View {
    let elapsed: Int
    let sessionName: String

    private var hours: Int   { elapsed / 3600 }
    private var minutes: Int { (elapsed % 3600) / 60 }
    private var seconds: Int { elapsed % 60 }

    private var timeString: String {
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Session Time")
                .font(.headline)
                .padding(.top, 28)
            Text(sessionName)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(timeString)
                .font(.system(size: 72, weight: .thin, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)

            Spacer()
        }
    }
}

// MARK: - Success Banner

struct SaveSuccessBanner: View {
    var body: some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Workout saved!")
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: Capsule())
            .padding(.top, 8)
            Spacer()
        }
    }
}
