--[[
	Mundo3D (cliente): todo lo 3D que ve el jugador y que NO decide nada.
	- Dibuja las crías de TODOS los jugadores (atributo «Pets» del jugador) siguiéndolos o picando su
	  montón (atributo «Target»). Son piezas locales ancladas y sin colisión: ligeras.
	- Carteles traducidos sobre huevos y puertas (precio; crías descubiertas o puntuación Brillante que pide la
  puerta); abre (localmente) las puertas de las islas ya abiertas.
	- Números «+🪙» flotando donde se rompe un montón. Estrella 🌟 que se ve de lejos sobre el Montón Dorado.
	- Dice qué huevo / puerta tienes al lado (Mundo3D.near) para que el HUD muestre sus botones.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local Mundo3D = {}
Mundo3D.near = { egg = 0, door = 0 }

local Kit: any = nil
local world: Instance = nil :: any
local pileFolder: Instance = nil :: any
local localFolder: Folder = nil :: any
local eggs: { { part: BasePart, zone: number, title: TextLabel, price: TextLabel } } = {}
local doors: { { part: BasePart, zone: number, gui: BillboardGui, title: TextLabel, price: TextLabel, crystals: TextLabel } } = {}

type Rig = { attr: string, pets: { { body: BasePart, pos: Vector3 } } }
local rigs: { [Player]: Rig } = {}
local pileById: { [number]: BasePart } = {}
local clock = 0
local pileScan = 0
local guideGui: BillboardGui? = nil -- flecha del tutorial sobre el huevo o la puerta
local guideKey = ""
local guideBase = 0
local goldMarks: { BillboardGui } = {} -- estrellas sobre los Montones Dorados (se van con el montón)

local function billboard(parent: Instance, size: UDim2, offset: Vector3, maxDistance: number): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.StudsOffset = offset
	gui.MaxDistance = maxDistance
	gui.LightInfluence = 0
	gui.Parent = parent
	return gui
end

local function textOn(gui: Instance, y: number, h: number, size: number, color: Color3): TextLabel
	local t = Kit.title(gui, "", size, color, {
		Position = UDim2.fromScale(0, y), Size = UDim2.fromScale(1, h), TextXAlignment = Enum.TextXAlignment.Center,
	})
	Kit.textStroke(2.5).Parent = t
	Kit.fit(t, size)
	return t
end

-- Bola del color de la cría con su emoji (la ronda 2b pone los animales 3D). Tamaño por rareza; aura de luz
-- desde Épica; las Brillantes, destellos y algo de brillo
local function makePet(kind: string, shiny: boolean): BasePart
	local def = Config.PetById[kind]
	local rarity = Config.Rarities[def.rarity]
	local s = 2.2 * rarity.size
	local body = Instance.new("Part")
	body.Name = "Cria"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(s, s, s)
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.CastShadow = false
	body.Material = if shiny then Enum.Material.Foil else Enum.Material.SmoothPlastic
	body.Color = if shiny then def.color:Lerp(Color3.new(1, 1, 1), 0.25) else def.color
	-- La cara es el emoji de la cría (se reconoce de lejos)
	-- StudsOffset Z va hacia la cámara: la cara queda delante de la bola y no la tapa
	local face = billboard(body, UDim2.fromScale(s * 1.3, s * 1.3), Vector3.new(0, 0, s * 0.6), 120)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = def.emoji
	label.TextScaled = true
	label.Parent = face
	if rarity.aura or shiny then
		local light = Instance.new("PointLight")
		light.Color = if shiny then Config.Colors.white else rarity.color
		light.Range = 8
		light.Brightness = 1.5
		light.Parent = body
	end
	if shiny then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Config.Colors.white
		sparkles.Parent = body
	end
	body.Parent = localFolder
	return body
end

local function rebuild(rig: Rig, attr: string, start: Vector3)
	for _, p in rig.pets do
		p.body:Destroy()
	end
	rig.pets = {}
	rig.attr = attr
	for entry in string.gmatch(attr, "[^,]+") do
		local kind, shiny = string.match(entry, "^(%w+):(%d)$")
		if kind and Config.PetById[kind] then
			table.insert(rig.pets, { body = makePet(kind, shiny == "1"), pos = start })
		end
	end
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function step(dt: number)
	clock += dt
	pileScan -= dt
	if pileScan <= 0 then
		pileScan = 0.4
		pileById = {}
		for _, p in pileFolder:GetChildren() do
			local id = p:GetAttribute("PileId")
			if type(id) == "number" and p:IsA("BasePart") then
				pileById[id] = p
				-- Montón Dorado: estrella enorme que se ve a través de todo (local, solo se crea una vez)
				if p:GetAttribute("Gold") == true and not p:FindFirstChild("MarcaDorada") then
					local mark = billboard(p, UDim2.fromOffset(120, 120), Vector3.new(0, 7, 0), 400)
					mark.Name = "MarcaDorada"
					mark.AlwaysOnTop = true
					local star = textOn(mark, 0, 1, 90, Config.Colors.gold)
					star.Text = "🌟"
					table.insert(goldMarks, mark)
				end
			end
		end
	end
	-- La estrella sube y baja (las de montones ya rotos se quitan de la lista)
	for i = #goldMarks, 1, -1 do
		local mark = goldMarks[i]
		if mark.Parent then
			mark.StudsOffset = Vector3.new(0, 7 + math.sin(clock * 3) * 0.6, 0)
		else
			table.remove(goldMarks, i)
		end
	end
	local alpha = math.min(1, dt * 7)
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		local rig = rigs[player]
		if not rig then
			rig = { attr = "", pets = {} }
			rigs[player] = rig
		end
		local attr = player:GetAttribute("Pets")
		if type(attr) ~= "string" then
			attr = ""
		end
		if root and attr ~= rig.attr then
			rebuild(rig, attr :: string, root.Position)
		end
		if root then
			local target = pileById[player:GetAttribute("Target") :: any]
			local n = #rig.pets
			for i, pet in rig.pets do
				local goal: Vector3
				local look: Vector3
				if target and (target.Position - root.Position).Magnitude <= Config.REACH then
					-- Picando: en círculo alrededor del montón, dando saltitos
					local a = i / n * math.pi * 2 + clock * 0.8
					local hop = math.abs(math.sin(clock * 9 + i)) * 1.6
					local rad = (target:GetAttribute("Radius") :: number?) or 4.5 -- las rocas grandes se rodean más lejos
					goal = target.Position + Vector3.new(math.cos(a) * rad, 1.5 + hop, math.sin(a) * rad)
					look = target.Position
				else
					-- Siguiendo: en filas de 3 detrás del jugador, flotando
					local row = (i - 1) // 3
					local col = (i - 1) % 3 - 1
					local spot = root.CFrame * CFrame.new(col * 4, 0, 6 + row * 4)
					goal = spot.Position + Vector3.new(0, -1 + math.sin(clock * 3 + i) * 0.4, 0)
					look = goal + root.CFrame.LookVector
				end
				pet.pos = pet.pos:Lerp(goal, alpha)
				pet.body.CFrame = CFrame.lookAt(pet.pos, Vector3.new(look.X, pet.pos.Y, look.Z))
			end
		end
	end
	-- Jugadores que se han ido
	for player, rig in rigs do
		if not player.Parent then
			for _, p in rig.pets do
				p.body:Destroy()
			end
			rigs[player] = nil
		end
	end
	-- Flecha del tutorial: sube y baja para que se vea de lejos
	if guideGui then
		guideGui.StudsOffset = Vector3.new(0, guideBase + math.sin(clock * 4) * 0.8, 0)
	end
	-- ¿Qué tengo al lado?
	local me = rootOf(Players.LocalPlayer)
	Mundo3D.near.egg, Mundo3D.near.door = 0, 0
	if me then
		local s = Kit.ctx.state
		for _, e in eggs do
			if (e.part.Position - me.Position).Magnitude <= Config.EGG_REACH - 2 and s and e.zone <= s.zones then
				Mundo3D.near.egg = e.zone
			end
		end
		for _, d in doors do
			if (d.part.Position - me.Position).Magnitude <= Config.DOOR_REACH and s and d.zone > s.zones then
				Mundo3D.near.door = d.zone
			end
		end
	end
end

-- Texto flotante en el mundo (p. ej. «+🪙 25» al romper un montón). rel = lo que vale frente al premio típico
-- de la isla (1 = normal): cuanto más vale, más grande sale (Config.FLOAT_TEXT)
function Mundo3D.floatText(pos: Vector3, text: string, color: Color3?, rel: number?)
	local f = Config.FLOAT_TEXT
	local size = math.clamp(f.base * math.max(rel or 1, 0.01) ^ f.exp, f.min, f.max)
	local k = size / f.base
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
	anchor.Parent = localFolder
	local gui = billboard(anchor, UDim2.fromOffset(math.floor(160 * k), math.floor(44 * k)), Vector3.new(0, 0, 0), 150)
	gui.AlwaysOnTop = true
	local t = textOn(gui, 0, 1, math.floor(size), color or Config.Colors.gold)
	t.Text = text
	Kit.tween(gui, 0.9, { StudsOffset = Vector3.new(0, 5, 0) })
	Kit.tween(t, 0.9, { TextTransparency = 1 })
	task.delay(0.9, function()
		anchor:Destroy()
	end)
end

-- Con cada estado: puertas abiertas/cerradas y precios
function Mundo3D.refresh(s: any)
	local T = Kit.T
	for _, e in eggs do
		local z = Config.Zones[e.zone]
		e.title.Text = "🥚 " .. T("egg_title", { zone = T("zone_" .. z.id), rarity = T("egg_" .. Config.Rarities[z.eggRarity].id) })
		e.price.Text = if e.zone <= s.zones then "🪙 " .. Kit.fmt(Config.eggCost(e.zone, s)) else "🔒"
	end
	for _, d in doors do
		local open = s.zones >= d.zone
		d.part.CanCollide = not open
		d.part.Transparency = if open then 1 else 0.2
		d.gui.Enabled = not open
		d.title.Text = T("door_title", { zone = T("zone_" .. Config.Zones[d.zone].id) })
		-- Lo que pide: «📖 9/11» (crías descubiertas) o «✨ 143/200» (puntuación Brillante)
		if d.zone == s.zones + 1 then
			local _ok, kind, need, have = Config.zoneNeed(s, d.zone)
			d.price.Text = (if kind == "shiny" then "✨ " else "📖 ") .. math.min(have, need) .. "/" .. need
		else
			d.price.Text = T("door_need")
		end
		-- Cuánto rinden sus cristales frente a la isla 1 (monedas por punto de vida: lo que de verdad se gana)
		d.crystals.Text = T("door_crystals", { value = Kit.fmt(Config.zoneCrystalMult(d.zone)) })
	end
end

-- Flecha grande (se ve a través de todo) sobre el huevo de la última isla abierta («egg») o sobre la
-- puerta de la siguiente («door»). kind = "" la quita. Solo es una ayuda visual del tutorial.
function Mundo3D.guide(kind: string, zones: number)
	local key = kind .. ":" .. zones
	if key == guideKey then
		return
	end
	guideKey = key
	if guideGui then
		guideGui:Destroy()
		guideGui = nil
	end
	local target: BasePart? = nil
	if kind == "egg" then
		for _, e in eggs do
			if e.zone == math.max(1, zones) then
				target = e.part
			end
		end
	elseif kind == "door" then
		for _, d in doors do
			if d.zone == zones + 1 then
				target = d.part
			end
		end
	end
	if not target then
		return
	end
	guideBase = if kind == "egg" then 14 else 10
	local gui = billboard(target, UDim2.fromOffset(110, 110), Vector3.new(0, guideBase, 0), 2000)
	gui.Name = "GuiaTutorial"
	gui.AlwaysOnTop = true
	local arrow = textOn(gui, 0, 1, 90, Config.Colors.gold)
	arrow.Text = "⬇️"
	guideGui = gui
end

function Mundo3D.start(kit: any)
	Kit = kit
	world = Workspace:WaitForChild("Mundo")
	pileFolder = world:WaitForChild("Montones")
	localFolder = Instance.new("Folder")
	localFolder.Name = "CriasLocales"
	localFolder.Parent = Workspace
	-- Huevos y puertas (también los que lleguen más tarde, por si el mapa se carga por partes)
	local function register(d: Instance)
		local zone = d:GetAttribute("Zone")
		if d:IsA("BasePart") and type(zone) == "number" then
			if d.Name == "Huevo" then
				local gui = billboard(d, UDim2.fromOffset(240, 80), Vector3.new(0, 8, 0), 140)
				table.insert(eggs, { part = d, zone = zone, title = textOn(gui, 0, 0.5, 26, Config.Colors.white), price = textOn(gui, 0.5, 0.5, 26, Config.Colors.gold) })
			elseif d.Name == "Puerta" then
				local gui = billboard(d, UDim2.fromOffset(260, 112), Vector3.new(0, 5, 0), 160)
				table.insert(doors, {
					part = d, zone = zone, gui = gui, title = textOn(gui, 0, 0.36, 26, Config.Colors.white),
					price = textOn(gui, 0.36, 0.34, 24, Config.Colors.gold), crystals = textOn(gui, 0.7, 0.3, 20, Config.Colors.sky),
				})
			end
			if Kit.ctx.state then
				Mundo3D.refresh(Kit.ctx.state)
			end
		end
	end
	for _, d in world:GetDescendants() do
		register(d)
	end
	world.DescendantAdded:Connect(register)
	RunService.RenderStepped:Connect(step)
end

return Mundo3D
