#!/bin/bash

shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Select bundled tools based on OS
case "$(uname)" in
    Darwin)
        TOOL_3DS="$SCRIPT_DIR/tools/macos/3dstool"
        VGM="$SCRIPT_DIR/../tools/macos/vgmstream-cli"
        ;;
    Linux)
        TOOL_3DS="$SCRIPT_DIR/tools/linux/3dstool"
        VGM="$SCRIPT_DIR/../tools/linux/vgmstream-cli"
        ;;
    *)
        echo "Unsupported OS: $(uname). Only Linux and macOS are supported."
        exit 1
        ;;
esac

if [ ! -x "$TOOL_3DS" ]; then
    echo "3dstool not found or not executable at: $TOOL_3DS"
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
JINGLES_DIR="$REPO_ROOT/jingles/n3ds"
INDEX_JSON="$REPO_ROOT/index.json"

GAMES_DIR="$SCRIPT_DIR/games"
mkdir -p "$JINGLES_DIR"

for ROM in "$GAMES_DIR"/*.3ds "$GAMES_DIR"/*.cci; do
    echo "Processing $ROM..."
    BASENAME="${ROM%.*}"
    BASENAME="$(basename "$BASENAME")"

    "$TOOL_3DS" -xvtf cci "$ROM" -0 partition0.cxi --header /dev/null > /dev/null
    "$TOOL_3DS" -xvtf cxi partition0.cxi --exefs exefs.bin --exefs-auto-key > /dev/null
    "$TOOL_3DS" -xvtfu exefs exefs.bin --exefs-dir exefs_dir/ > /dev/null

    mv exefs_dir/banner.bnr banner.bin

    "$TOOL_3DS" -xvtf banner banner.bin --banner-dir banner_dir/ > /dev/null

    # Trim bcwav to the size declared in its header
    python3 -c "
import struct
with open('banner_dir/banner.bcwav','rb') as f:
    data = f.read()
size = struct.unpack('<I', data[12:16])[0]
with open('banner_dir/banner.bcwav','wb') as f:
    f.write(data[:size])
"

    # Compute the sanitized filename (slug) and human-readable game title in one awk pass
    read -r FINAL GAME_TITLE < <(
        printf '%s\n' "$BASENAME" \
        | iconv -f utf-8 -t ascii//TRANSLIT \
        | awk '
        function trim(s) { gsub(/^ +| +$/, "", s); return s }
        {
            s=$0

            # 1. Strip TitleID prefix
            sub(/^0004[0-9A-Fa-f]{12}[-_ ]?/, "", s)

            # 2. Strip trailing noise tags (before the extension, which is already gone)
            sub(/[-_ .]?[Ss]tandard$/, "", s)
            sub(/[-_ .]?[Dd]ecrypted$/, "", s)
            sub(/[-_ .]?[Pp]iratelegit$/, "", s)
	    sub(/[-_ .]?\[b\]$/, "", s)

            # 3. Strip parenthetical regions/revisions for both outputs
            gsub(/\([^)]*\)/, "", s)
            s = trim(s)

            # 4. Move leading article — on the human-readable copy, before slugifying
            human = s
            if (match(human, /^(The|An|A) /)) {
                art  = substr(human, 1, RLENGTH-1)
                rest = substr(human, RLENGTH+1)
                rest = trim(rest)
                dash = index(rest, " - ")
                if (dash > 0) {
                    human = substr(rest,1,dash-1) ", " art " - " substr(rest,dash+3)
                } else {
                    human = rest ", " art
                }
            }
            # Clean up any double spaces left after stripping parens
            gsub(/ {2,}/, " ", human)
            human = trim(human)

            # 5. Slug: build from the article-moved human string
            slug = human
            gsub(/\047/, "", slug)           # apostrophes
            gsub(/ *- */, "-", slug)
            gsub(/ /, "-", slug)
            gsub(/[^A-Za-z0-9-]+/, "", slug)
            gsub(/-+/, "-", slug)
            gsub(/^-|-$/, "", slug)

            print tolower(slug) ".wav", human
        }')

    "$VGM" banner_dir/banner.bcwav -o "$JINGLES_DIR/$FINAL" > /dev/null

    rm -r partition0.cxi exefs.bin exefs_dir/ banner.bin banner_dir/

    echo "Saved: $FINAL  (Game: $GAME_TITLE)"

    # --- Update index.json ---
    JINGLE_PATH="jingles/n3ds/$FINAL"

    python3 - "$INDEX_JSON" "$GAME_TITLE" "$JINGLE_PATH" <<'PYEOF'
import sys, json

index_path, game_title, jingle_path = sys.argv[1], sys.argv[2], sys.argv[3]

try:
    with open(index_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
except FileNotFoundError:
    data = {"name": "Red's Jingles Pack", "n3ds": []}

n3ds = data.get("n3ds", [])

# Remove any existing entry for this file path (re-run idempotency)
n3ds = [e for e in n3ds if e.get("file") != jingle_path]

n3ds.append({"name": game_title, "file": jingle_path})

# Sort alphabetically by game title (case-insensitive)
n3ds.sort(key=lambda e: e["name"].lower())

data["n3ds"] = n3ds

with open(index_path, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write('\n')

print(f"index.json updated: {game_title}")
PYEOF

done
