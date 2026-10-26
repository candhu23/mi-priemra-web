--[[
	Servidor de Crías Míticas. EL SERVIDOR MANDA: el cliente solo enseña y pide acciones.
	Remotes (ReplicatedStorage.MythicHatchlingsRemotes):
	  Action (RemoteFunction): InvokeServer(acción, a, b) → (ok, claveTexto?, params?)
	  State  (RemoteEvent): estado completo cada segundo y tras cada acción
	  Notify (RemoteEvent): (tipo, claveTexto, params) — el cliente traduce con Lang
	Mundo: World.luau. Montones (Workspace.Mundo.Montones): Parts con atributos PileId, Zone, Hp, MaxHp.
	Crías visibles: cada jugador lleva los atributos «Pets» ("cría:0|1,…", 1 = Brillante) y «Target» (PileId); los
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
	lastAnnounce: number, -- os.clock() del último aviso de cría rara al servidor (solo en memoria)
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
type Pile = {
	id: number, part: BasePart, zone: number, hp: number, maxHp: number, coins: number, hits: { [Player]: number }, bar: Frame,
	gold: boolean?, -- Montón Dorado: no reaparece y caduca a los GOLD_LIFETIME s
}
local piles: { [number]: Pile } = {}
local nextPileId = 1

-- Mismas fórmulas que Config.PileKinds (maxHp = pileHp × hp, monedas = pileCoins × coins)
local GOLD_KIND = { id = "gold", hp = Config.GOLD_HP, coins = Config.GOLD_COINS }

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

-- Un montón desaparece: las crías de TODOS los que lo picaban dejan de ir a él (no solo las de quien lo rompe)
local function clearTarget(pileId: number)
	for player, s in sessions do
		if s.target == pileId then
			s.target = 0
			player:SetAttribute("Target", 0)
		end
	end
end

local function spawnPile(zone: number, gold: boolean?, hpCap: number?)
	local kind = if gold then GOLD_KIND else pickKind()
	local z = Config.Zones[zone]
	local pos = World.pilePosition(zone, rng)
	-- Cristal (pieza principal + puntas + losa); el aspecto está en World.crystal
	local p = World.crystal(kind.id, zone, pos, rng)
	local id = nextPileId
	nextPileId += 1
	local maxHp = math.floor(z.pileHp * kind.hp)
	if hpCap then -- el dorado se tiene que poder romper antes de que caduque
		maxHp = math.max(1, math.min(maxHp, math.floor(hpCap)))
	end
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
	gui.StudsOffset = Vector3.new(0, p.Size.Y / 2 + 2, 0)
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
	if gold then
		pile.gold = true
		p:SetAttribute("Gold", true)
		-- Si nadie lo rompe a tiempo, desaparece (sin premio)
		task.delay(Config.GOLD_LIFETIME, function()
			if piles[id] == pile then
				piles[id] = nil
				clearTarget(id)
				p:Destroy()
			end
		end)
	end
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
			local share = pile.coins * (dmg / total)
			local reward = share * Config.coinMult(s.data, s.bonuses)
			earn(s, reward)
			s.data.stats.piles += 1
			-- rel: lo que vale frente al premio típico de la isla (el cliente hace el «+🪙» más grande)
			notify(player, "coins", "n_coins", { value = reward, rel = share / Config.pileTypicalCoins(pile.zone), x = pos.X, y = pos.Y, z = pos.Z })
		end
	end
	clearTarget(pile.id)
	pile.part:Destroy()
	if not pile.gold then -- el dorado no reaparece: sale otro con el temporizador
		task.delay(Config.PILE_RESPAWN, spawnPile, pile.zone)
	end
end

-- Montón Dorado: uno en la isla más alta abierta de cada jugador (sin repetir isla ni duplicar si sigue vivo).
-- Esa isla la tiene pagada, así que siempre puede llegar. Se avisa a todos (quien no la tiene, sabe que existe)
local function spawnGold()
	-- Islas donde sale (la más alta de cada jugador) y el poder del más fuerte de esa isla
	local zones: { [number]: number } = {}
	for _, s in sessions do
		zones[s.data.zones] = math.max(zones[s.data.zones] or 0, Config.teamPower(s.data))
	end
	local spawned: { number } = {}
	for zone, power in zones do
		local alive = false
		for _, pile in piles do
			alive = alive or (pile.gold == true and pile.zone == zone)
		end
		if not alive then
			spawnPile(zone, true, power * Config.GOLD_MAX_SECONDS)
			table.insert(spawned, zone)
		end
	end
	-- Un aviso por jugador: el dorado más alto al que llega y, como mucho, uno de isla cerrada
	for player, s in sessions do
		local reach, locked = 0, 0
		for _, zone in spawned do
			if zone <= s.data.zones then
				reach = math.max(reach, zone)
			elseif locked == 0 or zone < locked then
				locked = zone
			end
		end
		if reach > 0 then
			notify(player, "gold", "n_gold_pile", { zone = reach, secs = Config.GOLD_LIFETIME })
		end
		if locked > 0 then
			notify(player, "gold", "n_gold_pile_locked", { zone = locked, secs = Config.GOLD_LIFETIME })
		end
	end
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

-- Atributos para que todos los clientes dibujen las crías de este jugador ("cría:0|1", 1 = Brillante)
local function syncPets(player: Player, s: Session)
	local parts = {}
	for _, uid in s.data.equipped do
		local p = petByUid(s.data, uid)
		if p then
			table.insert(parts, p.kind .. ":" .. (if p.shiny then 1 else 0))
		end
	end
	player:SetAttribute("Pets", table.concat(parts, ","))
	player:SetAttribute("Target", s.target)
end

-- Añade una cría y la apunta en el Índice (y en el Índice Brillante). Devuelve (cría, nueva en el Índice)
local function addPet(s: Session, kind: string, shiny: boolean): (any, boolean)
	local d = s.data
	local pet = { uid = d.nextUid, kind = kind, shiny = shiny }
	d.nextUid += 1
	table.insert(d.pets, pet)
	local isNew = not d.album[kind]
	d.album[kind] = true
	if shiny then
		d.shinyIndex[kind] = true
	end
	if #d.equipped < Config.slots(d, s.bonuses) then
		table.insert(d.equipped, pet.uid)
	end
	s.dirty = true
	return pet, isNew
end

local function byPower(a: any, b: any): boolean
	return Config.petPower(a.kind, a.shiny) > Config.petPower(b.kind, b.shiny)
end

local function equipBest(s: Session)
	local d = s.data
	local list = table.clone(d.pets)
	table.sort(list, byPower)
	d.equipped = {}
	for i = 1, math.min(Config.slots(d, s.bonuses), #list) do
		table.insert(d.equipped, list[i].uid)
	end
end

-- Huecos nuevos (mejora o pase): se llenan con las mejores sin equipar, sin tocar lo que ya eligió el jugador
local function fillSlots(s: Session)
	local d = s.data
	local free = {}
	for _, p in d.pets do
		if not table.find(d.equipped, p.uid) then
			table.insert(free, p)
		end
	end
	table.sort(free, byPower)
	local i = 1
	while #d.equipped < Config.slots(d, s.bonuses) and free[i] do
		table.insert(d.equipped, free[i].uid)
		i += 1
	end
end

-- Velocidad al andar (mejora «Brote Veloz»): al entrar, al reaparecer y al comprarla
local function applyWalk(player: Player, s: Session)
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = Config.walkSpeed(s.data)
	end
end

-- ¿Está junto a un Altar de Fusión? (Config.FUSE_NEEDS_ALTAR = false → en cualquier sitio)
local function atAltar(player: Player): boolean
	if not Config.FUSE_NEEDS_ALTAR then
		return true
	end
	local root = rootPart(player)
	return root ~= nil and World.nearAltar(root.Position)
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
	-- Lo que pide la puerta siguiente (para el HUD, el menú Islas y el cartel)
	local nextZone = nil
	if d.zones < #Config.Zones then
		local ok, kind, need, have = Config.zoneNeed(d, d.zones + 1)
		nextZone = { zone = d.zones + 1, ok = ok, kind = kind, need = need, have = have }
	end
	return {
		coins = d.coins,
		lifetimeCoins = d.lifetimeCoins,
		zones = d.zones,
		pets = d.pets,
		equipped = d.equipped,
		slots = Config.slots(d, s.bonuses),
		backpack = Config.backpack(d, s.bonuses),
		power = Config.teamPower(d),
		coinMult = Config.coinMult(d, s.bonuses),
		coinRate = rate(s),
		album = d.album,
		shinyIndex = d.shinyIndex,
		albumClaimed = d.albumClaimed,
		albumCount = Config.albumCount(d),
		albumTotal = Config.albumTotal(),
		shinyScore = Config.shinyScore(d),
		stones = d.stones,
		upgrades = d.upgrades,
		nextZone = nextZone,
		hatchCooldown = Config.hatchCooldown(d),
		walkSpeed = Config.walkSpeed(d),
		nearAltar = atAltar(player),
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

-- Aviso a todo el servidor si sale una Brillante o alguien crea una Mítica (máx. uno cada RARE_ANNOUNCE_COOLDOWN s
-- por jugador). Va por claves: cada cliente traduce la cría y la rareza; quien la saca no lo ve (ya tiene su ventana)
local function announceRare(player: Player, s: Session, textKey: string, kind: string)
	local pet = Config.PetById[kind]
	if not pet then
		return
	end
	local now = os.clock()
	if now - s.lastAnnounce < Config.RARE_ANNOUNCE_COOLDOWN then
		return
	end
	s.lastAnnounce = now
	notifyRemote:FireAllClients("rare", textKey, {
		uid = player.UserId, name = player.DisplayName, pet = kind, rarity = Config.Rarities[pet.rarity].id,
	})
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
	if now - s.lastHatch < Config.hatchCooldown(d) then
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
	local cost = Config.eggCost(zone, d) * count
	if d.coins < cost then
		return false, "n_no_money"
	end
	s.lastHatch = now
	d.coins -= cost
	local result = {}
	-- La especie y si sale Brillante (con suerte y mejoras) las decide el servidor: el cliente solo las dibuja
	local odds = Config.eggOdds(zone, d, s.bonuses)
	local shinyKind = ""
	for _ = 1, count do
		local kind = Config.rollPet(zone, rng:NextNumber())
		local shiny = Config.rollShiny(zone, d, s.bonuses, rng:NextNumber())
		local _pet, isNew = addPet(s, kind, shiny)
		if shiny then
			d.stats.shinies += 1
			shinyKind = kind
		end
		table.insert(result, {
			kind = kind, new = isNew, shiny = shiny, rarity = Config.PetById[kind].rarity,
			chance = if shiny then odds.shinyPct else 100 / #odds.species,
		})
	end
	d.stats.hatched += count
	syncPets(player, s)
	if shinyKind ~= "" then
		announceRare(player, s, "n_shiny_hatch", shinyKind) -- una sola vez por apertura
	end
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

-- Una fusión de un grupo (isla, rareza, Brillante): gasta fuseNeed crías y crea la de la rareza siguiente de esa isla.
-- Gasta primero las no equipadas y, entre ellas, la especie con más copias (te quedas con variedad).
-- Devuelve nil si no hay bastantes; si crea una Mítica, da una Piedra de Renacimiento en la MISMA operación
local function fuseGroup(s: Session, zone: number, rarity: number, shiny: boolean): any?
	local d = s.data
	local need = Config.Rarities[rarity].fuseNeed
	local made = Config.fuseResult(zone, rarity)
	if need <= 0 or not made then
		return nil
	end
	local cand, copies = {}, {}
	for _, p in d.pets do
		local def = Config.PetById[p.kind]
		if def and def.zone == zone and def.rarity == rarity and (p.shiny == true) == shiny then
			table.insert(cand, p)
			copies[p.kind] = (copies[p.kind] or 0) + 1
		end
	end
	if #cand < need then
		return nil
	end
	local isEq = {}
	for _, uid in d.equipped do
		isEq[uid] = true
	end
	table.sort(cand, function(a, b)
		if (isEq[a.uid] == true) ~= (isEq[b.uid] == true) then
			return not isEq[a.uid]
		end
		if copies[a.kind] ~= copies[b.kind] then
			return copies[a.kind] > copies[b.kind]
		end
		return a.uid < b.uid
	end)
	local gone, usedEquipped = {}, false
	for i = 1, need do
		gone[cand[i].uid] = true
		usedEquipped = usedEquipped or isEq[cand[i].uid] == true
	end
	local keep, keepEq = {}, {}
	for _, p in d.pets do
		if not gone[p.uid] then
			table.insert(keep, p)
		end
	end
	for _, uid in d.equipped do
		if not gone[uid] then
			table.insert(keepEq, uid)
		end
	end
	d.pets, d.equipped = keep, keepEq
	local _pet, isNew = addPet(s, made, shiny)
	d.stats.fused += 1
	local stone = rarity + 1 == Config.MYTHIC
	if stone then
		d.stones += 1
		d.stats.mythics += 1
	end
	return { kind = made, shiny = shiny, new = isNew, rarity = rarity + 1, stone = stone, usedEquipped = usedEquipped }
end

-- Tras fusionar: si se gastó alguna equipada, se equipa lo mejor; aviso de piedra y al servidor si hubo Mítica
local function afterFuse(player: Player, s: Session, usedEquipped: boolean, mythicKind: string?)
	if usedEquipped then
		equipBest(s)
	end
	syncPets(player, s)
	if mythicKind then
		notify(player, "success", "n_stone")
		announceRare(player, s, "n_mythic_made", mythicKind)
	end
end

-- Fusionar un grupo: zone = isla, rarity = rareza (1–7), shiny = si son Brillantes
function Actions.fuse(player: Player, s: Session, zone: any, rarity: any, shiny: any)
	if not isInt(zone, 1, #Config.Zones) or not isInt(rarity, 1, Config.MYTHIC - 1) or type(shiny) ~= "boolean" then
		return false
	end
	if not atAltar(player) then
		return false, "n_go_altar"
	end
	local r = fuseGroup(s, zone, rarity, shiny)
	if not r then
		return false, "n_fuse_need", { n = Config.Rarities[rarity].fuseNeed }
	end
	afterFuse(player, s, r.usedEquipped, if r.stone then r.kind else nil)
	return true, "n_fused", { made = { { kind = r.kind, shiny = r.shiny, new = r.new, rarity = r.rarity } }, stones = if r.stone then 1 else 0 }
end

-- «Fusionar todo»: repite fusiones de abajo arriba (lo nuevo se puede volver a fusionar en la misma pulsación),
-- en todas las islas, normales y Brillantes por separado. Máx. Config.FUSE_ALL_MAX por pulsación
function Actions.fuseAll(player: Player, s: Session)
	if not atAltar(player) then
		return false, "n_go_altar"
	end
	local d = s.data
	local before = Config.teamPower(d)
	local count, stones, usedEquipped = 0, 0, false
	local made, mythicKind = {}, nil
	while count < Config.FUSE_ALL_MAX do
		-- El grupo listo de rareza más baja
		local groups, best = {}, nil
		for _, p in d.pets do
			local def = Config.PetById[p.kind]
			if def and Config.Rarities[def.rarity].fuseNeed > 0 then
				local key = def.zone .. ":" .. def.rarity .. ":" .. tostring(p.shiny == true)
				groups[key] = (groups[key] or 0) + 1
				if groups[key] == Config.Rarities[def.rarity].fuseNeed and (best == nil or def.rarity < best.rarity) then
					best = { zone = def.zone, rarity = def.rarity, shiny = p.shiny == true }
				end
			end
		end
		local r = best and fuseGroup(s, best.zone, best.rarity, best.shiny)
		if not r then
			break
		end
		count += 1
		usedEquipped = usedEquipped or r.usedEquipped
		if r.stone then
			stones += 1
			mythicKind = r.kind
		end
		-- Para el resumen: solo las nuevas en el Índice, las Míticas y las Brillantes (máx. 6)
		if (r.new or r.stone or r.shiny) and #made < 6 then
			table.insert(made, { kind = r.kind, shiny = r.shiny, new = r.new, rarity = r.rarity })
		end
	end
	if count == 0 then
		return false, "n_fuse_none"
	end
	afterFuse(player, s, usedEquipped, mythicKind)
	return true, if count == 1 then "n_fused" else "n_fuse_all", { count = count, stones = stones, made = made, before = before, after = Config.teamPower(d) }
end

-- Soltar una cría (para hacer sitio en la mochila). Nunca la última.
function Actions.release(player: Player, s: Session, uid: any)
	local d = s.data
	local p, i = petByUid(d, uid)
	if not p or #d.pets <= 1 then
		return false
	end
	if table.find(d.equipped, uid) then
		return false, "n_release_equipped"
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

-- Abrir la isla siguiente: no cuesta monedas; pide crías descubiertas (zonas 2–8) o puntuación Brillante (zona 9)
function Actions.unlockZone(_player: Player, s: Session, zone: any)
	local d = s.data
	if not isInt(zone, 2, #Config.Zones) or zone ~= d.zones + 1 then
		return false
	end
	local ok, kind, need, have = Config.zoneNeed(d, zone)
	if not ok then
		return false, if kind == "shiny" then "n_need_shiny" else "n_need_index", { n = need, have = have }
	end
	d.zones = zone
	s.dirty = true
	return true, "n_zone_open", { zone = zone }
end

-- Viajar a una isla abierta, o al Jardín de Mejoras con zone = 0 (siempre abierto)
function Actions.teleport(player: Player, s: Session, zone: any)
	if not isInt(zone, 0, s.data.zones) then
		return false
	end
	local root = rootPart(player)
	if not root then
		return false
	end
	local garden = World.garden
	if zone == 0 and not garden then
		return false
	end
	-- mueve a todo el personaje (las piezas van unidas)
	root.CFrame = if zone == 0 and garden then garden.spawn else World.zones[zone].spawn
	s.target = 0
	return true
end

-- Comprar una mejora del Jardín con piedras (una vez cada una, con sus requisitos)
function Actions.buyUpgrade(player: Player, s: Session, id: any)
	local d = s.data
	if type(id) ~= "string" or not Config.UpgradeById[id] then
		return false
	end
	local ok, textKey, params = Config.canBuyUpgrade(d, id)
	if not ok then
		return false, textKey, params
	end
	if Config.UPGRADE_NEEDS_PEDESTAL then
		local root = rootPart(player)
		local pos = World.pedestals[id]
		if not (root and pos and (root.Position - pos).Magnitude <= Config.UPGRADE_REACH) then
			return false, "n_go_pedestal"
		end
	end
	d.stones -= Config.UpgradeById[id].cost
	d.upgrades[id] = true
	s.dirty = true
	fillSlots(s)
	applyWalk(player, s)
	syncPets(player, s)
	return true, "n_upgrade", { upgrade = id }
end

-- «Soltar repetidas»: suelta las que dice Config.dupesToRelease (nunca equipadas, Brillantes ni la última normal de
-- cada especie). Así la mochila no bloquea los huevos
function Actions.releaseDupes(player: Player, s: Session)
	local d = s.data
	local list = Config.dupesToRelease(d)
	if #list == 0 then
		return false, "n_no_dupes"
	end
	local gone = {}
	for _, uid in list do
		gone[uid] = true
	end
	local keep = {}
	for _, p in d.pets do
		if not gone[p.uid] then
			table.insert(keep, p)
		end
	end
	d.pets = keep
	s.dirty = true
	syncPets(player, s)
	return true, "n_released", { n = #list }
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

-- Pedestales del Jardín: mantener pulsado su ProximityPrompt compra la mejora (mismas validaciones que la acción,
-- también la distancia). La respuesta va como aviso porque no hay RemoteFunction de por medio
for id, base in World.pedestalParts do
	local pp = base:FindFirstChildOfClass("ProximityPrompt")
	if pp then
		pp.Triggered:Connect(function(player: Player)
			local s = sessions[player]
			if not s or tooFast(s.actionTimes, 10) then
				return
			end
			local ok, textKey, params = Actions.buyUpgrade(player, s, id)
			if textKey then
				notify(player, if ok then "success" else "error", textKey, params)
			end
			sendState(player)
		end)
	end
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
	if not player.Parent then -- se fue mientras se comprobaban los pases
		return
	end
	local s: Session = {
		data = data, canSave = canSave, bonuses = bonuses, actionTimes = {}, lastHatch = 0, target = 0, dirty = false,
		lastAnnounce = -math.huge,
	}
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
	local index = Instance.new("IntValue")
	index.Name = "Index"
	index.Value = Config.albumCount(data)
	index.Parent = stats
	stats.Parent = player
	syncPets(player, s)
	applyWalk(player, s)
	player.CharacterAdded:Connect(function(character: Model)
		local hum = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
		if hum and hum:IsA("Humanoid") and sessions[player] == s then
			hum.WalkSpeed = Config.walkSpeed(s.data)
		end
	end)

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
	local pending = 0
	for player in sessions do
		pending += 1
		task.spawn(function()
			save(player)
			pending -= 1
		end)
	end
	local waited = 0
	while pending > 0 and waited < 25 do
		task.wait(0.5)
		waited += 0.5
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
			fillSlots(s)
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
	-- Sin guardado (la carga falló) no se confirma: Roblox lo reintenta cuando vuelva a entrar
	if not s.canSave then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- Lo que se da, para poder deshacerlo RESTANDO si no se guarda (mientras tanto el juego sigue)
	local granted, boostAdded = 0, 0
	local minutes = Config.CashMinutes[item.key]
	if minutes then
		granted = Config.minutesReward(minutes, Config.CASH_MIN, rate(s))
		earn(s, granted)
	elseif item.key == "boost" then
		boostAdded = Config.BOOST_MINUTES * 60
		s.data.boosts.coinsUntil = math.max(os.time(), s.data.boosts.coinsUntil) + boostAdded
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
	if not Data.save(player.UserId, s.data) then
		s.data.receipts[id] = nil
		s.data.coins -= granted
		s.data.lifetimeCoins -= granted
		s.data.boosts.coinsUntil -= boostAdded
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
local goldTimer = 0
while true do
	task.wait(1)
	saveTimer += 1
	goldTimer += 1
	if goldTimer >= Config.GOLD_INTERVAL then
		goldTimer = 0
		spawnGold()
	end
	local now = os.time()
	for player, s in sessions do
		local d = s.data
		s.bonuses.boost = now < d.boosts.coinsUntil
		s.bonuses.luck = now < d.boosts.luckUntil
		local root = rootPart(player)
		-- Si se cae de las islas, vuelve a su isla más alta (sin esperar a morir abajo)
		if root and root.Position.Y < World.TOP - 60 then
			root.CFrame = World.zones[math.clamp(d.zones, 1, #World.zones)].spawn
			root.AssemblyLinearVelocity = Vector3.zero
		end
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
		local index = stats and stats:FindFirstChild("Index")
		if index and index:IsA("IntValue") then
			index.Value = Config.albumCount(d)
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
