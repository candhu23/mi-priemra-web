--[[
	MarketConfig (ModuleScript en ReplicatedStorage)

	La Bolsa de Ciudad Web (v3.0). Idea sacada del mercado de Cookie Clicker:
	  · 6 empresas cotizadas, cada una de un sector
	  · el precio se mueve cada TICK segundos siguiendo una "tendencia"
	    (estable, sube, baja, se dispara, se hunde, caótica) y siempre tira
	    un poco hacia su valor justo (rest)
	  · noticias de sector que cambian la tendencia (y se anuncian a todos)
	  · compras con comisión y un máximo invertido por empresa; si mantienes
	    las acciones cobras dividendos
	v4: el mercado es el MISMO EN TODOS LOS SERVIDORES. Los precios no usan
	números aleatorios del servidor sino un "dado" fijo por (empresa, tick):
	Market.hash. Así, si dos servidores calculan el precio del tick 1234,
	sale lo mismo y no se puede comprar barato en uno y vender caro en otro.
	El precio se calcula en escala logarítmica x = log(precio / valor justo):
	  x(siguiente) = (1 − REVERT)·x + tendencia + ruido     (y se limita)
	Como cada tick "olvida" un 3 % de dónde venía, da igual desde dónde se
	empiece a calcular: tras WINDOW ticks dos cálculos coinciden (0,97^1000 ≈ 0).
	Cada servidor, al arrancar, calcula los últimos WINDOW ticks y luego sigue
	tick a tick.

	La tendencia de cada empresa NO se enseña: el jugador ve un "rumor del
	analista" que acierta RUMOR_ACCURACY de las veces (más con I+D).

	Tu inversión se guarda en "participaciones": dinero invertido / precio.
	Lo que vale ahora = participaciones × precio actual. Así solo se gana o
	se pierde por lo que se mueve el precio.
]]

local Market = {}

Market.TICK = 30 -- segundos entre movimientos de precio (tick = os.time() // TICK)
Market.HISTORY = 48 -- puntos de la gráfica (24 minutos)
Market.FEE = 0.02 -- comisión al comprar (2 %)
Market.DIVIDEND = 0.0005 -- dividendo por tick sobre lo que vale tu inversión (0,05 %, ~6 %/hora)
Market.WINDOW = 1000 -- ticks que se calculan hacia atrás al arrancar un servidor
Market.REVERT = 0.03 -- cada tick vuelve un 3 % hacia el valor justo (en escala log)
Market.NOISE = 0.012 -- ruido base por tick
Market.MIN_MULT = 0.2 -- el precio va de ×0,2 a ×4 del valor justo
Market.MAX_MULT = 4
Market.MODE_BLOCK = 10 -- la tendencia cambia cada 10 ticks (5 minutos)
Market.NEWS_TICKS = 6 -- una noticia fija la tendencia durante 6 ticks (3 min)
Market.RUMOR_ACCURACY = 0.6 -- el rumor del analista acierta un 60 % (I+D "analyst" lo sube)
Market.CAP_SECONDS = 900 -- máximo invertido por empresa = 15 min de tus mejores ingresos...
Market.CAP_MIN = 2000 -- ...o como mínimo esto
Market.NEWS_CHANCE = 0.08 -- probabilidad de noticia en cada tick

Market.Stocks = {
	{ id = "byte", ticker = "BYTE", name = "ByteCorp", emoji = "🤖", sector = "tech", rest = 50, vol = 1.0 },
	{ id = "shop", ticker = "SHOP", name = "ShopNova", emoji = "🛍️", sector = "ecommerce", rest = 35, vol = 1.0 },
	{ id = "pixl", ticker = "PIXL", name = "PixelPlay", emoji = "🎮", sector = "gaming", rest = 40, vol = 1.3 },
	{ id = "bank", ticker = "BANK", name = "CobreBank", emoji = "💳", sector = "finanzas", rest = 60, vol = 0.6 },
	{ id = "vita", ticker = "VITA", name = "VitaSalud", emoji = "🩺", sector = "salud", rest = 45, vol = 0.8 },
	{ id = "trip", ticker = "TRIP", name = "ViajaYa", emoji = "✈️", sector = "viajes", rest = 25, vol = 1.5 },
}

-- Tendencias: drift = cambio medio por tick (escala log); noise = cuánto baila
-- dir = lo que diría el analista (up / down / flat)
Market.Modes = {
	{ id = "stable", emoji = "➡️", name = "Estable", drift = 0, noise = 0.6, weight = 3, dir = "flat" },
	{ id = "slowRise", emoji = "↗️", name = "Sube poco a poco", drift = 0.006, noise = 0.8, weight = 2, dir = "up" },
	{ id = "slowFall", emoji = "↘️", name = "Baja poco a poco", drift = -0.006, noise = 0.8, weight = 2, dir = "down" },
	{ id = "fastRise", emoji = "🚀", name = "Se dispara", drift = 0.025, noise = 1.2, weight = 1, dir = "up" },
	{ id = "fastFall", emoji = "📉", name = "Se hunde", drift = -0.025, noise = 1.2, weight = 1, dir = "down" },
	{ id = "chaotic", emoji = "🌀", name = "Caótica", drift = 0, noise = 3.0, weight = 1, dir = "flat" },
}

-- Lo que puede decir el rumor del analista
Market.RumorDirs = {
	up = { emoji = "📈", text = "subirá" },
	down = { emoji = "📉", text = "bajará" },
	flat = { emoji = "➡️", text = "se quedará igual" },
}

-- Noticias por sector: good = sube, si no baja. %s = nombre de la empresa
Market.News = {
	{ good = true, text = "📰 %s presenta un producto que lo peta: sus acciones se disparan" },
	{ good = true, text = "📰 Récord de ventas en %s: los inversores se lanzan a comprar" },
	{ good = true, text = "📰 %s firma un acuerdo gigante: ¡sube y sube!" },
	{ good = false, text = "📰 Escándalo en %s: sus acciones se hunden" },
	{ good = false, text = "📰 %s pierde a su mejor cliente: caída en bolsa" },
	{ good = false, text = "📰 Hackean a %s: los inversores huyen" },
}

local function index(list)
	local map = {}
	for i, item in list do
		item.order = i
		map[item.id] = item
	end
	return map
end
Market.StockById = index(Market.Stocks)
Market.ModeById = index(Market.Modes)

---------------------------------------------------------------------
-- Cálculo determinista (igual en todos los servidores)
---------------------------------------------------------------------
-- "Dado" fijo: número en [0, 1) que solo depende de (a, b, c)
local TWO32 = 4294967296
function Market.hash(a: number, b: number, c: number): number
	local h = (a * 73856093 + b * 19349663 + c * 83492791 + 2654435769) % TWO32
	for _ = 1, 3 do
		h = bit32.bxor(h, bit32.lshift(h, 13))
		h = bit32.bxor(h, bit32.rshift(h, 17))
		h = bit32.bxor(h, bit32.lshift(h, 5))
	end
	return h / TWO32
end

local function pickMode(roll: number): string
	local total = 0
	for _, mode in Market.Modes do
		total += mode.weight
	end
	roll *= total
	for _, mode in Market.Modes do
		roll -= mode.weight
		if roll < 0 then
			return mode.id
		end
	end
	return "stable"
end

-- Tendencia "de base" de una empresa en un bloque de MODE_BLOCK ticks
local function baseMode(stockIndex: number, block: number): string
	return pickMode(Market.hash(stockIndex, block, 1))
end

-- Noticia del tick (o nil): { stock = índice, news = índice en Market.News }
function Market.newsAt(tick: number): { stock: number, news: number }?
	if Market.hash(0, tick, 4) >= Market.NEWS_CHANCE then
		return nil
	end
	return {
		stock = 1 + math.floor(Market.hash(0, tick, 5) * #Market.Stocks),
		news = 1 + math.floor(Market.hash(0, tick, 6) * #Market.News),
	}
end

-- Tendencia real de una empresa en un tick
function Market.modeAt(stockIndex: number, tick: number): string
	-- Una noticia reciente manda
	for d = 0, Market.NEWS_TICKS - 1 do
		local news = Market.newsAt(tick - d)
		if news and news.stock == stockIndex then
			return if Market.News[news.news].good then "fastRise" else "fastFall"
		end
	end
	local block = tick // Market.MODE_BLOCK
	local previous = baseMode(stockIndex, block - 1)
	-- Después de dispararse, lo normal es que se hunda (y al revés, que rebote)
	if previous == "fastRise" and Market.hash(stockIndex, block, 2) < 0.6 then
		return "fastFall"
	elseif previous == "fastFall" and Market.hash(stockIndex, block, 3) < 0.4 then
		return "slowRise"
	end
	return baseMode(stockIndex, block)
end

local LOG_MIN = math.log(Market.MIN_MULT)
local LOG_MAX = math.log(Market.MAX_MULT)

-- Un tick: x = log(precio / valor justo)
function Market.step(x: number, stockIndex: number, tick: number): number
	local def = Market.Stocks[stockIndex]
	local mode = Market.ModeById[Market.modeAt(stockIndex, tick)]
	local noise = (Market.hash(stockIndex, tick, 7) * 2 - 1) * Market.NOISE * mode.noise * def.vol
	return math.clamp((1 - Market.REVERT) * x + mode.drift * def.vol + noise, LOG_MIN, LOG_MAX)
end

function Market.priceOf(stockIndex: number, x: number): number
	return Market.Stocks[stockIndex].rest * math.exp(x)
end

-- x de una empresa en un tick, calculado desde cero (WINDOW ticks atrás)
function Market.xAt(stockIndex: number, tick: number): number
	local x = 0
	for t = tick - Market.WINDOW + 1, tick do
		x = Market.step(x, stockIndex, t)
	end
	return x
end

-- Rumor del analista para un jugador: acierta "accuracy" de las veces. Es
-- fijo para (empresa, bloque, jugador): preguntar otra vez no cambia nada.
function Market.rumor(stockIndex: number, tick: number, userId: number, accuracy: number): string
	local truth = Market.ModeById[Market.modeAt(stockIndex, tick)].dir
	local block = tick // Market.MODE_BLOCK
	local seed = userId % 1000003
	if Market.hash(stockIndex * 7 + 3, block, seed) < accuracy then
		return truth
	end
	local others = {}
	for _, dir in { "up", "down", "flat" } do
		if dir ~= truth then
			table.insert(others, dir)
		end
	end
	return others[if Market.hash(stockIndex * 7 + 5, block, seed) < 0.5 then 1 else 2]
end

-- Máximo que puedes tener invertido en UNA empresa
function Market.cap(peakIncome: number): number
	return math.max(Market.CAP_MIN, (peakIncome or 0) * Market.CAP_SECONDS)
end

-- Valor actual de una inversión
function Market.value(position, price: number): number
	if not position then
		return 0
	end
	return position.units * price
end

return Market
