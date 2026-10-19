"""Velas e indicadores técnicos, calculados paso a paso.

Las velas se añaden de una en una (igual en la prueba con el pasado que en vivo), así un
plugin NUNCA puede ver el futuro: solo existe lo que ya ha pasado.
Cada indicador guarda su serie y solo calcula las velas nuevas (rápido aunque haya miles).
"""
from __future__ import annotations

import math


class Velas:
	__slots__ = ("t", "apertura", "maximo", "minimo", "cierre", "volumen")

	def __init__(self) -> None:
		self.t: list[int] = []
		self.apertura: list[float] = []
		self.maximo: list[float] = []
		self.minimo: list[float] = []
		self.cierre: list[float] = []
		self.volumen: list[float] = []

	def agregar(self, v) -> bool:
		"""Añade una vela cerrada. Ignora repetidas o más antiguas que la última."""
		if self.t and v.t <= self.t[-1]:
			return False
		self.t.append(v.t)
		self.apertura.append(v.apertura)
		self.maximo.append(v.maximo)
		self.minimo.append(v.minimo)
		self.cierre.append(v.cierre)
		self.volumen.append(v.volumen)
		return True

	def __len__(self) -> int:
		return len(self.t)


class _EmaInc:
	"""Media exponencial que recibe valores de uno en uno (empieza con la media simple)."""

	def __init__(self, periodo: int) -> None:
		self.p = periodo
		self.k = 2.0 / (periodo + 1)
		self.n = 0
		self.suma = 0.0
		self.valor: float | None = None

	def agregar(self, x: float | None) -> float | None:
		if x is None:
			return None
		if self.valor is None:
			self.n += 1
			self.suma += x
			if self.n == self.p:
				self.valor = self.suma / self.p
			return self.valor
		self.valor = x * self.k + self.valor * (1 - self.k)
		return self.valor


class _Calc:
	def __init__(self) -> None:
		self.valores: list = []

	def actualizar(self, v: Velas) -> None:
		for i in range(len(self.valores), len(v)):
			self.valores.append(self.paso(v, i))

	def paso(self, v: Velas, i: int):  # pragma: no cover - se redefine
		raise NotImplementedError


class EMA(_Calc):
	def __init__(self, periodo: int, campo: str = "cierre") -> None:
		super().__init__()
		self.e = _EmaInc(periodo)
		self.campo = campo

	def paso(self, v, i):
		return self.e.agregar(getattr(v, self.campo)[i])


class SMA(_Calc):
	def __init__(self, periodo: int, campo: str = "cierre") -> None:
		super().__init__()
		self.p = periodo
		self.campo = campo

	def paso(self, v, i):
		if i < self.p - 1:
			return None
		serie = getattr(v, self.campo)
		return math.fsum(serie[i - self.p + 1:i + 1]) / self.p


class RSI(_Calc):
	"""RSI de Wilder (el estándar de TradingView y Binance)."""

	def __init__(self, periodo: int) -> None:
		super().__init__()
		self.p = periodo
		self.sg = self.sp = 0.0
		self.ag: float | None = None
		self.ap: float | None = None

	def paso(self, v, i):
		if i == 0:
			return None
		d = v.cierre[i] - v.cierre[i - 1]
		g, l = (d, 0.0) if d > 0 else (0.0, -d)
		if self.ag is None:
			self.sg += g
			self.sp += l
			if i < self.p:
				return None
			self.ag, self.ap = self.sg / self.p, self.sp / self.p
		else:
			self.ag = (self.ag * (self.p - 1) + g) / self.p
			self.ap = (self.ap * (self.p - 1) + l) / self.p
		if self.ap == 0:
			return 100.0 if self.ag > 0 else 50.0
		return 100.0 - 100.0 / (1.0 + self.ag / self.ap)


class ATR(_Calc):
	"""Rango verdadero medio de Wilder: cuánto se mueve el precio normalmente."""

	def __init__(self, periodo: int) -> None:
		super().__init__()
		self.p = periodo
		self.suma = 0.0
		self.valor: float | None = None

	def paso(self, v, i):
		h, l = v.maximo[i], v.minimo[i]
		tr = h - l if i == 0 else max(h - l, abs(h - v.cierre[i - 1]), abs(l - v.cierre[i - 1]))
		if self.valor is None:
			self.suma += tr
			if i < self.p - 1:
				return None
			self.valor = self.suma / self.p
			return self.valor
		self.valor = (self.valor * (self.p - 1) + tr) / self.p
		return self.valor


class Bollinger(_Calc):
	def __init__(self, periodo: int, desv: float) -> None:
		super().__init__()
		self.p = periodo
		self.k = desv

	def paso(self, v, i):
		if i < self.p - 1:
			return None
		ventana = v.cierre[i - self.p + 1:i + 1]
		media = math.fsum(ventana) / self.p
		std = math.sqrt(math.fsum((x - media) ** 2 for x in ventana) / self.p)
		return (media, media + self.k * std, media - self.k * std)


class MACD(_Calc):
	def __init__(self, rapida: int, lenta: int, senal: int) -> None:
		super().__init__()
		self.r = _EmaInc(rapida)
		self.l = _EmaInc(lenta)
		self.s = _EmaInc(senal)

	def paso(self, v, i):
		x = v.cierre[i]
		r, l = self.r.agregar(x), self.l.agregar(x)
		if r is None or l is None:
			return None
		m = r - l
		s = self.s.agregar(m)
		if s is None:
			return None
		return (m, s, m - s)


class Indicadores:
	"""Acceso cómodo para los plugins: ctx.ind.ema(20), ctx.ind.rsi(14, atras=1)…

	`atras=0` es la última vela cerrada, `atras=1` la anterior. Devuelve None si aún no hay
	velas suficientes para calcularlo.
	"""

	def __init__(self, velas: Velas) -> None:
		self.v = velas
		self._cache: dict[tuple, _Calc] = {}

	def _valor(self, clave: tuple, fabrica, atras: int):
		c = self._cache.get(clave)
		if c is None:
			c = fabrica()
			self._cache[clave] = c
		c.actualizar(self.v)
		idx = len(self.v) - 1 - atras
		if idx < 0 or atras < 0:
			return None
		return c.valores[idx]

	def ema(self, periodo: int, atras: int = 0):
		return self._valor(("ema", periodo), lambda: EMA(periodo), atras)

	def sma(self, periodo: int, atras: int = 0):
		return self._valor(("sma", periodo), lambda: SMA(periodo), atras)

	def rsi(self, periodo: int = 14, atras: int = 0):
		return self._valor(("rsi", periodo), lambda: RSI(periodo), atras)

	def atr(self, periodo: int = 14, atras: int = 0):
		return self._valor(("atr", periodo), lambda: ATR(periodo), atras)

	def bollinger(self, periodo: int = 20, desv: float = 2.0, atras: int = 0):
		"""(media, banda superior, banda inferior)"""
		return self._valor(("bb", periodo, desv), lambda: Bollinger(periodo, desv), atras)

	def macd(self, rapida: int = 12, lenta: int = 26, senal: int = 9, atras: int = 0):
		"""(línea MACD, línea de señal, histograma)"""
		return self._valor(("macd", rapida, lenta, senal), lambda: MACD(rapida, lenta, senal), atras)

	def volumen_medio(self, periodo: int = 20, atras: int = 0):
		return self._valor(("vol", periodo), lambda: SMA(periodo, "volumen"), atras)

	def cierre(self, atras: int = 0):
		idx = len(self.v) - 1 - atras
		return self.v.cierre[idx] if 0 <= idx < len(self.v) else None

	def volumen(self, atras: int = 0):
		idx = len(self.v) - 1 - atras
		return self.v.volumen[idx] if 0 <= idx < len(self.v) else None


def cruza_arriba(a_antes, a_ahora, b_antes, b_ahora) -> bool:
	"""True si la serie A pasa de estar por debajo (o igual) de B a estar por encima."""
	if None in (a_antes, a_ahora, b_antes, b_ahora):
		return False
	return a_antes <= b_antes and a_ahora > b_ahora


def cruza_abajo(a_antes, a_ahora, b_antes, b_ahora) -> bool:
	if None in (a_antes, a_ahora, b_antes, b_ahora):
		return False
	return a_antes >= b_antes and a_ahora < b_ahora
