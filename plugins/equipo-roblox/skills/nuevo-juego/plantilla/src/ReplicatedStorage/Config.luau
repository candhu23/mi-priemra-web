--[[
	Config: TODOS los números del juego (economía, tienda, colores) y las fórmulas que usan
	servidor y cliente. Para equilibrar el juego se toca solo este archivo.
]]

local Config = {}

Config.VERSION = "0.1"
Config.GROUP_ID = 0 -- grupo de Roblox para el +10 % (0 = desactivado)

---------------------------------------------------------------------
-- Economía base (bucle principal: pulsar → comprar generadores → ganar solo)
---------------------------------------------------------------------
Config.START_MONEY = 0
Config.CLICK_BASE = 1
Config.OFFLINE_RATE = 0.5 -- 50 % de lo que habrías ganado
Config.OFFLINE_MAX_HOURS = 8

export type Generator = { id: string, emoji: string, base: number, income: number, growth: number }
Config.Generators = {
	{ id = "lemonade", emoji = "🍋", base = 15, income = 0.5, growth = 1.15 },
	{ id = "foodtruck", emoji = "🚚", base = 200, income = 4, growth = 1.15 },
	{ id = "shop", emoji = "🏪", base = 2_500, income = 35, growth = 1.15 },
	{ id = "factory", emoji = "🏭", base = 30_000, income = 300, growth = 1.15 },
} :: { Generator }
Config.GeneratorById = {} :: { [string]: Generator }
for _, g in Config.Generators do
	Config.GeneratorById[g.id] = g
end

Config.ClickUpgrade = { base = 50, growth = 1.8, max = 25 } -- cada nivel: +1 por clic y x1,15

-- Recompensa diaria (racha de 7): minutos de ingresos, con un mínimo fijo
Config.Daily = { { 5, 100 }, { 10, 250 }, { 15, 500 }, { 20, 1_000 }, { 30, 2_000 }, { 45, 4_000 }, { 60, 10_000 } }

---------------------------------------------------------------------
-- Tienda (Robux). id = 0 → no se vende (sale «Próximamente»). price = precio recomendado
---------------------------------------------------------------------
export type ShopItem = { key: string, id: number, emoji: string, price: number }
Config.GamePasses = {
	{ key = "x2", id = 0, emoji = "💰", price = 199 }, -- dinero x2 para siempre
	{ key = "auto", id = 0, emoji = "🤖", price = 149 }, -- clic automático 2/s
} :: { ShopItem }
Config.Products = {
	{ key = "cash_s", id = 0, emoji = "💵", price = 25 },
	{ key = "cash_l", id = 0, emoji = "🏦", price = 99 },
} :: { ShopItem }
Config.CashMinutes = { cash_s = 15, cash_l = 90 } :: { [string]: number }
Config.CASH_MIN = 500

---------------------------------------------------------------------
-- Colores (tokens de diseño: úsalos siempre, no pongas colores sueltos)
---------------------------------------------------------------------
Config.Colors = {
	ink = Color3.fromRGB(30, 41, 59), -- texto principal sobre claro
	muted = Color3.fromRGB(100, 116, 139),
	white = Color3.fromRGB(255, 255, 255),
	panel = Color3.fromRGB(248, 250, 252),
	panelDark = Color3.fromRGB(226, 232, 240),
	sky = Color3.fromRGB(56, 189, 248),
	orange = Color3.fromRGB(249, 115, 22),
	orangeDark = Color3.fromRGB(194, 65, 12),
	blue = Color3.fromRGB(59, 130, 246),
	blueDark = Color3.fromRGB(29, 78, 216),
	green = Color3.fromRGB(34, 197, 94),
	greenDark = Color3.fromRGB(21, 128, 61),
	gold = Color3.fromRGB(250, 204, 21),
	goldDark = Color3.fromRGB(202, 138, 4),
	red = Color3.fromRGB(239, 68, 68),
	redDark = Color3.fromRGB(185, 28, 28),
	grey = Color3.fromRGB(148, 163, 184),
	greyDark = Color3.fromRGB(100, 116, 139),
}

---------------------------------------------------------------------
-- Fórmulas (iguales en servidor y cliente)
-- bonuses = { x2: boolean, auto: boolean, boost: boolean, friends: number, premium: boolean }
---------------------------------------------------------------------
function Config.genCost(id: string, owned: number): number
	local g = Config.GeneratorById[id]
	return math.floor(g.base * g.growth ^ owned)
end

function Config.moneyMult(bonuses: any): number
	local m = 1
	if bonuses.x2 then
		m *= 2
	end
	if bonuses.boost then
		m *= 2
	end
	m *= 1 + 0.1 * math.min(bonuses.friends or 0, 4)
	if bonuses.premium then
		m *= 1.1
	end
	return m
end

function Config.incomePerSec(data: any, bonuses: any): number
	local total = 0
	for _, g in Config.Generators do
		total += (data.generators[g.id] or 0) * g.income
	end
	return total * Config.moneyMult(bonuses)
end

function Config.clickValue(data: any, bonuses: any): number
	local lvl = data.clickLevel or 0
	return (Config.CLICK_BASE + lvl) * 1.15 ^ lvl * Config.moneyMult(bonuses)
end

function Config.clickUpgradeCost(level: number): number
	return math.floor(Config.ClickUpgrade.base * Config.ClickUpgrade.growth ^ level)
end

function Config.dailyReward(day: number, incomePerSec: number): number
	local d = Config.Daily[math.clamp(day, 1, #Config.Daily)]
	return math.max(d[2], math.floor(incomePerSec * 60 * d[1]))
end

return Config
