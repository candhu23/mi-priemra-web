"""Estrategia 3 · Bandas de Bollinger (rebote en la banda inferior)."""
from nucleo.config import P
from nucleo.plugins import Plugin


class Bollinger(Plugin):
	nombre = "bollinger"
	orden = 3
	titulo = "Bandas de Bollinger"
	tipo = "estrategia"
	descripcion = ("Compra cuando el precio vuelve a entrar por la banda inferior (rebote tras una caída exagerada) "
		"y vende cuando llega a la banda superior. Pensada para mercados de lado.")
	parametros = {
		"periodo": P(20, int, 5, 500, "Velas de la media central"),
		"desviaciones": P(2.0, float, 0.5, 5, "Anchura de las bandas"),
	}

	def senal(self, ctx):
		p, k = self.a["periodo"], self.a["desviaciones"]
		antes, ahora = ctx.ind.bollinger(p, k, atras=1), ctx.ind.bollinger(p, k)
		c_antes, c_ahora = ctx.ind.cierre(1), ctx.ind.cierre()
		if antes is None or ahora is None or c_antes is None:
			return None
		if c_antes < antes[2] and c_ahora >= ahora[2]:
			return "comprar"
		if c_antes < antes[1] and c_ahora >= ahora[1]:
			return "vender"
		return None
