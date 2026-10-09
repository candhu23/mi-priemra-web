--[[
	Locale (ModuleScript en ReplicatedStorage)

	Idiomas del juego. Todo está escrito en español; LocaleEN (inglés) y
	LocalePT (portugués de Brasil, v4) tienen las traducciones: la clave es
	el texto en español TAL CUAL está en el código (las plantillas con
	%s / %d también). Las claves de LocaleEN son la lista oficial.

	  · Locale.t(lang, texto)            → traduce un texto fijo
	  · Locale.f(lang, plantilla, ...)    → traduce y rellena (como string.format)
	  · Locale.translate(lang, texto)    → traduce un texto YA rellenado (lo que
	    manda el servidor o los carteles del mundo): busca qué plantilla
	    encaja y traduce también los trozos (nombres de webs, nichos...).

	Para añadir un texto nuevo hay que añadirlo a LocaleEN y a LocalePT.
	Si falta, se queda en español (no se rompe nada, pero el harness falla).
]]

local EN: { [string]: string } = require(script.Parent:WaitForChild("LocaleEN"))
local PT: { [string]: string } = require(script.Parent:WaitForChild("LocalePT"))

local Locale = {}

Locale.LANGS = { "es", "en", "pt" } -- orden del botón 🌐
Locale.NAMES = { es = "Español", en = "English", pt = "Português" }
Locale.EN = EN
Locale.PT = PT
local DICTS: { [string]: { [string]: string } } = { en = EN, pt = PT }

-- Para las pruebas: se llama con cada texto de Locale.t/f que no tiene traducción
Locale.onMissing = nil :: ((text: string, lang: string) -> ())?

-- Idioma a usar: el elegido a mano (botón 🌐) o, en "auto", el de la cuenta
-- de Roblox (es* → español, pt* → portugués; si no, inglés).
function Locale.resolve(setting: string?, localeId: string?): string
	if setting and (setting == "es" or DICTS[setting] ~= nil) then
		return setting
	end
	local prefix = if type(localeId) == "string" then string.lower(string.sub(localeId, 1, 2)) else ""
	if prefix == "es" then
		return "es"
	elseif prefix == "pt" then
		return "pt"
	end
	return "en"
end

-- ¿Es un idioma válido para el ajuste? ("auto" también)
function Locale.isValid(lang: any): boolean
	return lang == "auto" or lang == "es" or (type(lang) == "string" and DICTS[lang] ~= nil)
end

function Locale.has(text: string): boolean
	return EN[text] ~= nil
end

function Locale.t(lang: string, text: string): string
	local dict = DICTS[lang]
	if not dict then
		return text
	end
	local translated = dict[text]
	if translated then
		return translated
	end
	if Locale.onMissing then
		Locale.onMissing(text, lang)
	end
	return text
end

-- Especificadores de formato (%s, %d, %.2f...) de una plantilla, en orden
local SPEC = "^%%[%-%+ #0]*%d*%.?%d*[sdif]"

local function specsOf(template: string): { string }
	local list = {}
	local i, n = 1, #template
	while i <= n do
		local start = string.find(template, "%", i, true)
		if not start then
			break
		end
		if string.sub(template, start + 1, start + 1) == "%" then
			i = start + 2
		else
			local spec = string.match(template, SPEC, start)
			if spec then
				table.insert(list, spec)
				i = start + #spec
			else
				i = start + 1
			end
		end
	end
	return list
end

-- Rellena una plantilla con textos ya preparados (uno por especificador)
local function fill(template: string, values: { string }): string
	local out = {}
	local i, n, k = 1, #template, 0
	while i <= n do
		local start = string.find(template, "%", i, true)
		if not start then
			table.insert(out, string.sub(template, i))
			break
		end
		table.insert(out, string.sub(template, i, start - 1))
		if string.sub(template, start + 1, start + 1) == "%" then
			table.insert(out, "%")
			i = start + 2
		else
			local spec = string.match(template, SPEC, start)
			if spec then
				k += 1
				table.insert(out, values[k] or "")
				i = start + #spec
			else
				table.insert(out, "%")
				i = start + 1
			end
		end
	end
	return table.concat(out)
end

function Locale.f(lang: string, template: string, ...: any): string
	local dict = DICTS[lang]
	if not dict then
		return string.format(template, ...)
	end
	local translated = dict[template]
	if not translated then
		if Locale.onMissing then
			Locale.onMissing(template, lang)
		end
		return string.format(template, ...)
	end
	-- Cada valor se formatea con el especificador del español y luego se
	-- coloca en la plantilla traducida (mismo orden)
	local values = {}
	for i, spec in specsOf(template) do
		values[i] = string.format(spec, (select(i, ...)))
	end
	return fill(translated, values)
end

---------------------------------------------------------------------
-- Traducir textos ya rellenados (servidor y carteles)
---------------------------------------------------------------------
local MAGIC = {}
for _, c in { "^", "$", "(", ")", "%", ".", "[", "]", "*", "+", "-", "?" } do
	MAGIC[c] = true
end

-- Convierte una plantilla en un patrón de Lua con una captura por hueco
local function toPattern(template: string): (string, number)
	local out = { "^" }
	local literal = 0
	local i, n = 1, #template
	while i <= n do
		local c = string.sub(template, i, i)
		if c == "%" and string.sub(template, i + 1, i + 1) == "%" then
			table.insert(out, "%%")
			literal += 1
			i += 2
		elseif c == "%" and string.match(template, SPEC, i) then
			local spec = string.match(template, SPEC, i) :: string
			table.insert(out, if string.sub(spec, -1) == "s" then "(.-)" else "([%-%d%.,]+)")
			i += #spec
		else
			table.insert(out, if MAGIC[c] then "%" .. c else c)
			literal += 1
			i += 1
		end
	end
	table.insert(out, "$")
	return table.concat(out), literal
end

type Rule = { pattern: string, template: string, literal: number, multiline: boolean }
local rules: { Rule }? = nil

local function getRules(): { Rule }
	if rules then
		return rules
	end
	local list: { Rule } = {}
	for template in EN do
		if #specsOf(template) > 0 then
			local pattern, literal = toPattern(template)
			table.insert(list, {
				pattern = pattern,
				template = template,
				literal = literal,
				multiline = string.find(template, "\n", 1, true) ~= nil,
			})
		end
	end
	-- Primero las plantillas con más texto fijo (las más concretas)
	table.sort(list, function(a, b)
		if a.literal ~= b.literal then
			return a.literal > b.literal
		end
		return a.template < b.template
	end)
	rules = list
	return list
end

local caches: { [string]: { [string]: string } } = {}
local cacheSize = 0

local function translateText(dict: { [string]: string }, text: string, depth: number): string
	local exact = dict[text]
	if exact then
		return exact
	end
	if depth > 2 or text == "" then
		return text
	end
	-- Un texto de varias líneas solo encaja con plantillas de varias líneas
	-- (si no, se traduce línea a línea, abajo)
	local multiline = string.find(text, "\n", 1, true) ~= nil
	for _, rule in getRules() do
		local captures = if rule.multiline == multiline then table.pack(string.match(text, rule.pattern)) else { n = 0 }
		if captures[1] ~= nil then
			local values = {}
			for i = 1, captures.n do
				-- Los trozos también pueden ser textos traducibles (nombres de webs...)
				values[i] = translateText(dict, captures[i], depth + 1)
			end
			return fill(dict[rule.template] or EN[rule.template], values)
		end
	end
	-- Texto de varias líneas sin plantilla entera: línea a línea
	if string.find(text, "\n", 1, true) then
		local lines = string.split(text, "\n")
		for i, line in lines do
			lines[i] = translateText(dict, line, depth + 1)
		end
		return table.concat(lines, "\n")
	end
	return text
end

function Locale.translate(lang: string, text: string): string
	local dict = DICTS[lang]
	if not dict or type(text) ~= "string" then
		return text
	end
	local cache = caches[lang]
	if not cache then
		cache = {}
		caches[lang] = cache
	end
	local hit = cache[text]
	if hit then
		return hit
	end
	local result = translateText(dict, text, 0)
	if cacheSize > 6000 then
		table.clear(caches)
		cacheSize = 0
		cache = {}
		caches[lang] = cache
	end
	cache[text] = result
	cacheSize += 1
	return result
end

return Locale
