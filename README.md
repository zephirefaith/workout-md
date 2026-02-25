# WorkoutMD

An iOS app for logging workouts directly into your [Obsidian](https://obsidian.md) vault as markdown files.

## What it does

WorkoutMD reads workout templates from your vault, lets you track sets and reps during a live session, and writes the completed session back as a dated markdown file — keeping all fitness data inside your Obsidian notes.

- Pick one or more workout templates from your vault's `templates/` folder (multi-select for combo sessions)
- Log sets, reps, and weight for each exercise; weights are pre-filled from the previous session
- Save the session: writes a workout file, updates the daily journal, and persists last-used weights
- Tap any exercise name to see a weight-over-time progression chart (Swift Charts)
- Browse session history in the Overview tab; tap a past workout to see the full set log
- Hike/cardio and recovery session types are also supported
- Exercise demo videos can be attached to template entries and played in-app

## Requirements

- iOS 17+
- Xcode 15+
- An Obsidian vault accessible from your device (e.g. via iObsidian sync)

## Project structure

```
WorkoutMD/
├── generate_xcodeproj.py          # Regenerate Xcode project after adding Swift files
├── WorkoutMD/                     # Swift source root
│   ├── WorkoutMDApp.swift         # @main entry point; injects VaultService
│   ├── ContentView.swift          # Root TabView (Home + Overview tabs)
│   ├── Models/
│   │   ├── Exercise.swift         # ObservableObject; mutable during a session
│   │   ├── WorkoutSet.swift       # Value type; one logged set (weight, reps, isDone)
│   │   ├── WorkoutTemplate.swift  # Loaded from a template file; owns [Exercise]
│   │   └── LastWeight.swift       # Codable; persisted weight/reps per exercise name
│   ├── Views/
│   │   ├── TemplatePickerView.swift       # Home tab: grid of template cards → start session
│   │   ├── WorkoutSessionView.swift       # Live session: exercise list, timers, save flow
│   │   ├── ExerciseCardView.swift         # One exercise section with its sets + header
│   │   ├── SetRowView.swift               # One set row: weight field, reps stepper, done toggle
│   │   ├── HikeSessionView.swift          # Cardio session entry: distance + time
│   │   ├── RecoverySessionView.swift      # Recovery session entry: type picker
│   │   ├── OverviewView.swift             # History tab: workouts grouped by week
│   │   ├── WorkoutDetailView.swift        # Past workout detail: exercises + sets
│   │   ├── ExerciseProgressionView.swift  # Swift Charts sheet: max weight over time
│   │   ├── VideoPlayerView.swift          # AVPlayer sheet for exercise demo videos
│   │   └── VaultSetupView.swift           # Shown on first launch to pick vault folder
│   ├── Services/
│   │   ├── VaultService.swift     # File I/O, security-scoped bookmarks, last-weights store
│   │   ├── MarkdownParser.swift   # Template parser + history (set) parser
│   │   └── MarkdownWriter.swift   # Produces all markdown output (frontmatter, body, filenames)
│   └── Settings/
│       └── SettingsView.swift     # Folder name overrides (journals, templates, workouts)
└── WorkoutMD.xcodeproj/           # Generated Xcode project (do not edit by hand)

sample_data/
├── journals/                      # Example daily journal entry
├── templates/                     # Example workout templates
└── videos/                        # Placeholder for exercise demo videos
```

## Architecture

### Layers

```
┌─────────────────────────────────────────────────────────┐
│  Views  (SwiftUI, read models via @ObservedObject /      │
│          @EnvironmentObject; no direct file I/O)         │
├─────────────────────────────────────────────────────────┤
│  Models  (Exercise, WorkoutSet, WorkoutTemplate,          │
│           LastWeight — pure data, no I/O)                │
├─────────────────────────────────────────────────────────┤
│  Services  (VaultService, MarkdownParser,                 │
│             MarkdownWriter — all I/O is here)            │
└─────────────────────────────────────────────────────────┘
```

### Models

| Type | Kind | Notes |
|------|------|-------|
| `Exercise` | `class`, `ObservableObject` | Mutable during a session; `@Published var sets` so `ExerciseCardView` reacts to changes |
| `WorkoutSet` | `struct`, `Codable` | Value type — weight (String), reps (Int), isDone (Bool) |
| `WorkoutTemplate` | `struct` | Loaded once from disk at picker time; owns a copy of `[Exercise]` |
| `LastWeight` | `struct`, `Codable` | Serialized to `.obsidian/last-weights.json` in the vault; keyed by exercise name |

`Exercise` is a **class** rather than a struct because `ForEach($exercise.sets)` in `ExerciseCardView` requires a stable reference to drive `@ObservedObject` reactivity as individual sets change.

### Services

**`VaultService`** (`@MainActor`, `ObservableObject`)
- Holds a security-scoped bookmark to the vault folder (persisted in `UserDefaults`)
- Exposes synchronous helpers for the main thread: `readFile`, `writeFile`, `fileExists`, `listFiles`
- Exposes `withVaultURL(_:)` — a `nonisolated async` wrapper that runs file I/O on a background `Task.detached` thread, used for all save operations in `WorkoutSessionView`
- Stores user-configurable folder names (`journalsFolder`, `templatesFolder`, `workoutsFolder`) in `UserDefaults`
- Owns `readLastWeights()` / `writeLastWeights(_:)` for the JSON weight-persistence sidecar

**`MarkdownParser`** (`struct`)
- `parseTemplate(_:relativeTo:)` — reads a template file (`w-*-t.md`) into `[Exercise]`; top-level `- Name` lines become exercises, indented `- [video](path)` lines attach a video URL
- `parseSets(from:forExercise:)` — reads a saved workout file, finds a `### Exercise` section, and returns all `[x]`/`[ ]` set lines as `[ParsedSet]`; used by `ExerciseProgressionView` to build chart data

**`MarkdownWriter`** (`struct`)
- Produces all markdown text: frontmatter (workout, hike, recovery), body serialization, daily note embed
- Owns filename generation: `workoutFilename(sessionName:date:)` (ISO date + slug) and `dailyNoteFilename(for:)` (Obsidian `yyyy-MMM-dd` convention)
- `muscleGroups(from:)` — maps a session name like `"Back + Abs"` to muscle-group tags for the frontmatter

### Views & navigation

```
ContentView (TabView)
├── Tab: Home
│   NavigationStack
│   └── TemplatePickerView
│       ├── → WorkoutSessionView        (navigationDestination)
│       │     ExerciseCardView (per exercise)
│       │       SetRowView (per set)
│       │       ExerciseProgressionView (sheet, tapping exercise name)
│       ├── → HikeSessionView           (navigationDestination)
│       └── → RecoverySessionView       (navigationDestination)
│
└── Tab: Overview
    NavigationStack
    └── OverviewView
        └── → WorkoutDetailView         (NavigationLink)
              ExerciseProgressionView   (sheet, tapping exercise name)
```

`VaultService` is injected at the root as an `@EnvironmentObject` and flows down the entire tree.

### Data flow: starting a session

1. `TemplatePickerView.loadTemplates()` reads `templates/w-*-t.md` files via `VaultService.readFile`, parses them with `MarkdownParser.parseTemplate`, and stores them in `@State var templates`.
2. User selects one or more cards; tapping **Start Workout** pushes `WorkoutSessionView(templates:)`.
3. `WorkoutSessionView.onAppear` flattens all template exercises into `@State var exercises` and pre-fills each exercise's first set from `VaultService.readLastWeights()`.

### Data flow: saving a session

All four writes happen inside a single `VaultService.withVaultURL` call (background thread):

1. **Workout file** — `MarkdownWriter.workoutFrontmatter` + `serializeWorkout` → `workouts/yyyy-MM-dd-slug.md`
2. **Daily note** — read existing or fall back to `journal-t.md` template → `MarkdownWriter.appendEmbedIfNeeded` → `journals/yyyy-MMM-dd.md`
3. **Last-weights sidecar** — updated `LastWeightsStore` encoded to JSON → `.obsidian/last-weights.json`

### Data flow: exercise progression chart

`ExerciseProgressionView` scans every file in `workouts/` on load:
1. `VaultService.listFiles` returns all `.md` filenames, sorted.
2. For each file, `MarkdownParser.parseSets(from:forExercise:)` extracts sets for the named exercise.
3. The max weight across all sets in a file becomes one `ExerciseDataPoint`.
4. Points are sorted by date and plotted with Swift Charts (`LineMark` + `PointMark`).

## Building

1. Clone the repo
2. Open `WorkoutMD/WorkoutMD.xcodeproj` in Xcode
3. Select your target device or simulator and run

> If you add or remove Swift source files, update the UUID map and `SWIFT_FILES` list in `generate_xcodeproj.py`, then regenerate:
> ```bash
> cd WorkoutMD/
> python3 generate_xcodeproj.py
> ```

## Vault setup

On first launch the app shows a folder picker. It stores a security-scoped bookmark so it can access the vault across app launches without prompting again.

Configure the folder names used inside your vault from the Settings screen (defaults: `journals`, `templates`, `workouts`).

## File formats

### Workout template (`templates/w-chest-t.md`)

Filename convention: `w-{slug}-t.md`. Only files matching this pattern appear in the picker.

```
- Chest press
- Incline push-ups
- Loaded stretching chest + shoulder
  - [video](../videos/chest.mov)
```

Top-level `- Name` lines become exercises. Indented `  - [video](path)` lines attach a demo video to the preceding exercise.

### Completed workout (`workouts/2026-02-13-chest.md`)

Filename: `yyyy-MM-dd-{slug}.md`.

```markdown
---
date: 2026-02-13
categories:
  - "[[workouts]]"
muscles:
  - "[[chest]]"
effort: 7
duration: 45
---

## Chest — Feb 13, 2026
- Duration: 45m

### Chest press
- [x] 135 × 10
- [x] 135 × 8
- [ ] bodyweight × 10
```

`effort` is 0–10 (set at save time). `duration` is total elapsed minutes. Weight is `bodyweight` when the field is empty.

### Hike (`workouts/2026-02-13-hike.md`)

Same frontmatter shape plus optional `distance` (string) and `time` (integer minutes).

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

### Recovery session (`workouts/2026-02-13-recovery.md`)

```markdown
---
date: 2026-02-13
categories:
  - "[[workouts]]"
type: recovery
---

## Yoga — Feb 13, 2026
```

### Daily journal (`journals/2026-Feb-13.md`)

Filename uses Obsidian's `yyyy-MMM-dd` convention (three-letter month, not ISO).

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

After each save the app appends an `![[workouts/…]]` embed to the daily note (or creates it from `journal-t.md` if it doesn't exist yet).

### Last-weights sidecar (`.obsidian/last-weights.json`)

Stored inside the vault so weights follow the vault across devices. Format:

```json
{
  "Chest press": { "reps": 8, "updatedAt": "2026-02-13", "weight": "135" },
  "Incline push-ups": { "reps": 10, "updatedAt": "2026-02-13", "weight": "" }
}
```

## License

MIT
