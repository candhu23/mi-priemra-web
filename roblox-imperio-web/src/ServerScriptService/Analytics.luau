--[[
	Analytics (ModuleScript en ServerScriptService)

	Manda datos a Roblox (Creator Hub → tu experiencia → Analytics) para
	saber qué funciona y dónde se va la gente:
	  · Embudo de los primeros minutos (Onboarding): entra, primera web,
	    tutorial, primera venta, 5/15/30 minutos...
	  · Embudo del tutorial (un paso por pantalla)
	  · Economía: de dónde sale el dinero (Source) y en qué se gasta (Sink),
	    sumado por categoría y enviado cada FLUSH_INTERVAL (Roblox limita el
	    número de eventos: no se manda uno por segundo)
	  · Progresión: plantas del rascacielos, salidas a bolsa, rango
	  · Eventos sueltos (webs raras, fichajes legendarios...)
	Todo va con pcall: si el servicio falla (Studio sin publicar), el juego
	sigue igual.
]]

local AnalyticsService = game:GetService("AnalyticsService")

local Analytics = {}

Analytics.FLUSH_INTERVAL = 300 -- segundos entre envíos de economía
Analytics.CURRENCY = "Dinero"
local MAX_AMOUNT = 9e15 -- (más grande no se representa bien)

-- Pasos del embudo de los primeros minutos (en el orden en que suelen pasar)
Analytics.Onboarding = {
	{ id = "join", name = "Entra por primera vez" },
	{ id = "firstProject", name = "Empieza su primera web" },
	{ id = "firstSite", name = "Termina su primera web" },
	{ id = "tutorial", name = "Termina el tutorial" },
	{ id = "firstSale", name = "Vende su primera web" },
	{ id = "firstCompany", name = "Funda su primera empresa" },
	{ id = "min5", name = "Juega 5 minutos" },
	{ id = "floor3", name = "Llega a la planta 3" },
	{ id = "min15", name = "Juega 15 minutos" },
	{ id = "min30", name = "Juega 30 minutos" },
}
local onboardingStep: { [string]: number } = {}
for i, step in Analytics.Onboarding do
	onboardingStep[step.id] = i
end

-- Categoría de cada movimiento de dinero → tipo de transacción de Roblox
local TRANSACTION = {
	robux = Enum.AnalyticsEconomyTransactionType.IAP.Name,
	diaria = Enum.AnalyticsEconomyTransactionType.TimedReward.Name,
	regalo = Enum.AnalyticsEconomyTransactionType.TimedReward.Name,
	premios = Enum.AnalyticsEconomyTransactionType.TimedReward.Name,
	tutorial = Enum.AnalyticsEconomyTransactionType.Onboarding.Name,
}

local function safe(fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		Analytics.errors += 1
		if Analytics.errors <= 3 then
			warn("[ImperioWeb] Analytics:", err)
		end
	end
end
Analytics.errors = 0

---------------------------------------------------------------------
-- Economía (se acumula y se envía cada FLUSH_INTERVAL)
---------------------------------------------------------------------
type Pending = { Source: { [string]: number }, Sink: { [string]: number } }
local pending: { [any]: Pending } = setmetatable({}, { __mode = "k" }) :: any

-- flow = "Source" (gana) o "Sink" (gasta); tag = categoría (ingresos, ventas...)
function Analytics.track(data: any, flow: string, tag: string, amount: number)
	if type(amount) ~= "number" or amount <= 0 or amount ~= amount or amount == math.huge then
		return
	end
	local p = pending[data]
	if not p then
		p = { Source = {}, Sink = {} }
		pending[data] = p
	end
	local byTag = (p :: any)[flow]
	byTag[tag] = (byTag[tag] or 0) + amount
end

-- Lo pendiente de un jugador, sin enviarlo (para el harness)
function Analytics.peek(data: any): Pending?
	return pending[data]
end

function Analytics.flush(player: Player, data: any)
	local p = pending[data]
	if not p then
		return
	end
	pending[data] = nil
	local balance = math.clamp(math.floor(data.money or 0), 0, MAX_AMOUNT)
	for flowName, byTag in p :: any do
		local flow = if flowName == "Source" then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink
		for tag, amount in byTag do
			local value = math.min(math.floor(amount), MAX_AMOUNT)
			if value >= 1 then
				safe(function()
					AnalyticsService:LogEconomyEvent(player, flow, Analytics.CURRENCY, value, balance,
						TRANSACTION[tag] or Enum.AnalyticsEconomyTransactionType.Gameplay.Name, tag)
				end)
			end
		end
	end
end

---------------------------------------------------------------------
-- Embudos
---------------------------------------------------------------------
-- Primeros minutos: cada paso se manda una sola vez por jugador
-- (data.analytics.onboarding[id] = true)
function Analytics.onboarding(player: Player, data: any, id: string)
	local step = onboardingStep[id]
	local done = data.analytics and data.analytics.onboarding
	if not step or not done or done[id] then
		return
	end
	-- Solo para jugadores nuevos (su primera hora)
	if os.time() - (data.firstJoin or 0) > 3600 then
		return
	end
	done[id] = true
	safe(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, Analytics.Onboarding[step].name)
	end)
end

-- Embudo con nombre (p. ej. "Tutorial"); sessionId distingue cada intento
function Analytics.funnel(player: Player, funnel: string, sessionId: string, step: number, stepName: string)
	safe(function()
		AnalyticsService:LogFunnelStepEvent(player, funnel, sessionId, step, stepName)
	end)
end

---------------------------------------------------------------------
-- Progresión y eventos sueltos
---------------------------------------------------------------------
function Analytics.progress(player: Player, path: string, level: number, levelName: string)
	safe(function()
		AnalyticsService:LogProgressionCompleteEvent(player, path, level, levelName)
	end)
end

function Analytics.event(player: Player, name: string, value: number?, fields: { [string]: any }?)
	safe(function()
		AnalyticsService:LogCustomEvent(player, name, value, fields)
	end)
end

return Analytics
