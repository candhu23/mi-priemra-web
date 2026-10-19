"""Lo que comparten el núcleo y los plugins: modo, carpetas, ajustes y cómo avisar."""
from __future__ import annotations

import os
import time
from typing import Callable


class Registro:
	"""Escribe en pantalla (y en un archivo en modo vivo) con la hora delante."""

	def __init__(self, archivo: str | None = None, silencioso: bool = False, max_bytes: int = 5_000_000) -> None:
		self.archivo = archivo
		self.silencioso = silencioso
		self.max_bytes = max_bytes

	def __call__(self, texto: str, nivel: str = "info") -> None:
		marca = {"aviso": "AVISO: ", "error": "ERROR: "}.get(nivel, "")
		linea = f"[{time.strftime('%H:%M:%S')}] {marca}{texto}"
		if not self.silencioso:
			print(linea, flush=True)
		if self.archivo:
			try:
				if os.path.exists(self.archivo) and os.path.getsize(self.archivo) > self.max_bytes:
					os.replace(self.archivo, self.archivo + ".1")
				with open(self.archivo, "a", encoding="utf-8") as f:
					f.write(time.strftime("%Y-%m-%d ") + linea + "\n")
			except OSError:
				pass


class Entorno:
	def __init__(self, modo: str, ajustes, carpeta_resultados: str, registro: Registro | None = None,
			estricto: bool = False) -> None:
		self.modo = modo                    # "backtest" | "vivo"
		self.ajustes = ajustes
		self.carpeta_resultados = carpeta_resultados
		self.registro = registro or Registro()
		self.estricto = estricto            # True: un fallo de plugin para el bot (pruebas y backtest)
		self.plugins: list = []
		self.avisos: list[tuple[int, str, str]] = []
		self.resumen: Callable[[], dict] | None = None

	@property
	def secretos(self) -> dict:
		return self.ajustes.secretos

	def log(self, texto: str, nivel: str = "info") -> None:
		self.registro(texto, nivel)

	def avisar(self, texto: str, nivel: str = "aviso", tiempo: int | None = None) -> None:
		"""Avisos importantes: van a pantalla, al informe y a los plugins (p. ej. Telegram).

		En la prueba con el pasado los avisos normales no se escriben en pantalla (serían cientos):
		quedan en el informe con la fecha simulada en la que ocurrieron.
		"""
		if self.modo != "backtest" or nivel == "error":
			self.registro(texto, nivel)
		self.avisos.append((int(tiempo if tiempo is not None else time.time() * 1000), nivel, texto))
		del self.avisos[:-200]
		for p in self.plugins:
			try:
				p.al_aviso(texto, nivel)
			except Exception as e:  # un aviso nunca debe tumbar el bot
				self.registro(f"El plugin '{p.nombre}' falló al avisar: {e}", "error")

	def ruta_resultado(self, nombre: str) -> str:
		os.makedirs(self.carpeta_resultados, exist_ok=True)
		return os.path.join(self.carpeta_resultados, nombre)
