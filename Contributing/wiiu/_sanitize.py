import re, unicodedata, sys

s = sys.argv[1]
s = unicodedata.normalize("NFKD", s)
s = s.encode("ascii", "ignore").decode("ascii")
s = s.lower()
s = re.sub(r"'", "", s)
s = re.sub(r"\s*-\s*", "-", s)
s = re.sub(r"\s+", "-", s)
s = re.sub(r"[^a-z0-9-]", "", s)
s = re.sub(r"-+", "-", s)
s = s.strip("-")
print(s + ".wav")
