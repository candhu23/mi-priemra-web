"""Estrategia 4 · MACD (cambios de impulso)."""
from nucleo.config import ErrorAjustes, P
from nucleo.indicadores import cruza_abajo, cruza_arriba
from nucleo.plugins import Plugin


class MACD(Plugin):
	nombre = "macd"
	orden = 4
	titulo = "MACD"
	tipo = "estrategia"
	descripcion = ("Compra cuando la línea MACD cruza hacia arriba su línea de señal (el impulso gira al alza) "
		"y vende cuando la cruza hacia abajo. Opcional: comprar solo si el cruce ocurre por debajo de cero.")
	parametros = {
		"rapida": P(12, int, 2, 200),
		"lenta": P(26, int, 3, 500),
		"senal": P(9, int, 2, 200),
		"solo_bajo_cero": P(False, bool, ayuda="Comprar solo si el MACD está por debajo de 0"),
	}

	def validar(self):
		if self.a["rapida"] >= self.a["lenta"]:
			raise ErrorAjustes("En [plugins.macd], 'rapida' tiene que ser menor que 'lenta'")

	def senal(self, ctx):
		r, l, s = self.a["rapida"], self.a["lenta"], self.a["senal"]
		antes, ahora = ctx.ind.macd(r, l, s, atras=1), ctx.ind.macd(r, l, s)
		if antes is None or ahora is None:
			return None
		if cruza_arriba(antes[0], ahora[0], antes[1], ahora[1]):
			if self.a["solo_bajo_cero"] and ahora[0] >= 0:
				return None
			return "comprar"
		if cruza_abajo(antes[0], ahora[0], antes[1], ahora[1]):
			return "vender"
		return None
