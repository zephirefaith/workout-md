import SwiftUI

private let recoveryTypes = [
    "Sauna",
    "Leg Compression",
    "Massage",
    "Ice Bath",
    "Stretching",
    "Foam Rolling",
]

struct RecoverySessionView: View {
    @EnvironmentObject var vaultService: VaultService

    @State private var selectedType: String? = nil
    @State private var isSaving = false
    @State private var saveError: String? = nil
    @State private var saveSuccess = false

    var body: some View {
        List(recoveryTypes, id: \.self) { type in
            Button {
                selectedType = (selectedType == type) ? nil : type
            } label: {
                HStack {
                    Text(type)
                        .foregroundStyle(.primary)
                    Spacer()
                    if selectedType == type {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.purple)
                    }
                }
            }
        }
        .navigationTitle("Recovery")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Log").bold()
                    }
                }
                .disabled(isSaving || selectedType == nil)
            }
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
    private func save() async {
        guard let type = selectedType else { return }
        isSaving = true
        defer { isSaving = false }

        let writer = MarkdownWriter()
        let today = Date()
        let fileName = writer.workoutFilename(sessionName: type, date: today)
        let workoutsFolder = vaultService.workoutsFolder
        let journalsFolder = vaultService.journalsFolder
        let templatesFolder = vaultService.templatesFolder
        let dailyNoteFilename = writer.dailyNoteFilename(for: today)
        let content = writer.recoveryFrontmatter(recoveryType: type, date: today)
            + "\n"
            + writer.serializeRecovery(recoveryType: type, date: today)

        do {
            try await vaultService.withVaultURL { vault in
                let fileURL = vault
                    .appendingPathComponent(workoutsFolder, isDirectory: true)
                    .appendingPathComponent(fileName)
                try FileManager.default.createDirectory(
                    at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try content.write(to: fileURL, atomically: true, encoding: .utf8)

                let dailyNoteURL = vault
                    .appendingPathComponent(journalsFolder, isDirectory: true)
                    .appendingPathComponent(dailyNoteFilename)
                let tmplURL = vault
                    .appendingPathComponent(templatesFolder, isDirectory: true)
                    .appendingPathComponent("journal-t.md")
                let noteContent = (try? String(contentsOf: dailyNoteURL, encoding: .utf8))
                    ?? (try? String(contentsOf: tmplURL, encoding: .utf8))
                    ?? ""
                let updated = writer.appendEmbedIfNeeded(
                    to: noteContent,
                    workoutsFolder: workoutsFolder,
                    workoutFilename: fileName
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
