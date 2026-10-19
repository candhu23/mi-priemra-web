"""Lee y comprueba ajustes.toml (y secretos.toml, opcional).

Quien edita el archivo no programa: cada error dice QUÉ clave está mal y cómo arreglarla.
"""
from __future__ import annotations

import difflib
import os
import re
import tomllib
from dataclasses import dataclass, field
from typing import Any

INTERVALOS_MS = {
	"1m": 60_000, "3m": 180_000, "5m": 300_000, "15m": 900_000, "30m": 1_800_000,
	"1h": 3_600_000, "2h": 7_200_000, "4h": 14_400_000, "6h": 21_600_000,
	"8h": 28_800_000, "12h": 43_200_000, "1d": 86_400_000,
}
MODOS = ("cualquiera", "mayoria", "todas")


class ErrorAjustes(Exception):
	"""Error en los ajustes, con un mensaje pensado para el usuario."""


@dataclass(frozen=True)
class P:
	"""Definición de un parámetro: valor por defecto, tipo, límites y ayuda."""
	defecto: Any
	tipo: type
	minimo: float | None = None
	maximo: float | None = None
	ayuda: str = ""
	opciones: tuple = ()


ESQUEMA_GENERAL = {
	"monedas": P(["BTC/USDT", "ETH/USDT"], list, ayuda="Pares de Binance, p. ej. \"BTC/USDT\""),
	"intervalo": P("4h", str, opciones=tuple(INTERVALOS_MS), ayuda="Duración de cada vela"),
	"capital_inicial": P(1000.0, float, 10, 1e9, "Dinero simulado con el que empieza"),
	"comision": P(0.1, float, 0, 5, "% que cobra el exchange en cada compra o venta"),
	"deslizamiento": P(0.05, float, 0, 5, "% de precio peor al ejecutar (realismo)"),
	"modo_entrada": P("cualquiera", str, opciones=MODOS),
	"modo_salida": P("cualquiera", str, opciones=MODOS),
	"memoria_senales": P(3, int, 1, 100, "Velas que una señal sigue contando"),
	"max_posiciones": P(2, int, 1, 50, "Monedas compradas a la vez como máximo"),
	"max_por_operacion": P(50.0, float, 1, 100, "% máximo del capital en una sola compra"),
	"orden_minima": P(10.0, float, 0, 1e9, "Compra mínima en USDT (Binance exige unos 5-10)"),
	"velas_calentamiento": P(300, int, 50, 1000, "Velas previas para calcular indicadores"),
}
ESQUEMA_BACKTEST = {
	"dias": P(365, int, 7, 3650, "Días del pasado que se prueban"),
	"abrir_informe": P(True, bool, ayuda="Abrir el informe en el navegador al terminar"),
}
ESQUEMA_VIVO = {
	"segundos_entre_consultas": P(30, int, 5, 3600, "Cada cuánto mira el precio"),
	"minutos_entre_resumenes": P(30, int, 1, 1440, "Cada cuánto escribe el estado en pantalla"),
}


@dataclass
class Ajustes:
	general: dict
	backtest: dict
	vivo: dict
	plugins: dict            # {nombre: {clave: valor}} tal cual del archivo (cada plugin lo valida)
	secretos: dict = field(default_factory=dict)
	avisos: list = field(default_factory=list)
	ruta: str = ""

	@property
	def monedas(self) -> list[str]:
		return self.general["monedas"]

	@property
	def intervalo(self) -> str:
		return self.general["intervalo"]

	@property
	def intervalo_ms(self) -> int:
		return INTERVALOS_MS[self.general["intervalo"]]

	@property
	def cotizacion(self) -> str:
		return self.monedas[0].split("/")[1]


def simbolo_binance(moneda: str) -> str:
	return moneda.replace("/", "")


def leer_toml(ruta: str) -> dict:
	try:
		with open(ruta, "rb") as f:
			datos = f.read()
	except FileNotFoundError:
		raise ErrorAjustes(f"No encuentro el archivo de ajustes: {ruta}") from None
	if datos.startswith(b"\xef\xbb\xbf"):  # el Bloc de notas a veces añade esta marca
		datos = datos[3:]
	try:
		texto = datos.decode("utf-8")
	except UnicodeDecodeError:
		texto = datos.decode("cp1252", errors="replace")
	try:
		return tomllib.loads(texto)
	except tomllib.TOMLDecodeError as e:
		raise ErrorAjustes(
			f"El archivo {os.path.basename(ruta)} tiene un error de formato ({e}).\n"
			"Pistas: los textos van entre comillas (\"4h\"), los decimales con punto (0.5), "
			"true/false sin comillas y las listas entre corchetes ([\"BTC/USDT\", \"ETH/USDT\"])."
		) from None


def _num(x: float) -> str:
	return str(int(x)) if float(x).is_integer() else str(x)


def validar_valor(seccion: str, clave: str, valor: Any, p: P) -> Any:
	nombre = f"En [{seccion}], '{clave}'"
	if p.tipo is bool:
		if not isinstance(valor, bool):
			raise ErrorAjustes(f"{nombre} debe ser true o false (sin comillas). Has puesto: {valor!r}")
		return valor
	if p.tipo is int:
		if isinstance(valor, float) and valor.is_integer():
			valor = int(valor)
		if isinstance(valor, bool) or not isinstance(valor, int):
			raise ErrorAjustes(f"{nombre} debe ser un número entero (sin decimales ni comillas). Has puesto: {valor!r}")
	elif p.tipo is float:
		if isinstance(valor, bool) or not isinstance(valor, (int, float)):
			raise ErrorAjustes(f"{nombre} debe ser un número (decimales con punto, sin comillas). Has puesto: {valor!r}")
		valor = float(valor)
	elif p.tipo is str:
		if not isinstance(valor, str):
			raise ErrorAjustes(f"{nombre} debe ir entre comillas. Has puesto: {valor!r}")
		if p.opciones and valor not in p.opciones:
			raise ErrorAjustes(f"{nombre} debe ser uno de estos: {', '.join(p.opciones)}. Has puesto: \"{valor}\"")
		return valor
	elif p.tipo is list:
		if not isinstance(valor, list) or not all(isinstance(x, str) for x in valor):
			raise ErrorAjustes(f"{nombre} debe ser una lista de textos, p. ej. [\"BTC/USDT\", \"ETH/USDT\"]")
		return list(valor)
	if p.minimo is not None and valor < p.minimo:
		raise ErrorAjustes(f"{nombre} no puede ser menor que {_num(p.minimo)}. Has puesto: {valor}")
	if p.maximo is not None and valor > p.maximo:
		raise ErrorAjustes(f"{nombre} no puede ser mayor que {_num(p.maximo)}. Has puesto: {valor}")
	return valor


def validar_seccion(seccion: str, datos: Any, esquema: dict[str, P], avisos: list[str]) -> dict:
	if datos is None:
		datos = {}
	if not isinstance(datos, dict):
		raise ErrorAjustes(f"[{seccion}] debe ser una sección con claves (clave = valor)")
	res = {}
	for clave, p in esquema.items():
		if clave in datos:
			res[clave] = validar_valor(seccion, clave, datos[clave], p)
		else:
			res[clave] = list(p.defecto) if isinstance(p.defecto, list) else p.defecto
	for clave in datos:
		if clave not in esquema:
			parecida = difflib.get_close_matches(clave, list(esquema), 1)
			pista = f" (¿querías decir '{parecida[0]}'?)" if parecida else ""
			avisos.append(f"En [{seccion}], '{clave}' no existe y se ignora{pista}")
	return res


def _validar_monedas(monedas: list[str]) -> list[str]:
	limpias: list[str] = []
	for m in monedas:
		m2 = m.strip().upper().replace("-", "/")
		if not re.fullmatch(r"[A-Z0-9]{1,15}/[A-Z0-9]{2,10}", m2):
			raise ErrorAjustes(f"En [general], la moneda \"{m}\" no tiene el formato correcto. Ejemplo: \"BTC/USDT\"")
		if m2 not in limpias:
			limpias.append(m2)
	if not limpias:
		raise ErrorAjustes("En [general], 'monedas' está vacía: pon al menos una, p. ej. [\"BTC/USDT\"]")
	if len(limpias) > 20:
		raise ErrorAjustes("En [general], 'monedas' admite como máximo 20 pares")
	cot = {m.split("/")[1] for m in limpias}
	if len(cot) > 1:
		raise ErrorAjustes(
			"En [general], todas las monedas deben ir contra la misma (p. ej. todas /USDT). "
			f"Ahora hay: {', '.join(sorted(cot))}"
		)
	return limpias


def cargar_secretos(ruta: str | None) -> dict:
	"""Token de Telegram: de secretos.toml o de variables de entorno (mandan las variables)."""
	sec: dict = {}
	if ruta and os.path.exists(ruta):
		datos = leer_toml(ruta)
		tg = datos.get("telegram", {}) if isinstance(datos.get("telegram", {}), dict) else {}
		if tg.get("token"):
			sec["telegram_token"] = str(tg["token"]).strip()
		if tg.get("chat_id"):
			sec["telegram_chat_id"] = str(tg["chat_id"]).strip()
	if os.environ.get("TELEGRAM_TOKEN"):
		sec["telegram_token"] = os.environ["TELEGRAM_TOKEN"].strip()
	if os.environ.get("TELEGRAM_CHAT_ID"):
		sec["telegram_chat_id"] = os.environ["TELEGRAM_CHAT_ID"].strip()
	return sec


def desde_dict(datos: dict, ruta: str = "", secretos: dict | None = None) -> Ajustes:
	avisos: list[str] = []
	for seccion in datos:
		if seccion not in ("general", "backtest", "vivo", "plugins"):
			avisos.append(f"La sección [{seccion}] no existe y se ignora")
	general = validar_seccion("general", datos.get("general"), ESQUEMA_GENERAL, avisos)
	general["monedas"] = _validar_monedas(general["monedas"])
	backtest = validar_seccion("backtest", datos.get("backtest"), ESQUEMA_BACKTEST, avisos)
	vivo = validar_seccion("vivo", datos.get("vivo"), ESQUEMA_VIVO, avisos)
	plugins = datos.get("plugins", {}) or {}
	if not isinstance(plugins, dict) or not all(isinstance(v, dict) for v in plugins.values()):
		raise ErrorAjustes("La parte de plugins debe tener secciones como [plugins.cruce_medias]")
	return Ajustes(general, backtest, vivo, plugins, dict(secretos or {}), avisos, ruta)


def cargar_ajustes(ruta: str, ruta_secretos: str | None = None) -> Ajustes:
	return desde_dict(leer_toml(ruta), ruta, cargar_secretos(ruta_secretos))
