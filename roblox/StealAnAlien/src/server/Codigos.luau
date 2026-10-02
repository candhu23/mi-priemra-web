--!strict
--[[
	CÓDIGOS PROMOCIONALES
	Publícalos en TikTok, YouTube, Discord o en la descripción del juego.
	Cada jugador puede canjear cada código una sola vez.

	Campos:
	  dinero      = cantidad fija
	  segundos    = X segundos de los ingresos del jugador (se escala solo)
	  boostMinutos= minutos de x2 ingresos
	  caduca      = os.time() en el que deja de funcionar (opcional). Ejemplo para
	                el 1 de enero de 2027 a las 00:00 UTC: 1798761600
	Los códigos no distinguen mayúsculas/minúsculas.
]]

export type Codigo = { dinero: number?, segundos: number?, boostMinutos: number?, caduca: number? }

local Codigos: { [string]: Codigo } = {
	RELEASE = { dinero = 1000, segundos = 120 },
	ALIENS = { boostMinutos = 10 },
}

return Codigos
