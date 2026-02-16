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

**Workout template** (`templates/w-chest-t.md`):
```
- Chest press
- Incline push-ups
- Loaded stretching chest + shoulder
  - [video](../videos/chest.mov)
```

**Completed workout** (`workouts/2026-02-13-chest.md`):
```markdown
---
categories:
  - "[[workouts]]"
date: 2026-02-13
template: chest
---

# Chest — 2026-02-13

## Chest press
| Set | Reps | Weight |
|-----|------|--------|
| 1   | 10   | 135    |
```

**Daily journal** (`journals/2026-Feb-13.md`):
```markdown
---
categories:
  - "[[journals]]"
habits:
---

# Notes

# Things I did Today
```

## Architecture

| Layer | Files |
|-------|-------|
| App entry | `WorkoutMDApp.swift`, `ContentView.swift` |
| Models | `Exercise`, `WorkoutSet`, `WorkoutTemplate` |
| Views | `TemplatePickerView`, `WorkoutSessionView`, `HikeSessionView`, `ExerciseCardView`, `SetRowView`, `VideoPlayerView`, `VaultSetupView`, `SettingsView` |
| Services | `VaultService` (file I/O + bookmarks), `MarkdownParser`, `MarkdownWriter` |

## License

MIT
