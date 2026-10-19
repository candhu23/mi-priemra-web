"""Filtro 2 · Volatilidad: ni mercado dormido ni mercado desbocado."""
from nucleo.config import ErrorAjustes, P
from nucleo.plugins import Plugin


class FiltroVolatilidad(Plugin):
	nombre = "filtro_volatilidad"
	orden = 6
	titulo = "Filtro de volatilidad"
	tipo = "filtro"
	descripcion = ("Mide cuánto se mueve el precio en cada vela (ATR en % del precio). No compra si se mueve "
		"tan poco que las comisiones se comen la ganancia, ni si se mueve tanto que es una ruleta.")
	activo_por_defecto = True
	parametros = {
		"periodo_atr": P(14, int, 2, 200),
		"minimo": P(0.3, float, 0, 50, "% mínimo de movimiento por vela"),
		"maximo": P(8.0, float, 0.1, 100, "% máximo de movimiento por vela"),
	}

	def validar(self):
		if self.a["minimo"] >= self.a["maximo"]:
			raise ErrorAjustes("En [plugins.filtro_volatilidad], 'minimo' tiene que ser menor que 'maximo'")

	def permitir_entrada(self, ctx):
		atr = ctx.ind.atr(self.a["periodo_atr"])
		if atr is None or ctx.precio <= 0:
			return False, "aún no hay velas suficientes"
		pct = atr / ctx.precio * 100
		if pct < self.a["minimo"]:
			return False, "el precio se mueve demasiado poco"
		if pct > self.a["maximo"]:
			return False, "el precio se mueve demasiado (riesgo alto)"
		return True
