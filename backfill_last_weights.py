#!/usr/bin/env python3
"""
backfill_last_weights.py

Scans all workout markdown files in the vault's workouts/ folder,
parses exercise sets, and writes _app_data/last-weights.json with
the most recently used weight+reps per exercise.

Usage:
    python3 backfill_last_weights.py [vault_path]

Default vault path: ~/Documents/Onyx
"""

import json
import re
import sys
from datetime import datetime
from pathlib import Path

# ── Config ────────────────────────────────────────────────────────────────────

DEFAULT_VAULT = Path.home() / "Documents" / "Onyx"
WORKOUTS_FOLDER = "workouts"
OUTPUT_PATH = "_app_data/last-weights.json"

# Matches:  - [x] 135lbs × 10  or  - [ ] bodyweight x 8  or  - [x] 12.5 × 10
SET_RE = re.compile(
    r"^\s*-\s+\[[ x]\]\s+(.+?)\s+[×x]\s+(\d+)",
    re.IGNORECASE
)

# ── Helpers ───────────────────────────────────────────────────────────────────

def parse_date_from_filename(filename: str) -> str:
    """Extract YYYY-MM-DD from filename like 2026-02-18-glutes-hamstrings.md"""
    match = re.match(r"(\d{4}-\d{2}-\d{2})", filename)
    return match.group(1) if match else "1970-01-01"


def parse_workout_file(path: Path) -> dict[str, dict]:
    """
    Parse a single workout file.
    Returns { exercise_name: { weight, reps, updatedAt } }
    using the LAST set per exercise (progressive overload = last set is peak).
    """
    text = path.read_text(encoding="utf-8")
    date_str = parse_date_from_filename(path.name)

    results = {}
    current_exercise = None

    for line in text.splitlines():
        # Detect exercise header: ### Exercise Name
        if line.startswith("### "):
            current_exercise = line[4:].strip()
            continue

        # Detect set line
        if current_exercise:
            m = SET_RE.match(line)
            if m:
                weight = m.group(1).strip()
                reps = int(m.group(2))
                # Always overwrite — last set in file wins (progressive overload)
                results[current_exercise] = {
                    "weight": weight,
                    "reps": reps,
                    "updatedAt": date_str
                }

    return results


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    vault = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_VAULT
    workouts_dir = vault / WORKOUTS_FOLDER
    output_file = vault / OUTPUT_PATH

    if not workouts_dir.exists():
        print(f"❌ Workouts folder not found: {workouts_dir}")
        sys.exit(1)

    # Get all workout .md files, sorted oldest → newest (so latest overwrites)
    workout_files = sorted(
        [f for f in workouts_dir.glob("*.md") if re.match(r"\d{4}-\d{2}-\d{2}", f.name)],
        key=lambda f: parse_date_from_filename(f.name)
    )

    if not workout_files:
        print(f"❌ No dated workout files found in {workouts_dir}")
        sys.exit(1)

    print(f"📂 Found {len(workout_files)} workout files in {workouts_dir}")

    # Merge all files — later files overwrite earlier ones
    store = {}
    for wf in workout_files:
        parsed = parse_workout_file(wf)
        if parsed:
            print(f"  ✅ {wf.name} → {len(parsed)} exercises")
            store.update(parsed)
        else:
            print(f"  ⚠️  {wf.name} → no sets found (skipped)")

    # Write output
    output_file.parent.mkdir(parents=True, exist_ok=True)
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(dict(sorted(store.items())), f, indent=2, ensure_ascii=False)

    print(f"\n✅ Written {len(store)} exercises to {output_file}")
    print("\n📋 Preview:")
    for name, data in sorted(store.items()):
        print(f"  {name:40s} → {data['weight']} × {data['reps']}  ({data['updatedAt']})")


if __name__ == "__main__":
    main()
