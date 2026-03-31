import sys, json

if len(sys.argv) != 4:
    print("Usage: _update_index_wiiu.py <index.json path> <game title> <jingle path>")
    sys.exit(1)

index_path, game_title, jingle_path = sys.argv[1], sys.argv[2], sys.argv[3]

# Normalize path separators to forward slashes (for cross-platform consistency)
jingle_path = jingle_path.replace('\\', '/')

try:
    with open(index_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
except FileNotFoundError:
    data = {"name": "Red's Jingles Pack", "wiiu": []}

wiiu = data.get("wiiu", [])

# Remove any existing entry with the same file path (idempotent re-runs)
wiiu = [e for e in wiiu if e.get("file") != jingle_path]

wiiu.append({"name": game_title, "file": jingle_path})

# Sort alphabetically by game title (case-insensitive)
wiiu.sort(key=lambda e: e["name"].lower())

data["wiiu"] = wiiu

with open(index_path, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write('\n')

print(f"[index.json] Added: {game_title} -> {jingle_path}")
