--[[
	GameServer (Script en ServerScriptService)

	El servidor manda: guarda la partida, reparte XP, oro y botín,
	comprueba cada acción del jugador (equipar, vender, forjar, viajar…),
	aplica la vida y el arma al personaje y gestiona las compras con Robux
	y la clasificación global. El combate está en CombatService.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local World = require(ServerScriptService:WaitForChild("World"))
local CombatService = require(ServerScriptService:WaitForChild("CombatService"))

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

-- Combate: cliente → servidor ("skill", id) · servidor → cliente ("hits", "hurt", "reward", "fx"…)
local combatEvent = Instance.new("RemoteEvent")
combatEvent.Name = "Combat"
combatEvent.Parent = remotes

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
		level = 1,
		xp = 0,
		gold = 0,
		lifetimeGold = 0,
		inventory = { { id = 1, def = Config.STARTER_WEAPON, rarity = "comun", up = 0 } },
		equipped = { weapon = 1 },
		nextItemId = 2,
		unlockedZone = 1,
		bossKills = {},
		stats = { kills = 0, bossKills = 0, deaths = 0, itemsFound = 0, upgrades = 0, chests = 0 },
		daily = { lastDay = -1, streak = 0 },
		boostUntil = 0,
		receipts = {},
		tutorialDone = false,
		settings = { muted = false, autoSell = false },
		lastOnline = os.time(),
	}
end

-- Campos que son listas o mapas del jugador: no se rellenan por dentro
local NO_DEEP_RECONCILE = { inventory = true, equipped = true, bossKills = true, receipts = true }

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
	xpPass: boolean,
	autoPass: boolean,
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
	skillWindowStart: number,
	skillCount: number,
	lastSkillError: number,
	lastManualSave: number,
	lastSaveOk: boolean?,
	lastSaveAt: number,
	friendIds: { [number]: boolean },
	deathZone: string?,
	deathAt: number,
	leaderLevel: IntValue,
	leaderZone: IntValue,
}

local sessions: { [Player]: Session } = {}

local function notify(player: Player, text: string, kind: string?)
	notifyEvent:FireClient(player, text, kind or "info")
end

local function popup(player: Player, title: string, body: string)
	notifyEvent:FireClient(player, title, "popup", body)
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

-- Arma visible en la mano del personaje (cambia de color con el objeto)
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

-- Recalcula daño y vida y los aplica al personaje
local function applyStats(player: Player, session: Session, fullHeal: boolean?)
	local data = session.data
	local equipped = equippedItems(data)
	session.stats = Config.playerStats(data.level, equipped)
	session.dirty = true
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		local ratio = humanoid.Health / math.max(1, humanoid.MaxHealth)
		humanoid.MaxHealth = session.stats.maxHealth
		humanoid.Health = if fullHeal then session.stats.maxHealth else math.max(1, ratio * session.stats.maxHealth)
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
		if roll <= 0 then
			return rarity.id
		end
	end
	return Config.Rarities[1].id
end

local function addGold(data, amount: number)
	amount = math.floor(amount)
	data.gold += amount
	data.lifetimeGold += amount
end

-- Añade un objeto a la mochila (o lo vende si no cabe / venta automática)
local function addItem(player: Player, session: Session, defId: string, rarityId: string, source: string)
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
		return
	end
	table.insert(data.inventory, item)
	combatEvent:FireClient(player, "loot", item, better)
	if rarity.index >= 5 then
		notifyAll("🌟 ¡" .. player.DisplayName .. " ha conseguido " .. def.name .. " LEGENDARIO " .. source .. "!", "loot")
	end
	session.dirty = true
end

---------------------------------------------------------------------
-- XP, oro y muertes de enemigos
---------------------------------------------------------------------
local function gainXp(player: Player, session: Session, amount: number)
	local data = session.data
	if data.level >= Config.MAX_LEVEL then
		return
	end
	data.xp += amount
	local leveled = false
	while data.level < Config.MAX_LEVEL and data.xp >= Config.xpToNext(data.level) do
		data.xp -= Config.xpToNext(data.level)
		data.level += 1
		leveled = true
		for _, skill in Config.Skills do
			if skill.level == data.level then
				popup(player, skill.emoji .. " ¡Nueva habilidad: " .. skill.name .. "!", "Pulsa " .. skill.key .. " o su botón de abajo para usarla.")
			end
		end
	end
	if data.level >= Config.MAX_LEVEL then
		data.xp = 0
	end
	if leveled then
		applyStats(player, session, true)
		session.leaderLevel.Value = data.level
		combatEvent:FireClient(player, "levelup", data.level)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			combatEvent:FireAllClients("fx", "levelup", root.Position, nil, player.UserId)
		end
	end
end

local function onKill(player: Player, info)
	local session = sessions[player]
	if not session then
		return
	end
	local data = session.data
	local goldMult, xpMult = Config.rewardMults(session.stats, session.bonuses)
	local xp = math.floor(info.stats.xp * xpMult)
	local gold = math.floor(info.stats.gold * goldMult)
	addGold(data, gold)
	data.stats.kills += 1
	combatEvent:FireClient(player, "reward", info.position, xp, gold)
	gainXp(player, session, xp)

	local zone = Config.Zones[info.zoneIndex]
	if info.isBoss then
		data.stats.bossKills += 1
		local first = not data.bossKills[zone.id]
		data.bossKills[zone.id] = (data.bossKills[zone.id] or 0) + 1
		addItem(player, session, zone.drops[random:NextInteger(1, #zone.drops)], rollRarity("bossWeight"), "del jefe")
		local nextZone = Config.Zones[info.zoneIndex + 1]
		if first and nextZone and data.unlockedZone < nextZone.index then
			data.unlockedZone = nextZone.index
			session.leaderZone.Value = nextZone.index
			popup(player, "🏆 ¡Has vencido a " .. Config.Enemies[zone.boss].name .. "!", "Se ha desbloqueado una zona nueva:\n" .. nextZone.emoji .. " " .. nextZone.name .. "\n\nVe al portal de la Ciudad o usa 🗺️ Zonas.")
		elseif first then
			popup(player, "🏆 ¡Has vencido al último jefe!", "Eres de los mejores aventureros. Pronto llegarán zonas nuevas: ¡sigue mejorando tu equipo!")
		else
			notify(player, "👑 ¡Jefe derrotado! +" .. Config.formatNumber(xp) .. " XP", "success")
		end
	elseif random:NextNumber() < Config.DROP_CHANCE then
		addItem(player, session, zone.drops[random:NextInteger(1, #zone.drops)], rollRarity("weight"), "")
	end
	session.dirty = true
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

local function buildState(session: Session)
	local data = session.data
	refreshBoost(session)
	local dailyAvailable, dailyDay = dailyStatus(data)
	return {
		version = Config.VERSION,
		level = data.level,
		xp = data.xp,
		xpNeeded = Config.xpToNext(data.level),
		gold = data.gold,
		stats = session.stats,
		inventory = data.inventory,
		equipped = data.equipped,
		capacity = capacity(session),
		unlockedZone = data.unlockedZone,
		bossKills = data.bossKills,
		bonuses = session.bonuses,
		boostLeft = math.max(0, data.boostUntil - os.time()),
		dailyAvailable = dailyAvailable,
		dailyDay = dailyDay,
		dailyReward = Config.goldPerMinute(data.unlockedZone) * Config.DAILY_MINUTES[dailyDay],
		tutorialDone = data.tutorialDone,
		settings = data.settings,
		kills = data.stats.kills,
		canSave = session.canSave,
		saveOk = session.lastSaveOk,
	}
end

local function sendState(player: Player)
	local session = sessions[player]
	if session then
		session.dirty = false
		session.lastStateAt = os.clock()
		stateEvent:FireClient(player, buildState(session))
	end
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

function Actions.teleport(player: Player, session: Session, zoneId: any)
	if zoneId == "lobby" then
		teleportTo(player, World.lobbySpawn())
		return true, "🏙️ De vuelta en la Ciudad"
	end
	local zone = type(zoneId) == "string" and Config.ZoneById[zoneId]
	if not zone then
		return false, "Zona desconocida"
	end
	if session.data.unlockedZone < zone.index then
		local previous = Config.Zones[zone.index - 1]
		return false, "🔒 Vence a " .. Config.Enemies[previous.boss].name .. " (" .. previous.name .. ") para entrar"
	end
	local entry = World.zoneEntry(zone.id)
	if entry then
		teleportTo(player, entry)
	end
	return true, zone.emoji .. " " .. zone.name
end

function Actions.equip(player: Player, session: Session, itemId: any)
	local item = findItem(session.data, itemId)
	if not item then
		return false, "Ese objeto ya no existe"
	end
	local slot = Config.Items[item.def].slot
	session.data.equipped[slot] = item.id
	applyStats(player, session)
	if slot == "weapon" and player.Character then
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
		if Config.Items[item.def].slot == "weapon" and player.Character then
			attachWeapon(player.Character, item)
		end
	end
	return true, "🔨 " .. Config.Items[item.def].name .. " +" .. item.up, { forge = true }
end

function Actions.buyChest(player: Player, session: Session, zoneIndex: any)
	local data = session.data
	local zone = type(zoneIndex) == "number" and Config.Zones[zoneIndex]
	if not zone then
		return false, "Cofre desconocido"
	end
	if data.unlockedZone < zone.index then
		return false, "🔒 Desbloquea antes " .. zone.name
	end
	local price = Config.chestPrice(zone.index)
	if data.gold < price then
		return false, "Te faltan 🪙" .. Config.formatNumber(price - data.gold)
	end
	if #data.inventory >= capacity(session) then
		return false, "🎒 Mochila llena: vende algo primero"
	end
	data.gold -= price
	data.stats.chests += 1
	addItem(player, session, zone.drops[random:NextInteger(1, #zone.drops)], rollRarity("chestWeight"), "en un cofre")
	return true, nil, { chest = true }
end

function Actions.claimDaily(player: Player, session: Session)
	local data = session.data
	local available, day = dailyStatus(data)
	if not available then
		return false, "Ya la has recogido hoy. ¡Vuelve mañana!"
	end
	local gold = Config.goldPerMinute(data.unlockedZone) * Config.DAILY_MINUTES[day]
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

-- Habilidades (van por un RemoteEvent: son muy frecuentes)
combatEvent.OnServerEvent:Connect(function(player: Player, kind: any, skillId: any)
	local session = sessions[player]
	if not session or kind ~= "skill" then
		return
	end
	local now = os.clock()
	if now - session.skillWindowStart > 1 then
		session.skillWindowStart = now
		session.skillCount = 0
	end
	session.skillCount += 1
	if session.skillCount > 20 then
		return
	end
	local ok, reason = CombatService.useSkill(player, skillId)
	if not ok and reason and now - session.lastSkillError > 2 then
		session.lastSkillError = now
		notify(player, reason, "error")
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
		local amount = Config.goldPerMinute(data.unlockedZone) * product.minutes
		addGold(data, amount)
		notify(player, product.emoji .. " ¡" .. product.name .. "! +🪙" .. Config.formatNumber(amount), "loot")
	elseif product.kind == "boost" then
		data.boostUntil = math.max(data.boostUntil, os.time()) + product.minutes * 60
		refreshBoost(session)
		notify(player, "🚀 ¡Boost x2 de oro y XP durante " .. product.minutes .. " minutos!", "loot")
	elseif product.kind == "revive" then
		-- La ventana de pago tarda: si ya reapareciste en la Ciudad, te llevamos igualmente
		local zoneId = session.deathZone
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local dead = not humanoid or humanoid.Health <= 0
		if zoneId and os.clock() - session.deathAt < 60 then
			session.deathZone = nil
			task.spawn(function()
				if dead then
					player:LoadCharacterAsync()
					task.wait(0.2)
				end
				local entry = World.zoneEntry(zoneId)
				if entry then
					teleportTo(player, entry)
				end
			end)
			notify(player, "💖 ¡De vuelta a la acción!", "success")
		else
			local amount = Config.goldPerMinute(data.unlockedZone) * 10
			addGold(data, amount)
			notify(player, "💖 Ya estabas vivo: te damos +🪙" .. Config.formatNumber(amount), "loot")
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
-- Amigos en el servidor (+10 % de oro y XP por cada uno)
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
			notify(other, "👫 ¡" .. player.DisplayName .. " ha entrado! +10 % de oro y XP por jugar con amigos", "success")
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

-- Puntuación de la clasificación: nivel y, para desempatar, la XP
local function leaderboardScore(data): number
	return data.level * 1e9 + math.min(math.floor(data.xp), 1e9 - 1)
end

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
			leaderboardStore:SetAsync("u_" .. player.UserId, leaderboardScore(session.data))
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
	humanoid.WalkSpeed = Config.WALK_SPEED
	applyStats(player, session, true)
	attachWeapon(character, equippedItems(session.data).weapon)
	humanoid.Died:Connect(function()
		local s = sessions[player]
		if not s then
			return
		end
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		s.data.stats.deaths += 1
		s.deathZone = if root then World.zoneAt(root.Position) else nil
		s.deathAt = os.clock()
		combatEvent:FireClient(player, "died", s.deathZone, Config.RESPAWN_TIME)
	end)
end

local function onPlayerAdded(player: Player)
	local data, canSave = loadData(player)
	if not player.Parent then
		return -- se fue mientras cargaba
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local leaderLevel = Instance.new("IntValue")
	leaderLevel.Name = "⭐ Nivel"
	leaderLevel.Value = data.level
	leaderLevel.Parent = leaderstats
	local leaderZone = Instance.new("IntValue")
	leaderZone.Name = "🗺️ Zona"
	leaderZone.Value = data.unlockedZone
	leaderZone.Parent = leaderstats
	leaderstats.Parent = player

	local bonuses: Bonuses = {
		goldPass = false,
		xpPass = false,
		autoPass = false,
		bagPass = false,
		boost = false,
		friends = 0,
	}
	checkPasses(player, bonuses)

	-- Lo equipado tiene que existir en la mochila
	for slot, id in data.equipped do
		if not findItem(data, id) then
			data.equipped[slot] = nil
		end
	end

	local session: Session = {
		data = data,
		canSave = canSave,
		bonuses = bonuses,
		stats = Config.playerStats(data.level, equippedItems(data)),
		dirty = true,
		lastStateAt = 0,
		actionWindowStart = 0,
		actionCount = 0,
		skillWindowStart = 0,
		skillCount = 0,
		lastSkillError = -math.huge,
		lastManualSave = -math.huge,
		lastSaveOk = nil,
		lastSaveAt = 0,
		friendIds = {},
		deathZone = nil,
		deathAt = -math.huge,
		leaderLevel = leaderLevel,
		leaderZone = leaderZone,
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
	sendState(player)
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	-- Se quita primero para que los bucles dejen de tocarlo
	sessions[player] = nil
	CombatService.removePlayer(player)
	for _, s in sessions do
		s.friendIds[player.UserId] = nil
		updateFriendBonus(s)
	end
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
		table.insert(rows, { name = name, level = entry.value // 1e9 })
	end
	World.setLeaderboard(rows, nil)
end

---------------------------------------------------------------------
-- Arranque
---------------------------------------------------------------------
local zones = World.build({
	onPortal = function(player: Player, zoneId: string)
		local session = sessions[player]
		if session then
			local ok, message = Actions.teleport(player, session, zoneId)
			notify(player, message or "", if ok then "info" else "error")
		end
	end,
	onReturn = function(player: Player)
		teleportTo(player, World.lobbySpawn())
	end,
	onOpen = function(player: Player, tab: string)
		openMenuEvent:FireClient(player, tab)
	end,
})

CombatService.init(zones, World.zoneAt, {
	level = function(player: Player): number?
		local session = sessions[player]
		return session and session.data.level
	end,
	stats = function(player: Player)
		local session = sessions[player]
		return if session then session.stats else Config.playerStats(1, {})
	end,
	onKill = onKill,
	send = function(player: Player, kind: string, a: any, b: any?)
		combatEvent:FireClient(player, kind, a, b)
	end,
	fx = function(source: Player?, kind: string, position: Vector3, extra: any?)
		combatEvent:FireAllClients("fx", kind, position, extra, if source then source.UserId else 0)
	end,
	zoneMessage = function(zoneId: string, text: string)
		for player in sessions do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and World.zoneAt(root.Position) == zoneId then
				notify(player, text, "boss")
			end
		end
	end,
})

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

game:BindToClose(function()
	for player, session in sessions do
		task.spawn(saveData, player, session)
	end
	-- Espera también a los guardados que ya estaban en marcha
	task.wait(0.5)
	local deadline = os.clock() + 25
	while pendingSaves > 0 and os.clock() < deadline do
		task.wait(0.5)
	end
end)

-- Combate: los enemigos se mueven unas 15 veces por segundo
local combatClock = 0
RunService.Heartbeat:Connect(function(dt: number)
	combatClock += dt
	if combatClock >= CombatService.TICK then
		CombatService.step(math.min(combatClock, 0.25))
		combatClock = 0
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

-- Estado: se envía cuando cambia algo (como mucho 4 veces por segundo) y cada 2 s
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
		if session.dirty or now - session.lastStateAt >= 2 then
			sendState(player)
		end
	end
end
