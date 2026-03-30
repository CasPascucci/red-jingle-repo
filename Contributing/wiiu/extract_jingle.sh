#!/bin/bash

shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Select bundled tools based on OS
case "$(uname)" in
    Darwin)
        TOOL_WUA="$SCRIPT_DIR/tools/macos/wua_extract_file"
        VGM="$SCRIPT_DIR/../tools/macos/vgmstream-cli"
        ;;
    Linux)
        TOOL_WUA="$SCRIPT_DIR/tools/linux/wua_extract_file"
        VGM="$SCRIPT_DIR/../tools/linux/vgmstream-cli"
        ;;
    *)
        echo "Unsupported OS: $(uname). Only Linux and macOS are supported."
        exit 1
        ;;
esac

if [ ! -x "$TOOL_WUA" ]; then
    echo "wua_extract_file not found or not executable at: $TOOL_WUA"
    exit 1
fi
if [ ! -x "$VGM" ]; then
    echo "vgmstream-cli not found or not executable at: $VGM"
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 could not be found. Please install python3."
    exit 1
fi

REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
JINGLES_DIR="$REPO_ROOT/jingles/wiiu"
INDEX_JSON="$REPO_ROOT/index.json"
GAMES_DIR="$SCRIPT_DIR/games"
mkdir -p "$JINGLES_DIR"

for ROM in "$GAMES_DIR"/*.wua; do
    echo "Processing $ROM..."
    tmpdir=$(mktemp -d)

    "$TOOL_WUA" "$ROM" meta/bootSound.btsnd "$tmpdir/out.btsnd" > /dev/null
    "$TOOL_WUA" "$ROM" meta/meta.xml "$tmpdir/out.xml" > /dev/null

    read -r FINAL GAME_TITLE < <(python3 - "$tmpdir/out.xml" <<'PYEOF'
import sys, re, unicodedata
import xml.etree.ElementTree as ET

ARTICLES = {"the", "a", "an"}

# Words that should never be title-cased (unless first word)
LOWERCASE_WORDS = {"a", "an", "the", "and", "but", "or", "for", "nor",
                   "on", "at", "to", "by", "in", "of", "up", "as", "is"}

# Words that should always stay uppercase
UPPERCASE_WORDS = {"hd", "rpg", "ii", "iii", "iv", "vi", "vii", "viii",
                   "ix", "xi", "xii", "xiii", "npc", "dlc", "usa", "eu", "u"}

def smart_title_case(s):
    words = s.split(" ")
    result = []
    for i, word in enumerate(words):
        lower = word.lower()
        if lower in UPPERCASE_WORDS:
            result.append(word.upper())
        elif i == 0 or lower not in LOWERCASE_WORDS:
            # Preserve trailing U in words like ZombiU
            cased = word.capitalize()
            if word.endswith("U") and len(word) > 1:
                cased = cased[:-1] + "U"
            result.append(cased)
        else:
            result.append(lower)
    return " ".join(result)

def move_article(title):
    """Move leading article to end: 'The Foo' -> 'Foo, The'"""
    words = title.split(" ", 1)
    if len(words) > 1 and words[0].lower() in ARTICLES:
        return f"{words[1]}, {words[0]}"
    return title

def slugify(s):
    s = unicodedata.normalize("NFKD", s)
    s = s.encode("ascii", "ignore").decode("ascii")
    s = s.lower()
    s = re.sub(r"'", "", s)           # strip apostrophes
    s = re.sub(r"\s*-\s*", "-", s)   # normalize dashes
    s = re.sub(r"\s+", "-", s)       # spaces to dashes
    s = re.sub(r"[^a-z0-9-]", "", s) # strip everything else
    s = re.sub(r"-+", "-", s)        # collapse multiple dashes
    s = s.strip("-")
    return s

tree = ET.parse(sys.argv[1])
root = tree.getroot()

longname = root.findtext("longname_en") or ""

# longname uses a newline to separate title from subtitle
parts = [smart_title_case(p.strip()) for p in longname.strip().split("\n") if p.strip()]

if len(parts) == 2:
    main_title, subtitle = parts
    human = f"{move_article(main_title)} - {subtitle}"
elif len(parts) == 1:
    human = move_article(parts[0])
else:
    human = longname.strip()

slug = slugify(human) + ".wav"

# Tab-separated so read -r splits correctly even if title contains spaces
print(f"{slug}\t{human}")
PYEOF
    )

    "$VGM" "$tmpdir/out.btsnd" -o "$JINGLES_DIR/$FINAL" > /dev/null
    rm -rf "$tmpdir"

    echo "Saved: $FINAL  (Game: $GAME_TITLE)"

    JINGLE_PATH="jingles/wiiu/$FINAL"

    python3 - "$INDEX_JSON" "$GAME_TITLE" "$JINGLE_PATH" <<'PYEOF'
import sys, json

index_path, game_title, jingle_path = sys.argv[1], sys.argv[2], sys.argv[3]

try:
    with open(index_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
except FileNotFoundError:
    data = {"name": "Red's Jingles Pack", "wiiu": []}

wiiu = data.get("wiiu", [])

# Remove any existing entry for this file path (re-run idempotency)
wiiu = [e for e in wiiu if e.get("file") != jingle_path]

wiiu.append({"name": game_title, "file": jingle_path})

# Sort alphabetically by game title (case-insensitive)
wiiu.sort(key=lambda e: e["name"].lower())

data["wiiu"] = wiiu

with open(index_path, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write('\n')

print(f"index.json updated: {game_title}")
PYEOF

done
