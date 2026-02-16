import SwiftUI

struct HikeSessionView: View {
    @EnvironmentObject var vaultService: VaultService

    @State private var distance = ""
    @State private var hikeHours: Int = 0
    @State private var hikeMinutes: Int = 0
    @State private var isSaving = false
    @State private var saveError: String? = nil
    @State private var saveSuccess = false
    @State private var showingEffortSheet = false
    @State private var effortValue: Int = 6

    private var totalMinutes: Int { hikeHours * 60 + hikeMinutes }
    private var hasInput: Bool { !distance.isEmpty || totalMinutes > 0 }

    var body: some View {
        Form {
            Section("Distance") {
                TextField("e.g. 6.2 mi", text: $distance)
                    .keyboardType(.decimalPad)
            }
            Section("Time") {
                Stepper("Hours: \(hikeHours)", value: $hikeHours, in: 0...23)
                Stepper("Minutes: \(hikeMinutes)", value: $hikeMinutes, in: 0...59)
            }
        }
        .navigationTitle("Hike")
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
                .disabled(isSaving || !hasInput)
            }
        }
        .sheet(isPresented: $showingEffortSheet) {
            EffortSheetView(title: "Hike", effort: $effortValue) {
                showingEffortSheet = false
                Task { await saveHike() }
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
        .animation(.easeInOut, value: saveSuccess)
    }

    // MARK: - Save

    @MainActor
    private func saveHike() async {
        isSaving = true
        defer { isSaving = false }

        let writer = MarkdownWriter()
        let today  = Date()

        // Capture all values needed inside the background closure
        let workoutFileName   = writer.workoutFilename(sessionName: "hike", date: today)
        let workoutsFolder    = vaultService.workoutsFolder
        let journalsFolder    = vaultService.journalsFolder
        let templatesFolder   = vaultService.templatesFolder
        let dailyNoteFilename = writer.dailyNoteFilename(for: today)
        let hikeContent     = writer.hikeFrontmatter(
                                  distance: distance,
                                  totalMinutes: totalMinutes,
                                  effort: effortValue,
                                  date: today
                              ) + "\n" + writer.serializeHike(
                                  distance: distance,
                                  totalMinutes: totalMinutes,
                                  date: today
                              )

        do {
            // All file I/O on a background thread via withVaultURL
            try await vaultService.withVaultURL { vault in
                // 1. Write hike file
                let workoutURL = vault
                    .appendingPathComponent(workoutsFolder, isDirectory: true)
                    .appendingPathComponent(workoutFileName)
                try FileManager.default.createDirectory(
                    at: workoutURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try hikeContent.write(to: workoutURL, atomically: true, encoding: .utf8)

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
