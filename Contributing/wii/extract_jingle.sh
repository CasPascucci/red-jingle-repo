#!/bin/bash

shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

case "$(uname)" in
    Darwin)
        TOOL_DOLPHIN="$SCRIPT_DIR/tools/macos/dolphin-tool"
        TOOL_WSZST="$SCRIPT_DIR/tools/macos/wszst"
        VGM="$SCRIPT_DIR/../tools/macos/vgmstream-cli"
        ;;
    Linux)
        TOOL_DOLPHIN="$SCRIPT_DIR/tools/linux/dolphin-tool"
        TOOL_WSZST="$SCRIPT_DIR/tools/linux/wszst"
        VGM="$SCRIPT_DIR/../tools/linux/vgmstream-cli"
        ;;
    *)
        echo "Unsupported OS: $(uname). Only Linux and macOS are supported."
        exit 1
        ;;
esac

WIITDB="$SCRIPT_DIR/tools/wiitdb.xml"

if [ ! -x "$TOOL_DOLPHIN" ]; then
    echo "dolphin-tool not found or not executable at: $TOOL_DOLPHIN"
    exit 1
fi
if [ ! -x "$TOOL_WSZST" ]; then
    echo "wszst not found or not executable at: $TOOL_WSZST"
    exit 1
fi
if [ ! -x "$VGM" ]; then
    echo "vgmstream-cli not found or not executable at: $VGM"
    exit 1
fi
if [ ! -f "$WIITDB" ]; then
    echo "wiitdb.xml not found at: $WIITDB"
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 could not be found. Please install python3."
    exit 1
fi

REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
JINGLES_DIR="$REPO_ROOT/jingles/wii"
INDEX_JSON="$REPO_ROOT/index.json"

GAMES_DIR="$SCRIPT_DIR/games"
mkdir -p "$JINGLES_DIR"

for ROM in "$GAMES_DIR"/*.rvz "$GAMES_DIR"/*.iso; do
    echo "Processing $ROM..."

    tmpdir=$(mktemp -d)
    bnr_dir="$tmpdir/bnr_extract"
    bnr="$bnr_dir/DATA/files/opening.bnr"

    "$TOOL_DOLPHIN" extract -i "$ROM" -s opening.bnr -o "$bnr_dir" > /dev/null

    # A bunch of Wii games have an annoying header that needs to be clipped before wszst can handle them.
    offset=$(LC_ALL=C grep -obam 1 $'\x55\xaa\x38\x2d' "$bnr" | LC_ALL=C head -1 | LC_ALL=C cut -d: -f1) > /dev/null
    if [[ -z "$offset" ]]; then
        echo "  Could not find U8 header, skipping."
        rm -rf "$tmpdir"
        continue
    fi

    dd if="$bnr" of="$tmpdir/opening.arc" bs=1 skip="$offset" status=none

    "$TOOL_WSZST" extract "$tmpdir/opening.arc" --dest "$tmpdir/bnr_out" > /dev/null

    sound=$(find "$tmpdir/bnr_out" -name "sound.bin" | head -1)
    if [[ -z "$sound" ]]; then
        echo "  No sound.bin found, skipping."
        rm -rf "$tmpdir"
        continue
    fi

    DOLPHIN_HEADER=$("$TOOL_DOLPHIN" header -i "$ROM")
    read -r FINAL GAME_TITLE < <(python3 - "$WIITDB" "$DOLPHIN_HEADER" <<'PYEOF'
import sys, re, unicodedata
import xml.etree.ElementTree as ET

db_path = sys.argv[1]
header_text = sys.argv[2]

game_id = None
for line in header_text.splitlines():
    if line.startswith("Game ID:"):
        game_id = line.split(":", 1)[1].strip()
        break

if not game_id:
    sys.stderr.write("Could not extract Game ID\n")
    sys.exit(1)

tree = ET.parse(db_path)
root = tree.getroot()

game = root.find(f".//game/id[.='{game_id}']/..")
if game is None:
    sys.stderr.write(f"Game ID {game_id} not found in wiitdb.xml\n")
    sys.exit(1)

raw_title = game.findtext("locale[@lang='EN']/title") or game.findtext("title") or ""

ARTICLES = {"the", "a", "an"}
LOWERCASE_WORDS = {"a", "an", "the", "and", "but", "or", "for", "nor",
                   "on", "at", "to", "by", "in", "of", "up", "as", "is"}
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
            cased = word.capitalize()
            if word.endswith("U") and len(word) > 1:
                cased = cased[:-1] + "U"
            result.append(cased)
        else:
            result.append(lower)
    return " ".join(result)

def move_article(title):
    words = title.split(" ", 1)
    if len(words) > 1 and words[0].lower() in ARTICLES:
        return f"{words[1]}, {words[0]}"
    return title

def slugify(s):
    s = unicodedata.normalize("NFKD", s)
    s = s.encode("ascii", "ignore").decode("ascii")
    s = s.lower()
    s = re.sub(r"'", "", s)
    s = re.sub(r"\s*-\s*", "-", s)
    s = re.sub(r"\s+", "-", s)
    s = re.sub(r"[^a-z0-9-]", "", s)
    s = re.sub(r"-+", "-", s)
    s = s.strip("-")
    return s

# GameTDB uses ": " as title/subtitle separator
parts = [smart_title_case(p.strip()) for p in raw_title.split(": ", 1) if p.strip()]

if len(parts) == 2:
    human = f"{move_article(parts[0])} - {parts[1]}"
elif len(parts) == 1:
    human = move_article(parts[0])
else:
    human = raw_title.strip()

slug = slugify(human) + ".wav"
print(f"{slug}\t{human}")
PYEOF
    )

    if [[ -z "$FINAL" ]]; then
        echo "  Could not determine title, skipping."
        rm -rf "$tmpdir"
        continue
    fi

    "$VGM" "$sound" -o "$JINGLES_DIR/$FINAL" > /dev/null

    rm -rf "$tmpdir"

    echo "Saved: $FINAL  (Game: $GAME_TITLE)"

    JINGLE_PATH="jingles/wii/$FINAL"

    python3 - "$INDEX_JSON" "$GAME_TITLE" "$JINGLE_PATH" <<'PYEOF'
import sys, json

index_path, game_title, jingle_path = sys.argv[1], sys.argv[2], sys.argv[3]

try:
    with open(index_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
except FileNotFoundError:
    data = {"name": "Red's Jingles Pack", "wii": []}

wii = data.get("wii", [])
wii = [e for e in wii if e.get("file") != jingle_path]
wii.append({"name": game_title, "file": jingle_path})
wii.sort(key=lambda e: e["name"].lower())
data["wii"] = wii

with open(index_path, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write('\n')

print(f"index.json updated: {game_title}")
PYEOF

echo "--------------------------------------"

done
