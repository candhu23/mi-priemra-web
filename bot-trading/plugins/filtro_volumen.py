"""Filtro 3 · Volumen: que haya gente detrás del movimiento."""
from nucleo.config import P
from nucleo.plugins import Plugin


class FiltroVolumen(Plugin):
	nombre = "filtro_volumen"
	orden = 7
	titulo = "Filtro de volumen"
	tipo = "filtro"
	descripcion = ("Solo compra si en la vela de la señal se negoció más de lo normal (volumen por encima de su media). "
		"Una señal con poco volumen suele ser una falsa alarma.")
	parametros = {
		"periodo": P(20, int, 2, 500, "Velas de la media de volumen"),
		"factor": P(1.2, float, 0.1, 20, "Volumen mínimo = factor × media"),
	}

	def permitir_entrada(self, ctx):
		media = ctx.ind.volumen_medio(self.a["periodo"], atras=1)
		vol = ctx.ind.volumen()
		if media is None or vol is None:
			return False, "aún no hay velas suficientes"
		if vol < self.a["factor"] * media:
			return False, "poco volumen en la señal"
		return True
