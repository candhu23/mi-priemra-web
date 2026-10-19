"""Conexión con Binance (simulada: sin Internet), caché de precios, formato español y órdenes de bot.py."""
import io
import json
import os
import tempfile
import time
import unittest
import urllib.error
from contextlib import redirect_stdout
from unittest import mock

from pruebas.utiles import AQUI, H, generar_velas
from nucleo import formato as F
from nucleo.datos import ErrorDatos, FuenteBinance, Vela, combinar, historico, huecos, leer_cache


class Respuesta(io.BytesIO):
	def __enter__(self):
		return self

	def __exit__(self, *a):
		return False


def http_error(codigo, cuerpo=b"{}", cabeceras=None):
	return urllib.error.HTTPError("https://x", codigo, "error", cabeceras or {}, io.BytesIO(cuerpo))


class AbrirFalso:
	"""Sustituye a urlopen: devuelve (o lanza) lo que se le diga, en orden."""

	def __init__(self, respuestas):
		self.respuestas = list(respuestas)
		self.urls = []

	def __call__(self, req, timeout=None):
		self.urls.append(req.full_url)
		r = self.respuestas.pop(0)
		if isinstance(r, Exception):
			raise r
		return Respuesta(json.dumps(r).encode())


def fila(t, c, cierre_t):
	return [t, str(c), str(c + 1), str(c - 1), str(c), "10", cierre_t, "0", 0, "0", "0", "0"]


class TestFuenteBinance(unittest.TestCase):
	def fuente(self, respuestas):
		self.abrir = AbrirFalso(respuestas)
		return FuenteBinance(espera=lambda s: None, abrir=self.abrir)

	def test_descarta_la_vela_que_aun_no_ha_cerrado(self):
		ahora = int(time.time() * 1000)
		f = self.fuente([[fila(ahora - 2 * H, 100, ahora - H - 1), fila(ahora - H, 101, ahora + H)]])
		velas = f.velas("BTC/USDT", "1h")
		self.assertEqual(len(velas), 1)
		self.assertEqual(velas[0].cierre, 100.0)
		self.assertIn("symbol=BTCUSDT", self.abrir.urls[0])

	def test_moneda_que_no_existe(self):
		f = self.fuente([http_error(400, b'{"code":-1121,"msg":"Invalid symbol."}')])
		with self.assertRaises(ErrorDatos) as e:
			f.precio("XXX/USDT")
		self.assertIn("no existe en Binance", str(e.exception))

	def test_si_un_servidor_esta_bloqueado_usa_el_otro(self):
		f = self.fuente([http_error(451), {"price": "123.5"}, {"price": "124"}])
		self.assertEqual(f.precio("BTC/USDT"), 123.5)
		self.assertIn("api.binance.com", self.abrir.urls[1])
		f.precio("BTC/USDT")
		self.assertIn("api.binance.com", self.abrir.urls[2], "recuerda el servidor que funciona")

	def test_reintenta_si_falla_la_red(self):
		f = self.fuente([urllib.error.URLError("sin red"), TimeoutError(), {"price": "1"}])
		self.assertEqual(f.precio("BTC/USDT"), 1.0)

	def test_demasiadas_peticiones_espera(self):
		esperas = []
		self.abrir = AbrirFalso([http_error(429, cabeceras={"Retry-After": "7"}), {"price": "2"}])
		f = FuenteBinance(espera=esperas.append, abrir=self.abrir)
		self.assertEqual(f.precio("BTC/USDT"), 2.0)
		self.assertEqual(esperas, [7.0])

	def test_sin_conexion_da_un_mensaje_claro(self):
		f = self.fuente([urllib.error.URLError("sin red")] * 8)
		with self.assertRaises(ErrorDatos) as e:
			f.precio("BTC/USDT")
		self.assertIn("conexión a Internet", str(e.exception))


class FuenteHistorica:
	def __init__(self, velas):
		self.todas = velas
		self.peticiones = 0
		self.ahora = velas[-1].t + 2 * H

	def ahora_ms(self):
		return self.ahora

	def velas(self, moneda, intervalo, desde=None, hasta=None, limite=1000):
		self.peticiones += 1
		sel = [v for v in self.todas if (desde is None or v.t >= desde) and (hasta is None or v.t <= hasta)
			and v.t + H <= self.ahora]
		return sel[:limite]


class TestHistorico(unittest.TestCase):
	def test_descarga_por_trozos_y_reutiliza_la_cache(self):
		velas = generar_velas(2500)
		fuente = FuenteHistorica(velas)
		cache = tempfile.mkdtemp()
		r = historico(fuente, "AAA/USDT", "1h", velas[0].t, cache)
		self.assertEqual(r, velas)
		self.assertGreaterEqual(fuente.peticiones, 3, "Binance da 1000 velas por petición")
		fuente.peticiones = 0
		r2 = historico(fuente, "AAA/USDT", "1h", velas[100].t, cache)
		self.assertEqual(r2, velas[100:])
		self.assertEqual(fuente.peticiones, 1, "solo pregunta si hay velas nuevas")
		self.assertEqual(leer_cache(os.path.join(cache, "AAAUSDT_1h.csv")), velas)

	def test_combinar_y_huecos(self):
		a = [Vela(0, 1, 1, 1, 1, 1), Vela(H, 2, 2, 2, 2, 2)]
		b = [Vela(H, 3, 3, 3, 3, 3), Vela(4 * H, 4, 4, 4, 4, 4)]
		c = combinar(a, b)
		self.assertEqual([v.t for v in c], [0, H, 4 * H])
		self.assertEqual(c[1].cierre, 3)
		self.assertEqual(huecos(c, H), [(H, 4 * H)])

	def test_cache_estropeada_se_ignora(self):
		ruta = os.path.join(tempfile.mkdtemp(), "x.csv")
		with open(ruta, "w") as f:
			f.write("t,apertura\nhola,adios\n")
		self.assertEqual(leer_cache(ruta), [])


class TestFormato(unittest.TestCase):
	def test_numeros_a_la_espanola(self):
		self.assertEqual(F.num(1234567.891), "1.234.567,89")
		self.assertEqual(F.num(-0.5, 1), "-0,5")
		self.assertEqual(F.pct(3.456), "+3,46 %")
		self.assertEqual(F.pct(-2), "-2,00 %")
		self.assertEqual(F.precio(82731.456), "82.731,46")
		self.assertEqual(F.precio(0.00001234), "0,00001234")
		self.assertEqual(F.num(None), "—")
		self.assertEqual(F.num(float("inf")), "∞")
		self.assertEqual(F.duracion(90 * 60_000), "1 h")


class TestOrdenes(unittest.TestCase):
	def ejecutar(self, *args):
		import bot
		salida = io.StringIO()
		with redirect_stdout(salida):
			codigo = bot.main(list(args))
		return codigo, salida.getvalue()

	def test_plugins(self):
		codigo, texto = self.ejecutar("plugins")
		self.assertEqual(codigo, 0)
		self.assertIn("15 plugins", texto)
		self.assertIn(" 1. [ACTIVO]      Cruce de medias", texto)
		self.assertIn("15. [ACTIVO]      Avisos por Telegram", texto)

	def test_informe_sin_informes(self):
		codigo, texto = self.ejecutar("--carpeta", tempfile.mkdtemp(), "informe")
		self.assertEqual(codigo, 1)
		self.assertIn("Todavía no hay", texto)

	def test_reiniciar(self):
		carpeta = tempfile.mkdtemp()
		os.makedirs(os.path.join(carpeta, "estado"))
		ruta = os.path.join(carpeta, "estado", "simulacion.json")
		with open(ruta, "w") as f:
			f.write("{}")
		codigo, _ = self.ejecutar("--carpeta", carpeta, "reiniciar", "--si")
		self.assertEqual(codigo, 0)
		self.assertFalse(os.path.exists(ruta))
		with mock.patch("builtins.input", return_value="no"):
			with open(ruta, "w") as f:
				f.write("{}")
			self.ejecutar("--carpeta", carpeta, "reiniciar")
		self.assertTrue(os.path.exists(ruta), "sin escribir SI no borra nada")

	def test_ajustes_rotos_dan_mensaje_y_codigo(self):
		ruta = os.path.join(tempfile.mkdtemp(), "a.toml")
		with open(ruta, "w", encoding="utf-8") as f:
			f.write('[general]\ncapital_inicial = "mucho"\n')
		codigo, texto = self.ejecutar("--ajustes", ruta, "plugins")
		self.assertEqual(codigo, 2)
		self.assertIn("PROBLEMA EN LOS AJUSTES", texto)

	def test_sin_orden_muestra_la_ayuda(self):
		codigo, texto = self.ejecutar()
		self.assertEqual(codigo, 0)
		self.assertIn("SOLO SIMULACIÓN", texto)

	def test_el_menu_de_windows_llama_a_ordenes_que_existen(self):
		import re
		with open(os.path.join(AQUI, "INICIAR.bat"), "rb") as f:
			contenido = f.read()
		self.assertIn(b"\r\n", contenido, "el .bat necesita saltos de línea de Windows (CRLF)")
		self.assertNotIn(b"\n", contenido.replace(b"\r\n", b""), "ningún salto de línea suelto")
		self.assertTrue(all(b < 128 for b in contenido), "solo caracteres simples (sin tildes) en el .bat")
		ordenes = set(re.findall(r"bot\.py (\w[\w-]*)", contenido.decode()))
		self.assertEqual(ordenes, {"backtest", "simular", "informe", "plugins", "telegram", "reiniciar", "autotest"})


if __name__ == "__main__":
	unittest.main()
