"""Base de los plugins y cargador.

Un plugin es un archivo .py en la carpeta plugins/ con una clase que hereda de `Plugin`.
Se activa o desactiva en ajustes.toml, sección [plugins.<nombre>], con `activo = true/false`.

Cada plugin rellena solo los "ganchos" que necesita (todos son opcionales):

  senal(ctx)                      → "comprar" | "vender" | None      (estrategias)
  permitir_entrada(ctx)           → True | False | (False, "motivo") (filtros y frenos)
  stop_inicial(ctx, precio)       → precio del stop loss | None
  objetivo_inicial(ctx, precio, stop) → precio de recogida de beneficios | None
  tamano(ctx, precio, stop)       → USDT a invertir | None
  actualizar_stop(ctx, posicion)  → nuevo stop (solo puede subir) | None
  forzar_salida(ctx, posicion)    → "motivo" para vender ya | None
  en_cada_vela(ctx)               → se llama con cada vela cerrada de cada moneda
  al_abrir(posicion) / al_cerrar(operacion) / al_aviso(texto, nivel)
  al_iniciar() / al_actualizar(resumen) (solo en vivo) / al_terminar(resumen)
  guardar_estado() → dict  /  cargar_estado(dict)   (para continuar tras reiniciar)
"""
from __future__ import annotations

import importlib.util
import inspect
import os
import sys

from .config import ErrorAjustes, P, validar_valor

TIPOS = {"estrategia": 0, "filtro": 1, "riesgo": 2, "info": 3}
NOMBRES_TIPO = {"estrategia": "Estrategias", "filtro": "Filtros", "riesgo": "Gestión del riesgo", "info": "Información"}


class Plugin:
	nombre = ""               # clave en ajustes.toml: [plugins.<nombre>]
	orden = 99                # posición en la lista (1-15)
	titulo = ""
	tipo = "info"
	descripcion = ""
	activo_por_defecto = False
	parametros: dict[str, P] = {}

	def __init__(self, ajustes: dict, entorno) -> None:
		self.a = ajustes
		self.entorno = entorno

	def validar(self) -> None:
		"""Comprobaciones entre parámetros (lanza ErrorAjustes si algo no cuadra)."""

	# --------------------------------------------------------------- ganchos
	def al_iniciar(self) -> None: ...
	def en_cada_vela(self, ctx) -> None: ...
	def senal(self, ctx): return None
	def permitir_entrada(self, ctx): return True
	def stop_inicial(self, ctx, precio): return None
	def objetivo_inicial(self, ctx, precio, stop): return None
	def tamano(self, ctx, precio, stop): return None
	def actualizar_stop(self, ctx, posicion): return None
	def forzar_salida(self, ctx, posicion): return None
	def al_abrir(self, posicion) -> None: ...
	def al_cerrar(self, operacion) -> None: ...
	def al_aviso(self, texto: str, nivel: str) -> None: ...
	def al_actualizar(self, resumen: dict) -> None: ...
	def al_terminar(self, resumen: dict) -> None: ...
	def guardar_estado(self) -> dict: return {}
	def cargar_estado(self, datos: dict) -> None: ...


def sobrescribe(plugin: Plugin, gancho: str) -> bool:
	"""¿El plugin rellena este gancho?"""
	return getattr(type(plugin), gancho) is not getattr(Plugin, gancho)


def descubrir(carpeta: str) -> list[type[Plugin]]:
	"""Todas las clases de plugin de la carpeta, ordenadas por tipo y nombre."""
	clases: list[type[Plugin]] = []
	vistos: dict[str, str] = {}
	for archivo in sorted(os.listdir(carpeta)):
		if not archivo.endswith(".py") or archivo.startswith("_"):
			continue
		ruta = os.path.join(carpeta, archivo)
		nombre_mod = f"plugins_bot_{archivo[:-3]}"
		try:
			spec = importlib.util.spec_from_file_location(nombre_mod, ruta)
			mod = importlib.util.module_from_spec(spec)
			sys.modules[nombre_mod] = mod
			spec.loader.exec_module(mod)
		except Exception as e:
			raise ErrorAjustes(f"El plugin {archivo} tiene un error y no se puede cargar: {e}") from e
		for _, obj in inspect.getmembers(mod, inspect.isclass):
			if issubclass(obj, Plugin) and obj is not Plugin and obj.__module__ == nombre_mod and obj.nombre:
				if obj.nombre in vistos:
					raise ErrorAjustes(f"Dos plugins se llaman '{obj.nombre}': {vistos[obj.nombre]} y {archivo}")
				if obj.tipo not in TIPOS:
					raise ErrorAjustes(f"El plugin {archivo} tiene un tipo desconocido: {obj.tipo}")
				vistos[obj.nombre] = archivo
				clases.append(obj)
	clases.sort(key=lambda c: (TIPOS[c.tipo], c.orden, c.nombre))
	return clases


def cargar_plugins(carpeta: str, ajustes, entorno) -> list[Plugin]:
	"""Crea los plugins activos con sus parámetros ya comprobados."""
	import difflib
	clases = descubrir(carpeta)
	por_nombre = {c.nombre: c for c in clases}
	for nombre in ajustes.plugins:
		if nombre not in por_nombre:
			parecido = difflib.get_close_matches(nombre, list(por_nombre), 1)
			pista = f" (¿querías decir '{parecido[0]}'?)" if parecido else ""
			ajustes.avisos.append(f"[plugins.{nombre}] no corresponde a ningún plugin y se ignora{pista}")
	activos: list[Plugin] = []
	for c in clases:
		datos = dict(ajustes.plugins.get(c.nombre, {}))
		esquema = {"activo": P(c.activo_por_defecto, bool), **c.parametros}
		seccion = f"plugins.{c.nombre}"
		valores = {}
		for clave, p in esquema.items():
			valores[clave] = validar_valor(seccion, clave, datos[clave], p) if clave in datos else p.defecto
		for clave in datos:
			if clave not in esquema:
				parecida = difflib.get_close_matches(clave, list(esquema), 1)
				pista = f" (¿querías decir '{parecida[0]}'?)" if parecida else ""
				ajustes.avisos.append(f"En [{seccion}], '{clave}' no existe y se ignora{pista}")
		if not valores.pop("activo"):
			continue
		plugin = c(valores, entorno)
		plugin.validar()
		activos.append(plugin)
	return activos
