"""Riesgo 2 · Stop loss: vender si la compra sale mal, antes de que duela."""
from nucleo.config import P
from nucleo.plugins import Plugin


class StopLoss(Plugin):
	nombre = "stop_loss"
	orden = 9
	titulo = "Stop loss"
	tipo = "riesgo"
	descripcion = ("Pone un precio de venta de emergencia al comprar. Modo 'atr': a X veces el movimiento normal "
		"del precio por debajo (se adapta a cada moneda). Modo 'porcentaje': un % fijo por debajo.")
	activo_por_defecto = True
	parametros = {
		"modo": P("atr", str, opciones=("atr", "porcentaje")),
		"multiplicador_atr": P(2.0, float, 0.5, 20),
		"periodo_atr": P(14, int, 2, 200),
		"porcentaje": P(5.0, float, 0.2, 90),
	}

	def stop_inicial(self, ctx, precio):
		if self.a["modo"] == "porcentaje":
			return precio * (1 - self.a["porcentaje"] / 100)
		atr = ctx.ind.atr(self.a["periodo_atr"])
		if atr is None:
			return precio * (1 - self.a["porcentaje"] / 100)
		stop = precio - self.a["multiplicador_atr"] * atr
		return stop if stop > 0 else None
