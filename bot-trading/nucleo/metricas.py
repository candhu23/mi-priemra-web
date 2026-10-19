"""Números para juzgar el bot sin engañarse: rentabilidad, caída máxima, aciertos…

Siempre se compara con "comprar y mantener" (comprar al principio y no hacer nada):
si el bot no lo supera, el bot no está aportando nada.
"""
from __future__ import annotations

import math
import time
from dataclasses import asdict

AÑO_MS = 365 * 86_400_000


def caida_maxima(valores: list[float], inicial: float | None = None) -> float:
	"""Mayor bajada (%) desde un máximo anterior."""
	pico = inicial if inicial is not None else (valores[0] if valores else 0.0)
	peor = 0.0
	for v in valores:
		if v > pico:
			pico = v
		if pico > 0:
			peor = max(peor, (1 - v / pico) * 100)
	return peor


def calcular(curva: list, operaciones: list, capital: float, intervalo_ms: int) -> dict:
	valores = [c[1] for c in curva] or [capital]
	final = valores[-1]
	rets = [valores[k] / valores[k - 1] - 1 for k in range(1, len(valores)) if valores[k - 1] > 0]
	sharpe = None
	if len(rets) > 10:
		media = sum(rets) / len(rets)
		var = sum((r - media) ** 2 for r in rets) / (len(rets) - 1)
		if var > 0:
			sharpe = media / math.sqrt(var) * math.sqrt(AÑO_MS / intervalo_ms)
	ops = [o if isinstance(o, dict) else asdict(o) for o in operaciones]
	ganan = [o["beneficio"] for o in ops if o["beneficio"] > 0]
	pierden = [o["beneficio"] for o in ops if o["beneficio"] <= 0]
	suma_p = -sum(pierden)
	factor = (sum(ganan) / suma_p) if suma_p > 0 else (float("inf") if ganan else None)
	duraciones = [o["tiempo_salida"] - o["tiempo_entrada"] for o in ops]
	return {
		"valor_final": final,
		"beneficio": final - capital,
		"rentabilidad": (final / capital - 1) * 100 if capital else 0.0,
		"caida_maxima": caida_maxima(valores, capital),
		"operaciones": len(ops),
		"ganadoras": len(ganan),
		"perdedoras": len(pierden),
		"aciertos": (len(ganan) / len(ops) * 100) if ops else None,
		"factor_beneficio": factor,
		"ganancia_media": (sum(ganan) / len(ganan)) if ganan else None,
		"perdida_media": (sum(pierden) / len(pierden)) if pierden else None,
		"esperanza": (sum(o["beneficio"] for o in ops) / len(ops)) if ops else None,
		"mejor": max((o["porcentaje"] for o in ops), default=None),
		"peor": min((o["porcentaje"] for o in ops), default=None),
		"duracion_media": (sum(duraciones) / len(duraciones)) if duraciones else None,
		"comisiones": sum(o["comisiones"] for o in ops),
		"sharpe": sharpe,
	}


def construir_resumen(entorno, motor, cartera, plugins_info: list[dict], desde: int | None, hasta: int | None,
		punto_actual: tuple | None = None) -> dict:
	"""`punto_actual` (vivo): valor de este momento, para que el informe no se quede en la última vela."""
	aj = entorno.ajustes
	curva = list(motor.curva) + ([punto_actual] if punto_actual else [])
	m = calcular(curva, cartera.operaciones, cartera.capital_inicial, aj.intervalo_ms)
	refs = [c[2] for c in curva if c[2] is not None]
	referencia = None
	if refs:
		referencia = {
			"valor_final": refs[-1],
			"rentabilidad": (refs[-1] / cartera.capital_inicial - 1) * 100,
			"caida_maxima": caida_maxima(refs, cartera.capital_inicial),
		}
	por_moneda: dict[str, dict] = {}
	for o in cartera.operaciones:
		d = por_moneda.setdefault(o.simbolo, {"operaciones": 0, "ganadoras": 0, "beneficio": 0.0})
		d["operaciones"] += 1
		d["ganadoras"] += o.beneficio > 0
		d["beneficio"] += o.beneficio
	abiertas = []
	for s, p in cartera.posiciones.items():
		precio = motor.ultimo_precio.get(s, p.precio_entrada)
		valor = p.cantidad * precio
		abiertas.append({**asdict(p), "precio_actual": precio, "valor": valor,
			"resultado": valor * (1 - cartera.com) - p.coste})
	return {
		"modo": entorno.modo,
		"generado": int(time.time() * 1000),
		"desde": desde, "hasta": hasta,
		"monedas": list(aj.monedas), "intervalo": aj.intervalo, "cotizacion": aj.cotizacion,
		"capital_inicial": cartera.capital_inicial, "efectivo": cartera.efectivo,
		"comision": aj.general["comision"], "deslizamiento": aj.general["deslizamiento"],
		"ajustes": dict(aj.general),
		"plugins": plugins_info,
		"metricas": m, "referencia": referencia,
		"curva": curva,
		"operaciones": [asdict(o) for o in cartera.operaciones],
		"abiertas": abiertas,
		"por_moneda": por_moneda,
		"bloqueos": dict(motor.bloqueos.most_common()),
		"avisos": list(entorno.avisos),
	}


def info_plugins(clases: list, activos: list) -> list[dict]:
	nombres = {p.nombre for p in activos}
	return [{"nombre": c.nombre, "titulo": c.titulo, "tipo": c.tipo, "activo": c.nombre in nombres,
		"descripcion": c.descripcion} for c in clases]
