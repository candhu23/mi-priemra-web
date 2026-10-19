"""Cartera SIMULADA: dinero de mentira, con comisiones y deslizamiento como en un exchange real.

Solo compra y vende al contado (spot): no hay apalancamiento ni ventas en corto, así
nunca se puede perder más de lo que se ha puesto.
"""
from __future__ import annotations

from dataclasses import asdict, dataclass


@dataclass
class Posicion:
	simbolo: str
	cantidad: float
	precio_entrada: float     # precio pagado (ya con deslizamiento)
	coste: float              # USDT gastados, comisión incluida
	comision: float
	tiempo_entrada: int       # ms
	stop: float | None
	objetivo: float | None
	maximo: float             # cierre más alto desde la compra (para el trailing stop)
	stop_tipo: str = "stop loss"
	motivo: str = ""


@dataclass
class Operacion:
	simbolo: str
	tiempo_entrada: int
	tiempo_salida: int
	precio_entrada: float
	precio_salida: float
	cantidad: float
	coste: float
	ingreso: float
	beneficio: float          # ingreso - coste (comisiones incluidas)
	porcentaje: float
	comisiones: float
	motivo_entrada: str
	motivo_salida: str


class Cartera:
	def __init__(self, capital: float, comision_pct: float = 0.1, deslizamiento_pct: float = 0.05,
			orden_minima: float = 10.0) -> None:
		self.capital_inicial = float(capital)
		self.efectivo = float(capital)
		self.com = comision_pct / 100.0
		self.desl = deslizamiento_pct / 100.0
		self.orden_minima = float(orden_minima)
		self.posiciones: dict[str, Posicion] = {}
		self.operaciones: list[Operacion] = []
		self.comisiones = 0.0

	def valor(self, precios: dict[str, float]) -> float:
		"""Efectivo + lo que valen ahora las monedas compradas."""
		return self.efectivo + sum(p.cantidad * precios.get(s, p.precio_entrada) for s, p in self.posiciones.items())

	def comprar(self, simbolo: str, importe: float, precio: float, tiempo: int,
			stop_frac: float | None = None, objetivo_frac: float | None = None, motivo: str = "") -> Posicion | None:
		if simbolo in self.posiciones or precio <= 0:
			return None
		importe = min(float(importe), self.efectivo)
		if importe <= 0 or importe < self.orden_minima:
			return None
		precio_ej = precio * (1 + self.desl)
		comision = importe * self.com
		cantidad = (importe - comision) / precio_ej
		self.efectivo -= importe
		if abs(self.efectivo) < 1e-9:
			self.efectivo = 0.0
		self.comisiones += comision
		stop = precio_ej * (1 - stop_frac) if stop_frac and 0 < stop_frac < 1 else None
		objetivo = precio_ej * (1 + objetivo_frac) if objetivo_frac and objetivo_frac > 0 else None
		pos = Posicion(simbolo, cantidad, precio_ej, importe, comision, int(tiempo), stop, objetivo, precio_ej,
			"stop loss", motivo)
		self.posiciones[simbolo] = pos
		return pos

	def vender(self, simbolo: str, precio: float, tiempo: int, motivo: str) -> Operacion | None:
		pos = self.posiciones.pop(simbolo, None)
		if pos is None:
			return None
		precio_ej = precio * (1 - self.desl)
		bruto = pos.cantidad * precio_ej
		comision = bruto * self.com
		ingreso = bruto - comision
		self.efectivo += ingreso
		self.comisiones += comision
		op = Operacion(simbolo, pos.tiempo_entrada, int(tiempo), pos.precio_entrada, precio_ej, pos.cantidad,
			pos.coste, ingreso, ingreso - pos.coste, (ingreso / pos.coste - 1) * 100, pos.comision + comision,
			pos.motivo, motivo)
		self.operaciones.append(op)
		return op

	# ------------------------------------------------------------ guardar / cargar
	def a_dict(self) -> dict:
		return {
			"capital_inicial": self.capital_inicial, "efectivo": self.efectivo, "comisiones": self.comisiones,
			"posiciones": [asdict(p) for p in self.posiciones.values()],
			"operaciones": [asdict(o) for o in self.operaciones],
		}

	def cargar_dict(self, d: dict) -> None:
		self.capital_inicial = float(d["capital_inicial"])
		self.efectivo = float(d["efectivo"])
		self.comisiones = float(d.get("comisiones", 0.0))
		self.posiciones = {p["simbolo"]: Posicion(**p) for p in d.get("posiciones", [])}
		self.operaciones = [Operacion(**o) for o in d.get("operaciones", [])]
