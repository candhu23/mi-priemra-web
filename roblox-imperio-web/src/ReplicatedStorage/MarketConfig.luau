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
	El mercado es el mismo para todo el servidor.

	Tu inversión se guarda en "participaciones": dinero invertido / precio.
	Lo que vale ahora = participaciones × precio actual. Así solo se gana o
	se pierde por lo que se mueve el precio.
]]

local Market = {}

Market.TICK = 30 -- segundos entre movimientos de precio
Market.HISTORY = 48 -- puntos de la gráfica (24 minutos)
Market.FEE = 0.02 -- comisión al comprar (2 %)
Market.DIVIDEND = 0.0015 -- dividendo por tick sobre lo que vale tu inversión (0,15 %)
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

-- Tendencias: drift = cambio medio por tick; noise = cuánto baila
Market.Modes = {
	{ id = "stable", emoji = "➡️", name = "Estable", drift = 0, noise = 0.6, minTicks = 8, maxTicks = 20, weight = 3 },
	{ id = "slowRise", emoji = "↗️", name = "Sube poco a poco", drift = 0.006, noise = 0.8, minTicks = 8, maxTicks = 20, weight = 2 },
	{ id = "slowFall", emoji = "↘️", name = "Baja poco a poco", drift = -0.006, noise = 0.8, minTicks = 8, maxTicks = 20, weight = 2 },
	{ id = "fastRise", emoji = "🚀", name = "Se dispara", drift = 0.03, noise = 1.2, minTicks = 3, maxTicks = 7, weight = 1 },
	{ id = "fastFall", emoji = "📉", name = "Se hunde", drift = -0.03, noise = 1.2, minTicks = 3, maxTicks = 7, weight = 1 },
	{ id = "chaotic", emoji = "🌀", name = "Caótica", drift = 0, noise = 3.0, minTicks = 5, maxTicks = 12, weight = 1 },
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
