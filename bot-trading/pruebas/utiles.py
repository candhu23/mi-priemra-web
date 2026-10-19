"""Ayudas para las pruebas: precios inventados (sin Internet) y una fuente de datos falsa."""
from __future__ import annotations

import math
import os
import random
import sys

AQUI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if AQUI not in sys.path:
	sys.path.insert(0, AQUI)

from nucleo.config import desde_dict  # noqa: E402
from nucleo.datos import ErrorDatos, Vela  # noqa: E402

PLUGINS = os.path.join(AQUI, "plugins")
H = 3_600_000
T0 = 1_700_000_000_000 // H * H
NOMBRES = ["cruce_medias", "rsi", "bollinger", "macd", "filtro_tendencia", "filtro_volatilidad", "filtro_volumen",
	"tamano_posicion", "stop_loss", "take_profit", "trailing_stop", "freno_emergencia", "diario", "informe", "telegram"]


def generar_velas(n: int, paso: int = H, precio: float = 100.0, semilla: int = 1, t0: int = T0) -> list[Vela]:
	"""Paseo aleatorio con tramos de subida, bajada y lateral (cada vela abre en el cierre anterior)."""
	rnd = random.Random(semilla)
	velas = []
	deriva = 0.0
	for k in range(n):
		if k % 120 == 0:
			deriva = rnd.choice([-0.003, -0.001, 0.0, 0.001, 0.003])
		vol = 0.012
		o = precio
		c = o * math.exp(deriva + vol * rnd.gauss(0, 1))
		h = max(o, c) * (1 + abs(rnd.gauss(0, vol / 2)))
		l = min(o, c) * (1 - abs(rnd.gauss(0, vol / 2)))
		v = 100 * (1 + abs(rnd.gauss(0, 1))) * (3 if rnd.random() < 0.1 else 1)
		velas.append(Vela(t0 + k * paso, o, h, l, c, v))
		precio = c
	return velas


def ajustes(general: dict | None = None, plugins: dict | None = None, backtest: dict | None = None,
		vivo: dict | None = None, secretos: dict | None = None):
	g = {"monedas": ["AAA/USDT", "BBB/USDT"], "intervalo": "1h", "velas_calentamiento": 250}
	g.update(general or {})
	return desde_dict({"general": g, "plugins": plugins or {}, "backtest": backtest or {}, "vivo": vivo or {}},
		secretos=secretos)


def todos_activos(**extra) -> dict:
	d = {n: {"activo": True} for n in NOMBRES}
	for k, v in extra.items():
		d.setdefault(k, {}).update(v)
	return d


def solo(*nombres, **extra) -> dict:
	"""Activa solo los plugins indicados (el resto apagados)."""
	d = {n: {"activo": n in nombres} for n in NOMBRES}
	for k, v in extra.items():
		d.setdefault(k, {}).update(v)
	return d


class FuenteFalsa:
	"""Imita a Binance con velas inventadas y un reloj que controlan las pruebas."""

	def __init__(self, datos: dict[str, list[Vela]], paso: int, ahora: int) -> None:
		self.datos = datos
		self.paso = paso
		self.ahora = ahora
		self.fallar = False
		self.peticiones = 0

	def sincronizar(self) -> None:
		pass

	def ahora_ms(self) -> int:
		return self.ahora

	def _comprobar(self):
		self.peticiones += 1
		if self.fallar:
			raise ErrorDatos("sin conexión (prueba)")

	def precio(self, s: str) -> float:
		self._comprobar()
		velas = self.datos[s]
		for v in velas:
			if v.t <= self.ahora < v.t + self.paso:
				f = (self.ahora - v.t) / self.paso
				return v.apertura + (v.cierre - v.apertura) * f
		return velas[-1].cierre

	def velas(self, s, intervalo, desde=None, hasta=None, limite=1000):
		self._comprobar()
		cerradas = [v for v in self.datos[s] if v.t + self.paso <= self.ahora
			and (desde is None or v.t >= desde) and (hasta is None or v.t <= hasta)]
		return cerradas[:limite] if desde is not None else cerradas[-limite:]

	def ultimas_velas(self, s, intervalo, n):
		return self.velas(s, intervalo, limite=n)
