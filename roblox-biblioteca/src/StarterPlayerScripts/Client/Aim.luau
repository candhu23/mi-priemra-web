--!strict
-- Cruceta: rayo desde el centro de la cámara (alcance Config.REACH). Decide qué pasa al pulsar USAR y
-- lo resalta en VERDE (se puede) o ROJO (bloqueado: manos llenas, manos vacías, cofre sin llave…).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local BookData = require(ReplicatedStorage:WaitForChild("BookData"))
local Layout = require(ReplicatedStorage:WaitForChild("Layout"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Books = require(script.Parent:WaitForChild("Books"))

local Aim = {}

export type Target = {
	kind: string, -- "book" | "slot" | "interact"
	ok: boolean,
	book: number?,
	slot: number?,
	interact: string?,
	part: BasePart?,
	label: string,
	section: string?,
	pos: Vector3,
}

Aim.target = nil :: Target?
Aim.sectionCode = nil :: string? -- sección apuntada (para Autocolocar), aunque esté lejos

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
local cursor: Part? = nil
local box: SelectionBox? = nil
local GREEN = Color3.fromRGB(90, 255, 130)
local RED = Color3.fromRGB(255, 80, 70)

local function ensureCursor()
	if cursor then
		return
	end
	local c = Instance.new("Part")
	c.Name = "AimCursor"
	c.Anchored = true
	c.CanCollide = false
	c.CanQuery = false
	c.CanTouch = false
	c.Transparency = 1
	c.Size = Layout.BOOK
	c.Parent = Workspace
	local b = Instance.new("SelectionBox")
	b.Adornee = c
	b.LineThickness = 0.04
	b.SurfaceTransparency = 0.85
	b.Color3 = GREEN
	b.SurfaceColor3 = GREEN
	b.Visible = false
	b.Parent = c
	cursor, box = c, b
end

local function hand(): { number }
	return Kit.ctx.state.hand or {}
end

local function cap(): number
	return Kit.ctx.state.cap or Config.CAPACITY
end

-- Texto corto de un libro: «Tomo 3/10 · 1A»
local function bookText(id: number): string
	local def = Books.def :: Layout.Def
	local info = def.books[id]
	local s = BookData.Series[info.series]
	return Kit.T("hud_vol", { v = info.vol, n = s.volumes })
end

local function interactInfo(kind: string): (boolean, string)
	local st = Kit.ctx.state
	if kind == "letter" then
		return true, Kit.T("aim_letter")
	elseif kind == "door" then
		if st.door then
			return true, Kit.T(if st.lib == "special" then "aim_exit_special" else "aim_door")
		end
		return false, Kit.T("aim_door_locked", { n = Kit.num((st.total or 0) - (st.shelved or 0)) })
	elseif kind == "map1" or kind == "map2" then
		return true, Kit.T("aim_map")
	elseif kind == "crystal" then
		return true, Kit.T("aim_crystal")
	elseif string.sub(kind, 1, 4) == "key_" then
		return true, Kit.T("aim_key")
	elseif string.sub(kind, 1, 6) == "chest_" then
		local color = string.sub(kind, 7)
		local chests = st.chests or {}
		local keys = st.keys or {}
		if chests[color] then
			return false, Kit.T("aim_chest_open")
		elseif keys[color] then
			return true, Kit.T("aim_chest")
		end
		return false, Kit.T("aim_chest_locked", { color = Kit.T("key_" .. color) })
	elseif string.sub(kind, 1, 9) == "painting_" then
		return true, Kit.T("aim_painting")
	end
	return true, ""
end

-- Busca la parte con atributo (la propia o su padre)
local function attr(inst: Instance, name: string): any
	local v = inst:GetAttribute(name)
	if v == nil and inst.Parent then
		v = inst.Parent:GetAttribute(name)
	end
	return v
end

-- Recalcula el objetivo. camCF: CFrame de la cámara. exclude: cosas que el rayo ignora (personaje…)
function Aim.update(camCF: CFrame, exclude: { Instance })
	ensureCursor()
	local list = table.clone(exclude)
	local clientBooks = Workspace:FindFirstChild("ClientBooks")
	if clientBooks then
		for _, name in { "Shelved", "Glows" } do
			local f = clientBooks:FindFirstChild(name)
			if f then
				table.insert(list, f)
			end
		end
	end
	table.insert(list, cursor :: Part)
	params.FilterDescendantsInstances = list
	local origin = camCF.Position
	local result = Workspace:Raycast(origin, camCF.LookVector * Config.REACH, params)
	local target: Target? = nil
	Aim.sectionCode = nil
	local def = Books.def
	if result and def then
		local inst = result.Instance
		local bookId = attr(inst, "Book")
		local rowId = attr(inst, "Row")
		local interact = attr(inst, "Interact")
		if type(bookId) == "number" and def.books[bookId] then
			local ok = #hand() < cap()
			target = {
				kind = "book", ok = ok, book = bookId, part = if Books.parts[bookId] then Books.parts[bookId].body :: BasePart else nil,
				label = (if ok then Kit.T("aim_pick") else Kit.T("aim_full")) .. " · " .. bookText(bookId), pos = result.Position,
			}
		elseif type(rowId) == "number" and def.rows[rowId] then
			local slot = Books.slotAt(rowId, result.Position)
			local row = def.rows[rowId]
			local inSlot = Books.slotBook[slot]
			local secName = row.section .. " " .. BookData.sectionName(def.sectionByCode[row.section].theme, Kit.ctx.lang)
			Aim.sectionCode = row.section
			if inSlot then
				local ok = #hand() < cap()
				target = {
					kind = "book", ok = ok, book = inSlot, slot = slot, section = row.section,
					label = (if ok then Kit.T("aim_pick") else Kit.T("aim_full")) .. " · " .. bookText(inSlot), pos = result.Position,
				}
			else
				local ok = #hand() > 0
				target = {
					kind = "slot", ok = ok, slot = slot, section = row.section,
					label = (if ok then Kit.T("aim_place") else Kit.T("aim_empty")) .. " · " .. secName, pos = result.Position,
				}
			end
		elseif type(interact) == "string" then
			local ok, text = interactInfo(interact)
			target = { kind = "interact", ok = ok, interact = interact, part = inst :: BasePart, label = text, pos = result.Position }
		end
	end
	-- Sección apuntada de lejos (Autocolocar): rayo largo contra las cajas de las filas
	if not Aim.sectionCode and def then
		local far = Workspace:Raycast(origin, camCF.LookVector * Config.AIM_SECTION_RANGE, params)
		if far then
			local rowId = attr(far.Instance, "Row")
			if type(rowId) == "number" and def.rows[rowId] then
				Aim.sectionCode = def.rows[rowId].section
			end
		end
	end
	Aim.target = target
	-- Resaltado
	local c, b = cursor :: Part, box :: SelectionBox
	if target then
		if target.kind == "slot" and def then
			c.CFrame = (def :: Layout.Def).slotCF[target.slot :: number]
			c.Size = Layout.BOOK
		elseif target.slot and def then
			c.CFrame = (def :: Layout.Def).slotCF[target.slot :: number]
			c.Size = Layout.BOOK + Vector3.new(0.05, 0.05, 0.05)
		elseif target.part then
			c.CFrame = target.part.CFrame
			c.Size = target.part.Size + Vector3.new(0.08, 0.08, 0.08)
		end
		b.Color3 = if target.ok then GREEN else RED
		b.SurfaceColor3 = b.Color3
		b.Visible = true
	else
		b.Visible = false
	end
	return target
end

function Aim.hide()
	if box then
		box.Visible = false
	end
	Aim.target = nil
end

local _ = Players
return Aim
