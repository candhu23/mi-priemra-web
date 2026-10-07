--[[
	GameServer (Script en ServerScriptService)

	El servidor manda: guarda la partida, comprueba cada acción del jugador
	(clases, mejoras permanentes, mochila, forja, cofres, grupos, elegir
	mejora en partida…), reparte las recompensas al acabar cada partida y
	gestiona las compras con Robux y la clasificación global.
	Las partidas en sí están en RunManager.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local World = require(ServerScriptService:WaitForChild("World"))
local RunManager = require(ServerScriptService:WaitForChild("RunManager"))

local random = Random.new()
local Monetization = Config.Monetization

Players.RespawnTime = Config.RESPAWN_TIME

---------------------------------------------------------------------
-- Remotes (canales de comunicación cliente <-> servidor)
---------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "DungeonRemotes"

local actionFunction = Instance.new("RemoteFunction")
actionFunction.Name = "Action"
actionFunction.Parent = remotes

local stateEvent = Instance.new("RemoteEvent")
stateEvent.Name = "State"
stateEvent.Parent = remotes

local notifyEvent = Instance.new("RemoteEvent")
notifyEvent.Name = "Notify"
notifyEvent.Parent = remotes

-- Partida: servidor → cliente (enemigos en un buffer, cristales y efectos) ·
-- cliente → servidor ("dash")
local swarmEvent = Instance.new("RemoteEvent")
swarmEvent.Name = "Swarm"
swarmEvent.Parent = remotes

local openMenuEvent = Instance.new("RemoteEvent")
openMenuEvent.Name = "OpenMenu"
openMenuEvent.Parent = remotes

remotes.Parent = ReplicatedStorage

---------------------------------------------------------------------
-- Guardado
---------------------------------------------------------------------
local store: DataStore? = nil
local leaderboardStore: OrderedDataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DATASTORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DungeonAscend] DataStore no disponible, no se guardará la partida:", result)
	end
	local okBoard, board = pcall(function()
		return DataStoreService:GetOrderedDataStore(Config.LEADERBOARD_NAME)
	end)
	if okBoard then
		leaderboardStore = board
	end
end

local function newData()
	return {
		gold = 0,
		lifetimeGold = 0,
		inventory = { { id = 1, def = Config.STARTER_WEAPON, rarity = "comun", up = 0 } },
		equipped = { weapon = 1 },
		nextItemId = 2,
		upgrades = {},
		classes = { guerrero = true },
		selectedClass = "guerrero",
		unlockedMap = 1,
		mapWins = {},
		bestTime = {},
		stats = { runs = 0, wins = 0, kills = 0, bossKills = 0, deaths = 0, itemsFound = 0, upgrades = 0, chests = 0 },
		daily = { lastDay = -1, streak = 0 },
		boostUntil = 0,
		receipts = {},
		tutorialDone = false,
		settings = { muted = false, autoSell = false },
		lastOnline = os.time(),
	}
end

-- Campos que son listas o mapas del jugador: no se rellenan por dentro
local NO_DEEP_RECONCILE = { inventory = true, equipped = true, upgrades = true, classes = true, mapWins = true, bestTime = true, receipts = true }

-- Rellena campos que falten en partidas guardadas con versiones antiguas
local function reconcile(data, template)
	for key, value in template do
		if data[key] == nil then
			data[key] = value
		elseif type(value) == "table" and type(data[key]) == "table" and not NO_DEEP_RECONCILE[key] then
			reconcile(data[key], value)
		end
	end
	return data
end

local function dataKey(player: Player): string
	return "player_" .. player.UserId
end

---------------------------------------------------------------------
-- Sesiones de jugador
---------------------------------------------------------------------
type Bonuses = {
	goldPass: boolean,
	choicePass: boolean,
	rerollPass: boolean,
	bagPass: boolean,
	boost: boolean,
	friends: number,
}
type Session = {
	data: any,
	canSave: boolean,
	bonuses: Bonuses,
	stats: Config.Stats,
	dirty: boolean,
	lastStateAt: number,
	actionWindowStart: number,
	actionCount: number,
	lastManualSave: number,
	lastSaveOk: boolean?,
	lastSaveAt: number,
	friendIds: { [number]: boolean },
	leaderKills: IntValue,
	leaderWins: IntValue,
}

local sessions: { [Player]: Session } = {}

local function notify(player: Player, text: string, kind: string?)
	notifyEvent:FireClient(player, text, kind or "info")
end

local function notifyAll(text: string, kind: string)
	for player in sessions do
		notify(player, text, kind)
	end
end

---------------------------------------------------------------------
-- Objetos y estadísticas
---------------------------------------------------------------------
local function findItem(data, itemId: any): (any, number?)
	if type(itemId) ~= "number" then
		return nil, nil
	end
	for i, item in data.inventory do
		if item.id == itemId then
			return item, i
		end
	end
	return nil, nil
end

local function isEquipped(data, item): boolean
	for _, id in data.equipped do
		if id == item.id then
			return true
		end
	end
	return false
end

local function equippedItems(data): { [string]: Config.Item? }
	local result = {}
	for slot, id in data.equipped do
		local item = findItem(data, id)
		if item then
			result[slot] = item
		end
	end
	return result
end

local function capacity(session: Session): number
	return Config.INVENTORY_SIZE + (if session.bonuses.bagPass then Config.INVENTORY_PASS_BONUS else 0)
end

local function refreshBoost(session: Session)
	session.bonuses.boost = session.data.boostUntil > os.time()
end

-- Arma de la mochila visible en la mano del personaje (para presumir en el lobby)
local function attachWeapon(character: Model, item: Config.Item?)
	local old = character:FindFirstChild("ArmaEquipada")
	if old then
		old:Destroy()
	end
	if not item then
		return
	end
	local hand = (character:FindFirstChild("RightHand") :: BasePart?) or (character:FindFirstChild("Right Arm") :: BasePart?)
	if not hand then
		return
	end
	local def = Config.Items[item.def]
	local rarity = Config.RarityById[item.rarity]
	local yOffset = if hand.Name == "RightHand" then -0.3 else -0.9
	local model = Instance.new("Model")
	model.Name = "ArmaEquipada"
	local function piece(size: Vector3, offset: CFrame, color: Color3, material: Enum.Material): Part
		local part = Instance.new("Part")
		part.Size = size
		part.CFrame = hand.CFrame * offset
		part.Color = color
		part.Material = material
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.Anchored = false
		part.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = part
		weld.Parent = part
		return part
	end
	local blade = piece(Vector3.new(0.25, 0.7, 3.8), CFrame.new(0, yOffset, -2.5), def.color, if rarity.index >= 4 then Enum.Material.Neon else Enum.Material.Metal)
	blade.Name = "Hoja"
	piece(Vector3.new(1.4, 0.3, 0.3), CFrame.new(0, yOffset, -0.6), rarity.color, Enum.Material.Metal)
	if rarity.index >= 3 then
		local light = Instance.new("PointLight")
		light.Color = rarity.color
		light.Range = 8
		light.Brightness = 1.2
		light.Parent = blade
	end
	model.Parent = character
end

-- Recalcula las estadísticas permanentes y, si está en el lobby, las aplica al personaje
local function applyStats(player: Player, session: Session)
	local data = session.data
	session.stats = Config.baseStats(data.selectedClass, data.upgrades, equippedItems(data))
	session.dirty = true
	if RunManager.runOf(player) then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.MaxHealth = session.stats.health
		humanoid.Health = session.stats.health
		humanoid.WalkSpeed = Config.WALK_SPEED * session.stats.speed
	end
end

local function rollRarity(field: string): string
	local total = 0
	for _, rarity in Config.Rarities do
		total += rarity[field]
	end
	local roll = random:NextNumber() * total
	for _, rarity in Config.Rarities do
		roll -= rarity[field]
		if roll <= 0 and rarity[field] > 0 then
			return rarity.id
		end
	end
	return Config.Rarities[#Config.Rarities].id
end

local function addGold(data, amount: number)
	amount = math.floor(amount)
	data.gold += amount
	data.lifetimeGold += amount
end

-- Añade un objeto a la mochila (o lo vende si no cabe / venta automática). Devuelve el objeto.
local function addItem(player: Player, session: Session, defId: string, rarityId: string, source: string): any
	local data = session.data
	local item = { id = data.nextItemId, def = defId, rarity = rarityId, up = 0 }
	data.nextItemId += 1
	data.stats.itemsFound += 1
	local def = Config.Items[defId]
	local rarity = Config.RarityById[rarityId]
	local current = equippedItems(data)[def.slot]
	local better = not current or Config.itemPower(item) > Config.itemPower(current)
	local full = #data.inventory >= capacity(session)
	if full or (data.settings.autoSell and rarity.index == 1 and not better) then
		local price = Config.sellPrice(item)
		addGold(data, price)
		local why = if full then "🎒 Mochila llena: " else "♻️ Venta automática: "
		notify(player, why .. def.name .. " (" .. rarity.name .. ") vendido por 🪙" .. Config.formatNumber(price), "info")
		return item
	end
	table.insert(data.inventory, item)
	notifyEvent:FireClient(player, "", "loot_item", { item = item, better = better })
	if rarity.index >= 5 then
		notifyAll("🌟 ¡" .. player.DisplayName .. " ha conseguido " .. def.name .. " LEGENDARIO " .. source .. "!", "loot")
	end
	session.dirty = true
	return item
end

---------------------------------------------------------------------
-- Grupos del lobby (hasta 4 jugadores juegan juntos)
---------------------------------------------------------------------
type Group = { id: number, leader: Player, mapIndex: number, members: { Player } }
local groups: { [number]: Group } = {}
local groupOf: { [Player]: Group } = {}
local nextGroupId = 0

local function leaveGroup(player: Player)
	local group = groupOf[player]
	if not group then
		return
	end
	groupOf[player] = nil
	local index = table.find(group.members, player)
	if index then
		table.remove(group.members, index)
	end
	if #group.members == 0 then
		groups[group.id] = nil
	elseif group.leader == player then
		group.leader = group.members[1]
		notify(group.leader, "👑 Ahora eres el líder del grupo", "info")
	end
	for _, other in group.members do
		local s = sessions[other]
		if s then
			s.dirty = true
		end
	end
end

local function groupsSummary(): { any }
	local list = {}
	for _, group in groups do
		local names = {}
		for _, member in group.members do
			table.insert(names, member.DisplayName)
		end
		table.insert(list, { id = group.id, leader = group.leader.DisplayName, map = group.mapIndex, members = names })
	end
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	return list
end

---------------------------------------------------------------------
-- Estado que se envía al cliente
---------------------------------------------------------------------
local function dailyStatus(data): (boolean, number)
	local today = os.time() // 86400
	if data.daily.lastDay == today then
		return false, data.daily.streak
	end
	local streak = if data.daily.lastDay == today - 1 then data.daily.streak % #Config.DAILY_MINUTES + 1 else 1
	return true, streak
end

local function buildState(player: Player, session: Session)
	local data = session.data
	refreshBoost(session)
	local dailyAvailable, dailyDay = dailyStatus(data)
	local group = groupOf[player]
	return {
		version = Config.VERSION,
		gold = data.gold,
		stats = session.stats,
		inventory = data.inventory,
		equipped = data.equipped,
		capacity = capacity(session),
		upgrades = data.upgrades,
		classes = data.classes,
		selectedClass = data.selectedClass,
		unlockedMap = data.unlockedMap,
		mapWins = data.mapWins,
		bestTime = data.bestTime,
		bonuses = session.bonuses,
		boostLeft = math.max(0, data.boostUntil - os.time()),
		dailyAvailable = dailyAvailable,
		dailyDay = dailyDay,
		dailyReward = Config.goldPerMinute(data.unlockedMap) * Config.DAILY_MINUTES[dailyDay],
		tutorialDone = data.tutorialDone,
		settings = data.settings,
		totals = data.stats,
		canSave = session.canSave,
		saveOk = session.lastSaveOk,
		groups = groupsSummary(),
		myGroup = if group then { id = group.id, leader = group.leader == player, map = group.mapIndex } else nil,
		run = RunManager.stateFor(player),
	}
end

local function sendState(player: Player)
	local session = sessions[player]
	if session then
		session.dirty = false
		session.lastStateAt = os.clock()
		stateEvent:FireClient(player, buildState(player, session))
	end
end

local function markAllDirty()
	for _, session in sessions do
		session.dirty = true
	end
end

---------------------------------------------------------------------
-- Fin de partida: recompensas
---------------------------------------------------------------------
local function onFinish(player: Player, result)
	local session = sessions[player]
	if not session then
		return
	end
	local data = session.data
	local map = Config.Maps[result.mapIndex]
	addGold(data, result.gold)
	data.stats.runs += 1
	data.stats.kills += result.kills
	session.leaderKills.Value = data.stats.kills
	local summary = {
		result = result.result,
		map = map.id,
		time = result.time,
		kills = result.kills,
		level = result.level,
		gold = result.gold,
		item = nil,
		unlocked = nil,
	}
	if result.result == "win" then
		data.stats.wins += 1
		data.stats.bossKills += 1
		session.leaderWins.Value = data.stats.wins
		data.mapWins[map.id] = (data.mapWins[map.id] or 0) + 1
		data.bestTime[map.id] = math.max(data.bestTime[map.id] or 0, math.floor(result.time))
		summary.item = addItem(player, session, map.drops[random:NextInteger(1, #map.drops)], rollRarity("bossWeight"), "del jefe")
		local nextMap = Config.Maps[result.mapIndex + 1]
		if nextMap and data.unlockedMap < nextMap.index then
			data.unlockedMap = nextMap.index
			summary.unlocked = nextMap.id
		end
	elseif result.result == "dead" then
		data.stats.deaths += 1
	end
	notifyEvent:FireClient(player, "", "summary", summary)
	applyStats(player, session)
	session.dirty = true
end

---------------------------------------------------------------------
-- Acciones que puede pedir el cliente
---------------------------------------------------------------------
local Actions: { [string]: (Player, Session, any, any) -> (boolean, string?, any?) } = {}

local function teleportTo(player: Player, cframe: CFrame)
	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		character:PivotTo(cframe)
	end
end

local function canPlayMap(session: Session, mapIndex: any): (any, string?)
	local map = type(mapIndex) == "number" and Config.Maps[mapIndex]
	if not map then
		return nil, "Mapa desconocido"
	end
	if session.data.unlockedMap < map.index then
		return nil, "🔒 Escapa antes de " .. Config.Maps[map.index - 1].name
	end
	return map, nil
end

local function startRunFor(players: { Player }, mapIndex: number): (boolean, string?)
	for _, player in players do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return false, player.DisplayName .. " todavía no ha reaparecido"
		end
	end
	local ok, reason = RunManager.startRun(players, mapIndex)
	if ok then
		for _, player in players do
			leaveGroup(player)
		end
		markAllDirty()
	end
	return ok, reason
end

function Actions.playSolo(player: Player, session: Session, mapIndex: any)
	local map, reason = canPlayMap(session, mapIndex)
	if not map then
		return false, reason
	end
	if RunManager.runOf(player) then
		return false, "Ya estás en una partida"
	end
	local ok, why = startRunFor({ player }, map.index)
	return ok, if ok then map.emoji .. " ¡A sobrevivir!" else why
end

function Actions.createGroup(player: Player, session: Session, mapIndex: any)
	local map, reason = canPlayMap(session, mapIndex)
	if not map then
		return false, reason
	end
	if RunManager.runOf(player) then
		return false, "Ya estás en una partida"
	end
	leaveGroup(player)
	nextGroupId += 1
	local group: Group = { id = nextGroupId, leader = player, mapIndex = map.index, members = { player } }
	groups[group.id] = group
	groupOf[player] = group
	markAllDirty()
	return true, "👥 Grupo creado. Espera a tus amigos y pulsa Empezar"
end

function Actions.joinGroup(player: Player, _session: Session, groupId: any)
	local group = type(groupId) == "number" and groups[groupId]
	if not group then
		return false, "Ese grupo ya no existe"
	end
	if groupOf[player] == group then
		return true, nil
	end
	if #group.members >= Config.MAX_GROUP then
		return false, "El grupo está lleno"
	end
	if RunManager.runOf(player) then
		return false, "Ya estás en una partida"
	end
	leaveGroup(player)
	table.insert(group.members, player)
	groupOf[player] = group
	for _, other in group.members do
		if other ~= player then
			notify(other, "👋 " .. player.DisplayName .. " se ha unido al grupo", "success")
		end
	end
	markAllDirty()
	return true, "👥 Te has unido al grupo de " .. group.leader.DisplayName
end

function Actions.leaveGroup(player: Player, _session: Session)
	if not groupOf[player] then
		return false, "No estás en ningún grupo"
	end
	leaveGroup(player)
	markAllDirty()
	return true, "Has salido del grupo"
end

function Actions.startGroup(player: Player, _session: Session)
	local group = groupOf[player]
	if not group then
		return false, "No estás en ningún grupo"
	end
	if group.leader ~= player then
		return false, "Solo el líder puede empezar"
	end
	-- El mapa tiene que estar desbloqueado para todos
	for _, member in group.members do
		local s = sessions[member]
		if not s or s.data.unlockedMap < group.mapIndex then
			return false, "🔒 " .. member.DisplayName .. " aún no tiene ese mapa"
		end
	end
	local players = table.clone(group.members)
	local ok, why = startRunFor(players, group.mapIndex)
	return ok, if ok then "👥 ¡A sobrevivir juntos!" else why
end

function Actions.choose(player: Player, _session: Session, index: any)
	return RunManager.choose(player, index)
end

function Actions.reroll(player: Player, _session: Session)
	return RunManager.reroll(player)
end

function Actions.leaveRun(player: Player, _session: Session)
	local ok, reason = RunManager.leave(player)
	return ok, if ok then "🏳️ Has abandonado: te quedas la mitad del oro" else reason
end

function Actions.buyUpgrade(player: Player, session: Session, upgradeId: any)
	local upgrade = type(upgradeId) == "string" and Config.MetaById[upgradeId]
	if not upgrade then
		return false, "Mejora desconocida"
	end
	local data = session.data
	local level = data.upgrades[upgrade.id] or 0
	if level >= upgrade.max then
		return false, "Ya está al máximo"
	end
	local cost = Config.metaCost(upgrade.id, level)
	if data.gold < cost then
		return false, "Te faltan 🪙" .. Config.formatNumber(cost - data.gold)
	end
	data.gold -= cost
	data.upgrades[upgrade.id] = level + 1
	data.stats.upgrades += 1
	applyStats(player, session)
	return true, upgrade.emoji .. " " .. upgrade.name .. " nivel " .. (level + 1), { forge = true }
end

function Actions.buyClass(player: Player, session: Session, classId: any)
	local class = type(classId) == "string" and Config.ClassById[classId]
	if not class then
		return false, "Clase desconocida"
	end
	local data = session.data
	if data.classes[class.id] then
		data.selectedClass = class.id
		applyStats(player, session)
		return true, class.emoji .. " Clase elegida: " .. class.name
	end
	if data.gold < class.price then
		return false, "Te faltan 🪙" .. Config.formatNumber(class.price - data.gold)
	end
	data.gold -= class.price
	data.classes[class.id] = true
	data.selectedClass = class.id
	applyStats(player, session)
	return true, class.emoji .. " ¡Nueva clase: " .. class.name .. "!", { equip = true }
end

function Actions.equip(player: Player, session: Session, itemId: any)
	local item = findItem(session.data, itemId)
	if not item then
		return false, "Ese objeto ya no existe"
	end
	local slot = Config.Items[item.def].slot
	session.data.equipped[slot] = item.id
	applyStats(player, session)
	if slot == "weapon" and player.Character and not RunManager.runOf(player) then
		attachWeapon(player.Character, item)
	end
	return true, "✅ Equipado: " .. Config.Items[item.def].name, { equip = true }
end

function Actions.sell(_player: Player, session: Session, itemId: any)
	local data = session.data
	local item, index = findItem(data, itemId)
	if not item or not index then
		return false, "Ese objeto ya no existe"
	end
	if isEquipped(data, item) then
		return false, "No puedes vender lo que llevas puesto"
	end
	local price = Config.sellPrice(item)
	table.remove(data.inventory, index)
	addGold(data, price)
	return true, "💰 Vendido por 🪙" .. Config.formatNumber(price), { gold = true }
end

-- Vende todo lo no equipado de rareza igual o menor que maxRarity (1 = Común)
function Actions.sellJunk(_player: Player, session: Session, maxRarity: any)
	local data = session.data
	if type(maxRarity) ~= "number" or maxRarity < 1 or maxRarity > 3 then
		return false, "Opción no válida"
	end
	local total, count = 0, 0
	for i = #data.inventory, 1, -1 do
		local item = data.inventory[i]
		if Config.RarityById[item.rarity].index <= maxRarity and not isEquipped(data, item) then
			total += Config.sellPrice(item)
			count += 1
			table.remove(data.inventory, i)
		end
	end
	if count == 0 then
		return false, "No hay nada que vender de esa rareza"
	end
	addGold(data, total)
	return true, "💰 " .. count .. " objetos vendidos por 🪙" .. Config.formatNumber(total), { gold = true }
end

function Actions.upgrade(player: Player, session: Session, itemId: any)
	local data = session.data
	local item = findItem(data, itemId)
	if not item then
		return false, "Ese objeto ya no existe"
	end
	if item.up >= Config.MAX_UPGRADE then
		return false, "Ya está al máximo (+" .. Config.MAX_UPGRADE .. ")"
	end
	local cost = Config.upgradeCost(item)
	if data.gold < cost then
		return false, "Te faltan 🪙" .. Config.formatNumber(cost - data.gold)
	end
	data.gold -= cost
	item.up += 1
	data.stats.upgrades += 1
	if isEquipped(data, item) then
		applyStats(player, session)
		if Config.Items[item.def].slot == "weapon" and player.Character and not RunManager.runOf(player) then
			attachWeapon(player.Character, item)
		end
	end
	return true, "🔨 " .. Config.Items[item.def].name .. " +" .. item.up, { forge = true }
end

function Actions.buyChest(player: Player, session: Session, mapIndex: any)
	local data = session.data
	local map = type(mapIndex) == "number" and Config.Maps[mapIndex]
	if not map then
		return false, "Cofre desconocido"
	end
	if data.unlockedMap < map.index then
		return false, "🔒 Desbloquea antes " .. map.name
	end
	local price = Config.chestPrice(map.index)
	if data.gold < price then
		return false, "Te faltan 🪙" .. Config.formatNumber(price - data.gold)
	end
	if #data.inventory >= capacity(session) then
		return false, "🎒 Mochila llena: vende algo primero"
	end
	data.gold -= price
	data.stats.chests += 1
	addItem(player, session, map.drops[random:NextInteger(1, #map.drops)], rollRarity("chestWeight"), "en un cofre")
	return true, nil, { chest = true }
end

function Actions.claimDaily(_player: Player, session: Session)
	local data = session.data
	local available, day = dailyStatus(data)
	if not available then
		return false, "Ya la has recogido hoy. ¡Vuelve mañana!"
	end
	local gold = Config.goldPerMinute(data.unlockedMap) * Config.DAILY_MINUTES[day]
	addGold(data, gold)
	data.daily.lastDay = os.time() // 86400
	data.daily.streak = day
	local text = "🎁 Día " .. day .. ": +🪙" .. Config.formatNumber(gold)
	if day == #Config.DAILY_MINUTES then
		data.boostUntil = math.max(data.boostUntil, os.time()) + Config.DAILY_BOOST_MINUTES * 60
		refreshBoost(session)
		text ..= " y 🚀 boost x2 de " .. Config.DAILY_BOOST_MINUTES .. " min"
	end
	return true, text, { gold = true }
end

function Actions.finishTutorial(_player: Player, session: Session)
	if session.data.tutorialDone then
		return true, nil
	end
	session.data.tutorialDone = true
	addGold(session.data, Config.TUTORIAL_REWARD)
	return true, "🎓 ¡Tutorial completado! +🪙" .. Config.TUTORIAL_REWARD, { gold = true }
end

function Actions.setMuted(_player: Player, session: Session, muted: any)
	session.data.settings.muted = muted == true
	return true, nil
end

function Actions.setAutoSell(_player: Player, session: Session, enabled: any)
	session.data.settings.autoSell = enabled == true
	return true, if enabled == true then "♻️ Venta automática de objetos Comunes activada" else "♻️ Venta automática desactivada"
end

actionFunction.OnServerInvoke = function(player: Player, action: any, a: any, b: any)
	local session = sessions[player]
	if not session or type(action) ~= "string" then
		return false, "Cargando datos…"
	end
	local handler = Actions[action]
	if not handler then
		return false, "Acción desconocida"
	end
	local now = os.clock()
	if now - session.actionWindowStart > 1 then
		session.actionWindowStart = now
		session.actionCount = 0
	end
	session.actionCount += 1
	if session.actionCount > 10 then
		return false, "Vas muy rápido 😅"
	end
	local ok, message, extra = handler(player, session, a, b)
	if ok then
		sendState(player)
	end
	return ok, message, extra
end

-- Esquivar (va por el RemoteEvent de la partida: es frecuente)
swarmEvent.OnServerEvent:Connect(function(player: Player, kind: any)
	if kind == "dash" and sessions[player] then
		RunManager.dash(player)
	end
end)

---------------------------------------------------------------------
-- Compras con Robux
---------------------------------------------------------------------
local passKeyById: { [number]: string } = {}
for _, pass in Monetization.GamePasses do
	if pass.id ~= 0 then
		passKeyById[pass.id] = pass.key
	end
end

local productById: { [number]: any } = {}
for _, product in Monetization.Products do
	if product.id ~= 0 then
		productById[product.id] = product
	end
end

local function grantProduct(player: Player, session: Session, product)
	local data = session.data
	if product.kind == "gold" then
		local amount = Config.goldPerMinute(data.unlockedMap) * product.minutes
		addGold(data, amount)
		notify(player, product.emoji .. " ¡" .. product.name .. "! +🪙" .. Config.formatNumber(amount), "loot")
	elseif product.kind == "boost" then
		data.boostUntil = math.max(data.boostUntil, os.time()) + product.minutes * 60
		refreshBoost(session)
		notify(player, "🚀 ¡Boost x2 de oro durante " .. product.minutes .. " minutos!", "loot")
	elseif product.kind == "revive" then
		if RunManager.revive(player) then
			notify(player, "💖 ¡De vuelta a la partida!", "success")
		else
			local amount = Config.goldPerMinute(data.unlockedMap) * 10
			addGold(data, amount)
			notify(player, "💖 No había nada que revivir: te damos +🪙" .. Config.formatNumber(amount), "loot")
		end
	end
	session.dirty = true
end

local saveData: (Player, Session) -> boolean

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local session = player and sessions[player]
	local product = productById[receipt.ProductId]
	if not player or not session or not product then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = session.data
	local purchaseId = tostring(receipt.PurchaseId)
	if not data.receipts[purchaseId] then
		grantProduct(player, session, product)
		data.receipts[purchaseId] = os.time()
		-- Guardamos solo las 50 compras más recientes
		local entries = {}
		for id, time in data.receipts do
			table.insert(entries, { id = id, time = time })
		end
		if #entries > 50 then
			table.sort(entries, function(x, y)
				return x.time < y.time
			end)
			for i = 1, #entries - 50 do
				data.receipts[entries[i].id] = nil
			end
		end
		sendState(player)
	end
	-- Solo confirmamos la compra cuando está guardada
	if session.canSave and not saveData(player, session) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	local key = passKeyById[passId]
	local session = sessions[player]
	if purchased and key and session then
		(session.bonuses :: any)[key] = true
		local def = Config.PassByKey[key]
		notify(player, def.emoji .. " ¡Gracias! Ya tienes " .. def.name .. ".", "loot")
		sendState(player)
	end
end)

---------------------------------------------------------------------
-- Amigos en el servidor (+10 % de oro por cada uno)
---------------------------------------------------------------------
local function updateFriendBonus(session: Session)
	local count = 0
	for other in sessions do
		if session.friendIds[other.UserId] then
			count += 1
		end
	end
	session.bonuses.friends = count
	session.dirty = true
end

local function registerFriends(player: Player, session: Session)
	-- Copia de la lista: IsFriendsWithAsync espera a la red
	local others = {}
	for other in sessions do
		if other ~= player then
			table.insert(others, other)
		end
	end
	for _, other in others do
		local ok, isFriend = pcall(function()
			return player:IsFriendsWithAsync(other.UserId)
		end)
		local otherSession = sessions[other]
		if ok and isFriend and otherSession and sessions[player] then
			session.friendIds[other.UserId] = true
			otherSession.friendIds[player.UserId] = true
			notify(other, "👫 ¡" .. player.DisplayName .. " ha entrado! +10 % de oro por jugar con amigos", "success")
		end
	end
	for _, s in sessions do
		updateFriendBonus(s)
	end
end

---------------------------------------------------------------------
-- Entrar y salir del juego
---------------------------------------------------------------------
local function loadData(player: Player): (any, boolean)
	if not store then
		return newData(), false
	end
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return store:GetAsync(dataKey(player))
		end)
		if ok then
			if type(result) == "table" then
				return reconcile(result, newData()), true
			end
			return newData(), true
		end
		warn("[DungeonAscend] Error cargando datos (intento " .. attempt .. "):", result)
		task.wait(2)
	end
	return newData(), false
end

local pendingSaves = 0

function saveData(player: Player, session: Session): boolean
	if not session.canSave or not store then
		return false
	end
	session.data.lastOnline = os.time()
	pendingSaves += 1
	local ok, err = pcall(function()
		store:UpdateAsync(dataKey(player), function()
			return session.data
		end)
	end)
	if leaderboardStore then
		pcall(function()
			leaderboardStore:SetAsync("u_" .. player.UserId, math.floor(session.data.stats.kills))
		end)
	end
	pendingSaves -= 1
	session.lastSaveOk = ok
	if ok then
		session.lastSaveAt = os.time()
	else
		warn("[DungeonAscend] Error guardando datos de " .. player.Name .. ":", err)
	end
	return ok
end

Actions.saveNow = function(player: Player, session: Session)
	if not session.canSave then
		return false, "⚠️ El guardado está desactivado: publica el juego y activa «Enable Studio Access to API Services»."
	end
	local now = os.clock()
	if now - session.lastManualSave < Config.MANUAL_SAVE_COOLDOWN then
		return false, "Espera " .. math.ceil(Config.MANUAL_SAVE_COOLDOWN - (now - session.lastManualSave)) .. " s para volver a guardar."
	end
	session.lastManualSave = now
	if saveData(player, session) then
		return true, "💾 Partida guardada"
	end
	return false, "❌ No se pudo guardar. Se volverá a intentar solo."
end

local function checkPasses(player: Player, bonuses: Bonuses)
	for _, pass in Monetization.GamePasses do
		if pass.id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			if ok and owns then
				(bonuses :: any)[pass.key] = true
			end
		end
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local session = sessions[player]
	if not session then
		return
	end
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	character:WaitForChild("HumanoidRootPart")
	if not RunManager.onCharacter(player) then
		applyStats(player, session)
		attachWeapon(character, equippedItems(session.data).weapon)
	end
	humanoid.Died:Connect(function()
		RunManager.onDied(player)
	end)
end

local function onPlayerAdded(player: Player)
	local data, canSave = loadData(player)
	if not player.Parent then
		return -- se fue mientras cargaba
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local leaderKills = Instance.new("IntValue")
	leaderKills.Name = "💀 Bajas"
	leaderKills.Value = data.stats.kills
	leaderKills.Parent = leaderstats
	local leaderWins = Instance.new("IntValue")
	leaderWins.Name = "🏆 Victorias"
	leaderWins.Value = data.stats.wins
	leaderWins.Parent = leaderstats
	leaderstats.Parent = player

	local bonuses: Bonuses = {
		goldPass = false,
		choicePass = false,
		rerollPass = false,
		bagPass = false,
		boost = false,
		friends = 0,
	}
	checkPasses(player, bonuses)

	-- Lo equipado tiene que existir en la mochila, y la clase elegida tiene que ser tuya
	for slot, id in data.equipped do
		if not findItem(data, id) then
			data.equipped[slot] = nil
		end
	end
	if not data.classes[data.selectedClass] or not Config.ClassById[data.selectedClass] then
		data.selectedClass = "guerrero"
	end

	local session: Session = {
		data = data,
		canSave = canSave,
		bonuses = bonuses,
		stats = Config.baseStats(data.selectedClass, data.upgrades, equippedItems(data)),
		dirty = true,
		lastStateAt = 0,
		actionWindowStart = 0,
		actionCount = 0,
		lastManualSave = -math.huge,
		lastSaveOk = nil,
		lastSaveAt = 0,
		friendIds = {},
		leaderKills = leaderKills,
		leaderWins = leaderWins,
	}
	sessions[player] = session
	refreshBoost(session)

	if not canSave then
		task.delay(5, function()
			notify(player, "⚠️ No se pudo conectar con el guardado: esta partida no se guardará.", "error")
		end)
	end
	local dailyAvailable = dailyStatus(data)
	if dailyAvailable and data.tutorialDone then
		task.delay(4, function()
			notify(player, "🎁 ¡Tu recompensa diaria te espera! Pulsa 🎁 en el menú", "success")
		end)
	end

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end

	task.spawn(registerFriends, player, session)
	markAllDirty()
	sendState(player)
end

local function onPlayerRemoving(player: Player)
	-- Primero se cierra su partida (recibe su oro) y luego se guarda
	RunManager.playerRemoving(player)
	leaveGroup(player)
	local session = sessions[player]
	sessions[player] = nil
	for _, s in sessions do
		s.friendIds[player.UserId] = nil
		updateFriendBonus(s)
	end
	markAllDirty()
	if session then
		saveData(player, session)
	end
end

---------------------------------------------------------------------
-- Clasificación global
---------------------------------------------------------------------
local nameCache: { [number]: string } = {}

local function refreshLeaderboard()
	if not leaderboardStore then
		World.setLeaderboard(nil, "Publica el juego para ver la clasificación")
		return
	end
	local ok, pages = pcall(function()
		return leaderboardStore:GetSortedAsync(false, 10)
	end)
	if not ok then
		World.setLeaderboard(nil, "Clasificación disponible al publicar el juego")
		return
	end
	local rows = {}
	for _, entry in pages:GetCurrentPage() do
		local userId = tonumber(string.sub(entry.key, 3))
		local name = "???"
		if userId then
			if not nameCache[userId] then
				local okName, result = pcall(function()
					return Players:GetNameFromUserIdAsync(userId)
				end)
				nameCache[userId] = if okName then result else "Jugador"
			end
			name = nameCache[userId]
		end
		table.insert(rows, { name = name, value = entry.value })
	end
	World.setLeaderboard(rows, nil)
end

---------------------------------------------------------------------
-- Arranque
---------------------------------------------------------------------
World.build({
	onOpen = function(player: Player, tab: string, mapId: string?)
		openMenuEvent:FireClient(player, tab, mapId)
	end,
})

RunManager.init({
	buildArena = World.buildArena,
	destroyArena = World.destroyArena,
	baseStats = function(player: Player)
		local session = sessions[player]
		return if session then session.stats else Config.baseStats("guerrero", {}, {})
	end,
	classWeapon = function(player: Player): string
		local session = sessions[player]
		local class = session and Config.ClassById[session.data.selectedClass]
		return if class then class.weapon else "espada"
	end,
	bonuses = function(player: Player)
		local session = sessions[player]
		return if session then session.bonuses else {}
	end,
	teleport = teleportTo,
	onFinish = onFinish,
	notify = notify,
	markDirty = function(player: Player)
		local session = sessions[player]
		if session then
			session.dirty = true
		end
	end,
	sendSwarm = function(player: Player, enemies: buffer, gemAdds: { number }, gemRemoves: { number }, fx: { any })
		swarmEvent:FireClient(player, enemies, gemAdds, gemRemoves, fx)
	end,
})

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

game:BindToClose(function()
	for player, session in sessions do
		RunManager.playerRemoving(player)
		task.spawn(saveData, player, session)
	end
	-- Espera también a los guardados que ya estaban en marcha
	task.wait(0.5)
	local deadline = os.clock() + 25
	while pendingSaves > 0 and os.clock() < deadline do
		task.wait(0.5)
	end
end)

-- Partidas: 15 pasos de simulación por segundo
local runClock = 0
RunService.Heartbeat:Connect(function(dt: number)
	runClock += dt
	if runClock >= RunManager.TICK then
		RunManager.step(math.min(runClock, 0.25))
		runClock = 0
	end
end)

-- Guardado automático
task.spawn(function()
	while true do
		task.wait(Config.AUTOSAVE_INTERVAL)
		for player, session in sessions do
			task.spawn(saveData, player, session)
		end
	end
end)

-- Clasificación
task.spawn(function()
	task.wait(5)
	while true do
		refreshLeaderboard()
		task.wait(Config.LEADERBOARD_REFRESH)
	end
end)

-- Estado: se envía cuando cambia algo (como mucho 4 veces por segundo) y cada segundo
-- durante una partida (reloj y XP), o cada 2 s en el lobby
while true do
	task.wait(0.25)
	local now = os.clock()
	for player, session in sessions do
		local hadBoost = session.bonuses.boost
		refreshBoost(session)
		if hadBoost and not session.bonuses.boost then
			notify(player, "🚀 Tu boost x2 ha terminado", "info")
			session.dirty = true
		end
		local interval = if RunManager.runOf(player) then 0.5 else 2
		if session.dirty or now - session.lastStateAt >= interval then
			sendState(player)
		end
	end
end
