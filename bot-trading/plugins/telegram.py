"""Info 3 · Avisos al móvil por Telegram (opcional; solo en la simulación en vivo)."""
import json
import urllib.parse
import urllib.request

from nucleo import formato as F
from nucleo.config import P
from nucleo.plugins import Plugin

DIA_MS = 86_400_000
API = "https://api.telegram.org/bot{token}/{metodo}"


def llamar_api(token, metodo, datos=None, timeout=10):
	"""Llama a la API de Telegram. Devuelve el JSON de respuesta (lanza excepción si falla)."""
	cuerpo = urllib.parse.urlencode(datos).encode() if datos else None
	req = urllib.request.Request(API.format(token=token, metodo=metodo), data=cuerpo,
		headers={"User-Agent": "BotTradingSimulado/1.0"})
	with urllib.request.urlopen(req, timeout=timeout) as r:
		res = json.loads(r.read().decode("utf-8"))
	if not res.get("ok"):
		raise RuntimeError(res.get("description", "Telegram ha rechazado el mensaje"))
	return res


class Telegram(Plugin):
	nombre = "telegram"
	orden = 15
	titulo = "Avisos por Telegram"
	tipo = "info"
	descripcion = ("Manda al móvil cada compra y venta simulada, los avisos importantes (frenos, errores, sin "
		"conexión) y un resumen diario. Hay que configurarlo una vez con la opción del menú.")
	activo_por_defecto = True
	parametros = {
		"avisar_compras": P(True, bool),
		"avisar_ventas": P(True, bool),
		"avisos_importantes": P(True, bool),
		"resumen_diario": P(True, bool),
	}
	enviar_api = staticmethod(llamar_api)   # se puede sustituir en las pruebas

	def __init__(self, ajustes, entorno):
		super().__init__(ajustes, entorno)
		self.token = entorno.secretos.get("telegram_token")
		self.chat = entorno.secretos.get("telegram_chat_id")
		self.fallos = 0
		self.dia = None

	def listo(self):
		return self.entorno.modo == "vivo" and bool(self.token and self.chat) and self.fallos < 5

	def enviar(self, texto):
		if not self.listo():
			return False
		try:
			self.enviar_api(self.token, "sendMessage", {"chat_id": self.chat, "text": texto[:4000]})
			self.fallos = 0
			return True
		except Exception as e:  # sin Internet, token mal… nunca debe parar el bot
			self.fallos += 1
			if self.fallos == 1 or self.fallos == 5:
				fin = " Dejo de intentarlo hasta que reinicies el bot." if self.fallos == 5 else ""
				self.entorno.log(f"Telegram no ha podido enviar el mensaje ({e}).{fin}", "aviso")
			return False

	def al_iniciar(self):
		if self.entorno.modo != "vivo":
			return
		if not (self.token and self.chat):
			self.entorno.log("Telegram sin configurar (es opcional: opción 'Configurar Telegram' del menú).")
			return
		aj = self.entorno.ajustes
		self.enviar(f"🤖 Bot SIMULADO en marcha (dinero de mentira)\nMonedas: {', '.join(aj.monedas)} · velas de {aj.intervalo}")

	def al_abrir(self, pos):
		if self.a["avisar_compras"]:
			stop = f"\nStop: {F.precio(pos.stop)}" if pos.stop else ""
			self.enviar(f"🟢 COMPRA simulada {pos.simbolo}\n{F.num(pos.coste)} {self.entorno.ajustes.cotizacion} a "
				f"{F.precio(pos.precio_entrada)}{stop}\nMotivo: {pos.motivo}")

	def al_cerrar(self, op):
		if self.a["avisar_ventas"]:
			icono = "✅" if op.beneficio > 0 else "🔴"
			self.enviar(f"{icono} VENTA simulada {op.simbolo} a {F.precio(op.precio_salida)}\n"
				f"Resultado: {F.num(op.beneficio)} {self.entorno.ajustes.cotizacion} ({F.pct(op.porcentaje)})\n"
				f"Motivo: {op.motivo_salida}")

	def al_aviso(self, texto, nivel):
		if self.a["avisos_importantes"] and nivel in ("aviso", "error"):
			self.enviar(("⚠️ " if nivel == "aviso" else "❌ ") + texto)

	def en_cada_vela(self, ctx):
		dia = ctx.tiempo // DIA_MS
		if self.dia is None:
			self.dia = dia
			return
		if dia == self.dia:
			return
		self.dia = dia
		if self.a["resumen_diario"] and self.listo() and self.entorno.resumen:
			r = self.entorno.resumen()
			m, ref = r["metricas"], r["referencia"]
			ref_txt = f"\nComprar y mantener: {F.pct(ref['rentabilidad'])}" if ref else ""
			self.enviar(f"📊 Resumen del día (simulación)\nValor: {F.num(m['valor_final'])} {r['cotizacion']} "
				f"({F.pct(m['rentabilidad'])}){ref_txt}\nOperaciones cerradas: {m['operaciones']} · "
				f"posiciones abiertas: {len(r['abiertas'])}")

	def al_terminar(self, resumen):
		if self.entorno.modo == "vivo":
			m = resumen["metricas"]
			self.enviar(f"⏹ Bot parado. Valor: {F.num(m['valor_final'])} {resumen['cotizacion']} ({F.pct(m['rentabilidad'])})")

	def guardar_estado(self):
		return {"dia": self.dia}

	def cargar_estado(self, datos):
		self.dia = datos.get("dia")
