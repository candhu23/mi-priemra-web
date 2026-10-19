"""Guardar y cargar la simulación en vivo sin perder datos.

- Se escribe primero en un archivo temporal y luego se sustituye (si se va la luz a medias,
  el archivo bueno sigue ahí). La versión anterior queda como copia .bak.
- Si el archivo está estropeado se usa la copia. Si las dos fallan, el bot NO arranca
  (para no machacar una simulación con una vacía).
"""
from __future__ import annotations

import json
import os
import time


class ErrorEstado(Exception):
	pass


def guardar(ruta: str, datos: dict) -> None:
	os.makedirs(os.path.dirname(ruta) or ".", exist_ok=True)
	tmp = ruta + ".tmp"
	with open(tmp, "w", encoding="utf-8") as f:
		json.dump(datos, f, ensure_ascii=False, separators=(",", ":"))
		f.flush()
		os.fsync(f.fileno())
	for intento in range(5):   # en Windows el antivirus puede bloquear el archivo un instante
		try:
			if os.path.exists(ruta):
				os.replace(ruta, ruta + ".bak")
			os.replace(tmp, ruta)
			return
		except PermissionError:
			if intento == 4:
				raise
			time.sleep(0.2 * (intento + 1))


def cargar(ruta: str) -> dict | None:
	"""None si no hay simulación guardada. ErrorEstado si existe pero no se puede leer."""
	candidatos = [r for r in (ruta, ruta + ".bak") if os.path.exists(r)]
	if not candidatos:
		return None
	for r in candidatos:
		try:
			with open(r, encoding="utf-8") as f:
				datos = json.load(f)
			if isinstance(datos, dict) and "cartera" in datos:
				return datos
		except (OSError, ValueError):
			continue
	raise ErrorEstado(
		f"La simulación guardada ({os.path.basename(ruta)}) está estropeada y su copia también. "
		"No la toco para no perder nada. Si quieres empezar de cero, usa la opción 'Reiniciar simulación'."
	)


def borrar(ruta: str) -> bool:
	borrado = False
	for r in (ruta, ruta + ".bak", ruta + ".tmp"):
		if os.path.exists(r):
			os.remove(r)
			borrado = True
	return borrado


class Cerrojo:
	"""Impide dos simulaciones a la vez sobre el mismo estado (p. ej. abrir el menú dos veces).

	Usa un bloqueo del sistema operativo: si el programa se cierra o se cuelga, se suelta solo.
	"""

	def __init__(self, ruta: str) -> None:
		self.ruta = ruta
		self.f = None

	def adquirir(self) -> bool:
		os.makedirs(os.path.dirname(self.ruta) or ".", exist_ok=True)
		f = open(self.ruta, "a+")
		try:
			if os.name == "nt":
				import msvcrt
				f.seek(0)
				msvcrt.locking(f.fileno(), msvcrt.LK_NBLCK, 1)
			else:
				import fcntl
				fcntl.flock(f.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
		except OSError:
			f.close()
			return False
		self.f = f
		return True

	def soltar(self) -> None:
		if self.f is not None:
			try:
				if os.name == "nt":
					import msvcrt
					self.f.seek(0)
					msvcrt.locking(self.f.fileno(), msvcrt.LK_UNLCK, 1)
			except OSError:
				pass
			self.f.close()
			self.f = None
