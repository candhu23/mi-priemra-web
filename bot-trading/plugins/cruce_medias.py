"""Estrategia 1 · Cruce de medias (seguir la tendencia)."""
from nucleo.config import ErrorAjustes, P
from nucleo.indicadores import cruza_abajo, cruza_arriba
from nucleo.plugins import Plugin


class CruceMedias(Plugin):
	nombre = "cruce_medias"
	orden = 1
	titulo = "Cruce de medias"
	tipo = "estrategia"
	descripcion = ("Compra cuando la media rápida cruza hacia arriba la media lenta (suele empezar una subida) "
		"y vende cuando la cruza hacia abajo. Funciona bien con tendencias claras y mal con el precio de lado.")
	activo_por_defecto = True
	parametros = {
		"rapida": P(12, int, 2, 500, "Velas de la media rápida"),
		"lenta": P(26, int, 3, 1000, "Velas de la media lenta"),
	}

	def validar(self):
		if self.a["rapida"] >= self.a["lenta"]:
			raise ErrorAjustes("En [plugins.cruce_medias], 'rapida' tiene que ser menor que 'lenta'")

	def senal(self, ctx):
		r, l = self.a["rapida"], self.a["lenta"]
		r_antes, r_ahora = ctx.ind.ema(r, atras=1), ctx.ind.ema(r)
		l_antes, l_ahora = ctx.ind.ema(l, atras=1), ctx.ind.ema(l)
		if cruza_arriba(r_antes, r_ahora, l_antes, l_ahora):
			return "comprar"
		if cruza_abajo(r_antes, r_ahora, l_antes, l_ahora):
			return "vender"
		return None
