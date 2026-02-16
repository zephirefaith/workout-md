import Foundation

struct MarkdownParser {

    // MARK: - Template parsing

    /// Parses a workout template file into a list of Exercise objects.
    /// Top-level `- Name` lines become exercises.
    /// Indented `  - [video](path)` lines attach a video URL to the previous exercise.
    func parseTemplate(_ text: String, relativeTo baseURL: URL? = nil) -> [Exercise] {
        var exercises: [Exercise] = []
        let lines = text.components(separatedBy: "\n")

        for line in lines {
            if line.hasPrefix("- ") {
                // Top-level exercise
                let name = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                exercises.append(Exercise(name: name))
            } else if (line.hasPrefix("  - ") || line.hasPrefix("\t- ")), !exercises.isEmpty {
                // Indented sub-item — check for video link
                let sub = line.trimmingCharacters(in: .whitespaces).dropFirst(2) // drop "- "
                if let videoURL = extractVideoURL(from: String(sub), relativeTo: baseURL) {
                    exercises[exercises.count - 1].videoURL = videoURL
                }
            }
        }

        return exercises
    }

    // MARK: - Helpers

    /// Extracts the path from a markdown link like `[video](../videos/chest.mov)`
    /// and resolves it relative to `baseURL` if provided.
    private func extractVideoURL(from text: String, relativeTo baseURL: URL?) -> URL? {
        guard let parenOpen = text.firstIndex(of: "("),
              let parenClose = text.lastIndex(of: ")"),
              parenOpen < parenClose else { return nil }

        let path = String(text[text.index(after: parenOpen)..<parenClose])

        if let base = baseURL {
            return base.deletingLastPathComponent().appendingPathComponent(path)
        }
        return URL(fileURLWithPath: path)
    }
}
