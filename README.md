# WorkoutMD

An iOS app for logging workouts directly into your [Obsidian](https://obsidian.md) vault as markdown files.

## What it does

WorkoutMD reads workout templates from your vault, lets you track sets and reps during a session, and writes the completed workout back as a markdown file — keeping your fitness data inside your Obsidian notes.

- Pick a workout template (e.g. `chest`, `back`, `legs`) from your vault's `templates/` folder
- Log sets, reps, and weight for each exercise
- Save the session as a dated markdown file in your vault's `workouts/` folder
- Hike/cardio sessions and video exercise demos are also supported
- Daily journal entries are linked via wikilinks in the YAML frontmatter

## Requirements

- iOS 17+
- Xcode 15+
- An Obsidian vault accessible from your device (e.g. via iObsidian sync)

## Project structure

```
WorkoutMD/
├── generate_xcodeproj.py   # Regenerate the Xcode project after adding Swift files
├── WorkoutMD/              # Swift source files
│   ├── Models/             # Exercise, WorkoutSet, WorkoutTemplate
│   ├── Views/              # SwiftUI views
│   ├── Services/           # VaultService, MarkdownParser, MarkdownWriter
│   └── Settings/           # SettingsView
└── WorkoutMD.xcodeproj/    # Generated Xcode project

sample_data/
├── journals/               # Example daily journal entry
├── templates/              # Example workout templates
└── videos/                 # Placeholder for exercise demo videos
```

## Building

1. Clone the repo
2. Open `WorkoutMD/WorkoutMD.xcodeproj` in Xcode
3. Select your target device or simulator and run

> If you add or remove Swift source files, regenerate the Xcode project:
> ```bash
> cd WorkoutMD/
> python3 generate_xcodeproj.py
> ```

## Vault setup

On first launch the app will ask you to select your vault folder. It stores a security-scoped bookmark so it can access the folder across app launches without prompting again.

Configure the folder names used inside your vault from the Settings screen (defaults: `journals`, `templates`, `workouts`).

## File format

### Workout template (`templates/w-chest-t.md`)

Filename convention: `w-{slug}-t.md`. Only files matching this pattern are shown in the template picker.

```
- Chest press
- Incline push-ups
- Loaded stretching chest + shoulder
  - [video](../videos/chest.mov)
```

Top-level `- Name` lines become exercises. Indented `  - [video](path)` lines attach a demo video to the preceding exercise.

### Completed workout (`workouts/2026-02-13-chest.md`)

Filename: `yyyy-MM-dd-{slug}.md` (ISO date, then slugified session name).

```markdown
---
date: 2026-02-13
categories:
  - "[[workouts]]"
muscles:
  - "[[chest]]"
effort: 7
---

## Chest — Feb 13, 2026

### Chest press
- [x] 135 × 10
- [x] 135 × 8
- [ ] bodyweight × 10
```

Frontmatter fields: `date` (ISO), `categories`, `muscles` (list of `[[muscle]]` wikilinks), `effort` (integer 0–10).
Body: `## {session} — {date}`, then `### {exercise}`, then `- [x/[ ]] weight × reps` (weight is `bodyweight` when empty).

### Hike (`workouts/2026-02-13-hike.md`)

Same frontmatter shape plus optional `distance` and `time` (minutes) fields. Muscles default to quads/hams/glutes.

```markdown
---
date: 2026-02-13
categories:
  - "[[workouts]]"
muscles:
  - "[[quads]]"
  - "[[hams]]"
  - "[[glutes]]"
effort: 6
distance: 5.2km
time: 75
---

## Hike — Feb 13, 2026

- Distance: 5.2km
- Time: 1h 15m
```

### Daily journal (`journals/2026-Feb-13.md`)

Filename: `yyyy-MMM-dd.md` (Obsidian convention — three-letter month, NOT ISO).

```markdown
---
categories:
  - "[[journals]]"
habits:
---

# Notes

# Things I did Today

![[workouts/2026-02-13-chest]]
```

The app appends an embed line (`![[workouts/…]]`) to the daily note after saving a workout.

## Architecture

| Layer | Files |
|-------|-------|
| App entry | `WorkoutMDApp.swift`, `ContentView.swift` |
| Models | `Exercise`, `WorkoutSet`, `WorkoutTemplate` |
| Views | `TemplatePickerView`, `WorkoutSessionView`, `HikeSessionView`, `ExerciseCardView`, `SetRowView`, `VideoPlayerView`, `VaultSetupView`, `SettingsView` |
| Services | `VaultService` (file I/O + bookmarks), `MarkdownParser`, `MarkdownWriter` |

## License

MIT
