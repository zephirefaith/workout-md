import Foundation

struct MarkdownWriter {

    // MARK: - Frontmatter

    /// YAML frontmatter block for a template-based workout file.
    func workoutFrontmatter(sessionName: String, muscles: [String], effort: Int, date: Date, duration: Int = 0) -> String {
        let muscleLines = muscles.map { "  - \"[[\($0)]]\"" }.joined(separator: "\n")
        var lines = [
            "---",
            "date: \(isoDateString(for: date))",
            "categories:",
            "  - \"[[workouts]]\"",
            "muscles:",
            muscleLines,
            "effort: \(effort)"
        ]
        if duration > 0 { lines.append("duration: \(duration)") }
        lines.append("---")
        return lines.joined(separator: "\n")
    }

    /// YAML frontmatter block for a hike file.
    func hikeFrontmatter(distance: String, totalMinutes: Int, effort: Int, date: Date) -> String {
        var lines = [
            "---",
            "date: \(isoDateString(for: date))",
            "categories:",
            "  - \"[[workouts]]\"",
            "muscles:",
            "  - \"[[quads]]\"",
            "  - \"[[hams]]\"",
            "  - \"[[glutes]]\"",
            "effort: \(effort)"
        ]
        if !distance.isEmpty  { lines.append("distance: \(distance)") }
        if totalMinutes > 0   { lines.append("time: \(totalMinutes)") }
        lines.append("---")
        return lines.joined(separator: "\n")
    }

    /// YAML frontmatter block for a recovery file.
    func recoveryFrontmatter(recoveryType: String, date: Date) -> String {
        return [
            "---",
            "date: \(isoDateString(for: date))",
            "categories:",
            "  - \"[[workouts]]\"",
            "type: recovery",
            "---"
        ].joined(separator: "\n")
    }

    // MARK: - Body serialization

    /// Produces the markdown body for a template-based session (no frontmatter).
    func serializeWorkout(templateName: String, exercises: [Exercise], date: Date, duration: Int = 0) -> String {
        let dateStr = formattedDate(date)
        var lines: [String] = []

        lines.append("## \(templateName) — \(dateStr)")
        if duration > 0 { lines.append("- Duration: \(formatMinutes(duration))") }
        lines.append("")

        for exercise in exercises {
            lines.append("### \(exercise.name)")
            if exercise.sets.isEmpty {
                lines.append("- [ ] ")
            } else {
                for set in exercise.sets {
                    let check = set.isDone ? "[x]" : "[ ]"
                    let weight = set.weight.isEmpty ? "bodyweight" : set.weight
                    lines.append("- \(check) \(weight) × \(set.reps)")
                }
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    /// Produces the markdown body for a recovery session (no frontmatter).
    func serializeRecovery(recoveryType: String, date: Date) -> String {
        return "## \(recoveryType) — \(formattedDate(date))\n"
    }

    /// Produces the markdown body for a hike (no frontmatter).
    func serializeHike(distance: String, totalMinutes: Int, date: Date) -> String {
        let dateStr = formattedDate(date)
        var lines: [String] = []
        lines.append("## Hike — \(dateStr)")
        lines.append("")
        if !distance.isEmpty  { lines.append("- Distance: \(distance)") }
        if totalMinutes > 0   { lines.append("- Time: \(formatMinutes(totalMinutes))") }
        lines.append("")
        return lines.joined(separator: "\n")
    }

    // MARK: - Daily note embed

    /// Appends `![[workouts/YYYY-MM-DD-name]]` to the daily note if not already present.
    func appendEmbedIfNeeded(to dailyNote: String,
                             workoutsFolder: String,
                             workoutFilename: String) -> String {
        let stem = workoutFilename.hasSuffix(".md")
            ? String(workoutFilename.dropLast(3))
            : workoutFilename
        let embedLine = "![[" + workoutsFolder + "/" + stem + "]]"

        if dailyNote.contains(embedLine) { return dailyNote }

        var result = dailyNote
        if !result.hasSuffix("\n") { result += "\n" }
        result += "\n" + embedLine + "\n"
        return result
    }

    // MARK: - Filenames

    /// `2026-Feb-11.md` — Obsidian daily note filename (MMM = abbreviated month).
    func dailyNoteFilename(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MMM-dd"
        return f.string(from: date) + ".md"
    }

    /// `2026-02-11-back-abs.md` — slugified workout file name.
    func workoutFilename(sessionName: String, date: Date) -> String {
        let slug = slugify(sessionName)
        return "\(isoDateString(for: date))-\(slug.isEmpty ? "workout" : slug).md"
    }

    // MARK: - Helpers

    /// Maps a session name (e.g. "Back + Abs") to muscle-group tags.
    func muscleGroups(from name: String) -> [String] {
        name.components(separatedBy: " + ")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .flatMap { part -> [String] in
                if part.contains("hike")                               { return ["quads", "hams", "glutes"] }
                if part.contains("leg") || part.contains("quad")       { return ["legs"] }
                if part.contains("ham") || part.contains("glute")      { return ["legs"] }
                if part.contains("chest")                              { return ["chest"] }
                if part.contains("back")                               { return ["back"] }
                if part.contains("shoulder")                           { return ["shoulders"] }
                if part.contains("arm") || part.contains("bicep")
                    || part.contains("tricep")                         { return ["arms"] }
                if part.contains("abs")                                { return ["abs"] }
                if part.contains("core")                               { return ["core"] }
                return [part]
            }
    }

    /// `"Feb 11, 2026"` — human-readable date used in body headings.
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    /// `"2026-02-11"` — ISO date string used in filenames and frontmatter.
    func isoDateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// Formats total minutes to a human-readable string: 83 → "1h 23m", 60 → "1h", 45 → "45m".
    func formatMinutes(_ total: Int) -> String {
        guard total > 0 else { return "" }
        let hours = total / 60
        let mins  = total % 60
        switch (hours, mins) {
        case (0, _): return "\(mins)m"
        case (_, 0): return "\(hours)h"
        default:     return "\(hours)h \(mins)m"
        }
    }

    /// Converts a session name to a URL-safe slug: "Back + Abs" → "back-abs".
    private func slugify(_ name: String) -> String {
        var s = name.lowercased()
        s = s.replacingOccurrences(of: "+", with: "-")
        s = s.replacingOccurrences(of: " ", with: "-")
        s = s.replacingOccurrences(of: "-{2,}", with: "-", options: .regularExpression)
        s = s.filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return s.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
