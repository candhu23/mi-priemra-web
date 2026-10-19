"""Info 1 · Diario de operaciones en CSV (se abre con Excel)."""
import csv
import os

from nucleo import formato as F
from nucleo.config import P
from nucleo.plugins import Plugin

COLUMNAS = ["Moneda", "Compra", "Venta", "Precio compra", "Precio venta", "Cantidad", "Invertido", "Recibido",
	"Beneficio", "Beneficio %", "Comisiones", "Motivo compra", "Motivo venta", "Duración"]


class Diario(Plugin):
	nombre = "diario"
	orden = 13
	titulo = "Diario de operaciones"
	tipo = "info"
	descripcion = ("Apunta cada operación (fechas, precios, beneficio, comisiones y motivo) en un archivo CSV "
		"de la carpeta resultados/ que se abre con Excel.")
	activo_por_defecto = True
	parametros = {
		"formato_excel_es": P(True, bool, ayuda="Coma decimal y ';' para Excel en español"),
	}

	def _ruta(self):
		nombre = "backtest_operaciones.csv" if self.entorno.modo == "backtest" else "simulacion_operaciones.csv"
		return self.entorno.ruta_resultado(nombre)

	def _n(self, x, dec):
		s = f"{x:.{dec}f}"
		return s.replace(".", ",") if self.a["formato_excel_es"] else s

	def _fila(self, o):
		return [o.simbolo, F.fecha(o.tiempo_entrada), F.fecha(o.tiempo_salida), self._n(o.precio_entrada, 8),
			self._n(o.precio_salida, 8), self._n(o.cantidad, 8), self._n(o.coste, 2), self._n(o.ingreso, 2),
			self._n(o.beneficio, 2), self._n(o.porcentaje, 2), self._n(o.comisiones, 2), o.motivo_entrada,
			o.motivo_salida, F.duracion(o.tiempo_salida - o.tiempo_entrada)]

	def _escribir(self, ruta, filas, nuevo):
		sep = ";" if self.a["formato_excel_es"] else ","
		modo, cod = ("w", "utf-8-sig") if nuevo else ("a", "utf-8")
		with open(ruta, modo, newline="", encoding=cod) as f:
			w = csv.writer(f, delimiter=sep)
			if nuevo:
				w.writerow(COLUMNAS)
			w.writerows(filas)

	def __init__(self, ajustes, entorno):
		super().__init__(ajustes, entorno)
		self.por_escribir = []   # filas que no se pudieron escribir (p. ej. el CSV estaba abierto en Excel)

	def al_cerrar(self, op):
		if self.entorno.modo != "vivo":
			return
		self.por_escribir.append(self._fila(op))
		ruta = self._ruta()
		try:
			self._escribir(ruta, self.por_escribir, nuevo=not os.path.exists(ruta))
			self.por_escribir = []
		except PermissionError:
			self.entorno.log("No puedo apuntar la operación en el CSV: ciérralo en Excel. Lo reintento en la "
				"próxima operación (no se pierde).", "aviso")

	def al_terminar(self, resumen):
		ruta = self._ruta()
		if self.entorno.modo == "backtest":
			from nucleo.cartera import Operacion
			filas = [self._fila(Operacion(**o)) for o in resumen["operaciones"]]
			try:
				self._escribir(ruta, filas, nuevo=True)
			except PermissionError:   # abierto en Excel: se guarda con otro nombre
				ruta = ruta.replace(".csv", f"_{resumen['generado']}.csv")
				self._escribir(ruta, filas, nuevo=True)
				self.entorno.log(f"El CSV estaba abierto en Excel; lo he guardado como {os.path.basename(ruta)}", "aviso")
		elif self.por_escribir:
			try:
				self._escribir(ruta, self.por_escribir, nuevo=not os.path.exists(ruta))
				self.por_escribir = []
			except PermissionError:
				self.entorno.log("No he podido apuntar las últimas operaciones en el CSV (estaba abierto en Excel). "
					"Siguen en el informe.", "aviso")
		if os.path.exists(ruta):
			resumen.setdefault("archivos", []).append(ruta)

	def guardar_estado(self):
		return {"por_escribir": self.por_escribir}

	def cargar_estado(self, datos):
		self.por_escribir = list(datos.get("por_escribir", []))
