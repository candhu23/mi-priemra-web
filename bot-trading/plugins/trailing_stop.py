"""Riesgo 4 · Trailing stop: el stop sube con el precio para asegurar ganancias."""
from nucleo.config import P
from nucleo.plugins import Plugin


class TrailingStop(Plugin):
	nombre = "trailing_stop"
	orden = 11
	titulo = "Trailing stop"
	tipo = "riesgo"
	descripcion = ("Cuando el precio sube, el stop sube detrás a X veces el movimiento normal (ATR) por debajo del "
		"cierre más alto. Nunca baja. Deja correr las ganancias y vende cuando la subida se da la vuelta.")
	activo_por_defecto = True
	parametros = {
		"multiplicador_atr": P(3.0, float, 0.5, 20),
		"periodo_atr": P(14, int, 2, 200),
		"activar_tras_ganancia": P(0.0, float, 0, 100, "% de ganancia a partir del cual empieza a subir"),
	}

	def actualizar_stop(self, ctx, posicion):
		ganancia = (posicion.maximo / posicion.precio_entrada - 1) * 100
		if ganancia < self.a["activar_tras_ganancia"]:
			return None
		atr = ctx.ind.atr(self.a["periodo_atr"])
		if atr is None:
			return None
		return posicion.maximo - self.a["multiplicador_atr"] * atr
