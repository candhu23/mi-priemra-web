"""Comprueba que todas las claves de texto usadas por el código existen en Lang.en y Lang.es.
Uso: python3 -I check_lang.py <carpeta src>. Sale con error si falta alguna.
"""
import glob
import os
import re
import sys

SRC = sys.argv[1]
lang = open(os.path.join(SRC, "ReplicatedStorage", "Lang.luau")).read()
config = open(os.path.join(SRC, "ReplicatedStorage", "Config.luau")).read()


def table_keys(name):
	start = lang.index(f"Lang.{name} = {{")
	end = lang.index("\n}\n", start)
	return set(re.findall(r"\b([a-zA-Z0-9_]+) = \"", lang[start:end]))


en, es = table_keys("en"), table_keys("es")

used = set()
for f in glob.glob(os.path.join(SRC, "**", "*.luau"), recursive=True):
	s = open(f).read()
	used |= set(re.findall(r"\bT\(\s*\"([a-z0-9_]+)\"\s*[,)]", s))
	used |= set(re.findall(r"return\s+(?:true|false),\s*\"([a-z0-9_]+)\"", s))
	used |= set(re.findall(r"notify(?:All)?\([^\n]*?\"(n_[a-z0-9_]+)\"", s))
	used |= set(re.findall(r"\"(err_[a-z0-9_]+)\"", s))
	used |= set(re.findall(r"\"(tut_[a-z0-9_]+)\"", s))

# Claves que se forman con datos de Config
def ids(block_start, block_end, field="id"):
	i = config.index(block_start)
	j = config.index(block_end, i)
	return re.findall(rf"\b{field} = \"([a-zA-Z0-9_]+)\"", config[i:j])

for g in ids("Config.Goods = {", "} :: { Good }"):
	used.add("good_" + g)
for p in ids("Config.Planes = {", "} :: { PlaneModel }"):
	used |= {"plane_" + p, "plane_" + p + "_d"}
for u in ids("Config.Upgrades = {", "} :: { Upgrade }"):
	used |= {"up_" + u, "up_" + u + "_d"}
for r in ids("Config.Regions = {", "} :: { Region }"):
	used.add("r_" + r)
for m in ids("Config.MissionPool = {", "} :: { MissionDef }"):
	used.add("mission_" + m)
for st in re.findall(r"\{ stat = \"([a-z]+)\", targets", config):
	used.add("goal_" + st)
for k in ids("Config.GamePasses = {", "} :: { ShopItem }", "key") + ids("Config.Products = {", "} :: { ShopItem }", "key"):
	used.add("item_" + k)
	if not k.startswith("cash_"):
		used.add("item_" + k + "_d")

missing_en = sorted(k for k in used if k not in en)
missing_es = sorted(k for k in used if k not in es)
if missing_en or missing_es:
	print("Faltan en inglés:", missing_en)
	print("Faltan en español:", missing_es)
	sys.exit(1)
print(f"{len(used)} claves usadas · todas en inglés y español")
