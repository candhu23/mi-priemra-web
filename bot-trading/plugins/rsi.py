"""Estrategia 2 · RSI (comprar barato tras una caída fuerte)."""
from nucleo.config import ErrorAjustes, P
from nucleo.plugins import Plugin


class RSI(Plugin):
	nombre = "rsi"
	orden = 2
	titulo = "RSI (sobreventa)"
	tipo = "estrategia"
	descripcion = ("Compra cuando el RSI sale de la zona de sobreventa (el precio cayó mucho y empieza a rebotar) "
		"y vende cuando entra en sobrecompra. Funciona mejor con el precio de lado que en tendencias fuertes.")
	parametros = {
		"periodo": P(14, int, 2, 200, "Velas para calcular el RSI"),
		"sobreventa": P(30.0, float, 1, 99, "Por debajo de esto se considera 'barato'"),
		"sobrecompra": P(70.0, float, 1, 99, "Por encima de esto se considera 'caro'"),
	}

	def validar(self):
		if self.a["sobreventa"] >= self.a["sobrecompra"]:
			raise ErrorAjustes("En [plugins.rsi], 'sobreventa' tiene que ser menor que 'sobrecompra'")

	def senal(self, ctx):
		antes, ahora = ctx.ind.rsi(self.a["periodo"], atras=1), ctx.ind.rsi(self.a["periodo"])
		if antes is None or ahora is None:
			return None
		if antes < self.a["sobreventa"] <= ahora:
			return "comprar"
		if antes < self.a["sobrecompra"] <= ahora:
			return "vender"
		return None
