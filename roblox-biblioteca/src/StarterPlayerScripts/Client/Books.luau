--!strict
-- Libros en el CLIENTE: cada libro = cuerpo + franja (2 Part ancladas, sin colisión, visibles para el rayo).
-- El servidor manda dónde está cada libro (foto + deltas) y aquí solo se dibuja:
--   · brillo dorado / rojo detrás de cada hueco (una pieza fina; nada de Highlight, que Roblox limita a ~31)
--   · placas de sección (azules cuando toda la sección está bien)
--   · etiquetas de lomo/tapa: un grupo REUTILIZABLE de SurfaceGui solo para los libros cercanos
--   · Revelar (material Neón) y Guía de estantería (SelectionBox)
--   · animaciones: los libros vuelan (sin física: se interpola en Heartbeat)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BookData = require(ReplicatedStorage:WaitForChild("BookData"))
local Layout = require(ReplicatedStorage:WaitForChild("Layout"))
local Rules = require(ReplicatedStorage:WaitForChild("Rules"))
local Codec = require(ReplicatedStorage:WaitForChild("Codec"))
local Lang = require(ReplicatedStorage:WaitForChild("Lang"))

local Books = {}

type Parts = { body: Part, band: Part }
type Anim = { from: CFrame, to: CFrame, t: number, dur: number, arc: number }

Books.def = nil :: Layout.Def?
Books.locs = {} :: { Codec.Loc }
Books.slotBook = {} :: { [number]: number }
Books.parts = {} :: { [number]: Parts }
Books.rowCorrect = {} :: { [number]: boolean }
Books.sectionDone = {} :: { [string]: boolean }
Books.lang = "es"
Books.onRow = nil :: ((rowId: number, correct: boolean) -> ())?
Books.onSection = nil :: ((code: string, done: boolean) -> ())?

local GOLD = Color3.fromRGB(255, 196, 60) -- cambia con el pase de mecenas (Books.setGlowColor)
local RED = Color3.fromRGB(205, 70, 60)
local PLATE_DONE = Color3.fromRGB(70, 140, 255)
local LABELS = 36 -- etiquetas reutilizables
local LABEL_RANGE = 12

local root: Folder? = nil
local looseFolder: Folder? = nil
local shelfFolder: Folder? = nil
local glowFolder: Folder? = nil
local rowFolder: Folder? = nil
local glows: { [number]: Part } = {}
local rowHit: { [number]: Part } = {}
local anims: { [number]: Anim } = {}
local plateGuis: { [string]: SurfaceGui } = {}
local labelPool: { SurfaceGui } = {}
local labelOf: { [number]: SurfaceGui } = {}
local revealed: { [number]: boolean } = {}
local guideBoxes: { Instance } = {}
local colorCache: { [string]: Color3 } = {}
local loading = false -- durante la carga no suenan avisos de filas/placas

local function color(hex: string): Color3
	local c = colorCache[hex]
	if not c then
		c = BookData.color(hex)
		colorCache[hex] = c
	end
	return c
end

local function playerGui(): Instance?
	local plr = Players.LocalPlayer
	return if plr then plr:FindFirstChild("PlayerGui") else nil
end

local function newFolder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local BAND_Y = { 0.46, 0, -0.46 }

local function bookParts(id: number): Parts
	local def = Books.def :: Layout.Def
	local info = def.books[id]
	local cover = BookData.Series[info.series].cover
	local body = Instance.new("Part")
	body.Name = "B" .. id
	body.Anchored = true
	body.CanCollide = false
	body.CanTouch = false
	body.CastShadow = false
	body.Size = Layout.BOOK
	body.Color = color(cover.base)
	body.Material = Enum.Material.SmoothPlastic
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body:SetAttribute("Book", id)
	local band = Instance.new("Part")
	band.Name = "F" .. id
	band.Anchored = true
	band.CanCollide = false
	band.CanTouch = false
	band.CastShadow = false
	band.Size = Vector3.new(Layout.BOOK.X + 0.02, 0.2, Layout.BOOK.Z + 0.02)
	band.Color = color(cover.band)
	band.Material = Enum.Material.SmoothPlastic
	band:SetAttribute("Book", id)
	return { body = body, band = band }
end

local function bandOffset(id: number): CFrame
	local def = Books.def :: Layout.Def
	local cover = BookData.Series[def.books[id].series].cover
	return CFrame.new(0, BAND_Y[cover.pos] or 0, 0)
end

local function setCF(id: number, cf: CFrame)
	local p = Books.parts[id]
	p.body.CFrame = cf
	p.band.CFrame = cf * bandOffset(id)
end

-- Dónde se dibuja un libro según su sitio (nil = en la mano: no se dibuja)
local function targetCF(id: number, loc: Codec.Loc): CFrame?
	if loc.k == 3 then
		return nil
	end
	return Layout.bookCF(Books.def :: Layout.Def, id, loc)
end

local function place(id: number, loc: Codec.Loc)
	local p = Books.parts[id]
	local cf = targetCF(id, loc)
	if not cf then
		p.body.Parent = nil :: any
		p.band.Parent = nil :: any
		return
	end
	setCF(id, cf)
	-- En estantería el rayo lo recoge la caja de la fila; sueltos, el propio libro
	local parent = if loc.k == 1 then shelfFolder else looseFolder
	p.body.CanQuery = loc.k ~= 1
	p.band.CanQuery = loc.k ~= 1
	p.body.Parent = parent
	p.band.Parent = parent
end

---------------------------------------------------------------------
-- Brillos, filas y placas
---------------------------------------------------------------------
local function glowPart(slot: number): Part
	local existing = glows[slot]
	if existing then
		return existing
	end
	local def = Books.def :: Layout.Def
	local g = Instance.new("Part")
	g.Name = "G" .. slot
	g.Anchored = true
	g.CanCollide = false
	g.CanQuery = false
	g.CanTouch = false
	g.CastShadow = false
	g.Material = Enum.Material.Neon
	g.Size = Vector3.new(Layout.BOOK.X + 0.1, Layout.BOOK.Y + 0.12, 0.06)
	g.CFrame = def.slotCF[slot] * CFrame.new(0, 0.03, Layout.BOOK.Z / 2 + 0.06)
	g.Parent = glowFolder
	glows[slot] = g
	return g
end

local function refreshPlate(code: string)
	local def = Books.def :: Layout.Def
	local sec = def.sectionByCode[code]
	local done = true
	for _, r in sec.rows do
		if not Books.rowCorrect[r] then
			done = false
			break
		end
	end
	local was = Books.sectionDone[code]
	Books.sectionDone[code] = done
	local model = Workspace:FindFirstChild(if def.name == "main" then "Library" else "Archive")
	local plates = model and model:FindFirstChild("plates")
	local plate = plates and plates:FindFirstChild("Plate_" .. code)
	if plate and plate:IsA("BasePart") then
		plate.Color = if done then PLATE_DONE else Layout.Colors.plate
		plate.Material = if done then Enum.Material.Neon else Enum.Material.SmoothPlastic
	end
	if not loading and was ~= nil and was ~= done and Books.onSection then
		(Books.onSection :: any)(code, done)
	end
end

function Books.refreshRow(rowId: number, quiet: boolean?)
	local def = Books.def :: Layout.Def
	local row = def.rows[rowId]
	local correct, list = Rules.row(def, rowId, Books.slotBook)
	for i = 1, row.len do
		local slot = row.first + i - 1
		local g = list[i]
		if g == Rules.GLOW_NONE then
			local part = glows[slot]
			if part then
				part.Transparency = 1
			end
		else
			local part = glowPart(slot)
			part.Color = if g == Rules.GLOW_GOLD then GOLD else RED
			part:SetAttribute("Good", g == Rules.GLOW_GOLD)
			part.Transparency = if g == Rules.GLOW_GOLD then 0 else 0.45
		end
	end
	local was = Books.rowCorrect[rowId]
	Books.rowCorrect[rowId] = correct
	if not loading and not quiet and was ~= correct and Books.onRow then
		(Books.onRow :: any)(rowId, correct)
	end
	if not quiet or was ~= correct then
		refreshPlate(row.section)
	end
end

function Books.countCorrect(): number
	local n = 0
	for _, ok in Books.rowCorrect do
		if ok then
			n += 1
		end
	end
	return n
end

function Books.countShelved(): number
	local n = 0
	for _ in Books.slotBook do
		n += 1
	end
	return n
end

---------------------------------------------------------------------
-- Etiquetas reutilizables (lomo en estantería, tapa en el suelo)
---------------------------------------------------------------------
local function makeLabel(): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BookLabel"
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 80
	gui.LightInfluence = 0.4
	gui.Enabled = false
	gui.ResetOnSpawn = false
	local function label(name: string, size: UDim2, pos: UDim2, font: Enum.Font): TextLabel
		local t = Instance.new("TextLabel")
		t.Name = name
		t.BackgroundTransparency = 1
		t.Size = size
		t.Position = pos
		t.TextScaled = true
		t.Font = font
		t.TextWrapped = true
		t.Parent = gui
		return t
	end
	-- Lomo (0,4 × 1,4 studs): símbolo arriba, título en vertical, tomo abajo
	label("SpineSym", UDim2.new(1, 0, 0.16, 0), UDim2.new(0, 0, 0.02, 0), Enum.Font.GothamBold)
	local title = label("SpineTitle", UDim2.new(0, 72, 0, 26), UDim2.new(0.5, -36, 0.46, -13), Enum.Font.Gotham)
	title.Rotation = 90
	label("SpineVol", UDim2.new(1, 0, 0.2, 0), UDim2.new(0, 0, 0.78, 0), Enum.Font.GothamBlack)
	-- Tapa (1 × 1,4 studs, mirando arriba cuando está tumbado)
	label("CoverSym", UDim2.new(1, 0, 0.2, 0), UDim2.new(0, 0, 0.04, 0), Enum.Font.GothamBold)
	label("CoverTitle", UDim2.new(0.9, 0, 0.5, 0), UDim2.new(0.05, 0, 0.25, 0), Enum.Font.GothamMedium)
	label("CoverVol", UDim2.new(1, 0, 0.18, 0), UDim2.new(0, 0, 0.78, 0), Enum.Font.GothamBlack)
	return gui
end

local function fillLabel(gui: SurfaceGui, id: number, loc: Codec.Loc)
	local def = Books.def :: Layout.Def
	local info = def.books[id]
	local s = BookData.Series[info.series]
	local tc = color(s.cover.text)
	local title = if Books.lang == "es" then s.es else s.en
	local spine = loc.k == 1
	gui.Face = if spine then Enum.NormalId.Front else Enum.NormalId.Right
	for _, child in gui:GetChildren() do
		if child:IsA("TextLabel") then
			local isSpine = string.sub(child.Name, 1, 5) == "Spine"
			child.Visible = isSpine == spine
			child.TextColor3 = tc
		end
	end
	local function set(name: string, text: string)
		local l = gui:FindFirstChild(name)
		if l and l:IsA("TextLabel") then
			l.Text = text
		end
	end
	set("SpineSym", s.cover.sym)
	set("SpineTitle", title)
	set("SpineVol", tostring(info.vol))
	set("CoverSym", s.cover.sym)
	set("CoverTitle", title)
	set("CoverVol", Lang.t(Books.lang, "hud_vol", { v = info.vol, n = s.volumes }))
end

-- Pone etiquetas en los libros más cercanos que estén delante de la cámara
function Books.updateLabels(camCF: CFrame)
	local def = Books.def
	if not def then
		return
	end
	local origin, look = camCF.Position, camCF.LookVector
	local near: { { id: number, d: number } } = {}
	local r2 = LABEL_RANGE * LABEL_RANGE
	for id, p in Books.parts do
		if p.body.Parent then
			local off = p.body.CFrame.Position - origin
			local d = off.X * off.X + off.Y * off.Y + off.Z * off.Z
			if d < r2 and off:Dot(look) > -1 then
				table.insert(near, { id = id, d = d })
			end
		end
	end
	table.sort(near, function(a, b)
		return a.d < b.d
	end)
	local wanted: { [number]: boolean } = {}
	for i = 1, math.min(#near, LABELS) do
		wanted[near[i].id] = true
	end
	-- Libera las que ya no hacen falta
	for id, gui in labelOf do
		if not wanted[id] then
			gui.Enabled = false
			-- (en Lune no se puede poner Adornee = nil; desactivarla basta)
			labelOf[id] = nil
			table.insert(labelPool, gui)
		end
	end
	for id in wanted do
		local loc = Books.locs[id]
		local face = if loc.k == 1 then Enum.NormalId.Front else Enum.NormalId.Right
		local gui: SurfaceGui? = labelOf[id]
		if gui == nil then
			local free = table.remove(labelPool)
			if free == nil then
				continue
			end
			labelOf[id] = free
			fillLabel(free, id, loc)
			gui = free
		elseif gui.Face ~= face then
			fillLabel(gui, id, loc)
		end
		local g = gui :: SurfaceGui
		g.Adornee = Books.parts[id].body
		g.Enabled = true
	end
end

---------------------------------------------------------------------
-- Revelar y Guía
---------------------------------------------------------------------
-- Hace brillar (Neón) los tomos de una serie a menos de `range` de `origin` (series nil = apagar)
function Books.reveal(series: number?, origin: Vector3?, range: number?)
	local def = Books.def
	if not def then
		return
	end
	local want: { [number]: boolean } = {}
	if series and origin then
		local first = def.seriesFirst[series]
		for v = 1, BookData.Series[series].volumes do
			local id = first + v - 1
			local p = Books.parts[id]
			if p and p.body.Parent and (p.body.CFrame.Position - origin).Magnitude <= (range or 1e9) then
				want[id] = true
			end
		end
	end
	for id in revealed do
		if not want[id] then
			local p = Books.parts[id]
			local cover = BookData.Series[def.books[id].series].cover
			p.body.Material = Enum.Material.SmoothPlastic
			p.body.Color = color(cover.base)
			p.band.Material = Enum.Material.SmoothPlastic
			p.band.Color = color(cover.band)
			revealed[id] = nil
		end
	end
	for id in want do
		if not revealed[id] then
			local p = Books.parts[id]
			p.body.Material = Enum.Material.Neon
			p.body.Color = p.body.Color:Lerp(Color3.new(1, 1, 1), 0.35)
			p.band.Material = Enum.Material.Neon
			p.band.Color = Color3.fromRGB(110, 240, 255)
			revealed[id] = true
		end
	end
end

-- Resalta la sección de una serie y sus filas libres de la longitud correcta (series nil = apagar)
function Books.guide(series: number?)
	for _, inst in guideBoxes do
		inst:Destroy()
	end
	table.clear(guideBoxes)
	local def = Books.def
	if not def or not series or not root then
		return
	end
	local code = def.seriesSection[series]
	local sec = def.sectionByCode[code]
	if not sec then
		return
	end
	local len = BookData.Series[series].volumes
	local function boxFor(cf: CFrame, size: Vector3, c: Color3, thick: number)
		local holder = Instance.new("Part")
		holder.Name = "Guide"
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.CFrame = cf
		holder.Size = size
		holder.Parent = root
		local sb = Instance.new("SelectionBox")
		sb.Adornee = holder
		sb.Color3 = c
		sb.LineThickness = thick
		sb.SurfaceTransparency = 1
		sb.Parent = holder
		table.insert(guideBoxes, holder)
	end
	local b = sec.box
	boxFor(CFrame.new((b.min + b.max) / 2), b.max - b.min + Vector3.new(0.3, 0.3, 0.3), Color3.fromRGB(110, 240, 255), 0.12)
	for _, rowId in sec.rows do
		local row = def.rows[rowId]
		if row.len == len then
			local ok = true
			for i = 1, row.len do
				local bk = Books.slotBook[row.first + i - 1]
				if bk and def.books[bk].series ~= series then
					ok = false
					break
				end
			end
			if ok and not Books.rowCorrect[rowId] then
				boxFor(row.cf, row.size, Color3.fromRGB(120, 255, 160), 0.05)
			end
		end
	end
end

---------------------------------------------------------------------
-- Carga, movimientos y animaciones
---------------------------------------------------------------------
function Books.init()
	if root then
		return
	end
	local r = newFolder("ClientBooks", Workspace)
	root = r
	looseFolder = newFolder("Loose", r)
	shelfFolder = newFolder("Shelved", r)
	glowFolder = newFolder("Glows", r)
	rowFolder = newFolder("Rows", r)
	local gui = playerGui()
	for _ = 1, LABELS do
		local l = makeLabel()
		l.Parent = gui
		table.insert(labelPool, l)
	end
	RunService.Heartbeat:Connect(function(dt: number)
		Books.step(dt)
	end)
end

-- Construye todos los libros de una biblioteca a partir de sus sitios
function Books.load(def: Layout.Def, locs: { Codec.Loc })
	Books.clear()
	Books.def = def
	Books.locs = locs
	for id = 1, #def.books do
		Books.parts[id] = bookParts(id)
		local loc = locs[id]
		if loc.k == 1 then
			Books.slotBook[loc.s :: number] = id
		end
		place(id, loc)
	end
	for _, row in def.rows do
		local hit = Instance.new("Part")
		hit.Name = "Row" .. row.id
		hit.Anchored = true
		hit.CanCollide = false
		hit.CanTouch = false
		hit.CastShadow = false
		hit.Transparency = 1
		hit.CFrame = row.cf
		hit.Size = row.size
		hit:SetAttribute("Row", row.id)
		hit.Parent = rowFolder
		rowHit[row.id] = hit
	end
	loading = true
	for _, row in def.rows do
		Books.refreshRow(row.id, true)
	end
	loading = false
	Books.setLang(Books.lang)
end

function Books.clear()
	for _, p in Books.parts do
		p.body:Destroy()
		p.band:Destroy()
	end
	for _, g in glows do
		g:Destroy()
	end
	for _, h in rowHit do
		h:Destroy()
	end
	for id, gui in labelOf do
		gui.Enabled = false
		-- (en Lune no se puede poner Adornee = nil; desactivarla basta)
		table.insert(labelPool, gui)
		labelOf[id] = nil
	end
	for _, gui in plateGuis do
		gui:Destroy()
	end
	Books.guide(nil)
	table.clear(plateGuis)
	table.clear(glows)
	table.clear(rowHit)
	table.clear(anims)
	table.clear(revealed)
	Books.parts = {}
	Books.slotBook = {}
	Books.rowCorrect = {}
	Books.sectionDone = {}
	Books.locs = {}
end

-- Aplica un cambio del servidor. anim: "fly" (vuela desde `from`), "throw" (arco), nil (al instante)
function Books.move(id: number, loc: Codec.Loc, anim: string?, from: Vector3?)
	local def = Books.def
	if not def or not Books.parts[id] then
		return
	end
	local old = Books.locs[id]
	local rowsTouched: { [number]: boolean } = {}
	if old and old.k == 1 then
		local s = old.s :: number
		if Books.slotBook[s] == id then
			Books.slotBook[s] = nil
		end
		rowsTouched[def.slotRow[s]] = true
	end
	if labelOf[id] then
		labelOf[id].Enabled = false
		-- (desactivada basta)
		table.insert(labelPool, labelOf[id])
		labelOf[id] = nil
	end
	Books.locs[id] = loc
	if loc.k == 1 then
		Books.slotBook[loc.s :: number] = id
		rowsTouched[def.slotRow[loc.s :: number]] = true
	end
	place(id, loc)
	local to = targetCF(id, loc)
	if anim and from and to then
		anims[id] = { from = CFrame.new(from) * to.Rotation, to = to, t = 0, dur = if anim == "throw" then 0.55 else 0.35, arc = if anim == "throw" then 2.5 else 0.6 }
		setCF(id, anims[id].from)
	else
		anims[id] = nil
	end
	for rowId in rowsTouched do
		Books.refreshRow(rowId)
	end
end

function Books.step(dt: number)
	for id, a in anims do
		a.t += dt
		local k = math.clamp(a.t / a.dur, 0, 1)
		local e = 1 - (1 - k) * (1 - k)
		local cf = a.from:Lerp(a.to, e) + Vector3.new(0, math.sin(k * math.pi) * a.arc, 0)
		if k >= 1 then
			cf = a.to
			anims[id] = nil
		end
		if Books.parts[id] then
			setCF(id, cf)
		end
	end
end

function Books.finishAnims()
	for id, a in anims do
		setCF(id, a.to)
	end
	table.clear(anims)
end

-- Textos de las placas (en el idioma del jugador)
function Books.setLang(lang: string)
	Books.lang = lang
	local def = Books.def
	if not def then
		return
	end
	for _, gui in plateGuis do
		gui:Destroy()
	end
	table.clear(plateGuis)
	local model = Workspace:FindFirstChild(if def.name == "main" then "Library" else "Archive")
	local plates = model and model:FindFirstChild("plates")
	local pg = playerGui()
	if not plates or not pg then
		return
	end
	for _, sec in def.sections do
		local plate = plates:FindFirstChild("Plate_" .. sec.code)
		if plate then
			local gui = Instance.new("SurfaceGui")
			gui.Name = "Plate_" .. sec.code
			gui.Face = Enum.NormalId.Front
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 60
			gui.LightInfluence = 0.3
			gui.ResetOnSpawn = false
			gui.Adornee = plate
			local code = Instance.new("TextLabel")
			code.Name = "Code"
			code.BackgroundTransparency = 1
			code.Size = UDim2.new(0.28, 0, 1, 0)
			code.Text = if def.name == "main" then sec.code else string.sub(sec.code, 2)
			code.TextScaled = true
			code.Font = Enum.Font.GothamBlack
			code.TextColor3 = Color3.fromRGB(255, 236, 190)
			code.Parent = gui
			local name = Instance.new("TextLabel")
			name.Name = "Theme"
			name.BackgroundTransparency = 1
			name.Position = UDim2.new(0.28, 0, 0.12, 0)
			name.Size = UDim2.new(0.7, 0, 0.76, 0)
			name.Text = BookData.sectionName(sec.theme, lang)
			name.TextScaled = true
			name.TextWrapped = true
			name.Font = Enum.Font.GothamBold
			name.TextColor3 = Color3.fromRGB(255, 255, 255)
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.Parent = gui
			gui.Parent = pg
			plateGuis[sec.code] = gui
		end
	end
	for id, gui in labelOf do
		fillLabel(gui, id, Books.locs[id])
	end
end

-- Hueco de una fila a partir del punto donde la ha tocado el rayo
function Books.slotAt(rowId: number, hitPos: Vector3): number
	local def = Books.def :: Layout.Def
	local row = def.rows[rowId]
	local x = row.cf:PointToObjectSpace(hitPos).X
	local i = math.floor((-x + row.len * Layout.PITCH / 2) / Layout.PITCH) + 1
	return row.first + math.clamp(i, 1, row.len) - 1
end

function Books.rowPart(rowId: number): Part?
	return rowHit[rowId]
end

-- Color del brillo «bien colocado» (pase de mecenas). Repinta los que ya brillan.
function Books.setGlowColor(color: Color3)
	if color == GOLD then
		return
	end
	GOLD = color
	for _, part in glows do
		if part:GetAttribute("Good") == true then
			part.Color = color
		end
	end
end

return Books
