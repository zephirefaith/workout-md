import Foundation
import UIKit

@MainActor
class VaultService: ObservableObject {

    // MARK: - Published State

    @Published var vaultURL: URL? = nil

    private let bookmarkKey = "vaultBookmark"
    private let journalsFolderKey = "journalsFolder"
    private let templatesFolderKey = "templatesFolder"
    private let workoutsFolderKey = "workoutsFolder"

    // MARK: - Settings

    var journalsFolder: String {
        get { UserDefaults.standard.string(forKey: journalsFolderKey) ?? "journals" }
        set { UserDefaults.standard.set(newValue, forKey: journalsFolderKey) }
    }

    var templatesFolder: String {
        get { UserDefaults.standard.string(forKey: templatesFolderKey) ?? "templates" }
        set { UserDefaults.standard.set(newValue, forKey: templatesFolderKey) }
    }

    var workoutsFolder: String {
        get { UserDefaults.standard.string(forKey: workoutsFolderKey) ?? "workouts" }
        set { UserDefaults.standard.set(newValue, forKey: workoutsFolderKey) }
    }

    // MARK: - Init

    init() {
        resolveBookmark()
    }

    // MARK: - Bookmark Management

    func saveBookmark(for url: URL) {
        do {
            let bookmark = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
            vaultURL = url
        } catch {
            print("VaultService: failed to save bookmark: \(error)")
        }
    }

    private func resolveBookmark() {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return }
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                saveBookmark(for: url)
            }
            vaultURL = url
        } catch {
            print("VaultService: failed to resolve bookmark: \(error)")
        }
    }

    // MARK: - Background file I/O

    /// Runs `body` on a background thread with security-scoped access to the vault URL.
    /// Use this for all save operations to keep the main thread free.
    nonisolated func withVaultURL(
        _ body: @Sendable @escaping (URL) throws -> Void
    ) async throws {
        guard let vault = await vaultURL else { throw VaultError.noVaultSelected }
        try await Task.detached(priority: .userInitiated) {
            let accessed = vault.startAccessingSecurityScopedResource()
            defer { if accessed { vault.stopAccessingSecurityScopedResource() } }
            try body(vault)
        }.value
    }

    // MARK: - File I/O (main-thread helpers, use withVaultURL for bulk saves)

    func readFile(relativePath: String) throws -> String {
        guard let vault = vaultURL else { throw VaultError.noVaultSelected }
        let fileURL = vault.appendingPathComponent(relativePath)
        let accessed = vault.startAccessingSecurityScopedResource()
        defer { if accessed { vault.stopAccessingSecurityScopedResource() } }
        return try String(contentsOf: fileURL, encoding: .utf8)
    }

    func writeFile(relativePath: String, content: String) throws {
        guard let vault = vaultURL else { throw VaultError.noVaultSelected }
        let fileURL = vault.appendingPathComponent(relativePath)
        let accessed = vault.startAccessingSecurityScopedResource()
        defer { if accessed { vault.stopAccessingSecurityScopedResource() } }
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func fileExists(relativePath: String) -> Bool {
        guard let vault = vaultURL else { return false }
        let fileURL = vault.appendingPathComponent(relativePath)
        let accessed = vault.startAccessingSecurityScopedResource()
        defer { if accessed { vault.stopAccessingSecurityScopedResource() } }
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    /// Returns file names matching a pattern inside a folder.
    func listFiles(inFolder folder: String, matching predicate: (String) -> Bool) throws -> [String] {
        guard let vault = vaultURL else { throw VaultError.noVaultSelected }
        let folderURL = vault.appendingPathComponent(folder)
        let accessed = vault.startAccessingSecurityScopedResource()
        defer { if accessed { vault.stopAccessingSecurityScopedResource() } }
        let contents = try FileManager.default.contentsOfDirectory(atPath: folderURL.path)
        return contents.filter(predicate).sorted()
    }

    /// Returns the URL for a relative path inside the vault (for AVPlayer use).
    func resolveURL(relativePath: String) -> URL? {
        guard let vault = vaultURL else { return nil }
        return vault.appendingPathComponent(relativePath)
    }
}

// MARK: - Errors

enum VaultError: LocalizedError {
    case noVaultSelected

    var errorDescription: String? {
        switch self {
        case .noVaultSelected: return "No vault folder selected. Open Settings to choose your vault."
        }
    }
}
