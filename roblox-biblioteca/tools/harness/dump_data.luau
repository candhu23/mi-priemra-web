-- Carga BookData y Lang reales (sin Roblox) y los vuelca a JSON para check_books.py.
-- Uso: lune run dump_data.luau <carpeta src> <salida.json>
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local SRC = process.args[1]
local OUT = process.args[2]
local loaded = {}
local function load(name)
	if loaded[name] == nil then
		local src = fs.readFile(SRC .. "/ReplicatedStorage/" .. name .. ".luau")
		local env = setmetatable({
			Color3 = roblox.Color3, Vector3 = roblox.Vector3, CFrame = roblox.CFrame,
			game = { GetService = function() return { WaitForChild = function(_, n) return n end } end },
			script = { Parent = { WaitForChild = function(_, n) return n end } },
			require = function(n) return load(n) end,
		}, { __index = _G })
		loaded[name] = luau.load(src, { debugName = name, environment = env })()
	end
	return loaded[name]
end
local BookData = load("BookData")
local Lang = load("Lang")
local out = { sections = {}, series = {}, lang = { es = Lang.es, en = Lang.en } }
for _, s in BookData.Sections do
	table.insert(out.sections, { code = s.code, floor = s.floor, n10 = s.n10, n5 = s.n5, n3 = s.n3, es = s.es, en = s.en, series = s.series })
end
for _, s in BookData.Series do
	table.insert(out.series, s)
end
fs.writeFile(OUT, serde.encode("json", out, true))
print("datos volcados: " .. #out.series .. " series")
