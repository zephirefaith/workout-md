import SwiftUI

struct TemplatePickerView: View {
    @EnvironmentObject var vaultService: VaultService
    @State private var templates: [WorkoutTemplate] = []
    @State private var errorMessage: String? = nil
    @State private var isLoading = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var navigateToSession = false
    @State private var navigateToHike = false

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    private var selectedTemplates: [WorkoutTemplate] {
        templates.filter { selectedIDs.contains($0.id) }
    }

    private var startButtonLabel: String {
        let names = selectedTemplates.map(\.displayName).joined(separator: " + ")
        return names.isEmpty ? "Start Workout" : "Start Workout (\(names))"
    }

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else if let error = errorMessage {
                ContentUnavailableView(
                    "Could not load templates",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
                .padding()
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(templates) { template in
                        Button {
                            toggleSelection(template)
                        } label: {
                            TemplateCard(
                                name: template.displayName,
                                isSelected: selectedIDs.contains(template.id)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        navigateToHike = true
                    } label: {
                        HikeCard()
                    }
                    .buttonStyle(.plain)
                }
                .padding()

                if templates.isEmpty {
                    Text("Add workout templates (w-*-t.md) to your templates folder.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
        .navigationTitle("Today's Workout")
        .navigationDestination(isPresented: $navigateToSession) {
            WorkoutSessionView(templates: selectedTemplates)
        }
        .navigationDestination(isPresented: $navigateToHike) {
            HikeSessionView()
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                navigateToSession = true
            } label: {
                Text(startButtonLabel)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedIDs.isEmpty ? Color.gray.opacity(0.4) : Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
            .disabled(selectedIDs.isEmpty)
            .background(.ultraThinMaterial)
        }
        .task {
            await loadTemplates()
        }
        .refreshable {
            await loadTemplates()
        }
    }

    private func toggleSelection(_ template: WorkoutTemplate) {
        if selectedIDs.contains(template.id) {
            selectedIDs.remove(template.id)
        } else {
            selectedIDs.insert(template.id)
        }
    }

    @MainActor
    private func loadTemplates() async {
        isLoading = true
        errorMessage = nil
        selectedIDs = []
        defer { isLoading = false }

        do {
            let folder = vaultService.templatesFolder
            let files = try vaultService.listFiles(inFolder: folder) { name in
                name.hasPrefix("w-") && name.hasSuffix("-t.md")
            }

            let parser = MarkdownParser()
            templates = files.map { fileName -> WorkoutTemplate in
                let displayName = WorkoutTemplate.displayName(from: fileName)
                let relativePath = "\(folder)/\(fileName)"
                let text = (try? vaultService.readFile(relativePath: relativePath)) ?? ""
                let vaultURL = vaultService.vaultURL?
                    .appendingPathComponent(relativePath)
                let exercises = parser.parseTemplate(text, relativeTo: vaultURL)
                return WorkoutTemplate(
                    fileName: fileName,
                    displayName: displayName,
                    exercises: exercises
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Template Card

private struct TemplateCard: View {
    let name: String
    let isSelected: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.blue.gradient)
            .frame(height: 100)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: iconName(for: name))
                        .font(.title2)
                    Text(name)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.white)
                .padding(12)
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .padding(8)
                }
            }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.white, lineWidth: 2.5)
                }
            }
    }

    private func iconName(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("chest") { return "figure.strengthtraining.traditional" }
        if lower.contains("back") { return "figure.strengthtraining.functional" }
        if lower.contains("quad") || lower.contains("leg") { return "figure.walk" }
        if lower.contains("abs") || lower.contains("core") { return "figure.core.training" }
        if lower.contains("ham") || lower.contains("glute") { return "figure.run" }
        return "dumbbell"
    }
}

// MARK: - Hike Card

private struct HikeCard: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.green.gradient)
            .frame(height: 100)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "figure.hiking")
                        .font(.title2)
                    Text("Hike")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .padding(12)
            }
    }
}
