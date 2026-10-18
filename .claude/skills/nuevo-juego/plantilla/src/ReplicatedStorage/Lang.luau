--[[
	Lang: todos los textos en español e inglés. Lang.t(lang, clave, { param = valor }) con {param}.
	Regla: el servidor manda CLAVES (nunca textos) y el cliente las traduce.
	tools/check.sh comprueba que cada clave existe en los dos idiomas.
]]

local Lang = {}

Lang.es = {
	game_title = "{{NOMBRE}}",
	money = "Dinero",
	per_sec = "{value}/s",
	tap = "¡TOCA!",
	tap_hint = "Toca para ganar dinero",
	generators = "Negocios",
	buy = "Comprar",
	owned = "x{n}",
	income_each = "+{value}/s c/u",
	click_upgrade = "Mejor clic",
	click_level = "Nivel {n}",
	shop = "Tienda",
	daily = "Diario",
	close = "Cerrar",
	soon = "Próximamente",
	passes = "Pases (para siempre)",
	products = "Ayudas",
	gen_lemonade = "Puesto de limonada",
	gen_foodtruck = "Food truck",
	gen_shop = "Tienda de barrio",
	gen_factory = "Fábrica",
	pass_x2 = "Dinero x2",
	pass_x2_desc = "Ganas el doble para siempre",
	pass_auto = "Clic automático",
	pass_auto_desc = "Pulsa solo 2 veces por segundo",
	prod_cash_s = "Maletín",
	prod_cash_s_desc = "15 min de ingresos",
	prod_cash_l = "Caja fuerte",
	prod_cash_l_desc = "90 min de ingresos",
	daily_title = "Recompensa diaria",
	daily_day = "Día {n}",
	daily_claim = "Recoger",
	daily_done = "Vuelve mañana",
	welcome_back = "¡Has ganado {value} mientras no estabas!",
	n_bought = "¡Comprado: {item}!",
	n_no_money = "No tienes dinero suficiente",
	n_daily = "¡+{value} de recompensa diaria!",
	n_purchase = "¡Gracias por tu compra!",
	n_no_save = "⚠️ Sin guardado: publica el juego y activa API Services",
	n_too_fast = "Más despacio",
	settings_lang = "Idioma",
}

Lang.en = {
	game_title = "{{NOMBRE_EN}}",
	money = "Money",
	per_sec = "{value}/s",
	tap = "TAP!",
	tap_hint = "Tap to earn money",
	generators = "Businesses",
	buy = "Buy",
	owned = "x{n}",
	income_each = "+{value}/s each",
	click_upgrade = "Better tap",
	click_level = "Level {n}",
	shop = "Shop",
	daily = "Daily",
	close = "Close",
	soon = "Coming soon",
	passes = "Passes (forever)",
	products = "Boosts",
	gen_lemonade = "Lemonade stand",
	gen_foodtruck = "Food truck",
	gen_shop = "Corner shop",
	gen_factory = "Factory",
	pass_x2 = "x2 Money",
	pass_x2_desc = "Earn double, forever",
	pass_auto = "Auto Tap",
	pass_auto_desc = "Taps for you twice a second",
	prod_cash_s = "Briefcase",
	prod_cash_s_desc = "15 min of income",
	prod_cash_l = "Vault",
	prod_cash_l_desc = "90 min of income",
	daily_title = "Daily reward",
	daily_day = "Day {n}",
	daily_claim = "Claim",
	daily_done = "Come back tomorrow",
	welcome_back = "You earned {value} while you were away!",
	n_bought = "Bought: {item}!",
	n_no_money = "Not enough money",
	n_daily = "+{value} daily reward!",
	n_purchase = "Thanks for your purchase!",
	n_no_save = "⚠️ Not saving: publish the game and enable API Services",
	n_too_fast = "Slow down",
	settings_lang = "Language",
}

-- "es-es", "es-mx"… → "es"; el resto → "en"
function Lang.detect(localeId: string?): string
	if localeId and string.sub(string.lower(localeId), 1, 2) == "es" then
		return "es"
	end
	return "en"
end

function Lang.t(lang: string, key: string, params: { [string]: any }?): string
	local tabla = (Lang :: any)[lang] or Lang.en
	local text = tabla[key] or Lang.en[key] or key
	if params then
		text = string.gsub(text, "{(%w+)}", function(name)
			local v = params[name]
			return if v ~= nil then tostring(v) else "{" .. name .. "}"
		end)
	end
	return text
end

return Lang
