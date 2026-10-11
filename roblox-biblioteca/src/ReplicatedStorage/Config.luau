--!strict
-- Todos los números del juego. Lo que lleva «(supuesto)» no se sabe del juego en que se inspira:
-- es una decisión nuestra y está explicada en DISENO.md. Cambiar aquí cambia el juego entero.

local Config = {}

Config.VERSION = "0.9.1" -- juego completo + tienda, pendiente de probar en Studio (1.0 al publicar)
-- Nombre del juego (fácil de cambiar): no usar el nombre del juego original
Config.GAME_NAME = { es = "Estanterías Hechizadas", en = "Spellbound Shelves" }

-- Totales que el código comprueba con assert (BookData y Layout)
Config.TOTAL_SERIES = 400
Config.TOTAL_BOOKS = 3072

---------------------------------------------------------------------
-- Personaje y manos
---------------------------------------------------------------------
Config.WALK_SPEED = 12 -- (supuesto)
Config.RUN_SPEED = 22 -- (supuesto) con la llave verde, manteniendo Mayús
Config.JUMP_HEIGHT = 10 -- (supuesto) salto alto con la llave roja (normal de Roblox: 7,2)
Config.CAPACITY = 10 -- libros en mano al empezar
Config.CAPACITY_BONUS = { yellow = 3, blue = 2 } -- 10 → 15
Config.REACH = 10 -- alcance de la cruceta (studs)
Config.REACH_SLACK = 6 -- margen extra que acepta el servidor (lag, cámara por encima de la cadera)
Config.KEY_REACH = 4.5 -- las llaves se cogen de cerca (por eso algunas exigen saltar)
Config.AIM_SECTION_RANGE = 40 -- Autocolocar: distancia máxima a la sección apuntada
Config.HOLD_DROP_ALL = 0.45 -- segundos manteniendo R para soltar toda la pila
Config.ACTIONS_PER_SECOND = 25

-- Lanzar (parábola calculada en el servidor; el cliente solo la anima)
Config.THROW_SPEED = 34
Config.THROW_UP = 10
Config.THROW_GRAVITY = 70
Config.THROW_MAX_TIME = 4

---------------------------------------------------------------------
-- Puntos (por RÉCORD de filas correctas, no por cada fila rehecha)
-- (supuesto) filas 1–20 → 1 punto cada 2; 21–80 → cada 4; 81–200 → cada 6. Total 45.
---------------------------------------------------------------------
Config.POINT_TIERS = {
	{ upTo = 20, every = 2 },
	{ upTo = 80, every = 4 },
	{ upTo = 200, every = 6 },
}
Config.TOTAL_POINTS = 45

---------------------------------------------------------------------
-- Magia mayor (manual personal). Cada nivel cuesta 1 punto; el nivel 1 compra el hechizo.
-- Máximos sacados de las guías del original; los niveles intermedios son (supuesto) interpolados.
-- El enfriamiento empieza cuando el efecto termina (supuesto).
---------------------------------------------------------------------
export type Skill = {
	id: string,
	key: number, -- tecla 1–5
	max: number,
	cooldown: { number },
	duration: { number }?, -- segundos activo (si dura)
	count: { number }?, -- Reunir: libros que atrae
	range: { number }?, -- Revelar: alcance en studs
}
Config.Skills = {
	{ id = "sort", key = 1, max = 5, cooldown = { 30, 24, 18, 11, 5 } },
	{
		id = "guide", key = 2, max = 10,
		duration = { 15, 20, 25, 30, 35, 40, 45, 50, 55, 60 },
		cooldown = { 60, 54, 48, 42, 36, 29, 23, 17, 11, 5 },
	},
	{
		id = "reveal", key = 3, max = 10,
		duration = { 10, 13, 17, 20, 23, 27, 30, 33, 37, 40 },
		cooldown = { 60, 56, 51, 47, 42, 38, 33, 29, 24, 20 },
		range = { 25, 50, 75, 100, 125, 150, 175, 200, 225, 250 },
	},
	{
		id = "auto", key = 4, max = 10,
		duration = { 10, 15, 20, 25, 30, 35, 40, 45, 50, 55 },
		cooldown = { 120, 108, 96, 83, 71, 59, 47, 34, 22, 10 },
	},
	{
		id = "gather", key = 5, max = 10,
		count = { 1, 2, 3, 4, 5, 5, 6, 7, 8, 9 },
		cooldown = { 90, 81, 72, 63, 54, 46, 37, 28, 19, 10 },
	},
} :: { Skill }
Config.SkillById = {} :: { [string]: Skill }
for _, s in Config.Skills do
	Config.SkillById[s.id] = s
end

---------------------------------------------------------------------
-- Magia menor: 4 llaves → 4 cofres
---------------------------------------------------------------------
Config.KEYS = { "red", "green", "yellow", "blue" }
Config.ChestReward = { red = "jump", green = "run", yellow = "cap3", blue = "cap2" }

-- Cristal de recuperación (no cuenta como magia)
Config.CRYSTAL_MAX = 20

---------------------------------------------------------------------
-- Final, rangos y fase especial
---------------------------------------------------------------------
Config.PIZZA_TIME = 3 * 3600 -- (supuesto) final Pizza: todo bien en menos de 3 h de juego
-- (supuesto) rangos 1–6 (ver Rules.rank):
--   1 ¡Despedido! = 0 filas correctas · 2 = menos del 50 % · 3 = menos del 100 %
--   con 400/400: 6 si tiempo ≤ 3 h o (sin magia y ≤ 8 h) · 5 si tiempo ≤ 6 h o sin magia · 4 si no
Config.RANK_TIME_TOP = 3 * 3600
Config.RANK_TIME_TOP_NOMAGIC = 8 * 3600
Config.RANK_TIME_GOOD = 6 * 3600

Config.ULTIMATE_CHARGE = 600 -- (supuesto) 10 min para cargar la definitiva (tecla Z)
Config.ULTIMATE_PER_BOOK = 4 -- (supuesto) segundos extra por cada libro colocado

---------------------------------------------------------------------
-- Guardado (agrupado para respetar los límites de DataStore)
---------------------------------------------------------------------
Config.SLOTS = 3
Config.SAVE_MIN_INTERVAL = 30 -- como mucho una escritura cada 30 s (más al salir)
Config.SAVE_EVERY_BOOKS = 50 -- disparador del original: cada 50 libros colocados
Config.SAVE_IDLE_INTERVAL = 120 -- y cada 2 min si solo ha corrido el tiempo

---------------------------------------------------------------------
-- Luz: la tarde cae según el tiempo de juego (se congela en modo acogedor)
---------------------------------------------------------------------
Config.LIGHT_START = 15.5 -- media tarde
Config.LIGHT_END = 21.5 -- noche cerrada
Config.LIGHT_HOURS = 3 -- a las 3 h de juego ya es de noche («horas extra»)

---------------------------------------------------------------------
-- Audio. Solo audio con licencia: de la Creator Store de Roblox o los sonidos que trae Roblox
-- (rbxasset://). "" = sin sonido. Música por tramos según el % de filas correctas.
-- Si en Studio sale «Failed to load sound» en Output, cambia ese sonido por "" o por un ID de la Creator Store.
---------------------------------------------------------------------
Config.Music = {
	{ from = 0, id = "" },
	{ from = 0.25, id = "" },
	{ from = 0.5, id = "" },
	{ from = 0.85, id = "" },
}
Config.Sounds = {
	pick = "rbxasset://sounds/clickfast.wav",
	place = "rbxasset://sounds/clickfast.wav",
	thud = "rbxasset://sounds/action_jump_land.mp3",
	throw = "rbxasset://sounds/swordlunge.wav",
	row = "rbxasset://sounds/electronicpingshort.wav",
	plate = "rbxasset://sounds/electronicpingshort.wav",
	ui = "rbxasset://sounds/button.wav",
}

---------------------------------------------------------------------
-- Insignias (12 logros). 0 = desactivada (el logro se guarda igual en la partida).
---------------------------------------------------------------------
Config.Achievements = {
	"first_row", "rows_50", "rows_200", "rows_400", "first_spell", "all_spells",
	"chests", "spells_max", "ultimate", "fired", "pizza", "nomagic",
}
Config.Badges = {
	first_row = 0, rows_50 = 0, rows_200 = 0, rows_400 = 0, first_spell = 0, all_spells = 0,
	chests = 0, spells_max = 0, ultimate = 0, fired = 0, pizza = 0, nomagic = 0,
} :: { [string]: number }

---------------------------------------------------------------------
-- Tienda (fase 7). SOLO cosas decorativas o de apoyo: nada hace el juego más fácil ni es aleatorio.
-- id = 0 → no aparece en el juego publicado (en Studio se enseña como «Muestra» para probarlo).
-- Precios en Robux: recomendación (supuesto); el precio real lo pones al crear el pase en el Creator Hub.
---------------------------------------------------------------------
export type ShopItem = { key: string, id: number, price: number }
Config.GamePasses = {
	{ key = "patron", id = 0, price = 99 }, -- Mecenas: brillo de otro color (verde o violeta)
	{ key = "pet", id = 0, price = 149 }, -- Garabato, el gato alado, vuela a tu lado
	{ key = "themes", id = 0, price = 79 }, -- Temas de luz: noche estrellada y otoño
} :: { ShopItem }
Config.Products = {
	{ key = "tip_s", id = 0, price = 25 }, -- Propina: un café para la rectora
	{ key = "tip_l", id = 0, price = 100 }, -- Propina grande: pizza para todo el claustro
} :: { ShopItem }
Config.GLOW_COLORS = {
	gold = Color3.fromRGB(255, 196, 60),
	green = Color3.fromRGB(70, 235, 140),
	violet = Color3.fromRGB(190, 120, 255),
} :: { [string]: Color3 }
Config.THEMES = { "normal", "stars", "autumn" }

return Config
