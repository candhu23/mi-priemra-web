--[[
	ServerState (ModuleScript en ServerScriptService)

	Lo que comparten todos los módulos del servidor: sesiones de jugador,
	remotes, estado global (evento del servidor, meta común, clasificaciones),
	avisos (notify/popup) y gain. Tipos Session, Bonuses...

	v4: sacado de TycoonServer sin cambiar lo que hace.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("TycoonConfig"))
local Analytics = require(ServerScriptService:WaitForChild("Analytics"))
local random = Random.new()

local ServerState = {}

export type Offer = { id: number, company: string, niche: string, type: string, mult: number, expiresAt: number }

export type ActiveEvent = { id: string, name: string, endsAt: number, siteId: number? }

export type Bonuses = {
	pass: boolean,
	turbo: boolean,
	slotsPass: boolean,
	agencyPro: boolean,
	xpPass: boolean,
	boost: boolean,
	friends: number,
	premium: boolean,
	group: boolean,
	randomRestricted: boolean, -- Roblox no permite artículos aleatorios de pago a este jugador
	agencyWork: number,
	agencyBonus: number, -- % extra de dinero de tus programadores
	agencyQuality: number, -- % extra de calidad (Diseño)
	agencyVisits: number, -- % extra de visitas (Marketing)
	agencySale: number, -- % extra al vender (Ventas)
	agencyRare: number, -- % extra de webs raras (Datos)
	weekend: string?, -- evento de fin de semana activo
}

export type Session = {
	data: any,
	userId: number,
	combo: number, -- clics seguidos
	lastClickAt: number,
	floors: number, -- plantas (para avisar de lo que se desbloquea)
	achievementTiers: { [string]: number }, -- niveles de logros ya avisados
	canSave: boolean,
	bonuses: Bonuses,
	offers: { Offer },
	nextOfferId: number,
	nextOfferAt: number, -- cuándo llega la próxima oferta de cliente
	quickSaleReadyAt: number, -- venta rápida disponible otra vez
	event: ActiveEvent?,
	nextEventAt: number,
	giftReadyAt: number,
	contractBoard: { any }, -- encargos del tablón (CareerService)
	nextContractAt: number,
	askReadyAt: number,
	lastManualSave: number,
	lastSaveOk: boolean?,
	lastSaveAt: number,
	income: number,
	clickWindowStart: number,
	clickCount: number,
	actionWindowStart: number,
	actionCount: number,
	friendIds: { [number]: boolean },
	goalNotified: { [string]: boolean },
	leaderMoney: IntValue,
	leaderShares: IntValue,
	leaderLevel: IntValue,
	weeklyCheckAt: number, -- cuándo mirar si hay premio del ranking semanal
	weeklyChecking: boolean,
	closed: boolean, -- el jugador ya se fue (no se vuelve a guardar salvo al liberar)
	joinedAt: number, -- os.clock() al entrar (minutos jugados en esta sesión)
	tutorialSteps: { [number]: boolean }, -- pasos del tutorial ya apuntados
	badgeCheckAt: number,
	errors: number, -- errores en el bucle de la economía (F8)
	sent: any, -- copia del último estado enviado (para mandar solo lo que cambia)
	lastSendAt: number,
	dirty: boolean, -- hay cambios que enviar en cuanto se pueda
}

-- Evento del servidor (para todos a la vez) y meta cooperativa
export type ServerEvent = { id: string, endsAt: number }

export type Community = { target: number, endsAt: number, start: { [Player]: number } }

-- Clasificaciones (las rellena refreshLeaderboard y van en el estado)
export type BoardRow = { name: string, value: number, userId: number? }

local remotes = Instance.new("Folder")

remotes.Name = "TycoonRemotes"

local actionFunction = Instance.new("RemoteFunction")

actionFunction.Name = "Action"

actionFunction.Parent = remotes

local stateEvent = Instance.new("RemoteEvent")

stateEvent.Name = "State"

stateEvent.Parent = remotes

local notifyEvent = Instance.new("RemoteEvent")

notifyEvent.Name = "Notify"

notifyEvent.Parent = remotes

local openComputerEvent = Instance.new("RemoteEvent")

openComputerEvent.Name = "OpenComputer"

openComputerEvent.Parent = remotes

-- Ficha del imperio de otro jugador (al pulsar "Ver imperio" en su cartel)
local visitEvent = Instance.new("RemoteEvent")

visitEvent.Name = "Visit"

visitEvent.Parent = remotes

remotes.Parent = ReplicatedStorage

---------------------------------------------------------------------
-- Guardado
---------------------------------------------------------------------

local sessions: { [Player]: Session } = {}

-- Estado global del servidor (se reasigna, por eso va en una tabla)
local world: {
	serverEvent: ServerEvent?, -- evento del servidor (para todos a la vez)
	community: Community?, -- meta cooperativa
	globalTop: { BoardRow }, -- clasificaciones (las rellena LeaderboardService)
	weeklyTop: { BoardRow },
	weeklyTopWeek: number,
} = { serverEvent = nil, community = nil, globalTop = {}, weeklyTop = {}, weeklyTopWeek = -1 }

-- Lo ganado entre todos desde que empezó la meta
local function communityProgress(): number
	local goal = world.community
	if not goal then
		return 0
	end
	local total = 0
	for player, startEarned in goal.start do
		local session = sessions[player]
		if session then
			total += math.max(0, session.data.lifetimeEarned - startEarned)
		end
	end
	return total
end

local function serverEventIs(id: string): boolean
	return world.serverEvent ~= nil and world.serverEvent.id == id
end

local function notify(player: Player, text: string, kind: string?)
	if sessions[player] then
		notifyEvent:FireClient(player, text, kind or "info")
	end
end

-- Ventana emergente en el cliente
local function popup(player: Player, title: string, body: string)
	if sessions[player] then
		notifyEvent:FireClient(player, title, "popup", body)
	end
end

-- tag = de dónde sale el dinero (para la analítica): ingresos, ventas, encargos...
local function gain(data, amount: number, tag: string?)
	if amount <= 0 or amount ~= amount or amount == math.huge then
		return
	end
	data.money += amount
	data.totalEarned += amount
	data.lifetimeEarned += amount
	data.weekly.earned += amount
	Analytics.track(data, "Source", tag or "otros", amount)
end

-- Gasta dinero (ya comprobado que llega) y lo apunta en la analítica
local function spend(data, amount: number, tag: string)
	data.money -= amount
	Analytics.track(data, "Sink", tag, amount)
end

local function findSite(data, siteId: any)
	for i, site in data.sites do
		if site.id == siteId then
			return site, i
		end
	end
	return nil, nil
end

local function likedToday(data, ownerId: number): boolean
	local given = data.likesGiven
	return given.day == Config.dayIndex(os.time()) and given.ids["u" .. ownerId] == true
end

local function notifyAll(text: string, kind: string)
	for other in sessions do
		notify(other, text, kind)
	end
end

ServerState.actionFunction = actionFunction
ServerState.communityProgress = communityProgress
ServerState.findSite = findSite
ServerState.gain = gain
ServerState.spend = spend
ServerState.likedToday = likedToday
ServerState.notify = notify
ServerState.notifyAll = notifyAll
ServerState.notifyEvent = notifyEvent
ServerState.openComputerEvent = openComputerEvent
ServerState.popup = popup
ServerState.random = random
ServerState.serverEventIs = serverEventIs
ServerState.sessions = sessions
ServerState.stateEvent = stateEvent
ServerState.visitEvent = visitEvent
ServerState.world = world

return ServerState
