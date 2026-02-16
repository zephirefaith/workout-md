import Foundation

struct WorkoutTemplate: Identifiable {
    let id = UUID()
    let fileName: String        // e.g. "w-chest-t.md"
    let displayName: String     // e.g. "Chest" or "Hams Glutes"
    let exercises: [Exercise]

    /// Derives a display name from a template filename.
    /// "w-chest-t.md" → "Chest"
    /// "w-hams-glutes-t.md" → "Hams Glutes"
    static func displayName(from fileName: String) -> String {
        var name = fileName
        if name.hasPrefix("w-") { name = String(name.dropFirst(2)) }
        if name.hasSuffix("-t.md") { name = String(name.dropLast(5)) }
        return name
            .split(separator: "-")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }
}
