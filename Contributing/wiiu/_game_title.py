import re, unicodedata, sys
import xml.etree.ElementTree as ET

xml_path = sys.argv[1]

tree = ET.parse(xml_path)
root = tree.getroot()

longname = root.findtext("longname_en") or ""

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
            # Only uppercase the first char, preserve the rest as-is.
            # This handles Punch-Out!! (no lowercasing after hyphen),
            # ZombiU (trailing U preserved), NiGHTS (not mangled).
            cased = word[0].upper() + word[1:] if word else word
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

parts = [smart_title_case(p.strip()) for p in longname.strip().split("\n") if p.strip()]

if len(parts) == 2:
    human = f"{move_article(parts[0])} - {parts[1]}"
elif len(parts) == 1:
    human = move_article(parts[0])
else:
    human = longname.strip()

print(human)
