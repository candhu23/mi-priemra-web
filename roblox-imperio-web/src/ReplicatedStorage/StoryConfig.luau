--[[
	StoryConfig (ModuleScript en ReplicatedStorage)

	Modo Historia «Del garaje al imperio» (v4): 5 capítulos × 6 misiones
	guiadas por la mentora Ada. Las misiones van en orden; cada una se
	cumple sola (el servidor mira value(d) >= target cada segundo), da su
	premio y Ada presenta la siguiente. Al acabar un capítulo hay un premio
	especial y una vuelta de cámara alrededor de tu rascacielos.

	Campos de cada misión:
	  · id       = nombre corto (único)
	  · text     = lo que hay que hacer (se ve en la tarjeta de misión)
	  · say      = lo que dice Ada al presentarla
	  · hint     = dónde se hace
	  · value(d) = progreso con los datos de la partida; target = meta
	  · feature  = parte del juego que hace falta (si aún está cerrada, la
	    tarjeta dice en qué planta se abre)
	  · reward   = { minutes, min } en minutos de ingresos (como las misiones)
	Los primeros 3 capítulos ocupan los primeros 30-45 minutos.
]]

local Story = {}

Story.MENTOR = "Ada"
Story.MENTOR_EMOJI = "👩‍💻"

local function count(t: any): number
	local n = 0
	for _ in t or {} do
		n += 1
	end
	return n
end

local function companyLevels(d): number
	local n = 0
	for _, level in d.companies or {} do
		n += level
	end
	return n
end

local function built(typeId: string)
	return function(d): number
		return (d.stats and d.stats.byType and d.stats.byType[typeId]) or 0
	end
end

local function careerStat(field: string)
	return function(d): number
		return (d.career and d.career.stats and d.career.stats[field]) or 0
	end
end

local function rareEntries(d): number
	local n = 0
	for _, row in d.collection or {} do
		for variant in row do
			if variant ~= "normal" then
				n += 1
			end
		end
	end
	return n
end

local function collectionEntries(d): number
	local n = 0
	for _, row in d.collection or {} do
		n += count(row)
	end
	return n
end

local function maxSeo(d): number
	local best = 0
	for _, site in d.sites or {} do
		best = math.max(best, site.seo or 0)
	end
	return best
end

-- Plantas del rascacielos (la fórmula está en TycoonConfig; aquí se copia
-- para no depender de él)
local function floors(d): number
	return math.clamp(1 + math.floor(2.6 * math.log10(1 + math.max(d.lifetimeEarned or 0, 0) / 100)), 1, 40)
end

Story.Chapters = {
	{
		id = "garaje", emoji = "🚗", name = "El garaje",
		intro = "¡Hola! Soy Ada, tu mentora. Todo gran imperio empieza en un garaje con un ordenador viejo. Vamos a programar tu primera web.",
		outro = "¡Ya tienes un pequeño negocio! El garaje se te queda pequeño: es hora de montar una startup.",
		reward = { kind = "boost", minutes = 10 },
		missions = {
			{ id = "g1", text = "Programa tu primera web", say = "Abre el ordenador, elige la Landing Page y pulsa PROGRAMAR hasta terminarla.",
				hint = "💻 Ordenador → 🛠️ Producción → 🖥️ Crear", value = function(d) return d.stats.built or 0 end, target = 1,
				reward = { minutes = 1, min = 60 } },
			{ id = "g2", text = "Ten 3 webs a la vez", say = "Cada web gana dinero sola con sus visitas. ¡Cuantas más, mejor!",
				hint = "🖥️ Crear", value = function(d) return #(d.sites or {}) end, target = 3,
				reward = { minutes = 1.5, min = 100 } },
			{ id = "g3", text = "Mejora el SEO de una web", say = "El SEO hace que el buscador te encuentre: más visitas, más dinero.",
				hint = "🌐 Webs → 🔍 Abrir → 🔎 Mejorar SEO", value = maxSeo, target = 1,
				reward = { minutes = 1.5, min = 120 } },
			{ id = "g4", text = "Vende una web a una empresa", say = "Las empresas pagan bien por webs con visitas. Acepta una oferta: la venta tarda un poco.",
				hint = "💼 Negocio → 🤝 Clientes", value = function(d) return d.stats.sold or 0 end, target = 1, feature = "clients",
				reward = { minutes = 2, min = 200 } },
			{ id = "g5", text = "Programa un Blog", say = "Con ⭐ 6 de reputación ya puedes hacer un Blog: tiene muchas más visitas.",
				hint = "🖥️ Crear → ✍️ Blog", value = built("blog"), target = 1,
				reward = { minutes = 2, min = 250 } },
			{ id = "g6", text = "Gana $1K en total", say = "Deja que tus webs trabajen. ¡Tu primer millar está cerca!",
				hint = "Ten varias webs y deja que ganen dinero", value = function(d) return d.lifetimeEarned or 0 end, target = 1000,
				reward = { minutes = 2, min = 300 } },
		},
	},
	{
		id = "startup", emoji = "🚀", name = "La startup",
		intro = "Bienvenido a tu startup. Ahora toca ganar más con cada visita y montar tus primeras empresas.",
		outro = "¡Tu startup ya es una empresa de verdad! Las grandes compañías empiezan a fijarse en ti.",
		reward = { kind = "ticket", ticket = "premium", amount = 1 },
		missions = {
			{ id = "s1", text = "Desbloquea una segunda app de anuncios", say = "ClickBoom paga casi el doble por visita. ¡Ponla en tus webs!",
				hint = "🛠️ Producción → 📢 Anuncios", value = function(d) return count(d.unlockedAds) end, target = 2, feature = "ads",
				reward = { minutes = 2, min = 400 } },
			{ id = "s2", text = "Funda tu primera empresa", say = "El Equipo de Programadores programa por ti aunque no hagas clic.",
				hint = "💼 Negocio → 🏢 Empresas", value = companyLevels, target = 1, feature = "companies",
				reward = { minutes = 2, min = 500 } },
			{ id = "s3", text = "Compra ☁️ Hosting Nube", say = "Con Hosting tienes más huecos para webs a la vez.",
				hint = "🏢 Empresas → ☁️ Hosting Nube", value = function(d) return (d.companies or {}).hosting or 0 end, target = 1, feature = "companies",
				reward = { minutes = 2.5, min = 700 } },
			{ id = "s4", text = "Programa una Tienda Online", say = "Las tiendas online tienen el triple de visitas que un Blog. Necesitas ⭐ 59.",
				hint = "🖥️ Crear → 🛒 Tienda Online", value = built("tienda"), target = 1,
				reward = { minutes = 3, min = 900 } },
			{ id = "s5", text = "Vende 5 webs", say = "Cada venta te deja un contrato de mantenimiento que paga para siempre.",
				hint = "🤝 Clientes", value = function(d) return d.stats.sold or 0 end, target = 5, feature = "clients",
				reward = { minutes = 3, min = 1000 } },
			{ id = "s6", text = "Gana $10K en total", say = "¡Diez mil! Vas muy bien. Sigue mejorando tus webs y empresas.",
				hint = "Ten varias webs y deja que ganen dinero", value = function(d) return d.lifetimeEarned or 0 end, target = 1e4,
				reward = { minutes = 3, min = 1200 } },
		},
	},
	{
		id = "empresa", emoji = "🏢", name = "La empresa",
		intro = "Ahora eres una empresa. Las compañías te harán encargos y podrás montar tu propia agencia de programadores.",
		outro = "¡Tienes agencia y equipo! Es hora de pensar en grande: la corporación.",
		reward = { kind = "ticket", ticket = "legendary", amount = 1 },
		missions = {
			{ id = "e1", text = "Entrega tu primer encargo", say = "Acepta un encargo, pulsa «Programar ahora» y cuando termines la web se entrega sola. ¡Pagan mucho!",
				hint = "💼 Negocio → 💼 Carrera", value = careerStat("contracts"), target = 1, feature = "career",
				reward = { minutes = 3, min = 1500 } },
			{ id = "e2", text = "Suma 10 niveles de empresas", say = "Cada empresa sube tus ingresos para siempre. ¡Mira los hitos de nivel 10!",
				hint = "🏢 Empresas", value = companyLevels, target = 10, feature = "companies",
				reward = { minutes = 3, min = 2000 } },
			{ id = "e3", text = "Consigue una web rara", say = "A veces una web sale ✨ Brillante o mejor: ¡muchas más visitas!",
				hint = "Sigue programando webs", value = rareEntries, target = 1,
				reward = { minutes = 3, min = 2500 } },
			{ id = "e4", text = "Llega a nivel de programador 8", say = "Programar y entregar encargos te sube de nivel. Con nivel 8 puedes fundar tu agencia.",
				hint = "💼 Carrera", value = careerStat("devLevel"), target = 8, feature = "career",
				reward = { minutes = 3, min = 3000 } },
			{ id = "e5", text = "Funda tu agencia", say = "Tu agencia ficha programadores que trabajan para ti y te dan dinero extra.",
				hint = "💼 Negocio → 👥 Agencia", value = function(d) return if d.career and d.career.agency then 1 else 0 end, target = 1, feature = "agency",
				reward = { minutes = 4, min = 4000 } },
			{ id = "e6", text = "Ficha a tu primer programador", say = "Entrevista candidatos: cuanto más raro, más aporta. ¡Las probabilidades están a la vista!",
				hint = "👥 Agencia → 🎲 Entrevistar", value = function(d) return #((d.career and d.career.programmers) or {}) end, target = 1, feature = "agency",
				reward = { minutes = 4, min = 5000 } },
		},
	},
	{
		id = "corporacion", emoji = "🏙️", name = "La corporación",
		intro = "Tu corporación ya cotiza en la Bolsa de Ciudad Web. Invierte con cabeza y prepara la gran salida a bolsa.",
		outro = "¡Has ganado tu primer millón en una partida! Ya puedes salir a bolsa y empezar el imperio.",
		reward = { kind = "boost", minutes = 30 },
		missions = {
			{ id = "c1", text = "Gana $100K en total", say = "Cien mil. Con esto se abre la Bolsa de Ciudad Web.",
				hint = "Mejora tus webs y empresas", value = function(d) return d.lifetimeEarned or 0 end, target = 1e5,
				reward = { minutes = 4, min = 6000 } },
			{ id = "c2", text = "Programa un Periódico Digital", say = "Los periódicos digitales tienen tres veces más visitas que una tienda.",
				hint = "🖥️ Crear → 📰 Periódico Digital", value = built("noticias"), target = 1,
				reward = { minutes = 4, min = 8000 } },
			{ id = "c3", text = "Ten 3 programadores", say = "Un equipo completo (una de cada especialidad) da un bonus extra.",
				hint = "👥 Agencia", value = function(d) return #((d.career and d.career.programmers) or {}) end, target = 3, feature = "agency",
				reward = { minutes = 4, min = 10000 } },
			{ id = "c4", text = "Invierte en la Bolsa", say = "Compra acciones cuando estén baratas. El analista da pistas, pero no siempre acierta.",
				hint = "📈 Inversión → 📈 Bolsa", value = function(d) return if count(d.portfolio) > 0 or ((d.stats and d.stats.marketProfit) or 0) > 0 then 1 else 0 end,
				target = 1, feature = "market", reward = { minutes = 4, min = 12000 } },
			{ id = "c5", text = "Llega al rango Senior", say = "Los encargos te suben de rango: más encargos a la vez y mejor pagados.",
				hint = "💼 Carrera", value = careerStat("rank"), target = 3, feature = "career",
				reward = { minutes = 5, min = 15000 } },
			{ id = "c6", text = "Gana $1M en esta partida", say = "Con un millón ganado en la partida puedes salir a bolsa.",
				hint = "📈 Inversión → 🔔 Salir a bolsa", value = function(d) return d.totalEarned or 0 end, target = 1e6,
				reward = { minutes = 5, min = 20000 } },
		},
	},
	{
		id = "imperio", emoji = "👑", name = "El imperio",
		intro = "Saliendo a bolsa empiezas de cero, pero cada acción te da más dinero para siempre. Así se construye un imperio.",
		outro = "¡Lo has conseguido: tienes un imperio digital! A partir de aquí, el límite es el cielo.",
		reward = { kind = "patents", amount = 5 },
		missions = {
			{ id = "i1", text = "Sal a bolsa por primera vez", say = "Pierdes dinero, webs y empresas, pero ganas acciones y patentes para siempre.",
				hint = "📈 Inversión → 🔔 Salir a bolsa", value = function(d) return d.ipoCount or 0 end, target = 1, feature = "market",
				reward = { minutes = 5, min = 25000 } },
			{ id = "i2", text = "Compra una mejora de I+D", say = "Las patentes compran mejoras que no se pierden nunca.",
				hint = "📈 Inversión → 💡 I+D", value = function(d)
					local n = 0
					for _, level in d.research or {} do
						n += level
					end
					return n
				end, target = 1, feature = "market", reward = { minutes = 5, min = 30000 } },
			{ id = "i3", text = "Programa una Red Social", say = "Una red social: millones de usuarios hablando de tus webs.",
				hint = "🖥️ Crear → 💬 Red Social", value = built("red_social"), target = 1,
				reward = { minutes = 6, min = 40000 } },
			{ id = "i4", text = "Llega a la planta 15 de tu rascacielos", say = "Tu rascacielos crece con todo lo que ganas. ¡Que se vea desde toda la ciudad!",
				hint = "Sigue ganando dinero", value = floors, target = 15,
				reward = { minutes = 6, min = 50000 } },
			{ id = "i5", text = "Llena 12 casillas de la colección", say = "Cada combinación de web y rareza da dinero extra para siempre.",
				hint = "🎯 Progreso → 📖 Colección", value = collectionEntries, target = 12, feature = "collection",
				reward = { minutes = 6, min = 60000 } },
			{ id = "i6", text = "Sal a bolsa 2 veces", say = "La segunda salida a bolsa es mucho más rápida. ¡Demuéstralo!",
				hint = "📈 Inversión → 🔔 Salir a bolsa", value = function(d) return d.ipoCount or 0 end, target = 2, feature = "market",
				reward = { minutes = 8, min = 80000 } },
		},
	},
}

Story.MISSIONS_PER_CHAPTER = 6
Story.TOTAL = 0
for _, chapter in Story.Chapters do
	Story.TOTAL += #chapter.missions
end

-- Misión actual (nil si la historia ya está terminada)
function Story.current(story: any): (any?, any?)
	if not story or story.done then
		return nil, nil
	end
	local chapter = Story.Chapters[story.chapter]
	if not chapter then
		return nil, nil
	end
	return chapter.missions[story.mission], chapter
end

-- Número de paso (1..TOTAL) de una misión (para la analítica)
function Story.stepIndex(chapterIndex: number, missionIndex: number): number
	local n = 0
	for i = 1, chapterIndex - 1 do
		n += #Story.Chapters[i].missions
	end
	return n + missionIndex
end

return Story
