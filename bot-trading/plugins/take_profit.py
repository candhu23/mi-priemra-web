"""Riesgo 3 · Take profit: recoger beneficios en un precio objetivo."""
from nucleo.config import P
from nucleo.plugins import Plugin


class TakeProfit(Plugin):
	nombre = "take_profit"
	orden = 10
	titulo = "Take profit"
	tipo = "riesgo"
	descripcion = ("Vende automáticamente al llegar a un objetivo. Modo 'ratio': gana X veces lo que se arriesga "
		"con el stop (2 = si arriesgas 3 %, el objetivo es +6 %). Modo 'porcentaje': un % fijo por encima.")
	parametros = {
		"modo": P("ratio", str, opciones=("ratio", "porcentaje")),
		"ratio": P(2.0, float, 0.2, 50),
		"porcentaje": P(10.0, float, 0.2, 1000),
	}

	def objetivo_inicial(self, ctx, precio, stop):
		if self.a["modo"] == "ratio" and stop is not None and stop < precio:
			return precio + self.a["ratio"] * (precio - stop)
		return precio * (1 + self.a["porcentaje"] / 100)
