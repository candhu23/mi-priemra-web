"""Riesgo 1 · Tamaño de la posición: arriesgar siempre un % pequeño del capital."""
from nucleo.config import P
from nucleo.plugins import Plugin


class TamanoPosicion(Plugin):
	nombre = "tamano_posicion"
	orden = 8
	titulo = "Tamaño de posición"
	tipo = "riesgo"
	descripcion = ("Calcula cuánto comprar para que, si salta el stop loss, solo se pierda un % fijo del capital "
		"(por defecto el 1 %). Con stop cercano compra más; con stop lejano, menos. Es la regla que más "
		"protege la cuenta.")
	activo_por_defecto = True
	parametros = {
		"riesgo_por_operacion": P(1.0, float, 0.1, 10, "% del capital que se puede perder en una operación"),
		"sin_stop": P(10.0, float, 1, 100, "% del capital a invertir si no hay stop loss"),
	}

	def tamano(self, ctx, precio, stop):
		valor = ctx.valor_total()
		if stop is None or stop >= precio:
			return valor * self.a["sin_stop"] / 100
		distancia = (precio - stop) / precio
		return valor * (self.a["riesgo_por_operacion"] / 100) / distancia
