--[[
	MarketService (ModuleScript en ServerScriptService)

	Mueve los precios de la Bolsa, paga dividendos y gestiona las compras y
	ventas de cada jugador. Los datos y las fórmulas están en MarketConfig.

	v4: los precios son iguales en TODOS los servidores (ver MarketConfig:
	cálculo determinista por tick global = os.time() // TICK). Al arrancar se
	calculan los últimos WINDOW ticks; luego se sigue tick a tick.

	Inversión de cada jugador: data.portfolio[id] = { units, invested }
	  · units    = participaciones (dinero invertido / precio al comprar)
	  · invested = dinero que te ha costado (para enseñar si ganas o pierdes)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Market = require(ReplicatedStorage:WaitForChild("MarketConfig"))
local Config = require(ReplicatedStorage:WaitForChild("TycoonConfig"))
local Validate = require(ReplicatedStorage:WaitForChild("Validate"))

local MarketService = {}

type Ctx = {
	gain: (data: any, amount: number) -> (),
	notifyAll: (text: string, kind: string) -> (),
	sessions: () -> { [Player]: any },
	onTick: (rows: { any }) -> (), -- para el panel de la Bolsa en el mapa
	userId: (session: any) -> number, -- para el rumor del analista
}
local ctx: Ctx

-- history es un anillo de HISTORY precios: head = posición del más antiguo
-- (así, en cada tick solo cambia un hueco y el estado que se envía es pequeño)
type StockState = { x: number, price: number, last: number, history: { number }, head: number }
local stocks: { [string]: StockState } = {}
local currentTick = 0 -- último tick calculado

local function globalTick(): number
	return os.time() // Market.TICK
end

-- Calcula todo desde cero hasta "tick" (al arrancar, o si el servidor se
-- quedó parado mucho rato)
local function rebuild(tick: number)
	for i, def in Market.Stocks do
		local first = tick - Market.HISTORY + 1
		local x = Market.xAt(i, first - 1)
		local state: StockState = { x = x, price = Market.priceOf(i, x), last = Market.priceOf(i, x), history = {}, head = 1 }
		for t = first, tick do
			state.last = state.price
			state.x = Market.step(state.x, i, t)
			state.price = Market.priceOf(i, state.x)
			table.insert(state.history, state.price)
		end
		stocks[def.id] = state
	end
	currentTick = tick
end

function MarketService.init(context: Ctx)
	ctx = context
	rebuild(globalTick())
end

-- Avanza un tick. live = false cuando se está recuperando tiempo perdido
-- (sin noticias ni dividendos, que ya pasaron)
local function step(tick: number, live: boolean)
	for i, def in Market.Stocks do
		local state = stocks[def.id]
		state.last = state.price
		state.x = Market.step(state.x, i, tick)
		state.price = Market.priceOf(i, state.x)
		state.history[state.head] = state.price
		state.head = state.head % Market.HISTORY + 1
	end
	if not live then
		return
	end
	-- Noticias: cambian la tendencia de una empresa y lo sabe todo el servidor
	local news = Market.newsAt(tick)
	if news then
		local def = Market.Stocks[news.stock]
		ctx.notifyAll(string.format(Market.News[news.news].text, def.name), "event")
	end
	-- Dividendos a quien tenga acciones
	for _, session in ctx.sessions() do
		for id, position in session.data.portfolio do
			local state = stocks[id]
			if state and position.units > 0 then
				ctx.gain(session.data, position.units * state.price * Market.DIVIDEND)
			end
		end
	end
end

function MarketService.tick(_now: number)
	local target = globalTick()
	if target <= currentTick then
		return
	end
	if target - currentTick > Market.HISTORY then
		rebuild(target)
	else
		while currentTick < target do
			currentTick += 1
			step(currentTick, currentTick == target)
		end
	end
	ctx.onTick(MarketService.rows())
end

-- Para el panel del mapa: precio y cambio desde el tick anterior
function MarketService.rows(): { any }
	local rows = {}
	for _, def in Market.Stocks do
		local state = stocks[def.id]
		table.insert(rows, { id = def.id, ticker = def.ticker, emoji = def.emoji, price = state.price, change = state.price / state.last - 1 })
	end
	return rows
end

function MarketService.price(id: string): number
	local state = stocks[id]
	return if state then state.price else 0
end

function MarketService.currentTick(): number
	return currentTick
end

-- Acierto del rumor del analista (60 % + I+D)
function MarketService.rumorAccuracy(data): number
	return math.min(0.95, Market.RUMOR_ACCURACY + Config.researchValue(data, "analyst"))
end

-- Estado del mercado para el cliente (sin la tendencia real: solo el rumor)
function MarketService.buildState(session, _now: number)
	local list = {}
	local data = session.data
	local accuracy = MarketService.rumorAccuracy(data)
	local userId = ctx.userId(session)
	for i, def in Market.Stocks do
		local state = stocks[def.id]
		local position = data.portfolio[def.id]
		table.insert(list, {
			id = def.id,
			price = state.price,
			last = state.last,
			rumor = Market.rumor(i, currentTick, userId, accuracy),
			history = state.history,
			head = state.head,
			units = if position then position.units else 0,
			invested = if position then position.invested else 0,
		})
	end
	return {
		stocks = list,
		nextTick = math.max(0, (currentTick + 1) * Market.TICK - os.time()),
		cap = Market.cap(data.peakIncome),
		accuracy = accuracy,
	}
end

---------------------------------------------------------------------
-- Comprar y vender
---------------------------------------------------------------------
-- fraction = parte de tu dinero que inviertes (0..1; se le quita la comisión)
function MarketService.buy(session, id: any, fraction: any): (boolean, string?)
	local def = type(id) == "string" and Market.StockById[id]
	if not def or not Validate.number(fraction, 0, 1) or fraction <= 0 then
		return false, nil
	end
	local data = session.data
	local state = stocks[def.id]
	local position = data.portfolio[def.id] or { units = 0, invested = 0 }
	local room = Market.cap(data.peakIncome) - Market.value(position, state.price)
	local amount = math.min(data.money * fraction, room)
	if room <= 1 then
		return false, "Ya tienes invertido el máximo en esta empresa."
	end
	if amount < 1 then
		return false, "No tienes suficiente dinero."
	end
	data.money -= amount
	local net = amount * (1 - Market.FEE)
	position.units += net / state.price
	position.invested += amount
	data.portfolio[def.id] = position
	return true, string.format("📈 Compraste %s de %s %s (comisión %s)", Config.formatMoney(net), def.emoji, def.name, Config.formatMoney(amount - net))
end

-- fraction = parte de tus acciones que vendes (0..1)
function MarketService.sell(session, id: any, fraction: any): (boolean, string?, number?)
	local def = type(id) == "string" and Market.StockById[id]
	if not def or not Validate.number(fraction, 0, 1) or fraction <= 0 then
		return false, nil, nil
	end
	local data = session.data
	local position = data.portfolio[def.id]
	if not position or position.units <= 0 then
		return false, "No tienes acciones de esa empresa.", nil
	end
	local price = stocks[def.id].price
	local units = position.units * fraction
	local money = units * price
	local cost = position.invested * fraction
	position.units -= units
	position.invested -= cost
	if position.units < 1e-9 then
		data.portfolio[def.id] = nil
	end
	-- Recuperas lo invertido; solo el beneficio cuenta como "ganado"
	local profit = money - cost
	if profit > 0 then
		data.money += cost
		ctx.gain(data, profit)
	else
		data.money += money
	end
	return true, string.format("📊 Vendiste %s de %s %s (%s%s)", Config.formatMoney(money), def.emoji, def.name,
		if profit >= 0 then "+" else "-", Config.formatMoney(math.abs(profit))), profit
end

-- Al salir a bolsa se vende todo (el dinero se reinicia igualmente)
function MarketService.clear(session)
	session.data.portfolio = {}
end

return MarketService
