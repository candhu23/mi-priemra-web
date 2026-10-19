"""El corazón del bot. Lo usan IGUAL la prueba con el pasado (backtest) y la simulación en vivo.

Con cada vela cerrada de una moneda:
  1. Avisa a todos los plugins (en_cada_vela).
  2. Pregunta a las estrategias si ven compra o venta (cada señal "dura" `memoria_senales` velas).
  3. Si hay posición: sube el trailing stop, mira salidas forzadas y señales de venta.
     Si no hay: junta las señales de compra y pasa por filtros, frenos, stop, objetivo y tamaño.
  4. Deja una ORDEN PENDIENTE. Se ejecuta en la apertura de la vela siguiente (backtest) o
     al precio actual (vivo). Así nunca se compra a un precio que aún no se conocía.
"""
from __future__ import annotations

from collections import Counter
from dataclasses import asdict, dataclass

from . import formato as F
from .indicadores import Indicadores, Velas
from .plugins import sobrescribe

_FALLO = object()


@dataclass
class Orden:
	tipo: str                       # "comprar" | "vender"
	motivo: str
	importe: float = 0.0
	stop_frac: float | None = None
	objetivo_frac: float | None = None


class Contexto:
	"""Lo que ve un plugin en cada vela."""
	__slots__ = ("motor", "simbolo", "velas", "ind", "posicion", "precio", "tiempo", "modo")

	def __init__(self, motor: "Motor", simbolo: str) -> None:
		self.motor = motor
		self.simbolo = simbolo
		self.velas: Velas = motor.series[simbolo]
		self.ind: Indicadores = motor.ind[simbolo]
		self.posicion = motor.cartera.posiciones.get(simbolo)
		self.precio: float = self.velas.cierre[-1]
		self.tiempo: int = self.velas.t[-1] + motor.intervalo_ms   # hora de CIERRE de la vela
		self.modo: str = motor.entorno.modo

	@property
	def intervalo_ms(self) -> int:
		return self.motor.intervalo_ms

	def valor_total(self) -> float:
		return self.motor.valor_total()

	def efectivo_libre(self) -> float:
		return self.motor.efectivo_libre()


class Motor:
	def __init__(self, entorno, plugins: list, cartera) -> None:
		self.entorno = entorno
		self.cfg = entorno.ajustes.general
		self.cartera = cartera
		self.plugins = plugins
		self.intervalo_ms = entorno.ajustes.intervalo_ms
		self.estrategias = [p for p in plugins if sobrescribe(p, "senal")]
		self._con = {g: [p for p in plugins if sobrescribe(p, g)] for g in (
			"en_cada_vela", "permitir_entrada", "stop_inicial", "objetivo_inicial", "tamano",
			"actualizar_stop", "forzar_salida", "al_abrir", "al_cerrar")}
		self.series: dict[str, Velas] = {}
		self.ind: dict[str, Indicadores] = {}
		self.memoria: dict[str, dict[str, tuple[str, int]]] = {}
		for s in entorno.ajustes.monedas:
			self.preparar_moneda(s)
		self.pendientes: dict[str, Orden] = {}
		self.ultimo_precio: dict[str, float] = {}
		self.curva: list[tuple[int, float, float | None]] = []   # (ms, valor, referencia)
		self.bloqueos: Counter = Counter()
		self.decisiones: list[tuple[int, str, str, str]] = []

	def preparar_moneda(self, s: str) -> None:
		if s not in self.series:
			self.series[s] = Velas()
			self.ind[s] = Indicadores(self.series[s])
			self.memoria[s] = {}

	# ------------------------------------------------------------ utilidades
	def _llamar(self, plugin, gancho: str, *args):
		try:
			return getattr(plugin, gancho)(*args)
		except Exception as e:
			if self.entorno.estricto:
				raise
			self.entorno.avisar(f"El plugin '{plugin.nombre}' ha fallado ({gancho}): {e}", "error")
			return _FALLO

	def valor_total(self) -> float:
		return self.cartera.valor(self.ultimo_precio)

	def efectivo_libre(self) -> float:
		reservado = sum(o.importe for o in self.pendientes.values() if o.tipo == "comprar")
		return max(0.0, self.cartera.efectivo - reservado)

	def _bloquear(self, motivo: str) -> None:
		self.bloqueos[motivo] += 1

	def _decision(self, tiempo: int, s: str, accion: str, motivo: str) -> None:
		self.decisiones.append((tiempo, s, accion, motivo))
		if len(self.decisiones) > 5000:
			del self.decisiones[:1000]

	@staticmethod
	def _consenso(votos: int, total: int, modo: str) -> bool:
		if votos <= 0 or total <= 0:
			return False
		if modo == "todas":
			return votos >= total
		if modo == "mayoria":
			return votos * 2 > total
		return True

	# ------------------------------------------------------------ velas y decisiones
	def agregar_vela(self, s: str, vela, decidir: bool = True) -> bool:
		if not self.series[s].agregar(vela):
			return False
		self.ultimo_precio[s] = vela.cierre
		pos = self.cartera.posiciones.get(s)
		if pos is not None and vela.cierre > pos.maximo:
			pos.maximo = vela.cierre
		if decidir:
			self._decidir(s)
		return True

	def _decidir(self, s: str) -> None:
		ctx = Contexto(self, s)
		for p in self._con["en_cada_vela"]:
			self._llamar(p, "en_cada_vela", ctx)
		mem = self.memoria[s]
		t_vela = ctx.velas.t[-1]
		for p in self.estrategias:
			r = self._llamar(p, "senal", ctx)
			if r in ("comprar", "vender"):
				mem[p.nombre] = (r, t_vela)
		ventana = self.cfg["memoria_senales"] * self.intervalo_ms
		compras = sorted(n for n, (r, t) in mem.items() if r == "comprar" and t_vela - t < ventana)
		ventas = sorted(n for n, (r, t) in mem.items() if r == "vender" and t_vela - t < ventana)
		if s in self.pendientes:
			return
		ctx.posicion = self.cartera.posiciones.get(s)
		if ctx.posicion is not None:
			self._gestionar(ctx, ventas)
		else:
			self._buscar_entrada(ctx, compras, ventas)

	def _gestionar(self, ctx: Contexto, ventas: list[str]) -> None:
		pos = ctx.posicion
		for p in self._con["actualizar_stop"]:
			nuevo = self._llamar(p, "actualizar_stop", ctx, pos)
			if isinstance(nuevo, (int, float)) and nuevo > 0 and (pos.stop is None or nuevo > pos.stop):
				pos.stop = float(nuevo)
				pos.stop_tipo = "trailing stop"
		motivo = None
		for p in self._con["forzar_salida"]:
			m = self._llamar(p, "forzar_salida", ctx, pos)
			if m and m is not _FALLO:
				motivo = str(m)
				break
		if motivo is None and self._consenso(len(ventas), len(self.estrategias), self.cfg["modo_salida"]):
			motivo = "señal de venta: " + ", ".join(ventas)
		if motivo:
			self.pendientes[ctx.simbolo] = Orden("vender", motivo)
			self._decision(ctx.tiempo, ctx.simbolo, "vender", motivo)

	def _buscar_entrada(self, ctx: Contexto, compras: list[str], ventas: list[str]) -> None:
		if len(compras) <= len(ventas) or not self._consenso(len(compras), len(self.estrategias), self.cfg["modo_entrada"]):
			return
		s = ctx.simbolo
		abiertas = len(self.cartera.posiciones) + sum(1 for o in self.pendientes.values() if o.tipo == "comprar")
		if abiertas >= self.cfg["max_posiciones"]:
			return self._bloquear("Máximo de posiciones abiertas")
		for p in self._con["permitir_entrada"]:
			r = self._llamar(p, "permitir_entrada", ctx)
			if r is _FALLO:
				return self._bloquear(f"{p.titulo}: error del plugin")
			ok, razon = (r[0], r[1] if len(r) > 1 else "") if isinstance(r, tuple) else (bool(r), "")
			if not ok:
				return self._bloquear(f"{p.titulo}: {razon}" if razon else p.titulo)
		precio = ctx.precio
		stops = []
		for p in self._con["stop_inicial"]:
			r = self._llamar(p, "stop_inicial", ctx, precio)
			if r is _FALLO:
				return self._bloquear(f"{p.titulo}: error del plugin")
			if isinstance(r, (int, float)) and 0 < r < precio:
				stops.append(float(r))
		stop = max(stops) if stops else None          # el más ajustado
		objetivos = []
		for p in self._con["objetivo_inicial"]:
			r = self._llamar(p, "objetivo_inicial", ctx, precio, stop)
			if isinstance(r, (int, float)) and r > precio:
				objetivos.append(float(r))
		objetivo = min(objetivos) if objetivos else None
		valor = self.valor_total()
		tope = valor * self.cfg["max_por_operacion"] / 100.0
		importe = None
		for p in self._con["tamano"]:
			r = self._llamar(p, "tamano", ctx, precio, stop)
			if r is _FALLO:
				return self._bloquear(f"{p.titulo}: error del plugin")
			if isinstance(r, (int, float)) and r > 0:
				importe = float(r)
				break
		importe = min(tope if importe is None else importe, tope, self.efectivo_libre())
		if importe < max(self.cfg["orden_minima"], 0.01):
			return self._bloquear("No queda dinero libre suficiente")
		motivo = "señal de compra: " + ", ".join(compras)
		self.pendientes[s] = Orden("comprar", motivo, importe,
			(precio - stop) / precio if stop else None,
			(objetivo - precio) / precio if objetivo else None)
		self._decision(ctx.tiempo, s, "comprar", motivo)

	# ------------------------------------------------------------ ejecución
	def ejecutar_pendiente(self, s: str, precio: float, tiempo: int):
		o = self.pendientes.pop(s, None)
		if o is None:
			return None
		if o.tipo == "vender":
			return self.cerrar(s, precio, tiempo, o.motivo)
		pos = self.cartera.comprar(s, o.importe, precio, tiempo, o.stop_frac, o.objetivo_frac, o.motivo)
		if pos is None:
			return None
		self.memoria[s].clear()   # la señal ya se ha usado
		if self.entorno.modo == "vivo":
			extra = f", stop {F.precio(pos.stop)}" if pos.stop else ""
			self.entorno.log(f"COMPRA (simulada) {s}: {F.num(pos.coste)} a {F.precio(pos.precio_entrada)}{extra} · {o.motivo}")
		for p in self._con["al_abrir"]:
			self._llamar(p, "al_abrir", pos)
		return pos

	def cerrar(self, s: str, precio: float, tiempo: int, motivo: str):
		op = self.cartera.vender(s, precio, tiempo, motivo)
		if op is None:
			return None
		self.pendientes.pop(s, None)
		self.memoria.setdefault(s, {}).clear()   # evita volver a entrar con una señal vieja
		if self.entorno.modo == "vivo":
			self.entorno.log(f"VENTA (simulada) {s} a {F.precio(op.precio_salida)}: {F.num(op.beneficio)} "
				f"({F.pct(op.porcentaje)}) · {motivo}")
		for p in self._con["al_cerrar"]:
			self._llamar(p, "al_cerrar", op)
		return op

	def revisar_stops_vela(self, s: str, vela):
		"""Backtest: ¿la vela tocó el stop o el objetivo? Si tocó los dos, se asume lo peor (stop)."""
		pos = self.cartera.posiciones.get(s)
		if pos is None:
			return None
		if pos.stop is not None and vela.minimo <= pos.stop:
			precio = vela.apertura if vela.apertura < pos.stop else pos.stop   # hueco: sale a la apertura
			return self.cerrar(s, precio, vela.t, pos.stop_tipo)
		if pos.objetivo is not None and vela.maximo >= pos.objetivo:
			precio = vela.apertura if vela.apertura > pos.objetivo else pos.objetivo
			return self.cerrar(s, precio, vela.t, "take profit")
		return None

	def revisar_stops_precio(self, s: str, precio: float, tiempo: int):
		"""Vivo: compara el precio actual con el stop y el objetivo."""
		pos = self.cartera.posiciones.get(s)
		if pos is None:
			return None
		if pos.stop is not None and precio <= pos.stop:
			return self.cerrar(s, precio, tiempo, pos.stop_tipo)
		if pos.objetivo is not None and precio >= pos.objetivo:
			return self.cerrar(s, precio, tiempo, "take profit")
		return None

	def anotar_valor(self, tiempo: int, referencia: float | None = None) -> None:
		self.curva.append((int(tiempo), round(self.valor_total(), 6), None if referencia is None else round(referencia, 6)))

	# ------------------------------------------------------------ guardar / cargar
	def a_dict(self) -> dict:
		return {
			"memoria": {s: {n: list(v) for n, v in m.items()} for s, m in self.memoria.items()},
			"pendientes": {s: asdict(o) for s, o in self.pendientes.items()},
			"curva": [list(x) for x in self.curva[-20000:]],
			"bloqueos": dict(self.bloqueos),
			"decisiones": [list(x) for x in self.decisiones[-1000:]],
		}

	def cargar_dict(self, d: dict) -> None:
		for s, m in d.get("memoria", {}).items():
			self.preparar_moneda(s)
			self.memoria[s] = {n: (v[0], int(v[1])) for n, v in m.items()}
		self.pendientes = {s: Orden(**o) for s, o in d.get("pendientes", {}).items()}
		self.curva = [(int(x[0]), float(x[1]), x[2]) for x in d.get("curva", [])]
		self.bloqueos = Counter(d.get("bloqueos", {}))
		self.decisiones = [tuple(x) for x in d.get("decisiones", [])]
