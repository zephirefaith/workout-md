import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var vaultService: VaultService
    @State private var showingFolderPicker = false
    @State private var journalsFolder: String = ""
    @State private var templatesFolder: String = ""
    @State private var workoutsFolder: String = ""

    var body: some View {
        Form {
            Section("Vault") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Vault Folder")
                            .font(.body)
                        if let url = vaultService.vaultURL {
                            Text(url.lastPathComponent)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Not selected")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    Spacer()
                    Button("Choose…") {
                        showingFolderPicker = true
                    }
                    .buttonStyle(.bordered)
                }
            }

            Section("Paths (relative to vault)") {
                LabeledContent("Journals") {
                    TextField("journals", text: $journalsFolder)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                LabeledContent("Templates") {
                    TextField("templates", text: $templatesFolder)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                LabeledContent("Workouts") {
                    TextField("workouts", text: $workoutsFolder)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }

            Section {
                Button("Save") {
                    vaultService.journalsFolder  = journalsFolder.isEmpty  ? "journals"  : journalsFolder
                    vaultService.templatesFolder = templatesFolder.isEmpty ? "templates" : templatesFolder
                    vaultService.workoutsFolder  = workoutsFolder.isEmpty  ? "workouts"  : workoutsFolder
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            journalsFolder  = vaultService.journalsFolder
            templatesFolder = vaultService.templatesFolder
            workoutsFolder  = vaultService.workoutsFolder
        }
        .sheet(isPresented: $showingFolderPicker) {
            FolderPickerRepresentable { url in
                vaultService.saveBookmark(for: url)
                showingFolderPicker = false
            }
        }
    }
}
