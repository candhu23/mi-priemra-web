"""Comprueba que todas las claves de texto que usa el código existen en Lang.es y Lang.en.
Uso: python3 -I check_lang.py <carpeta src>. Sale con error si falta alguna.
"""
import glob
import os
import re
import sys

SRC = sys.argv[1]
lang = open(os.path.join(SRC, "ReplicatedStorage", "Lang.luau"), encoding="utf-8").read()
config = open(os.path.join(SRC, "ReplicatedStorage", "Config.luau"), encoding="utf-8").read()


def table_keys(name):
	start = lang.index(f"Lang.{name} = {{")
	end = lang.index("\n}\n", start)
	return set(re.findall(r"\b([a-zA-Z0-9_]+) = \"", lang[start:end]))


es, en = table_keys("es"), table_keys("en")
PREFIX = r"(?:err|n|tut|aim|btn|hud|menu|slot|sk|res|rank|end|ach|sp|map|list|opt|help|note|reward|key|painting|warn|letter|door|confirm|best|manual|special|time)_[a-z0-9_]+"
used = set()
for f in glob.glob(os.path.join(SRC, "**", "*.luau"), recursive=True):
	if f.endswith("Lang.luau"):
		continue
	s = open(f, encoding="utf-8").read()
	used |= set(re.findall(r"\"(" + PREFIX + r")\"", s))
	used |= set(re.findall(r"T\(\s*\"([a-z0-9_]+)\"", s))
used = {k for k in used if not k.endswith("_")}

# Claves formadas con datos de Config
keys = re.findall(r"\"(red|green|yellow|blue)\"", config.split("Config.KEYS")[1].split("\n")[0])
for k in keys:
	used |= {"key_" + k, "note_" + k, "painting_" + k}
for r in ("jump", "run", "cap3", "cap2"):
	used.add("reward_" + r)
for sid in re.findall(r"\{ id = \"([a-z]+)\", key = \d", config):
	used |= {"sk_" + sid, "sk_" + sid + "_d"}
for i in range(1, 7):
	used.add(f"rank_{i}")
for e in ("normal", "pizza", "nomagic", "fired", "partial"):
	used |= {"end_" + e, "end_" + e + "_d"}
ach = re.search(r"Config.Achievements = \{([^}]*)\}", config).group(1)
for a in re.findall(r"\"([a-z0-9_]+)\"", ach):
	used |= {"ach_" + a, "ach_" + a + "_d"}

missing_en = sorted(k for k in used if k not in en)
missing_es = sorted(k for k in used if k not in es)
extra = sorted((es | en) - used)
if missing_en or missing_es:
	print("Faltan en inglés:", missing_en)
	print("Faltan en español:", missing_es)
	sys.exit(1)
only = sorted(es ^ en)
if only:
	print("Claves solo en un idioma:", only)
	sys.exit(1)
print(f"Textos OK: {len(used)} claves usadas · todas en español e inglés")
