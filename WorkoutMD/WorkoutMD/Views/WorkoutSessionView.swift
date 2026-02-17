import SwiftUI

struct WorkoutSessionView: View {
    let templates: [WorkoutTemplate]
    @EnvironmentObject var vaultService: VaultService

    @State private var exercises: [Exercise] = []
    @State private var isSaving = false
    @State private var saveError: String? = nil
    @State private var saveSuccess = false
    @State private var showingEffortSheet = false
    @State private var effortValue: Int = 7

    var sessionName: String {
        templates.map(\.displayName).joined(separator: " + ")
    }

    var body: some View {
        List {
            ForEach(exercises) { exercise in
                ExerciseCardView(exercise: exercise, onRemove: {
                    exercises.removeAll { $0.id == exercise.id }
                })
            }
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.interactively)
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
        .sheet(isPresented: $showingEffortSheet) {
            EffortSheetView(title: sessionName, effort: $effortValue) {
                showingEffortSheet = false
                Task { await saveWorkout() }
            }
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
            for exercise in exercises where exercise.sets.isEmpty {
                exercise.addSet()
            }
        }
        .animation(.easeInOut, value: saveSuccess)
    }

    // MARK: - Save

    @MainActor
    private func saveWorkout() async {
        isSaving = true
        defer { isSaving = false }

        let writer  = MarkdownWriter()
        let today   = Date()
        let muscles = writer.muscleGroups(from: sessionName)

        // Capture all values needed inside the background closure
        let workoutFileName   = writer.workoutFilename(sessionName: sessionName, date: today)
        let workoutsFolder    = vaultService.workoutsFolder
        let journalsFolder    = vaultService.journalsFolder
        let templatesFolder   = vaultService.templatesFolder
        let dailyNoteFilename = writer.dailyNoteFilename(for: today)
        let workoutContent   = writer.workoutFrontmatter(
                                   sessionName: sessionName,
                                   muscles: muscles,
                                   effort: effortValue,
                                   date: today
                               ) + "\n" + writer.serializeWorkout(
                                   templateName: sessionName,
                                   exercises: exercises,
                                   date: today
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
