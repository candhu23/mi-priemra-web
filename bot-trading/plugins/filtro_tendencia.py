"""Filtro 1 · Tendencia de fondo: no comprar si el mercado va a la baja."""
from nucleo.config import P
from nucleo.plugins import Plugin


class FiltroTendencia(Plugin):
	nombre = "filtro_tendencia"
	orden = 5
	titulo = "Filtro de tendencia"
	tipo = "filtro"
	descripcion = ("Solo deja comprar si el precio está por encima de su media larga (por defecto 200 velas), "
		"es decir, si la tendencia de fondo es alcista. Evita muchas compras en mercados que caen.")
	activo_por_defecto = True
	parametros = {
		"periodo": P(200, int, 10, 1000, "Velas de la media larga"),
		"exigir_pendiente": P(False, bool, ayuda="Exigir además que la media esté subiendo"),
		"velas_pendiente": P(10, int, 1, 200, "Con cuántas velas atrás se compara la pendiente"),
	}

	def permitir_entrada(self, ctx):
		media = ctx.ind.ema(self.a["periodo"])
		if media is None:
			return False, "aún no hay velas suficientes"
		if ctx.precio <= media:
			return False, "el precio está por debajo de la media larga"
		if self.a["exigir_pendiente"]:
			antes = ctx.ind.ema(self.a["periodo"], atras=self.a["velas_pendiente"])
			if antes is None or media <= antes:
				return False, "la media larga no está subiendo"
		return True
