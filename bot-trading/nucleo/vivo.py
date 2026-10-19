"""Simulación en tiempo real con dinero de MENTIRA ("paper trading").

Mira el precio de Binance cada X segundos, decide con cada vela cerrada (igual que en la
prueba con el pasado) y apunta compras y ventas ficticias. Todo se guarda en estado/ para
continuar donde lo dejó si se cierra el programa o se apaga el PC.
"""
from __future__ import annotations

import os
import time
import traceback

from . import estado
from . import formato as F
from .cartera import Cartera
from .datos import ErrorDatos
from .entorno import Entorno, Registro
from .metricas import construir_resumen, info_plugins
from .motor import Motor
from .plugins import cargar_plugins, descubrir

VERSION_ESTADO = 1


class SimulacionEnVivo:
	def __init__(self, ajustes, carpeta_plugins: str, carpeta_resultados: str, carpeta_estado: str, fuente,
			registro: Registro | None = None, reloj=None, dormir=time.sleep, estricto: bool = False) -> None:
		self.ajustes = ajustes
		self.carpeta_plugins = carpeta_plugins
		self.fuente = fuente
		self.ruta_estado = os.path.join(carpeta_estado, "simulacion.json")
		self.reloj = reloj or fuente.ahora_ms
		self.dormir = dormir
		self.entorno = Entorno("vivo", ajustes, carpeta_resultados, registro, estricto)
		self.motor: Motor | None = None
		self.cartera: Cartera | None = None
		self.inicio = 0
		self.precios_inicio: dict[str, float] = {}
		self._ultimo_resumen_pantalla = 0
		self.continuada = False
		self.cerrojo = estado.Cerrojo(os.path.join(carpeta_estado, "simulacion.lock"))

	# ------------------------------------------------------------ arranque
	def preparar(self) -> None:
		aj, en = self.ajustes, self.entorno
		self.clases = descubrir(self.carpeta_plugins)
		self.plugins = cargar_plugins(self.carpeta_plugins, aj, en)
		en.plugins = self.plugins
		for aviso in aj.avisos:
			en.log(aviso, "aviso")
		if self.cerrojo.f is None and not self.cerrojo.adquirir():
			raise estado.ErrorEstado("Ya hay otra simulación en marcha (en otra ventana). Usa esa o ciérrala antes "
				"de abrir otra: dos a la vez estropearían la simulación guardada.")
		guardado = estado.cargar(self.ruta_estado)   # puede lanzar ErrorEstado: mejor parar que machacar
		g = aj.general
		self.cartera = Cartera(g["capital_inicial"], g["comision"], g["deslizamiento"], g["orden_minima"])
		self.motor = Motor(en, self.plugins, self.cartera)
		self.fuente.sincronizar()
		ahora = self.reloj()
		ultima_guardada: dict[str, int] = {}
		if guardado:
			self.continuada = True
			self.cartera.cargar_dict(guardado["cartera"])
			self.motor.cargar_dict(guardado.get("motor", {}))
			self.inicio = int(guardado.get("inicio", ahora))
			self.precios_inicio = {s: float(p) for s, p in guardado.get("precios_inicio", {}).items()}
			ultima_guardada = {s: int(t) for s, t in guardado.get("ultima_vela", {}).items()}
			estados = guardado.get("plugins", {})
			for p in self.plugins:
				if p.nombre in estados:
					self.motor._llamar(p, "cargar_estado", estados[p.nombre])
			if abs(self.cartera.capital_inicial - g["capital_inicial"]) > 1e-9:
				en.log(f"Sigo con la simulación guardada (capital inicial {F.num(self.cartera.capital_inicial)}). "
					"Para usar el capital nuevo de ajustes.toml, reinicia la simulación.", "aviso")
			if guardado.get("intervalo") not in (None, aj.intervalo):
				en.log(f"Has cambiado el intervalo ({guardado.get('intervalo')} → {aj.intervalo}). "
					"Funciona, pero lo ideal es reiniciar la simulación.", "aviso")
		else:
			self.inicio = ahora
			for s in aj.monedas:
				self.precios_inicio[s] = self.fuente.precio(s)

		calent = g["velas_calentamiento"]
		for s in aj.monedas:
			velas = self.fuente.ultimas_velas(s, aj.intervalo, calent)
			if not velas:
				raise ErrorDatos(f"Binance no devuelve velas de {s}")
			for v in velas:
				self.motor.agregar_vela(s, v, decidir=False)
			if s in ultima_guardada and velas[-1].t - ultima_guardada[s] > aj.intervalo_ms:
				perdidas = (velas[-1].t - ultima_guardada[s]) // aj.intervalo_ms
				en.log(f"{s}: el bot estuvo parado {perdidas} vela(s); retomo desde ahora.", "aviso")
			if s not in self.precios_inicio:
				self.precios_inicio[s] = velas[-1].cierre

		for s in [s for s in self.cartera.posiciones if s not in aj.monedas]:
			self.motor.preparar_moneda(s)
			precio = self.fuente.precio(s)
			self.motor.cerrar(s, precio, ahora, "moneda quitada de los ajustes")
		for s in aj.monedas:   # precio actual (no el de la última vela) y por si cruzó el stop con el bot apagado
			precio = self.fuente.precio(s)
			self.motor.ultimo_precio[s] = precio
			self.motor.revisar_stops_precio(s, precio, ahora)

		for p in self.plugins:
			self.motor._llamar(p, "al_iniciar")
		en.resumen = self.resumen
		if not self.motor.curva:
			self.motor.anotar_valor(ahora, self.referencia())
		self.guardar()
		r = self.resumen()   # el informe existe desde el primer momento
		for p in self.plugins:
			self.motor._llamar(p, "al_actualizar", r)

	# ------------------------------------------------------------ cálculo
	def referencia(self) -> float:
		"""Valor de "comprar y mantener" desde que empezó la simulación."""
		g = self.ajustes.general
		com, desl = g["comision"] / 100, g["deslizamiento"] / 100
		cap = self.cartera.capital_inicial
		n = len(self.precios_inicio) or 1
		total = 0.0
		for s, p0 in self.precios_inicio.items():
			p = self.motor.ultimo_precio.get(s)
			if p is None or p0 <= 0:
				total += cap / n
			else:
				total += cap / n * (1 - com) / (p0 * (1 + desl)) * p * (1 - com) * (1 - desl)
		return total

	def resumen(self) -> dict:
		ahora = self.reloj()
		punto = (ahora, round(self.motor.valor_total(), 6), round(self.referencia(), 6))
		r = construir_resumen(self.entorno, self.motor, self.cartera, info_plugins(self.clases, self.plugins),
			self.inicio, ahora, punto)
		r["archivos"] = []
		return r

	def guardar(self) -> None:
		datos = {
			"version": VERSION_ESTADO,
			"inicio": self.inicio,
			"guardado": self.reloj(),
			"monedas": list(self.ajustes.monedas),
			"intervalo": self.ajustes.intervalo,
			"precios_inicio": self.precios_inicio,
			"ultima_vela": {s: v.t[-1] for s, v in self.motor.series.items() if len(v)},
			"cartera": self.cartera.a_dict(),
			"motor": self.motor.a_dict(),
			"plugins": {p.nombre: self.motor._llamar(p, "guardar_estado") or {} for p in self.plugins},
		}
		datos["plugins"] = {k: (v if isinstance(v, dict) else {}) for k, v in datos["plugins"].items()}
		estado.guardar(self.ruta_estado, datos)

	# ------------------------------------------------------------ bucle
	def paso(self) -> bool:
		"""Una vuelta: precios → stops → velas nuevas → decisiones → guardar. Devuelve si hubo cambios."""
		aj, m = self.ajustes, self.motor
		ahora = self.reloj()
		cambios = nuevas_velas = False
		for s in aj.monedas:
			precio = self.fuente.precio(s)
			m.ultimo_precio[s] = precio
			if m.revisar_stops_precio(s, precio, ahora):
				cambios = True
			serie = m.series[s]
			if ahora >= serie.t[-1] + 2 * aj.intervalo_ms:   # ya ha cerrado otra vela
				faltan = int((ahora - serie.t[-1]) // aj.intervalo_ms) + 2
				nuevas = [v for v in self.fuente.ultimas_velas(s, aj.intervalo, min(faltan, 1000)) if v.t > serie.t[-1]]
				if nuevas:
					for v in nuevas[:-1]:
						m.agregar_vela(s, v, decidir=False)
					m.agregar_vela(s, nuevas[-1], decidir=True)
					m.ultimo_precio[s] = precio
					m.ejecutar_pendiente(s, precio, ahora)
					cambios = nuevas_velas = True
		if nuevas_velas:
			m.anotar_valor(ahora, self.referencia())
			r = self.resumen()
			for p in self.plugins:
				m._llamar(p, "al_actualizar", r)
		if cambios:
			self.guardar()
		self.mostrar_estado(ahora)
		return cambios

	def mostrar_estado(self, ahora: int, forzar: bool = False) -> None:
		cada = self.ajustes.vivo["minutos_entre_resumenes"] * 60_000
		if not forzar and ahora - self._ultimo_resumen_pantalla < cada:
			return
		self._ultimo_resumen_pantalla = ahora
		m, c, cot = self.motor, self.cartera, self.ajustes.cotizacion
		valor = m.valor_total()
		ref = self.referencia()
		cap = c.capital_inicial
		lineas = [f"Valor de la cartera: {F.num(valor)} {cot} ({F.pct((valor / cap - 1) * 100)}) · "
			f"comprar y mantener: {F.pct((ref / cap - 1) * 100)} · operaciones cerradas: {len(c.operaciones)}"]
		for s in self.ajustes.monedas:
			precio = m.ultimo_precio.get(s)
			pos = c.posiciones.get(s)
			if pos:
				res = (precio / pos.precio_entrada - 1) * 100 if precio else 0.0
				stop = f", stop {F.precio(pos.stop)}" if pos.stop else ""
				lineas.append(f"   {s}: {F.precio(precio)} · comprada a {F.precio(pos.precio_entrada)} ({F.pct(res)}){stop}")
			else:
				lineas.append(f"   {s}: {F.precio(precio)} · sin posición")
		serie = next(iter(m.series.values()))
		if len(serie):
			lineas.append(f"   Próxima decisión: {F.fecha(serie.t[-1] + 2 * self.ajustes.intervalo_ms)} (hora de tu PC)")
		self.entorno.log("\n".join(lineas))

	def bucle(self, max_pasos: int | None = None) -> dict | None:
		en = self.entorno
		seg = self.ajustes.vivo["segundos_entre_consultas"]
		resumen = None
		fallos = errores = pasos = 0
		if self.motor is None:
			self.preparar()   # si falla, no se guarda nada (no hay nada a medias que proteger)
		try:
			self.mostrar_estado(self.reloj(), forzar=True)
			while max_pasos is None or pasos < max_pasos:
				pasos += 1
				try:
					self.paso()
					if fallos >= 5:
						en.avisar("Vuelvo a tener precios de Binance. Todo sigue en marcha.", "info")
					fallos = errores = 0
				except ErrorDatos as e:
					fallos += 1
					en.log(str(e), "aviso")
					if fallos == 5 or fallos % 60 == 0:
						en.avisar(f"Llevo {fallos} intentos sin poder leer precios: {e}", "error")
					self.dormir(min(300, 10 * fallos))
					continue
				except KeyboardInterrupt:
					raise
				except Exception as e:
					if en.estricto:
						raise
					errores += 1
					try:
						with open(en.ruta_resultado("errores.log"), "a", encoding="utf-8") as f:
							f.write(time.strftime("%Y-%m-%d %H:%M:%S\n") + traceback.format_exc() + "\n")
					except OSError:
						pass
					en.avisar(f"Error inesperado: {e} (detalles en resultados/errores.log)", "error")
					if errores >= 5:
						en.avisar("5 errores seguidos: paro el bot por seguridad. Tu simulación está guardada.", "error")
						break
				self.dormir(seg)
		except KeyboardInterrupt:
			en.log("Parando el bot… (todo queda guardado)")
		finally:
			try:
				self.guardar()
			except Exception as e:  # pragma: no cover - disco lleno, etc.
				en.log(f"No he podido guardar la simulación: {e}", "error")
			resumen = self.resumen()
			for p in self.plugins:
				self.motor._llamar(p, "al_terminar", resumen)
			self.cerrojo.soltar()
		return resumen
