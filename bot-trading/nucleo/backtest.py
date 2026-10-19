"""Prueba con el pasado (backtest): ¿qué habría pasado si el bot hubiera funcionado estos días?

Se recorren las velas en orden. Las órdenes se ejecutan en la APERTURA de la vela siguiente a
la señal, con comisión y deslizamiento. Si una vela toca el stop y el objetivo a la vez, se
supone lo peor (el stop). Al final se vende lo que quede para medir el resultado real.
"""
from __future__ import annotations

import os
from itertools import groupby

from . import formato as F
from .cartera import Cartera
from .datos import ErrorDatos, historico, huecos
from .entorno import Entorno, Registro
from .metricas import construir_resumen, info_plugins
from .motor import Motor
from .plugins import cargar_plugins, descubrir

DIA_MS = 86_400_000


def ejecutar(ajustes, carpeta_plugins: str, carpeta_resultados: str, fuente=None, datos: dict | None = None,
		dias: int | None = None, registro: Registro | None = None, estricto: bool = True,
		carpeta_cache: str | None = None) -> dict:
	entorno = Entorno("backtest", ajustes, carpeta_resultados, registro, estricto)
	clases = descubrir(carpeta_plugins)
	plugins = cargar_plugins(carpeta_plugins, ajustes, entorno)
	entorno.plugins = plugins
	for aviso in ajustes.avisos:
		entorno.log(aviso, "aviso")
	paso = ajustes.intervalo_ms
	calent = ajustes.general["velas_calentamiento"]
	dias = dias or ajustes.backtest["dias"]

	if datos is None:
		fuente.sincronizar()
		inicio = fuente.ahora_ms() - dias * DIA_MS
		desde = inicio - calent * paso
		datos = {}
		for s in ajustes.monedas:
			datos[s] = historico(fuente, s, ajustes.intervalo, desde, carpeta_cache, entorno.log)
	else:
		inicio = min(v[0].t for v in datos.values() if v) + calent * paso

	for s in ajustes.monedas:
		velas = datos.get(s, [])
		utiles = sum(1 for v in velas if v.t >= inicio)
		if utiles < 10:
			raise ErrorDatos(f"No hay datos suficientes de {s} para probar ese periodo ({utiles} velas). "
				"Prueba con menos días o con otra moneda.")
		hs = huecos(velas, paso)
		if hs:
			peor = max(hs, key=lambda h: h[1] - h[0])
			entorno.log(f"{s}: faltan velas en {len(hs)} tramo(s) (el mayor, {F.fecha(peor[0])} → "
				f"{F.fecha(peor[1])}). Suele ser mantenimiento de Binance; la prueba sigue.", "aviso")

	g = ajustes.general
	cartera = Cartera(g["capital_inicial"], g["comision"], g["deslizamiento"], g["orden_minima"])
	motor = Motor(entorno, plugins, cartera)
	for p in plugins:
		motor._llamar(p, "al_iniciar")

	# Referencia "comprar y mantener": el capital repartido a partes iguales al empezar.
	com, desl = g["comision"] / 100, g["deslizamiento"] / 100
	n = len(ajustes.monedas)
	parte = g["capital_inicial"] / n
	liquidar = (1 - com) * (1 - desl)
	ref_cantidad: dict[str, float] = {}
	ultimo_cierre: dict[str, float] = {}

	orden = {s: k for k, s in enumerate(ajustes.monedas)}
	eventos = sorted(((v.t, orden[s], s, v) for s in ajustes.monedas for v in datos[s]), key=lambda e: (e[0], e[1]))
	hasta = None
	for t, grupo in groupby(eventos, key=lambda e: e[0]):
		operando = t >= inicio
		for _, _, s, v in grupo:
			if operando:
				motor.ejecutar_pendiente(s, v.apertura, v.t)
				motor.revisar_stops_vela(s, v)
				if s not in ref_cantidad:
					ref_cantidad[s] = parte * (1 - com) / (v.apertura * (1 + desl))
			motor.agregar_vela(s, v, decidir=operando)
			ultimo_cierre[s] = v.cierre
		if operando:
			hasta = t + paso
			ref = sum(q * ultimo_cierre[s] for s, q in ref_cantidad.items()) * liquidar + parte * (n - len(ref_cantidad))
			motor.anotar_valor(hasta, ref)

	# Fin: se vende todo lo abierto al último precio para que el resultado sea real.
	motor.pendientes.clear()
	for s in list(cartera.posiciones):
		motor.cerrar(s, ultimo_cierre[s], hasta, "fin de la prueba")
	if motor.curva:
		t_fin, _, ref_fin = motor.curva[-1]
		motor.curva[-1] = (t_fin, round(cartera.efectivo, 6), ref_fin)

	resumen = construir_resumen(entorno, motor, cartera, info_plugins(clases, plugins), inicio, hasta)
	resumen["dias"] = dias
	resumen["archivos"] = []
	for p in plugins:
		motor._llamar(p, "al_terminar", resumen)
	return resumen


def carpeta_por_defecto(base: str) -> dict[str, str]:
	return {
		"plugins": os.path.join(base, "plugins"),
		"resultados": os.path.join(base, "resultados"),
		"datos": os.path.join(base, "datos"),
		"estado": os.path.join(base, "estado"),
	}
