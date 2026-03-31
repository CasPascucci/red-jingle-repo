import re, unicodedata, sys
import xml.etree.ElementTree as ET

# Args: game_id, wiitdb_path
game_id = sys.argv[1]
db_path = sys.argv[2]

tree = ET.parse(db_path)
root = tree.getroot()

game = root.find(f".//game/id[.='{game_id}']/..")
if game is None:
    sys.stderr.write(f"Game ID {game_id} not found in wiitdb.xml\n")
    sys.exit(1)

raw_title = game.findtext("locale[@lang='EN']/title") or game.findtext("title") or ""

ARTICLES = {"the", "a", "an"}

def move_article(title):
    words = title.split(" ", 1)
    if len(words) > 1 and words[0].lower() in ARTICLES:
        return f"{words[1]}, {words[0]}"
    return title

# GameTDB uses ": " as title/subtitle separator
parts = [p.strip() for p in raw_title.split(": ", 1) if p.strip()]

if len(parts) == 2:
    human = f"{move_article(parts[0])} - {parts[1]}"
elif len(parts) == 1:
    human = move_article(parts[0])
else:
    human = raw_title.strip()

print(human)
