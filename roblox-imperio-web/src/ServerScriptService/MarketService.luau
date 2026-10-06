--[[
	MarketService (ModuleScript en ServerScriptService)

	Mueve los precios de la Bolsa (los mismos para todo el servidor), paga
	dividendos y gestiona las compras y ventas de cada jugador. Los datos y
	las reglas están en MarketConfig.

	Inversión de cada jugador: data.portfolio[id] = { units, invested }
	  · units    = participaciones (dinero invertido / precio al comprar)
	  · invested = dinero que te ha costado (para enseñar si ganas o pierdes)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Market = require(ReplicatedStorage:WaitForChild("MarketConfig"))
local Config = require(ReplicatedStorage:WaitForChild("TycoonConfig"))

local MarketService = {}

type Ctx = {
	random: Random,
	gain: (data: any, amount: number) -> (),
	notifyAll: (text: string, kind: string) -> (),
	sessions: () -> { [Player]: any },
	onTick: (rows: { any }) -> (), -- para el panel de la Bolsa en el mapa
}
local ctx: Ctx

type StockState = { price: number, mode: string, ticksLeft: number, history: { number }, last: number }
local stocks: { [string]: StockState } = {}
local nextTickAt = 0

local function pickMode(previous: string?): string
	-- Después de dispararse, lo normal es que se hunda (y al revés, que rebote)
	if previous == "fastRise" and ctx.random:NextNumber() < 0.6 then
		return "fastFall"
	elseif previous == "fastFall" and ctx.random:NextNumber() < 0.4 then
		return "slowRise"
	end
	local total = 0
	for _, mode in Market.Modes do
		total += mode.weight
	end
	local roll = ctx.random:NextNumber() * total
	for _, mode in Market.Modes do
		roll -= mode.weight
		if roll <= 0 then
			return mode.id
		end
	end
	return "stable"
end

local function setMode(state: StockState, modeId: string)
	local mode = Market.ModeById[modeId]
	state.mode = modeId
	state.ticksLeft = ctx.random:NextInteger(mode.minTicks, mode.maxTicks)
end

function MarketService.init(context: Ctx)
	ctx = context
	for _, def in Market.Stocks do
		-- Empieza cerca de su valor justo
		local price = def.rest * (0.85 + ctx.random:NextNumber() * 0.3)
		local state: StockState = { price = price, mode = "stable", ticksLeft = 0, history = {}, last = price }
		setMode(state, pickMode(nil))
		for _ = 1, Market.HISTORY do
			table.insert(state.history, price)
		end
		stocks[def.id] = state
	end
	nextTickAt = os.clock() + Market.TICK
end

-- Un movimiento de precios
local function step()
	for _, def in Market.Stocks do
		local state = stocks[def.id]
		local mode = Market.ModeById[state.mode]
		state.last = state.price
		local noise = (ctx.random:NextNumber() * 2 - 1) * 0.012 * mode.noise * def.vol
		local pull = (def.rest - state.price) / def.rest * 0.03 -- vuelve poco a poco a su valor justo
		local change = mode.drift * def.vol + noise + pull
		state.price = math.clamp(state.price * (1 + change), def.rest * 0.2, def.rest * 4)
		table.insert(state.history, state.price)
		if #state.history > Market.HISTORY then
			table.remove(state.history, 1)
		end
		state.ticksLeft -= 1
		if state.ticksLeft <= 0 then
			setMode(state, pickMode(state.mode))
		end
	end
	-- Noticias: cambian la tendencia de una empresa y lo sabe todo el servidor
	if ctx.random:NextNumber() < Market.NEWS_CHANCE then
		local def = Market.Stocks[ctx.random:NextInteger(1, #Market.Stocks)]
		local news = Market.News[ctx.random:NextInteger(1, #Market.News)]
		setMode(stocks[def.id], if news.good then "fastRise" else "fastFall")
		ctx.notifyAll(string.format(news.text, def.name), "event")
	end
	-- Dividendos a quien tenga acciones
	for _, session in ctx.sessions() do
		local portfolio = session.data.portfolio
		for id, position in portfolio do
			local state = stocks[id]
			if state and position.units > 0 then
				ctx.gain(session.data, position.units * state.price * Market.DIVIDEND)
			end
		end
	end
	ctx.onTick(MarketService.rows())
end

function MarketService.tick(now: number)
	if now >= nextTickAt then
		nextTickAt = now + Market.TICK
		step()
	end
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

-- Estado del mercado para el cliente
function MarketService.buildState(session, now: number)
	local list = {}
	local data = session.data
	for _, def in Market.Stocks do
		local state = stocks[def.id]
		local position = data.portfolio[def.id]
		table.insert(list, {
			id = def.id,
			price = state.price,
			last = state.last,
			mode = state.mode,
			history = state.history,
			units = if position then position.units else 0,
			invested = if position then position.invested else 0,
		})
	end
	return {
		stocks = list,
		nextTick = math.max(0, nextTickAt - now),
		cap = Market.cap(data.peakIncome),
	}
end

---------------------------------------------------------------------
-- Comprar y vender
---------------------------------------------------------------------
-- fraction = parte de tu dinero que inviertes (0..1; se le quita la comisión)
function MarketService.buy(session, id: any, fraction: any): (boolean, string?)
	local def = type(id) == "string" and Market.StockById[id]
	if not def or type(fraction) ~= "number" or fraction ~= fraction or fraction <= 0 or fraction > 1 then
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
	if not def or type(fraction) ~= "number" or fraction <= 0 or fraction > 1 then
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
