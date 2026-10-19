#!/usr/bin/env python3
"""Bot de trading de criptomonedas — SOLO SIMULACIÓN (no usa dinero real ni claves de exchange).

Uso (o usa el menú INICIAR.bat en Windows):
  python bot.py backtest            prueba la estrategia con los últimos días del pasado
  python bot.py simular             simulación en tiempo real con dinero de mentira
  python bot.py informe             abre el último informe
  python bot.py plugins             lista los plugins y si están activos
  python bot.py telegram            configura y prueba los avisos por Telegram
  python bot.py reiniciar           borra la simulación en vivo para empezar de cero
  python bot.py autotest            comprueba que todo funciona (sin Internet)
"""
from __future__ import annotations

import sys

if sys.version_info < (3, 11):
	print("Este bot necesita Python 3.11 o más nuevo. Descárgalo gratis en https://www.python.org/downloads/")
	sys.exit(1)

import argparse
import os
import re
import textwrap
import unittest
import webbrowser
from pathlib import Path

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)

from nucleo import estado  # noqa: E402
from nucleo import formato as F  # noqa: E402
from nucleo.backtest import ejecutar as ejecutar_backtest  # noqa: E402
from nucleo.config import ErrorAjustes, cargar_ajustes  # noqa: E402
from nucleo.datos import ErrorDatos, FuenteBinance  # noqa: E402
from nucleo.estado import ErrorEstado  # noqa: E402
from nucleo.entorno import Registro  # noqa: E402
from nucleo.plugins import NOMBRES_TIPO, descubrir  # noqa: E402
from nucleo.vivo import SimulacionEnVivo  # noqa: E402

LINEA = "=" * 64


def _utf8() -> None:
	for flujo in (sys.stdout, sys.stderr):
		try:
			flujo.reconfigure(encoding="utf-8", errors="replace")
		except (AttributeError, ValueError):
			pass


def _carpetas(args) -> dict[str, str]:
	base = os.path.abspath(args.carpeta or AQUI)
	return {
		"plugins": os.path.join(AQUI, "plugins"),
		"resultados": os.path.join(base, "resultados"),
		"datos": os.path.join(base, "datos"),
		"estado": os.path.join(base, "estado"),
		"secretos": _ruta_secretos(base),
	}


def _ruta_secretos(base: str) -> str:
	"""secretos.toml (o secretos.toml.txt, que es como lo guarda a veces el Bloc de notas)."""
	ruta = os.path.join(base, "secretos.toml")
	if not os.path.exists(ruta) and os.path.exists(ruta + ".txt"):
		return ruta + ".txt"
	return ruta


def _ajustes(args, c):
	return cargar_ajustes(args.ajustes or os.path.join(AQUI, "ajustes.toml"), c["secretos"])


def _abrir(ruta: str) -> None:
	try:
		webbrowser.open(Path(ruta).resolve().as_uri())
	except Exception:
		pass


def _texto_veredicto(m: dict, ref: dict | None) -> list[str]:
	lineas = []
	if ref:
		if m["rentabilidad"] >= ref["rentabilidad"]:
			lineas.append("El bot lo ha hecho MEJOR que comprar y mantener en este periodo.")
		else:
			lineas.append("El bot lo ha hecho PEOR que comprar y mantener en este periodo.")
	if m["operaciones"] < 30:
		lineas.append(f"Ojo: solo {m['operaciones']} operaciones; con tan pocas el resultado puede ser suerte.")
	lineas.append("Recuerda: que funcionara en el pasado no garantiza que funcione en el futuro.")
	return lineas


# ------------------------------------------------------------------ órdenes
def orden_backtest(args) -> int:
	c = _carpetas(args)
	aj = _ajustes(args, c)
	print(LINEA)
	print("  PRUEBA CON EL PASADO (dinero simulado)")
	print(LINEA)
	dias = args.dias or aj.backtest["dias"]
	print(f"Monedas: {', '.join(aj.monedas)} · velas de {aj.intervalo} · {dias} días")
	print("Bajando precios de Binance (la primera vez tarda un poco; luego se guardan en datos/)…")
	r = ejecutar_backtest(aj, c["plugins"], c["resultados"], fuente=FuenteBinance(), dias=dias,
		carpeta_cache=c["datos"], estricto=True)
	m, ref, cot = r["metricas"], r["referencia"], r["cotizacion"]
	print()
	print(LINEA)
	print("  RESULTADO")
	print(LINEA)
	print(f"  Periodo:            {F.fecha(r['desde'], False)} → {F.fecha(r['hasta'], False)}")
	print(f"  Capital:            {F.num(r['capital_inicial'])} → {F.num(m['valor_final'])} {cot} ({F.pct(m['rentabilidad'])})")
	if ref:
		print(f"  Comprar y mantener: {F.pct(ref['rentabilidad'])}")
	ref_caida = f"   (comprar y mantener: -{F.num(ref['caida_maxima'])} %)" if ref else ""
	print(f"  Caída máxima:       -{F.num(m['caida_maxima'])} %{ref_caida}".replace("-0,00 %", "0,00 %"))
	acierto = f" · {F.num(m['aciertos'], 0)} % ganadoras" if m["aciertos"] is not None else ""
	fb = m["factor_beneficio"]
	print(f"  Operaciones:        {m['operaciones']}{acierto} · factor de beneficio {F.num(fb) if fb is not None else '—'}")
	print(f"  Comisiones pagadas: {F.num(m['comisiones'])} {cot}")
	print()
	for linea in _texto_veredicto(m, ref):
		print("  " + linea)
	print()
	avisos = [a for a in r.get("avisos", []) if a[1] == "aviso"]
	if avisos:
		print(f"  Avisos durante la prueba: {len(avisos)} (p. ej. el freno de emergencia). Están en el informe.")
	for ruta in r.get("archivos", []):
		print(f"  Archivo: {ruta}")
	if r.get("informe") and aj.backtest["abrir_informe"] and not args.sin_abrir:
		_abrir(r["informe"])
	return 0


def orden_simular(args) -> int:
	c = _carpetas(args)
	aj = _ajustes(args, c)
	print(LINEA)
	print("  SIMULACIÓN EN TIEMPO REAL — dinero de MENTIRA, nada es real")
	print(LINEA)
	print(f"Monedas: {', '.join(aj.monedas)} · velas de {aj.intervalo} · mira el precio cada "
		f"{aj.vivo['segundos_entre_consultas']} s")
	print("El bot decide cada vez que se cierra una vela. Déjalo abierto; para pararlo pulsa Ctrl+C")
	print("(todo queda guardado y la próxima vez continúa donde lo dejó).")
	print()
	registro = Registro(os.path.join(c["resultados"], "registro_simulacion.log"))
	os.makedirs(c["resultados"], exist_ok=True)
	sim = SimulacionEnVivo(aj, c["plugins"], c["resultados"], c["estado"], FuenteBinance(), registro=registro)
	sim.preparar()
	if sim.continuada:
		print(f"Continúo la simulación que empezó el {F.fecha(sim.inicio)}.")
	else:
		print(f"Simulación nueva con {F.num(aj.general['capital_inicial'])} {aj.cotizacion} de mentira.")
	print(f"Informe (se actualiza solo): {os.path.join(c['resultados'], 'informe_simulacion.html')}")
	print()
	r = sim.bucle()
	if r:
		m = r["metricas"]
		print()
		print(f"Bot parado. Valor de la cartera: {F.num(m['valor_final'])} {r['cotizacion']} ({F.pct(m['rentabilidad'])}).")
	return 0


def orden_informe(args) -> int:
	c = _carpetas(args)
	candidatos = [os.path.join(c["resultados"], n) for n in ("informe_backtest.html", "informe_simulacion.html")]
	existentes = [r for r in candidatos if os.path.exists(r)]
	if not existentes:
		print("Todavía no hay ningún informe. Haz primero una prueba con el pasado o una simulación.")
		return 1
	ruta = max(existentes, key=os.path.getmtime)
	print(f"Abriendo {ruta}")
	_abrir(ruta)
	return 0


def orden_plugins(args) -> int:
	c = _carpetas(args)
	aj = _ajustes(args, c)
	clases = descubrir(c["plugins"])
	print(f"{len(clases)} plugins (actívalos o desactívalos en ajustes.toml con activo = true / false)\n")
	n = 0
	for tipo, titulo in NOMBRES_TIPO.items():
		del_tipo = [k for k in clases if k.tipo == tipo]
		if not del_tipo:
			continue
		print(titulo.upper())
		for k in del_tipo:
			n += 1
			activo = aj.plugins.get(k.nombre, {}).get("activo", k.activo_por_defecto)
			marca = "[ACTIVO]     " if activo else "[desactivado]"
			print(f" {n:2}. {marca} {k.titulo}  ([plugins.{k.nombre}])")
			for linea in textwrap.wrap(k.descripcion, 74):
				print(f"       {linea}")
		print()
	return 0


def orden_reiniciar(args) -> int:
	c = _carpetas(args)
	ruta = os.path.join(c["estado"], "simulacion.json")
	if not any(os.path.exists(ruta + x) for x in ("", ".bak")):
		print("No hay ninguna simulación guardada: ya empiezas de cero.")
		return 0
	if not args.si:
		resp = input("Esto borra la simulación en vivo (cartera y operaciones). Escribe SI para confirmar: ")
		if resp.strip().upper() not in ("SI", "SÍ"):
			print("Cancelado: no he borrado nada.")
			return 0
	estado.borrar(ruta)
	print("Simulación borrada. La próxima empieza de cero (los CSV e informes antiguos siguen en resultados/).")
	return 0


def _guardar_secretos(ruta: str, token: str, chat: str | None) -> None:
	lineas = ["# Secretos del bot. NO compartas este archivo con nadie.", "[telegram]", f'token = "{token}"']
	if chat:
		lineas.append(f'chat_id = "{chat}"')
	with open(ruta, "w", encoding="utf-8") as f:
		f.write("\n".join(lineas) + "\n")


def orden_telegram(args) -> int:
	from plugins_telegram import llamar_api  # cargado abajo con importlib
	c = _carpetas(args)
	aj = _ajustes(args, c)
	token = aj.secretos.get("telegram_token")
	chat = aj.secretos.get("telegram_chat_id")
	print("CONFIGURAR AVISOS POR TELEGRAM\n")
	if not token:
		print("1. En Telegram, busca @BotFather, escríbele /newbot y sigue los pasos.")
		print("2. Te dará un 'token' (algo como 123456789:ABCdef...). Cópialo.\n")
		token = input("Pega aquí el token y pulsa Enter: ").strip().strip('"')
	if not re.fullmatch(r"\d{5,}:[A-Za-z0-9_-]{20,}", token or ""):
		print("Eso no parece un token de Telegram. Debe ser como 123456789:ABCdef... Vuelve a intentarlo.")
		return 1
	try:
		yo = llamar_api(token, "getMe")["result"]
	except Exception as e:
		print(f"Telegram no acepta ese token ({e}). Comprueba que lo has copiado entero.")
		return 1
	usuario = yo.get("username", "tu bot")
	_guardar_secretos(c["secretos"], token, chat)
	if not chat:
		print(f"\nAhora abre Telegram, busca a @{usuario} y mándale cualquier mensaje (por ejemplo: hola).")
		for _ in range(3):
			input("Cuando lo hayas mandado, pulsa Enter aquí… ")
			try:
				updates = llamar_api(token, "getUpdates")["result"]
			except Exception as e:
				print(f"No he podido leer los mensajes ({e}).")
				continue
			chats = [u["message"]["chat"]["id"] for u in updates if "message" in u]
			if chats:
				chat = str(chats[-1])
				break
			print("Todavía no veo tu mensaje. Asegúrate de escribir al bot correcto y vuelve a probar.")
		if not chat:
			print("No he encontrado tu mensaje. Inténtalo de nuevo más tarde.")
			return 1
		_guardar_secretos(c["secretos"], token, chat)
	try:
		llamar_api(token, "sendMessage", {"chat_id": chat, "text": "✅ Avisos del bot de trading SIMULADO configurados."})
	except Exception as e:
		print(f"No he podido enviar el mensaje de prueba ({e}).")
		return 1
	print(f"\nListo: te he mandado un mensaje de prueba. Datos guardados en {c['secretos']}")
	print("(no compartas ese archivo: con el token cualquiera podría escribir como tu bot).")
	return 0


def orden_autotest(args) -> int:
	print("Comprobando el bot (sin Internet y sin tocar tus datos)…\n")
	cargador = unittest.TestLoader()
	suite = cargador.discover(os.path.join(AQUI, "pruebas"), top_level_dir=AQUI)
	res = unittest.TextTestRunner(verbosity=1 if not args.detalle else 2).run(suite)
	print()
	if res.wasSuccessful():
		print(f"TODO OK: {res.testsRun} pruebas superadas.")
		return 0
	print(f"FALLAN {len(res.failures) + len(res.errors)} de {res.testsRun} pruebas. Mira los detalles de arriba.")
	return 1


def _cargar_modulo_telegram() -> None:
	"""Hace importable el plugin de Telegram como 'plugins_telegram' (para la orden 'telegram')."""
	import importlib.util
	ruta = os.path.join(AQUI, "plugins", "telegram.py")
	spec = importlib.util.spec_from_file_location("plugins_telegram", ruta)
	mod = importlib.util.module_from_spec(spec)
	sys.modules["plugins_telegram"] = mod
	spec.loader.exec_module(mod)


def main(argv: list[str] | None = None) -> int:
	_utf8()
	p = argparse.ArgumentParser(prog="bot.py", description="Bot de trading de criptomonedas (SOLO SIMULACIÓN)")
	p.add_argument("--ajustes", help="otro archivo de ajustes (por defecto ajustes.toml)")
	p.add_argument("--carpeta", help="carpeta para resultados/, datos/ y estado/ (por defecto la del bot)")
	sub = p.add_subparsers(dest="orden")
	b = sub.add_parser("backtest", help="probar con el pasado")
	b.add_argument("--dias", type=int, help="días del pasado (por defecto los de ajustes.toml)")
	b.add_argument("--sin-abrir", action="store_true", help="no abrir el informe al terminar")
	sub.add_parser("simular", help="simulación en tiempo real con dinero de mentira")
	sub.add_parser("informe", help="abrir el último informe")
	sub.add_parser("plugins", help="ver los plugins")
	sub.add_parser("telegram", help="configurar los avisos por Telegram")
	r = sub.add_parser("reiniciar", help="borrar la simulación en vivo")
	r.add_argument("--si", action="store_true", help="no pedir confirmación")
	a = sub.add_parser("autotest", help="comprobar que todo funciona")
	a.add_argument("--detalle", action="store_true")
	args = p.parse_args(argv)
	ordenes = {"backtest": orden_backtest, "simular": orden_simular, "informe": orden_informe,
		"plugins": orden_plugins, "telegram": orden_telegram, "reiniciar": orden_reiniciar, "autotest": orden_autotest}
	if args.orden not in ordenes:
		p.print_help()
		return 0
	try:
		if args.orden == "telegram":
			_cargar_modulo_telegram()
		return ordenes[args.orden](args)
	except ErrorAjustes as e:
		print(f"\nPROBLEMA EN LOS AJUSTES: {e}")
		return 2
	except ErrorDatos as e:
		print(f"\nPROBLEMA CON LOS PRECIOS: {e}")
		return 3
	except ErrorEstado as e:
		print(f"\nPROBLEMA CON LA SIMULACIÓN GUARDADA: {e}")
		return 4
	except KeyboardInterrupt:
		print("\nCancelado.")
		return 130


if __name__ == "__main__":
	sys.exit(main())
