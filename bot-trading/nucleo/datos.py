"""Precios de Binance. Solo datos PÚBLICOS: no hace falta cuenta, ni clave, ni dinero.

- `FuenteBinance` pide velas y precios (con reintentos y servidor de reserva).
- `historico()` descarga el pasado y lo guarda en datos/ para no volver a bajarlo.
"""
from __future__ import annotations

import csv
import json
import os
import random
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Callable, NamedTuple

from .config import INTERVALOS_MS, simbolo_binance


class Vela(NamedTuple):
	t: int            # milisegundos de APERTURA (UTC)
	apertura: float
	maximo: float
	minimo: float
	cierre: float
	volumen: float


class ErrorDatos(Exception):
	"""Problema al conseguir precios, con mensaje para el usuario."""


def _traducir_error_binance(msg: str, params: dict | None) -> str:
	simbolo = (params or {}).get("symbol", "")
	if "Invalid symbol" in msg:
		return f"La moneda '{simbolo}' no existe en Binance. Revisa 'monedas' en ajustes.toml (ejemplo: \"BTC/USDT\")."
	if "interval" in msg.lower():
		return "Binance no acepta ese 'intervalo'. Usa uno de: " + ", ".join(INTERVALOS_MS)
	return f"Binance ha rechazado la petición: {msg}"


class FuenteBinance:
	BASES = ("https://data-api.binance.vision", "https://api.binance.com")

	def __init__(self, reintentos: int = 4, espera: Callable[[float], None] = time.sleep,
			tiempo_espera: float = 15.0, abrir=urllib.request.urlopen):
		self.reintentos = reintentos
		self.espera = espera
		self.tiempo_espera = tiempo_espera
		self.abrir = abrir
		self._base_ok: str | None = None
		self.desfase_ms = 0

	def _pedir(self, ruta: str, params: dict | None = None):
		bases = list(self.BASES)
		if self._base_ok in bases:
			bases.remove(self._base_ok)
			bases.insert(0, self._base_ok)
		ultimo = "sin respuesta"
		for base in bases:
			url = base + ruta + ("?" + urllib.parse.urlencode(params) if params else "")
			for intento in range(self.reintentos):
				try:
					req = urllib.request.Request(url, headers={
						"User-Agent": "BotTradingSimulado/1.0", "Accept": "application/json"})
					with self.abrir(req, timeout=self.tiempo_espera) as r:
						datos = json.loads(r.read().decode("utf-8"))
					self._base_ok = base
					return datos
				except urllib.error.HTTPError as e:
					try:
						msg = json.loads(e.read().decode("utf-8")).get("msg", "")
					except Exception:
						msg = ""
					if e.code == 400:
						raise ErrorDatos(_traducir_error_binance(msg, params)) from None
					if e.code in (403, 451):
						ultimo = f"servidor no disponible en tu zona (HTTP {e.code})"
						break  # probar el siguiente servidor
					if e.code in (418, 429):
						ultimo = "demasiadas peticiones"
						try:
							pausa = float(e.headers.get("Retry-After", 0) or 0)
						except (TypeError, ValueError):
							pausa = 0.0
						self.espera(max(pausa, 5.0 * (intento + 1)))
						continue
					ultimo = f"HTTP {e.code}"
				except (urllib.error.URLError, TimeoutError, ConnectionError, OSError, ValueError) as e:
					ultimo = str(getattr(e, "reason", e))
					if "CERTIFICATE_VERIFY_FAILED" in ultimo:
						ultimo += " (problema con los certificados de seguridad: reinstala Python desde python.org)"
				if intento < self.reintentos - 1:
					self.espera(min(2 ** intento, 16) + random.random())
		raise ErrorDatos(f"No puedo conseguir precios de Binance ({ultimo}). Comprueba tu conexión a Internet.")

	def sincronizar(self) -> None:
		"""Mide la diferencia entre el reloj del PC y el de Binance (para saber qué vela ya cerró)."""
		try:
			servidor = int(self._pedir("/api/v3/time")["serverTime"])
			self.desfase_ms = servidor - int(time.time() * 1000)
		except (ErrorDatos, KeyError, TypeError, ValueError):
			self.desfase_ms = 0

	def ahora_ms(self) -> int:
		return int(time.time() * 1000) + self.desfase_ms

	def precio(self, moneda: str) -> float:
		params = {"symbol": simbolo_binance(moneda)}
		d = self._pedir("/api/v3/ticker/price", params)
		try:
			return float(d["price"])
		except (KeyError, TypeError, ValueError):
			raise ErrorDatos(f"Respuesta rara de Binance al pedir el precio de {moneda}") from None

	def velas(self, moneda: str, intervalo: str, desde: int | None = None, hasta: int | None = None,
			limite: int = 1000) -> list[Vela]:
		"""Velas CERRADAS (la que está en curso se descarta), de más antigua a más nueva."""
		params: dict = {"symbol": simbolo_binance(moneda), "interval": intervalo, "limit": int(limite)}
		if desde is not None:
			params["startTime"] = int(desde)
		if hasta is not None:
			params["endTime"] = int(hasta)
		filas = self._pedir("/api/v3/klines", params)
		if not isinstance(filas, list):
			raise ErrorDatos(f"Respuesta rara de Binance al pedir velas de {moneda}")
		ahora = self.ahora_ms()
		res: list[Vela] = []
		for f in filas:
			try:
				if int(f[6]) >= ahora:  # hora de cierre aún no ha llegado → vela abierta
					continue
				res.append(Vela(int(f[0]), float(f[1]), float(f[2]), float(f[3]), float(f[4]), float(f[5])))
			except (IndexError, TypeError, ValueError):
				continue
		return res

	def ultimas_velas(self, moneda: str, intervalo: str, n: int) -> list[Vela]:
		return self.velas(moneda, intervalo, limite=min(n + 1, 1000))[-n:]


# ---------------------------------------------------------------- caché en disco

def _ruta_cache(carpeta: str, moneda: str, intervalo: str) -> str:
	return os.path.join(carpeta, f"{simbolo_binance(moneda)}_{intervalo}.csv")


def leer_cache(ruta: str) -> list[Vela]:
	if not os.path.exists(ruta):
		return []
	try:
		with open(ruta, newline="", encoding="utf-8") as f:
			lector = csv.reader(f)
			next(lector, None)
			velas = [Vela(int(r[0]), float(r[1]), float(r[2]), float(r[3]), float(r[4]), float(r[5])) for r in lector if r]
		return combinar(velas, [])
	except (OSError, ValueError, IndexError):
		return []  # caché estropeada: se vuelve a descargar


def guardar_cache(ruta: str, velas: list[Vela]) -> None:
	os.makedirs(os.path.dirname(ruta) or ".", exist_ok=True)
	tmp = ruta + ".tmp"
	with open(tmp, "w", newline="", encoding="utf-8") as f:
		w = csv.writer(f)
		w.writerow(Vela._fields)
		w.writerows(velas)
	os.replace(tmp, ruta)


def combinar(a: list[Vela], b: list[Vela]) -> list[Vela]:
	"""Une dos listas sin duplicados y ordenadas por tiempo."""
	por_t = {v.t: v for v in a}
	por_t.update({v.t: v for v in b})
	return [por_t[t] for t in sorted(por_t)]


def huecos(velas: list[Vela], paso_ms: int) -> list[tuple[int, int]]:
	"""Tramos donde faltan velas (p. ej. mantenimiento de Binance)."""
	return [(velas[k - 1].t, velas[k].t) for k in range(1, len(velas)) if velas[k].t - velas[k - 1].t > paso_ms]


def _descargar(fuente, moneda: str, intervalo: str, desde: int, hasta: int | None,
		mostrar: Callable[[str], None] | None) -> list[Vela]:
	paso = INTERVALOS_MS[intervalo]
	res: list[Vela] = []
	inicio = desde
	fin = hasta if hasta is not None else fuente.ahora_ms()
	ultimo_pct = -1
	while inicio <= fin:
		lote = fuente.velas(moneda, intervalo, desde=inicio, hasta=hasta, limite=1000)
		lote = [v for v in lote if v.t >= inicio]
		if not lote:
			break
		res.extend(lote)
		inicio = lote[-1].t + paso
		if mostrar and fin > desde:
			pct = min(100, int(100 * (inicio - desde) / (fin - desde)))
			if pct // 20 != ultimo_pct // 20:
				mostrar(f"  Descargando {moneda} ({intervalo}): {pct} %")
				ultimo_pct = pct
		if len(lote) < 990:
			break
	return res


def historico(fuente, moneda: str, intervalo: str, desde_ms: int, carpeta_cache: str | None = None,
		mostrar: Callable[[str], None] | None = None) -> list[Vela]:
	"""Velas cerradas desde `desde_ms` hasta ahora. Reutiliza lo ya descargado."""
	paso = INTERVALOS_MS[intervalo]
	ruta = _ruta_cache(carpeta_cache, moneda, intervalo) if carpeta_cache else None
	cache = leer_cache(ruta) if ruta else []
	nuevas: list[Vela] = []
	if not cache or cache[0].t > desde_ms:
		nuevas += _descargar(fuente, moneda, intervalo, desde_ms, (cache[0].t - 1) if cache else None, mostrar)
	ultima = max([v.t for v in cache[-1:]] + [v.t for v in nuevas[-1:]], default=desde_ms - paso)
	nuevas += _descargar(fuente, moneda, intervalo, ultima + paso, None, mostrar)
	todas = combinar(cache, nuevas)
	if ruta and nuevas:
		guardar_cache(ruta, todas)
	return [v for v in todas if v.t >= desde_ms]
