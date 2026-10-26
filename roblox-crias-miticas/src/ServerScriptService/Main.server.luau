--[[
	Servidor de Crías Míticas. EL SERVIDOR MANDA: el cliente solo enseña y pide acciones.
	Remotes (ReplicatedStorage.MythicHatchlingsRemotes):
	  Action (RemoteFunction): InvokeServer(acción, a, b) → (ok, claveTexto?, params?)
	  State  (RemoteEvent): estado completo cada segundo y tras cada acción
	  Notify (RemoteEvent): (tipo, claveTexto, params) — el cliente traduce con Lang
	Mundo: World.luau. Montones (Workspace.Mundo.Montones): Parts con atributos PileId, Zone, Hp, MaxHp.
	Crías visibles: cada jugador lleva los atributos «Pets» ("cría:versión,…") y «Target» (PileId); los
	clientes las dibujan (no hay física de crías en el servidor).
	Para añadir una acción: función en Actions + botón en el cliente + harness (run_juego.luau).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Data = require(ServerScriptService:WaitForChild("Data"))
local World = require(ServerScriptService:WaitForChild("World"))

---------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "MythicHatchlingsRemotes"
local actionRemote = Instance.new("RemoteFunction")
actionRemote.Name = "Action"
actionRemote.Parent = remotes
local stateRemote = Instance.new("RemoteEvent")
stateRemote.Name = "State"
stateRemote.Parent = remotes
local notifyRemote = Instance.new("RemoteEvent")
notifyRemote.Name = "Notify"
notifyRemote.Parent = remotes
remotes.Parent = ReplicatedStorage

local worldFolder = World.build()
local pileFolder = worldFolder:WaitForChild("Montones")
local rng = Random.new()

---------------------------------------------------------------------
-- Sesiones
---------------------------------------------------------------------
type Bonuses = {
	x2: boolean, slots: boolean, hatch3: boolean, autoHatch: boolean, backpack: boolean,
	boost: boolean, luck: boolean, friends: number, premium: boolean,
}
type Session = {
	data: any,
	canSave: boolean,
	bonuses: Bonuses,
	actionTimes: { number },
	lastHatch: number,
	target: number, -- PileId (0 = ninguno)
	dirty: boolean,
}
local sessions: { [Player]: Session } = {}

local function passByKey(k: string): Config.ShopItem?
	for _, p in Config.GamePasses do
		if p.key == k then
			return p
		end
	end
	return nil
end

local function notify(player: Player, kind: string, textKey: string, params: { [string]: any }?)
	notifyRemote:FireClient(player, kind, textKey, params or {})
end

local function today(): number
	return math.floor(os.time() / 86400)
end

local function earn(s: Session, amount: number)
	s.data.coins += amount
	s.data.lifetimeCoins += amount
	s.dirty = true
end

local function rootPart(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function rate(s: Session): number
	return Config.coinRate(s.data, s.bonuses)
end

---------------------------------------------------------------------
-- Montones (compartidos: las monedas se reparten según el daño de cada uno)
---------------------------------------------------------------------
type Pile = { id: number, part: BasePart, zone: number, hp: number, maxHp: number, coins: number, hits: { [Player]: number }, bar: Frame }
local piles: { [number]: Pile } = {}
local nextPileId = 1

local PILE_LOOK = {
	coins = { size = Vector3.new(5, 2.5, 5), shape = Enum.PartType.Cylinder, color = Config.Colors.gold, material = Enum.Material.Foil },
	chest = { size = Vector3.new(5, 4, 4), shape = Enum.PartType.Block, color = Color3.fromRGB(160, 100, 50), material = Enum.Material.WoodPlanks },
	crystal = { size = Vector3.new(3.5, 7, 3.5), shape = Enum.PartType.Block, color = Config.Colors.purple, material = Enum.Material.Glass },
}

local function pickKind(): any
	local total = 0
	for _, k in Config.PileKinds do
		total += k.weight
	end
	local roll = rng:NextNumber(0, total)
	for _, k in Config.PileKinds do
		roll -= k.weight
		if roll <= 0 then
			return k
		end
	end
	return Config.PileKinds[1]
end

local function spawnPile(zone: number)
	local kind = pickKind()
	local look = PILE_LOOK[kind.id]
	local z = Config.Zones[zone]
	local pos = World.pilePosition(zone, rng)
	local p = Instance.new("Part")
	p.Name = "Monton"
	p.Anchored = true
	p.Shape = look.shape
	p.Size = look.size
	p.Color = look.color
	p.Material = look.material
	p.CFrame = if look.shape == Enum.PartType.Cylinder
		then CFrame.new(pos + Vector3.new(0, look.size.Y / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		else CFrame.new(pos + Vector3.new(0, look.size.Y / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
	if look.shape == Enum.PartType.Cylinder then
		p.Size = Vector3.new(look.size.Y, look.size.X, look.size.Z)
	end
	local id = nextPileId
	nextPileId += 1
	local maxHp = math.floor(z.pileHp * kind.hp)
	p:SetAttribute("PileId", id)
	p:SetAttribute("Zone", zone)
	p:SetAttribute("Kind", kind.id)
	p:SetAttribute("Hp", maxHp)
	p:SetAttribute("MaxHp", maxHp)
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = Config.REACH
	click.Parent = p
	-- Barra de vida encima (sin texto: no hace falta traducir)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(70, 10)
	gui.StudsOffset = Vector3.new(0, 4.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 80
	gui.Enabled = false
	gui.Parent = p
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Config.Colors.ink
	back.BorderSizePixel = 0
	back.Parent = gui
	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromScale(1, 1)
	bar.BackgroundColor3 = Config.Colors.green
	bar.BorderSizePixel = 0
	bar.Parent = back
	p.Parent = pileFolder
	local pile: Pile = { id = id, part = p, zone = zone, hp = maxHp, maxHp = maxHp, coins = z.pileCoins * kind.coins, hits = {}, bar = bar }
	piles[id] = pile
	click.MouseClick:Connect(function(player: Player)
		local s = sessions[player]
		if s and zone <= s.data.zones then
			s.target = id
			player:SetAttribute("Target", id)
		end
	end)
end

for zone = 1, #Config.Zones do
	for _ = 1, Config.PILES_PER_ZONE do
		spawnPile(zone)
	end
end

local function breakPile(pile: Pile)
	piles[pile.id] = nil
	local total = 0
	for _, dmg in pile.hits do
		total += dmg
	end
	local pos = pile.part.Position
	for player, dmg in pile.hits do
		local s = sessions[player]
		if s and total > 0 then
			local reward = pile.coins * (dmg / total) * Config.coinMult(s.data, s.bonuses)
			earn(s, reward)
			s.data.stats.piles += 1
			notify(player, "coins", "n_coins", { value = reward, x = pos.X, y = pos.Y, z = pos.Z })
		end
	end
	pile.part:Destroy()
	task.delay(Config.PILE_RESPAWN, spawnPile, pile.zone)
end

local function pileInReach(s: Session, root: BasePart?, pile: Pile?, reach: number): boolean
	return pile ~= nil and root ~= nil and pile.zone <= s.data.zones and (pile.part.Position - root.Position).Magnitude <= reach
end

local function nearestPile(s: Session, root: BasePart): Pile?
	local best, bestDist = nil, Config.AUTO_REACH
	for _, pile in piles do
		if pile.zone <= s.data.zones then
			local d = (pile.part.Position - root.Position).Magnitude
			if d < bestDist then
				best, bestDist = pile, d
			end
		end
	end
	return best
end

---------------------------------------------------------------------
-- Crías
---------------------------------------------------------------------
local function petByUid(data: any, uid: any): (any?, number)
	for i, p in data.pets do
		if p.uid == uid then
			return p, i
		end
	end
	return nil, 0
end

local function unequip(data: any, uid: number)
	local i = table.find(data.equipped, uid)
	if i then
		table.remove(data.equipped, i)
	end
end

-- Atributos para que todos los clientes dibujen las crías de este jugador
local function syncPets(player: Player, s: Session)
	local parts = {}
	for _, uid in s.data.equipped do
		local p = petByUid(s.data, uid)
		if p then
			table.insert(parts, p.kind .. ":" .. p.tier)
		end
	end
	player:SetAttribute("Pets", table.concat(parts, ","))
	player:SetAttribute("Target", s.target)
end

local function addPet(s: Session, kind: string, tier: number): (any, boolean)
	local d = s.data
	local pet = { uid = d.nextUid, kind = kind, tier = tier }
	d.nextUid += 1
	table.insert(d.pets, pet)
	local key = Config.albumKey(kind, tier)
	local isNew = not d.album[key]
	d.album[key] = true
	if #d.equipped < Config.slots(d, s.bonuses) then
		table.insert(d.equipped, pet.uid)
	end
	s.dirty = true
	return pet, isNew
end

local function equipBest(s: Session)
	local d = s.data
	local list = table.clone(d.pets)
	table.sort(list, function(a, b)
		return Config.petPower(a.kind, a.tier) > Config.petPower(b.kind, b.tier)
	end)
	d.equipped = {}
	for i = 1, math.min(Config.slots(d, s.bonuses), #list) do
		table.insert(d.equipped, list[i].uid)
	end
end

-- Misiones del día (una fácil, una media y una difícil), iguales todo el día para cada jugador
local function ensureMissions(player: Player, s: Session)
	local m = s.data.missions
	local t = today()
	if m.day == t then
		return
	end
	m.day = t
	m.bonusGiven = false
	m.list = {}
	for i, tier in { "easy", "medium", "hard" } do
		local pool = Config.MissionPool[tier]
		local pick = pool[((t + player.UserId + i) % #pool) + 1]
		table.insert(m.list, { tier = tier, stat = pick.stat, n = pick.n, start = s.data.stats[pick.stat] or 0, claimed = false })
	end
	s.dirty = true
end

---------------------------------------------------------------------
-- Estado que se manda al cliente
---------------------------------------------------------------------
local function buildState(player: Player, s: Session): any
	local d = s.data
	ensureMissions(player, s)
	local missions = {}
	for _, m in d.missions.list do
		table.insert(missions, { tier = m.tier, stat = m.stat, n = m.n, progress = math.min(m.n, (d.stats[m.stat] or 0) - m.start), claimed = m.claimed })
	end
	local now = os.time()
	return {
		coins = d.coins,
		lifetimeCoins = d.lifetimeCoins,
		zones = d.zones,
		rebirths = d.rebirths,
		pets = d.pets,
		equipped = d.equipped,
		slots = Config.slots(d, s.bonuses),
		backpack = Config.backpack(d, s.bonuses),
		power = Config.teamPower(d),
		coinMult = Config.coinMult(d, s.bonuses),
		coinRate = rate(s),
		album = d.album,
		albumClaimed = d.albumClaimed,
		albumCount = Config.albumCount(d),
		rebirthZone = Config.rebirthZone(d.rebirths),
		rebirthCost = Config.rebirthCost(d.rebirths),
		daily = { available = d.daily.lastDay < today(), streak = d.daily.streak },
		missions = missions,
		missionBonus = d.missions.bonusGiven,
		boostLeft = math.max(0, d.boosts.coinsUntil - now),
		luckLeft = math.max(0, d.boosts.luckUntil - now),
		bonuses = s.bonuses,
		target = s.target,
		settings = d.settings,
		tutorialDone = d.tutorialDone,
		canSave = s.canSave,
		version = Config.VERSION,
	}
end

local function sendState(player: Player)
	local s = sessions[player]
	if s then
		stateRemote:FireClient(player, buildState(player, s))
	end
end

-- Límite de peticiones: devuelve true si se pasa (ventana de 1 s)
local function tooFast(times: { number }, limit: number): boolean
	local now = os.clock()
	while times[1] and now - times[1] > 1 do
		table.remove(times, 1)
	end
	if #times >= limit then
		return true
	end
	table.insert(times, now)
	return false
end

local function isInt(v: any, lo: number, hi: number): boolean
	return type(v) == "number" and v == math.floor(v) and v >= lo and v <= hi
end

---------------------------------------------------------------------
-- Acciones (valida SIEMPRE los argumentos: vienen del cliente)
---------------------------------------------------------------------
local Actions = {}

-- Mandar a las crías a un montón (también se hace tocando el montón: ClickDetector)
function Actions.target(player: Player, s: Session, pileId: any)
	if type(pileId) ~= "number" then
		return false
	end
	local pile = piles[pileId]
	if not pileInReach(s, rootPart(player), pile, Config.REACH) then
		return false
	end
	s.target = pileId
	return true
end

function Actions.setAuto(_player: Player, s: Session, on: any)
	if type(on) ~= "boolean" then
		return false
	end
	s.data.settings.auto = on
	s.dirty = true
	return true
end

-- Abrir huevos: zone = isla del huevo, count = 1 o 3 (pase), auto = abierto por el modo automático (pase)
function Actions.hatch(player: Player, s: Session, zone: any, count: any, auto: any)
	local d = s.data
	if not isInt(zone, 1, d.zones) or (count ~= 1 and count ~= 3) then
		return false
	end
	if count == 3 and not s.bonuses.hatch3 then
		return false, "n_need_pass"
	end
	if auto == true and not s.bonuses.autoHatch then
		return false, "n_need_pass"
	end
	local now = os.clock()
	if now - s.lastHatch < 0.9 then
		return false
	end
	local root = rootPart(player)
	local egg = World.zones[zone].egg
	if not root or (root.Position - egg.Position).Magnitude > Config.EGG_REACH then
		return false, "n_go_egg"
	end
	if #d.pets + count > Config.backpack(d, s.bonuses) then
		return false, "n_backpack_full"
	end
	local cost = Config.Zones[zone].eggCost * count
	if d.coins < cost then
		return false, "n_no_money"
	end
	s.lastHatch = now
	d.coins -= cost
	local result = {}
	for _ = 1, count do
		local kind = Config.rollPet(zone, s.bonuses.luck, rng:NextNumber())
		local _pet, isNew = addPet(s, kind, 0)
		table.insert(result, { kind = kind, new = isNew })
	end
	d.stats.hatched += count
	syncPets(player, s)
	return true, nil, { hatched = result }
end

function Actions.equip(player: Player, s: Session, uid: any)
	local d = s.data
	if not petByUid(d, uid) or table.find(d.equipped, uid) then
		return false
	end
	if #d.equipped >= Config.slots(d, s.bonuses) then
		return false, "n_slots_full"
	end
	table.insert(d.equipped, uid)
	s.dirty = true
	syncPets(player, s)
	return true
end

function Actions.unequip(player: Player, s: Session, uid: any)
	if not table.find(s.data.equipped, uid) then
		return false
	end
	unequip(s.data, uid)
	s.dirty = true
	syncPets(player, s)
	return true
end

function Actions.equipBest(player: Player, s: Session)
	equipBest(s)
	s.dirty = true
	syncPets(player, s)
	return true
end

-- Fusionar 5 crías iguales (misma cría y versión) → 1 de la versión siguiente
function Actions.fuse(player: Player, s: Session, kind: any, tier: any)
	local d = s.data
	if type(kind) ~= "string" or not Config.PetById[kind] or not isInt(tier, 0, Config.MAX_TIER - 1) then
		return false
	end
	-- Primero las no equipadas
	local chosen = {}
	for pass = 1, 2 do
		for _, p in d.pets do
			if #chosen < Config.FUSE_COUNT and p.kind == kind and p.tier == tier then
				local equipped = table.find(d.equipped, p.uid) ~= nil
				if (pass == 1 and not equipped) or (pass == 2 and equipped) then
					table.insert(chosen, p.uid)
				end
			end
		end
	end
	if #chosen < Config.FUSE_COUNT then
		return false, "n_fuse_need"
	end
	for _, uid in chosen do
		local _p, i = petByUid(d, uid)
		table.remove(d.pets, i)
		unequip(d, uid)
	end
	local _pet, isNew = addPet(s, kind, tier + 1)
	d.stats.fused += 1
	syncPets(player, s)
	return true, "n_fused", { kind = kind, tier = tier + 1, new = isNew }
end

-- Soltar una cría (para hacer sitio en la mochila). Nunca la última.
function Actions.release(player: Player, s: Session, uid: any)
	local d = s.data
	local p, i = petByUid(d, uid)
	if not p or #d.pets <= 1 then
		return false
	end
	table.remove(d.pets, i)
	unequip(d, uid)
	if #d.equipped == 0 then
		equipBest(s)
	end
	s.dirty = true
	syncPets(player, s)
	return true
end

function Actions.unlockZone(_player: Player, s: Session, zone: any)
	local d = s.data
	if not isInt(zone, 2, #Config.Zones) or zone ~= d.zones + 1 then
		return false
	end
	local cost = Config.Zones[zone].doorCost
	if d.coins < cost then
		return false, "n_no_money"
	end
	d.coins -= cost
	d.zones = zone
	s.dirty = true
	return true, "n_zone_open", { zone = zone }
end

function Actions.teleport(player: Player, s: Session, zone: any)
	if not isInt(zone, 1, s.data.zones) then
		return false
	end
	local root = rootPart(player)
	if not root then
		return false
	end
	root.CFrame = World.zones[zone].spawn -- mueve a todo el personaje (las piezas van unidas)
	s.target = 0
	return true
end

function Actions.rebirth(player: Player, s: Session)
	local d = s.data
	if d.zones < Config.rebirthZone(d.rebirths) then
		return false, "n_rebirth_need"
	end
	local cost = Config.rebirthCost(d.rebirths)
	if d.coins < cost then
		return false, "n_no_money"
	end
	d.coins = 0
	d.zones = 1
	d.rebirths += 1
	d.stats.rebirths += 1
	s.target = 0
	s.dirty = true
	local root = rootPart(player)
	if root then
		root.CFrame = World.zones[1].spawn
	end
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild("Rebirths")
	if value and value:IsA("IntValue") then
		value.Value = d.rebirths
	end
	return true, "n_rebirth", { n = d.rebirths }
end

function Actions.claimDaily(_player: Player, s: Session)
	local d = s.data.daily
	local t = today()
	if d.lastDay >= t then
		return false, "daily_done"
	end
	d.streak = if d.lastDay == t - 1 then (d.streak % #Config.Daily) + 1 else 1
	d.lastDay = t
	local reward = Config.dailyReward(d.streak, rate(s))
	earn(s, reward)
	return true, "n_daily", { value = reward }
end

function Actions.claimMission(player: Player, s: Session, index: any)
	ensureMissions(player, s)
	local m = s.data.missions
	if not isInt(index, 1, #m.list) then
		return false
	end
	local mission = m.list[index]
	if mission.claimed or (s.data.stats[mission.stat] or 0) - mission.start < mission.n then
		return false
	end
	mission.claimed = true
	local r = Config.MissionReward[mission.tier]
	local reward = Config.minutesReward(r[1], r[2], rate(s))
	earn(s, reward)
	local all = true
	for _, x in m.list do
		all = all and x.claimed
	end
	if all and not m.bonusGiven then
		m.bonusGiven = true
		local b = s.data.boosts
		b.luckUntil = math.max(os.time(), b.luckUntil) + Config.MISSION_LUCK_MINUTES * 60
		return true, "n_mission_all", { value = reward }
	end
	return true, "n_mission", { value = reward }
end

function Actions.claimAlbum(_player: Player, s: Session, index: any)
	local d = s.data
	if not isInt(index, 1, #Config.AlbumMilestones) or d.albumClaimed[tostring(index)] then
		return false
	end
	local m = Config.AlbumMilestones[index]
	if Config.albumCount(d) / Config.albumTotal() * 100 < m.pct then
		return false, "n_album_need"
	end
	d.albumClaimed[tostring(index)] = true
	s.dirty = true
	return true, "n_album", { pct = math.floor(m.bonus * 100) }
end

function Actions.finishTutorial(_player: Player, s: Session)
	if s.data.tutorialDone then
		return false
	end
	s.data.tutorialDone = true
	earn(s, Config.TUTORIAL_REWARD)
	return true, "n_tutorial", { value = Config.TUTORIAL_REWARD }
end

function Actions.setLang(_player: Player, s: Session, lang: any)
	if lang ~= "" and lang ~= "es" and lang ~= "en" then
		return false
	end
	s.data.settings.lang = lang
	s.dirty = true
	return true
end

function Actions.setMuted(_player: Player, s: Session, muted: any)
	if type(muted) ~= "boolean" then
		return false
	end
	s.data.settings.muted = muted
	s.dirty = true
	return true
end

actionRemote.OnServerInvoke = function(player: Player, action: any, a: any, b: any, c: any)
	local s = sessions[player]
	if not s or type(action) ~= "string" then
		return false
	end
	local fn = (Actions :: any)[action]
	if not fn then
		return false
	end
	if tooFast(s.actionTimes, 10) then
		return false, "n_too_fast"
	end
	local ok, textKey, params = fn(player, s, a, b, c)
	sendState(player)
	return ok, textKey, params
end

---------------------------------------------------------------------
-- Entrar y salir
---------------------------------------------------------------------
local function ownsPass(player: Player, key: string): boolean
	local item = passByKey(key)
	if not item or item.id == 0 then
		return false
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, item.id)
	end)
	return ok and owns == true
end

local function save(player: Player)
	local s = sessions[player]
	if s and s.canSave then
		s.data.lastOnline = os.time()
		Data.save(player.UserId, s.data)
		s.dirty = false
	end
end

-- +10 % por cada amigo en el mismo servidor (máx. 4)
local function updateFriends()
	for player, s in sessions do
		local n = 0
		for other in sessions do
			if other ~= player then
				local ok, friends = pcall(function()
					return player:IsFriendsWithAsync(other.UserId)
				end)
				if ok and friends then
					n += 1
				end
			end
		end
		s.bonuses.friends = n
	end
end

local function onPlayerAdded(player: Player)
	local data, canSave = Data.load(player.UserId)
	if not player.Parent then
		return
	end
	local bonuses: Bonuses = {
		x2 = false, slots = false, hatch3 = false, autoHatch = false, backpack = false,
		boost = false, luck = false, friends = 0,
		premium = player.MembershipType == Enum.MembershipType.Premium,
	}
	for _, p in Config.GamePasses do
		(bonuses :: any)[p.key] = ownsPass(player, p.key)
	end
	local s: Session = { data = data, canSave = canSave, bonuses = bonuses, actionTimes = {}, lastHatch = 0, target = 0, dirty = false }
	sessions[player] = s
	-- Seguridad: los equipados tienen que existir y caber
	local valid = {}
	for _, uid in data.equipped do
		if petByUid(data, uid) and #valid < Config.slots(data, bonuses) then
			table.insert(valid, uid)
		end
	end
	data.equipped = valid
	if #data.equipped == 0 then
		equipBest(s)
	end

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local coins = Instance.new("NumberValue")
	coins.Name = "Coins"
	coins.Value = math.floor(data.coins)
	coins.Parent = stats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = data.rebirths
	rebirths.Parent = stats
	stats.Parent = player
	syncPets(player, s)

	-- Ganancias mientras no estaba
	if data.lastOnline > 0 then
		local away = math.clamp(os.time() - data.lastOnline, 0, Config.OFFLINE_MAX_HOURS * 3600)
		local offline = math.floor(rate(s) * away * Config.OFFLINE_RATE)
		if offline > 0 then
			earn(s, offline)
			notify(player, "welcome", "welcome_back", { value = offline })
		end
	end
	if not canSave then
		notify(player, "error", "n_no_save")
	end
	task.spawn(updateFriends)
	sendState(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in Players:GetPlayers() do
	task.spawn(onPlayerAdded, p)
end
Players.PlayerRemoving:Connect(function(player)
	save(player)
	sessions[player] = nil
	for _, pile in piles do
		pile.hits[player] = nil
	end
	task.spawn(updateFriends)
end)
game:BindToClose(function()
	for player in sessions do
		save(player)
	end
end)

---------------------------------------------------------------------
-- Compras
---------------------------------------------------------------------
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, bought: boolean)
	local s = sessions[player]
	if not (s and bought) then
		return
	end
	for _, p in Config.GamePasses do
		if p.id ~= 0 and p.id == passId then
			(s.bonuses :: any)[p.key] = true
			notify(player, "success", "n_purchase")
			syncPets(player, s)
			sendState(player)
		end
	end
end)

MarketplaceService.ProcessReceipt = function(info: any)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local s = player and sessions[player]
	if not (player and s) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local id = tostring(info.PurchaseId)
	if s.data.receipts[id] then -- ya entregado (Roblox puede repetir el aviso)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local item: Config.ShopItem? = nil
	for _, p in Config.Products do
		if p.id ~= 0 and p.id == info.ProductId then
			item = p
		end
	end
	if not item then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- Guardar cómo estaba por si no se puede guardar (entonces se deshace)
	local coinsBefore, lifetimeBefore, boostBefore = s.data.coins, s.data.lifetimeCoins, s.data.boosts.coinsUntil
	local minutes = Config.CashMinutes[item.key]
	if minutes then
		earn(s, Config.minutesReward(minutes, Config.CASH_MIN, rate(s)))
	elseif item.key == "boost" then
		s.data.boosts.coinsUntil = math.max(os.time(), s.data.boosts.coinsUntil) + Config.BOOST_MINUTES * 60
	end
	s.data.receipts[id] = os.time()
	-- Solo las últimas 50
	local list = {}
	for k, t in s.data.receipts do
		table.insert(list, { k, t })
	end
	table.sort(list, function(x, y)
		return x[2] > y[2]
	end)
	for i = 51, #list do
		s.data.receipts[list[i][1]] = nil
	end
	-- Confirmar SOLO si se ha guardado (si no, se deshace y Roblox lo reintenta más tarde)
	if s.canSave and not Data.save(player.UserId, s.data) then
		s.data.receipts[id] = nil
		s.data.coins, s.data.lifetimeCoins, s.data.boosts.coinsUntil = coinsBefore, lifetimeBefore, boostBefore
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	notify(player, "success", "n_purchase")
	sendState(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

---------------------------------------------------------------------
-- Bucle principal (1 s): las crías pican el montón, avisos de tiempo, guardado
---------------------------------------------------------------------
local saveTimer = 0
while true do
	task.wait(1)
	saveTimer += 1
	local now = os.time()
	for player, s in sessions do
		local d = s.data
		s.bonuses.boost = now < d.boosts.coinsUntil
		s.bonuses.luck = now < d.boosts.luckUntil
		local root = rootPart(player)
		local pile = piles[s.target]
		if not pileInReach(s, root, pile, Config.REACH) then
			pile = nil
			s.target = 0
			if d.settings.auto and root then
				local near = nearestPile(s, root)
				if near then
					pile = near
					s.target = near.id
				end
			end
		end
		if pile then
			local dmg = math.min(pile.hp, Config.teamPower(d))
			pile.hp -= dmg
			pile.hits[player] = (pile.hits[player] or 0) + dmg
			pile.part:SetAttribute("Hp", pile.hp)
			pile.bar.Size = UDim2.fromScale(math.max(0, pile.hp / pile.maxHp), 1)
			local gui = pile.bar.Parent and pile.bar.Parent.Parent
			if gui and gui:IsA("BillboardGui") then
				gui.Enabled = true
			end
			if pile.hp <= 0 then
				breakPile(pile)
				s.target = 0
			end
		end
		if player:GetAttribute("Target") ~= s.target then
			player:SetAttribute("Target", s.target)
		end
		local stats = player:FindFirstChild("leaderstats")
		local coins = stats and stats:FindFirstChild("Coins")
		if coins and coins:IsA("NumberValue") then
			coins.Value = math.floor(d.coins)
		end
		sendState(player)
	end
	if saveTimer >= 60 then
		saveTimer = 0
		for player, s in sessions do
			if s.dirty then
				task.spawn(save, player)
			end
		end
	end
end
