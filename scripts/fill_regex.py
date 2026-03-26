#!/usr/bin/env python3
"""
fill_regex.py — Finds entries in index.json that are missing a "regex" field
and uses the Claude API to generate well-crafted Cocoon Shell regex patterns.

Usage:
    python scripts/fill_regex.py [--index PATH] [--dry-run]

Environment:
    ANTHROPIC_API_KEY   Required. Your Anthropic API key.
"""

import argparse
import json
import os
import sys
from pathlib import Path

import anthropic

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

REPO_ROOT = Path(__file__).parent.parent
DEFAULT_INDEX = REPO_ROOT / "index.json"
RULES_FILE = Path(__file__).parent / "regex_rules.md"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def load_index(path: Path) -> dict:
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def save_index(data: dict, path: Path) -> None:
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")


def find_missing(data: dict) -> list[tuple[str, int, dict]]:
    """Return (platform, index, entry) for every entry missing a 'regex' key."""
    missing = []
    for key, value in data.items():
        if not isinstance(value, list):
            continue  # skip top-level non-list fields like "name"
        for i, entry in enumerate(value):
            if isinstance(entry, dict) and "regex" not in entry:
                missing.append((key, i, entry))
    return missing


def load_rules() -> str:
    if not RULES_FILE.exists():
        sys.exit(f"ERROR: Rules file not found at {RULES_FILE}")
    return RULES_FILE.read_text(encoding="utf-8")


# ---------------------------------------------------------------------------
# Claude API call
# ---------------------------------------------------------------------------

def generate_regex(missing: list[tuple[str, int, dict]], rules: str) -> list[dict]:
    """
    Ask Claude to generate regex patterns for the given entries.
    Returns a list of {"platform": ..., "name": ..., "regex": ...} dicts.
    """
    needs_patterns = [
        {"platform": platform, "name": entry["name"]}
        for platform, _, entry in missing
    ]

    system = (
        "You are a regex pattern generator for the Cocoon Shell jingle matching system.\n"
        "You will be given a list of game entries that need regex patterns.\n"
        "Apply every rule in the provided rules document carefully.\n\n"
        "IMPORTANT: Respond with ONLY a valid JSON array. "
        "No markdown fences, no preamble, no explanation. "
        "Each element must have exactly three keys: platform, name, regex."
    )

    user = (
        f"Rules document:\n\n{rules}\n\n"
        "---\n\n"
        "Generate regex patterns for every entry in this list:\n\n"
        f"{json.dumps(needs_patterns, indent=2)}"
    )

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        sys.exit("ERROR: ANTHROPIC_API_KEY environment variable is not set.")

    client = anthropic.Anthropic(api_key=api_key)

    print(f"  Calling Claude API for {len(needs_patterns)} entries...")
    message = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=4096,
        system=system,
        messages=[{"role": "user", "content": user}],
    )

    raw = message.content[0].text.strip()

    # Strip accidental markdown fences
    if raw.startswith("```"):
        raw = raw.split("\n", 1)[1]
        raw = raw.rsplit("```", 1)[0].strip()

    try:
        results = json.loads(raw)
    except json.JSONDecodeError as e:
        print(f"ERROR: Claude returned non-JSON output:\n{raw}")
        sys.exit(f"JSON parse error: {e}")

    if not isinstance(results, list):
        sys.exit(f"ERROR: Expected a JSON array from Claude, got: {type(results)}")

    return results


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(description="Fill missing regex fields in index.json")
    parser.add_argument("--index", type=Path, default=DEFAULT_INDEX,
                        help="Path to index.json (default: repo root)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print what would change without writing the file")
    args = parser.parse_args()

    if not args.index.exists():
        sys.exit(f"ERROR: index.json not found at {args.index}")

    print(f"Loading {args.index} ...")
    data = load_index(args.index)

    missing = find_missing(data)

    if not missing:
        print("✓ All entries already have regex fields. Nothing to do.")
        return

    print(f"Found {len(missing)} entr{'y' if len(missing) == 1 else 'ies'} missing regex:")
    for platform, _, entry in missing:
        print(f"  [{platform}] {entry['name']}")
    print()

    rules = load_rules()
    results = generate_regex(missing, rules)

    # Build lookup: (platform, name) -> regex
    lookup: dict[tuple[str, str], str] = {
        (r["platform"], r["name"]): r["regex"]
        for r in results
        if "platform" in r and "name" in r and "regex" in r
    }

    filled = 0
    warnings = []

    for platform, idx, entry in missing:
        key = (platform, entry["name"])
        if key in lookup:
            if not args.dry_run:
                data[platform][idx]["regex"] = lookup[key]
            print(f"  ✓ [{platform}] {entry['name']}")
            print(f"      → {lookup[key]}")
            filled += 1
        else:
            warnings.append(f"  ⚠ No pattern returned for [{platform}] {entry['name']}")

    for w in warnings:
        print(w)

    if args.dry_run:
        print(f"\nDry run complete — {filled} pattern(s) would be written.")
        return

    save_index(data, args.index)
    print(f"\n✓ Saved {args.index} — {filled} new regex field(s) added.")

    if warnings:
        print(f"\n⚠ {len(warnings)} entry/entries could not be filled (see above).")
        sys.exit(1)  # Non-zero exit so CI can flag it


if __name__ == "__main__":
    main()
