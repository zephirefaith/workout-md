import SwiftUI

struct VaultSetupView: View {
    @EnvironmentObject var vaultService: VaultService
    @State private var showingPicker = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "folder.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("Select Your Vault")
                    .font(.title.bold())
                Text("Choose the folder where your Obsidian vault is stored.\nThis is typically in iCloud Drive.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            Button {
                showingPicker = true
            } label: {
                Label("Choose Vault Folder", systemImage: "folder")
                    .frame(maxWidth: 280)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .sheet(isPresented: $showingPicker) {
            FolderPickerRepresentable { url in
                vaultService.saveBookmark(for: url)
                showingPicker = false
            }
        }
    }
}

// MARK: - UIDocumentPickerViewController wrapper

struct FolderPickerRepresentable: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            _ = url.startAccessingSecurityScopedResource()
            onPick(url)
        }
    }
}
