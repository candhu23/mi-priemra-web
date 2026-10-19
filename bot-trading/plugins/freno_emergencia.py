"""Riesgo 5 · Freno de emergencia: para de comprar cuando las cosas van mal."""
from nucleo import formato as F
from nucleo.config import P
from nucleo.plugins import Plugin

DIA_MS = 86_400_000


class FrenoEmergencia(Plugin):
	nombre = "freno_emergencia"
	orden = 12
	titulo = "Freno de emergencia"
	tipo = "riesgo"
	descripcion = ("Deja de comprar si: se pierde más de un % en el día, la cartera cae más de un % desde su máximo "
		"(y entonces vende todo y descansa unos días), hay varias pérdidas seguidas o se hacen demasiadas "
		"operaciones en un día. Evita que una mala racha se convierta en un desastre.")
	activo_por_defecto = True
	parametros = {
		"perdida_diaria_max": P(5.0, float, 0.5, 100, "% de pérdida en un día que para las compras hasta mañana"),
		"caida_maxima": P(20.0, float, 1, 100, "% de caída desde el máximo que activa el freno fuerte"),
		"vender_todo_en_caida": P(True, bool, ayuda="Al activarse el freno fuerte, vender lo que haya"),
		"dias_pausa_tras_caida": P(7, int, 0, 365),
		"perdidas_seguidas_max": P(4, int, 1, 100),
		"velas_pausa_tras_perdidas": P(12, int, 0, 10000),
		"operaciones_dia_max": P(10, int, 1, 1000),
	}

	def __init__(self, ajustes, entorno):
		super().__init__(ajustes, entorno)
		self.pico = None
		self.dia = None
		self.valor_inicio_dia = None
		self.pausa_hasta = 0
		self.motivo_pausa = ""
		self.seguidas = 0
		self.ops_hoy = 0
		self.vender = []

	def _pausar(self, ahora, hasta, motivo):
		if hasta > self.pausa_hasta:
			self.pausa_hasta = hasta
			self.motivo_pausa = motivo
			self.entorno.avisar(f"Freno de emergencia: {motivo}. No compro hasta {F.fecha(hasta)}.", "aviso", ahora)

	def en_cada_vela(self, ctx):
		valor = ctx.valor_total()
		dia = ctx.tiempo // DIA_MS
		if dia != self.dia:
			self.dia = dia
			self.valor_inicio_dia = valor
			self.ops_hoy = 0
		if self.pico is None or valor > self.pico:
			self.pico = valor
		if ctx.tiempo < self.pausa_hasta:
			return
		if self.valor_inicio_dia and (1 - valor / self.valor_inicio_dia) * 100 >= self.a["perdida_diaria_max"]:
			self._pausar(ctx.tiempo, (dia + 1) * DIA_MS, f"pérdida de más del {F.num(self.a['perdida_diaria_max'], 1)} % hoy")
		if self.pico and (1 - valor / self.pico) * 100 >= self.a["caida_maxima"]:
			self._pausar(ctx.tiempo, ctx.tiempo + self.a["dias_pausa_tras_caida"] * DIA_MS,
				f"la cartera ha caído más del {F.num(self.a['caida_maxima'], 1)} % desde su máximo")
			if self.a["vender_todo_en_caida"]:
				self.vender = list(ctx.motor.cartera.posiciones)
			self.pico = valor   # tras la pausa se mide desde aquí

	def forzar_salida(self, ctx, posicion):
		if ctx.simbolo in self.vender:
			self.vender.remove(ctx.simbolo)
			return "freno de emergencia (caída máxima)"
		return None

	def permitir_entrada(self, ctx):
		if ctx.tiempo < self.pausa_hasta:
			return False, self.motivo_pausa or "pausa"
		if self.ops_hoy >= self.a["operaciones_dia_max"]:
			return False, "límite de operaciones del día"
		return True

	def al_abrir(self, posicion):
		self.ops_hoy += 1

	def al_cerrar(self, op):
		if op.beneficio < 0:
			self.seguidas += 1
			if self.seguidas >= self.a["perdidas_seguidas_max"]:
				self.seguidas = 0
				pausa = self.a["velas_pausa_tras_perdidas"] * self.entorno.ajustes.intervalo_ms
				if pausa > 0:
					self._pausar(op.tiempo_salida, op.tiempo_salida + pausa, f"{self.a['perdidas_seguidas_max']} pérdidas seguidas")
		else:
			self.seguidas = 0

	def guardar_estado(self):
		return {k: getattr(self, k) for k in ("pico", "dia", "valor_inicio_dia", "pausa_hasta", "motivo_pausa",
			"seguidas", "ops_hoy", "vender")}

	def cargar_estado(self, datos):
		for k, v in datos.items():
			if hasattr(self, k):
				setattr(self, k, v)
