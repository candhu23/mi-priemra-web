--!strict
-- Reglas del juego, IGUALES en servidor y cliente: validación de filas y brillos, puntos, hechizos,
-- rango y final. (Ver DISENO.md §6, §7 y §10.)

local RS = script.Parent
local Config = require(RS:WaitForChild("Config"))
local BookData = require(RS:WaitForChild("BookData"))
local Layout = require(RS:WaitForChild("Layout"))

local Rules = {}

Rules.GLOW_NONE, Rules.GLOW_GOLD, Rules.GLOW_RED = 0, 1, 2

-- Estado de una fila. slotBook[hueco] = libro. Devuelve (fila correcta, brillo de cada hueco 1..len).
-- Dorado: sección de la estantería + longitud de la serie = longitud de la fila + hueco = su tomo + en la fila
-- no hay libros de otra serie. Rojo tenue: sección correcta pero falla algo de lo anterior. Nada: otra sección.
function Rules.row(def: Layout.Def, rowId: number, slotBook: { [number]: number }): (boolean, { number })
	local row = def.rows[rowId]
	local glows = table.create(row.len, 0)
	local series: number? = nil
	local mixed, filled = false, 0
	for i = 1, row.len do
		local b = slotBook[row.first + i - 1]
		if b then
			filled += 1
			local s = def.books[b].series
			if series == nil then
				series = s
			elseif series ~= s then
				mixed = true
			end
		end
	end
	local correct = filled == row.len and not mixed
	for i = 1, row.len do
		local b = slotBook[row.first + i - 1]
		if b then
			local info = def.books[b]
			if def.seriesSection[info.series] == row.section then
				if BookData.Series[info.series].volumes == row.len and info.vol == i and not mixed then
					glows[i] = Rules.GLOW_GOLD
				else
					glows[i] = Rules.GLOW_RED
					correct = false
				end
			else
				correct = false
			end
		end
	end
	return correct, glows
end

---------------------------------------------------------------------
-- Puntos: por RÉCORD de filas correctas (Config.POINT_TIERS)
---------------------------------------------------------------------
function Rules.points(bestRows: number): number
	local total, prev = 0, 0
	for _, tier in Config.POINT_TIERS do
		local upto = math.min(bestRows, tier.upTo)
		if upto > prev then
			total += (upto - prev) // tier.every
		end
		prev = tier.upTo
	end
	return total
end

-- Nº de filas con el que llega el siguiente punto (nil si ya están todos)
function Rules.nextPointAt(bestRows: number): number?
	local prev = 0
	for _, tier in Config.POINT_TIERS do
		if bestRows < tier.upTo then
			local done = (math.max(bestRows, prev) - prev) // tier.every
			return prev + (done + 1) * tier.every
		end
		prev = tier.upTo
	end
	return nil
end

---------------------------------------------------------------------
-- Hechizos
---------------------------------------------------------------------
-- Valor de un hechizo a un nivel (field: "cooldown" | "duration" | "count" | "range")
function Rules.skill(id: string, level: number, field: string): number
	local s = Config.SkillById[id]
	local list = (s :: any)[field] :: { number }?
	if not list or level < 1 then
		return 0
	end
	return list[math.min(level, #list)]
end

function Rules.allLearned(levels: { [string]: number }): boolean
	for _, s in Config.Skills do
		if (levels[s.id] or 0) < 1 then
			return false
		end
	end
	return true
end

function Rules.allMaxed(levels: { [string]: number }): boolean
	for _, s in Config.Skills do
		if (levels[s.id] or 0) < s.max then
			return false
		end
	end
	return true
end

---------------------------------------------------------------------
-- Evaluación
---------------------------------------------------------------------
function Rules.rank(rows: number, total: number, seconds: number, magicUsed: boolean): number
	if rows <= 0 then
		return 1
	elseif rows < total * 0.5 then
		return 2
	elseif rows < total then
		return 3
	end
	if seconds <= Config.RANK_TIME_TOP or (not magicUsed and seconds <= Config.RANK_TIME_TOP_NOMAGIC) then
		return 6
	elseif seconds <= Config.RANK_TIME_GOOD or not magicUsed then
		return 5
	end
	return 4
end

-- Final principal y lista de finales conseguidos
function Rules.ending(rows: number, total: number, seconds: number, magicUsed: boolean): (string, { string })
	if rows <= 0 then
		return "fired", { "fired" }
	elseif rows < total then
		return "partial", { "partial" }
	end
	local list = { "normal" }
	if not magicUsed then
		table.insert(list, "nomagic")
	end
	if seconds < Config.PIZZA_TIME then
		table.insert(list, "pizza")
	end
	local main = if seconds < Config.PIZZA_TIME then "pizza" elseif not magicUsed then "nomagic" else "normal"
	return main, list
end

return Rules
