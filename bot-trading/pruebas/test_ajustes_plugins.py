"""Ajustes (errores claros en español) y cada uno de los 15 plugins por separado."""
import os
import tempfile
import tomllib
import unittest
from unittest import mock

from pruebas.utiles import AQUI, H, NOMBRES, PLUGINS, ajustes, generar_velas
from nucleo.cartera import Cartera, Operacion, Posicion
from nucleo.config import ErrorAjustes, cargar_ajustes, cargar_secretos, leer_toml
from nucleo.entorno import Entorno, Registro
from nucleo.indicadores import Indicadores, Velas
from nucleo.plugins import cargar_plugins, descubrir

AJUSTES = os.path.join(AQUI, "ajustes.toml")


def escribir(texto, bom=False):
	ruta = os.path.join(tempfile.mkdtemp(), "a.toml")
	with open(ruta, "wb") as f:
		f.write((b"\xef\xbb\xbf" if bom else b"") + texto.encode("utf-8"))
	return ruta


class TestAjustes(unittest.TestCase):
	def test_el_archivo_entregado_carga_sin_avisos(self):
		aj = cargar_ajustes(AJUSTES)
		entorno = Entorno("backtest", aj, tempfile.mkdtemp(), Registro(silencioso=True))
		cargar_plugins(PLUGINS, aj, entorno)
		self.assertEqual(aj.avisos, [])

	def test_el_archivo_documenta_todos_los_parametros_con_sus_valores_reales(self):
		"""Cada plugin aparece en ajustes.toml con todos sus parámetros y los valores por defecto del código."""
		datos = leer_toml(AJUSTES)["plugins"]
		for c in descubrir(PLUGINS):
			self.assertIn(c.nombre, datos, f"falta [plugins.{c.nombre}] en ajustes.toml")
			seccion = datos[c.nombre]
			self.assertEqual(set(seccion), {"activo", *c.parametros}, c.nombre)
			self.assertEqual(seccion["activo"], c.activo_por_defecto, c.nombre)
			for k, p in c.parametros.items():
				self.assertEqual(seccion[k], p.defecto, f"[plugins.{c.nombre}] {k}")

	def test_clave_mal_escrita_avisa_con_sugerencia(self):
		aj = ajustes({"capital_inicail": 5})
		self.assertTrue(any("capital_inicial" in a for a in aj.avisos), aj.avisos)

	def test_errores_de_tipo(self):
		with self.assertRaises(ErrorAjustes) as e:
			ajustes({"capital_inicial": "mil"})
		self.assertIn("capital_inicial", str(e.exception))
		with self.assertRaises(ErrorAjustes) as e:
			ajustes({"intervalo": "3h"})
		self.assertIn("4h", str(e.exception))
		with self.assertRaises(ErrorAjustes):
			ajustes({"max_posiciones": 2.5})
		with self.assertRaises(ErrorAjustes):
			ajustes({"comision": 50})

	def test_monedas(self):
		self.assertEqual(ajustes({"monedas": ["btc/usdt", "ETH-USDT", "BTC/USDT"]}).monedas, ["BTC/USDT", "ETH/USDT"])
		with self.assertRaises(ErrorAjustes):
			ajustes({"monedas": ["BTC/USDT", "ETH/EUR"]})
		with self.assertRaises(ErrorAjustes):
			ajustes({"monedas": ["BTCUSDT"]})
		with self.assertRaises(ErrorAjustes):
			ajustes({"monedas": []})

	def test_archivo_con_marca_bom_del_bloc_de_notas(self):
		aj = cargar_ajustes(escribir('[general]\nintervalo = "1h"\n', bom=True))
		self.assertEqual(aj.intervalo, "1h")

	def test_formato_roto_explica_como_arreglarlo(self):
		with self.assertRaises(ErrorAjustes) as e:
			cargar_ajustes(escribir("[general]\nintervalo = 1h\n"))
		self.assertIn("Pistas", str(e.exception))
		with self.assertRaises(ErrorAjustes):
			cargar_ajustes("/no/existe.toml")

	def test_parametros_de_plugins(self):
		entorno = lambda aj: Entorno("backtest", aj, tempfile.mkdtemp(), Registro(silencioso=True))
		aj = ajustes(plugins={"rsi": {"activo": True, "periodo": "x"}})
		with self.assertRaises(ErrorAjustes):
			cargar_plugins(PLUGINS, aj, entorno(aj))
		aj = ajustes(plugins={"cruce_medias": {"rapida": 30, "lenta": 20}})
		with self.assertRaises(ErrorAjustes):
			cargar_plugins(PLUGINS, aj, entorno(aj))
		aj = ajustes(plugins={"rsii": {"activo": True}, "rsi": {"perido": 3}})
		cargar_plugins(PLUGINS, aj, entorno(aj))
		self.assertTrue(any("'rsi'" in a for a in aj.avisos), aj.avisos)
		self.assertTrue(any("periodo" in a for a in aj.avisos), aj.avisos)

	def test_secretos(self):
		ruta = escribir('[telegram]\ntoken = "1:abc"\nchat_id = "5"\n')
		with mock.patch.dict(os.environ, {"TELEGRAM_CHAT_ID": "99"}, clear=True):
			self.assertEqual(cargar_secretos(ruta), {"telegram_token": "1:abc", "telegram_chat_id": "99"},
				"las variables de entorno mandan")
		with mock.patch.dict(os.environ, {}, clear=True):
			self.assertEqual(cargar_secretos(None), {})
			self.assertEqual(cargar_secretos("/no/existe.toml"), {})


# ---------------------------------------------------------------- plugins

class Ctx:
	"""Contexto mínimo para probar un plugin sin el motor."""

	def __init__(self, velas_lista, valor=1000.0, tiempo=None, simbolo="AAA/USDT", entorno=None, posiciones=None):
		self.velas = Velas()
		for v in velas_lista:
			self.velas.agregar(v)
		self.ind = Indicadores(self.velas)
		self.precio = self.velas.cierre[-1] if velas_lista else 100.0
		self.tiempo = tiempo if tiempo is not None else (self.velas.t[-1] + H if velas_lista else 0)
		self.simbolo = simbolo
		self._valor = valor
		self.intervalo_ms = H

		class _M:
			pass
		self.motor = _M()
		self.motor.cartera = Cartera(1000)
		self.motor.cartera.posiciones = posiciones or {}

	def valor_total(self):
		return self._valor


def instanciar(nombre, modo_bot="backtest", secretos=None, **params):
	aj = ajustes(plugins={nombre: {"activo": True, **params}}, secretos=secretos)
	entorno = Entorno(modo_bot, aj, tempfile.mkdtemp(), Registro(silencioso=True))
	plugins = [p for p in cargar_plugins(PLUGINS, aj, entorno) if p.nombre == nombre]
	entorno.plugins = plugins
	return plugins[0]


def posicion(precio=100.0, maximo=None, stop=None):
	return Posicion("AAA/USDT", 1.0, precio, precio, 0.1, 0, stop, None, maximo or precio)


def operacion(beneficio, t=0):
	return Operacion("AAA/USDT", t, t, 100, 100, 1, 100, 100 + beneficio, beneficio, beneficio, 0.2, "x", "y")


class TestPlugins(unittest.TestCase):
	def test_son_15_bien_definidos(self):
		clases = descubrir(PLUGINS)
		self.assertEqual(len(clases), 15)
		self.assertEqual(sorted(c.nombre for c in clases), sorted(NOMBRES))
		self.assertEqual([c.orden for c in clases], list(range(1, 16)), "numerados del 1 al 15 en orden")
		tipos = [c.tipo for c in clases]
		self.assertEqual((tipos.count("estrategia"), tipos.count("filtro"), tipos.count("riesgo"), tipos.count("info")),
			(4, 3, 5, 3))
		for c in clases:
			self.assertTrue(c.titulo and len(c.descripcion) > 60, c.nombre)

	def test_estrategias_dan_senales_en_datos_reales(self):
		velas = generar_velas(1500, semilla=3)
		for nombre in ("cruce_medias", "rsi", "bollinger", "macd"):
			p = instanciar(nombre)
			v = Velas()
			ind = Indicadores(v)
			vistas = set()
			for x in velas:
				v.agregar(x)
				ctx = type("C", (), {"ind": ind, "velas": v, "precio": x.cierre})()
				r = p.senal(ctx)
				self.assertIn(r, (None, "comprar", "vender"))
				vistas.add(r)
			self.assertEqual(vistas, {None, "comprar", "vender"}, nombre)

	def test_filtros(self):
		subida = [v._replace(cierre=100 + k * 0.5, apertura=100 + k * 0.5, maximo=101 + k * 0.5, minimo=99 + k * 0.5)
			for k, v in enumerate(generar_velas(260))]
		bajada = [v._replace(cierre=300 - k * 0.5, apertura=300 - k * 0.5, maximo=301 - k * 0.5, minimo=299 - k * 0.5)
			for k, v in enumerate(generar_velas(260))]
		f = instanciar("filtro_tendencia")
		self.assertIs(f.permitir_entrada(Ctx(subida)), True)
		self.assertFalse(f.permitir_entrada(Ctx(bajada))[0])
		self.assertFalse(f.permitir_entrada(Ctx(subida[:50]))[0], "sin velas suficientes no deja comprar")
		vol = instanciar("filtro_volatilidad", minimo=0.3, maximo=8.0)
		self.assertIs(vol.permitir_entrada(Ctx(subida)), True)   # ATR ~2 sobre ~200 = 1 %
		self.assertFalse(instanciar("filtro_volatilidad", minimo=5.0, maximo=8.0).permitir_entrada(Ctx(subida))[0])
		v = instanciar("filtro_volumen", factor=1.2)
		normal = generar_velas(40)
		normal = [x._replace(volumen=100) for x in normal]
		self.assertFalse(v.permitir_entrada(Ctx(normal))[0])
		normal[-1] = normal[-1]._replace(volumen=200)
		self.assertIs(v.permitir_entrada(Ctx(normal)), True)

	def test_tamano_posicion(self):
		p = instanciar("tamano_posicion", riesgo_por_operacion=1.0, sin_stop=10.0)
		self.assertAlmostEqual(p.tamano(Ctx([], valor=1000), 100.0, 95.0), 200.0)
		self.assertAlmostEqual(p.tamano(Ctx([], valor=1000), 100.0, None), 100.0)

	def test_stop_loss(self):
		velas = generar_velas(100)
		ctx = Ctx(velas)
		atr = ctx.ind.atr(14)
		self.assertAlmostEqual(instanciar("stop_loss", modo="atr", multiplicador_atr=2.0).stop_inicial(ctx, 100.0), 100 - 2 * atr)
		self.assertAlmostEqual(instanciar("stop_loss", modo="porcentaje", porcentaje=5.0).stop_inicial(ctx, 100.0), 95.0)

	def test_take_profit(self):
		self.assertAlmostEqual(instanciar("take_profit", modo="ratio", ratio=2.0).objetivo_inicial(None, 100.0, 95.0), 110.0)
		self.assertAlmostEqual(instanciar("take_profit", modo="ratio").objetivo_inicial(None, 100.0, None), 110.0)
		self.assertAlmostEqual(instanciar("take_profit", modo="porcentaje", porcentaje=7.0).objetivo_inicial(None, 100.0, 95.0), 107.0)

	def test_trailing_stop(self):
		ctx = Ctx(generar_velas(100))
		atr = ctx.ind.atr(14)
		t = instanciar("trailing_stop", multiplicador_atr=3.0, activar_tras_ganancia=0.0)
		self.assertAlmostEqual(t.actualizar_stop(ctx, posicion(100, maximo=120)), 120 - 3 * atr)
		t2 = instanciar("trailing_stop", activar_tras_ganancia=30.0)
		self.assertIsNone(t2.actualizar_stop(ctx, posicion(100, maximo=120)))

	def test_freno_perdidas_seguidas(self):
		f = instanciar("freno_emergencia", perdidas_seguidas_max=3, velas_pausa_tras_perdidas=10)
		for k in range(3):
			f.al_cerrar(operacion(-5, t=k * H))
		self.assertFalse(f.permitir_entrada(Ctx([], tiempo=5 * H))[0])
		self.assertIs(f.permitir_entrada(Ctx([], tiempo=13 * H)), True)
		f.al_cerrar(operacion(-5, t=20 * H))
		f.al_cerrar(operacion(+5, t=21 * H))
		f.al_cerrar(operacion(-5, t=22 * H))
		self.assertIs(f.permitir_entrada(Ctx([], tiempo=23 * H)), True, "una ganancia reinicia la cuenta")

	def test_freno_perdida_diaria(self):
		f = instanciar("freno_emergencia", perdida_diaria_max=5.0)
		dia = 20_000 * 86_400_000
		f.en_cada_vela(Ctx([], valor=1000, tiempo=dia + H))
		f.en_cada_vela(Ctx([], valor=940, tiempo=dia + 5 * H))
		self.assertFalse(f.permitir_entrada(Ctx([], valor=940, tiempo=dia + 6 * H))[0])
		self.assertIs(f.permitir_entrada(Ctx([], valor=940, tiempo=dia + 86_400_000 + H)), True, "mañana vuelve")

	def test_freno_caida_maxima_vende_todo(self):
		f = instanciar("freno_emergencia", caida_maxima=20.0, dias_pausa_tras_caida=7, perdida_diaria_max=50.0)
		pos = {"AAA/USDT": posicion(), "BBB/USDT": posicion()}
		f.en_cada_vela(Ctx([], valor=1000, tiempo=H, posiciones=pos))
		f.en_cada_vela(Ctx([], valor=790, tiempo=3 * 86_400_000, posiciones=pos))
		self.assertEqual(f.forzar_salida(Ctx([], simbolo="AAA/USDT"), pos["AAA/USDT"]), "freno de emergencia (caída máxima)")
		self.assertIsNone(f.forzar_salida(Ctx([], simbolo="AAA/USDT"), pos["AAA/USDT"]), "solo una vez")
		self.assertFalse(f.permitir_entrada(Ctx([], tiempo=5 * 86_400_000))[0])
		self.assertIs(f.permitir_entrada(Ctx([], tiempo=11 * 86_400_000)), True)

	def test_freno_guarda_y_recupera_su_estado(self):
		f = instanciar("freno_emergencia")
		f.al_cerrar(operacion(-1))
		f2 = instanciar("freno_emergencia")
		f2.cargar_estado(f.guardar_estado())
		self.assertEqual(f2.seguidas, 1)

	def test_telegram_sin_configurar_no_hace_nada(self):
		t = instanciar("telegram", modo_bot="vivo")
		with mock.patch.object(type(t), "enviar_api") as api:
			t.al_iniciar()
			t.al_abrir(posicion())
		self.assertEqual(api.call_count, 0)
		self.assertFalse(t.listo())

	def test_telegram_nunca_envia_en_la_prueba_con_el_pasado(self):
		t = instanciar("telegram", modo_bot="backtest", secretos={"telegram_token": "1:x", "telegram_chat_id": "2"})
		with mock.patch.object(type(t), "enviar_api") as api:
			t.al_iniciar()
			t.al_abrir(posicion())
			t.al_cerrar(operacion(5))
			t.al_aviso("hola", "aviso")
		self.assertEqual(api.call_count, 0)

	def test_telegram_en_vivo_y_tolerante_a_fallos(self):
		t = instanciar("telegram", modo_bot="vivo", secretos={"telegram_token": "1:x", "telegram_chat_id": "2"})
		enviados = []
		with mock.patch.object(type(t), "enviar_api", staticmethod(lambda tok, m, d=None: enviados.append(d["text"]))):
			t.al_abrir(posicion())
			t.al_cerrar(operacion(5))
			t.al_aviso("cuidado", "aviso")
			t.al_aviso("info", "info")
		self.assertEqual(len(enviados), 3)
		self.assertIn("COMPRA", enviados[0])
		with mock.patch.object(type(t), "enviar_api", side_effect=OSError("sin red")):
			for _ in range(8):
				self.assertFalse(t.enviar("x"))
		self.assertFalse(t.listo(), "tras 5 fallos deja de intentarlo")

	def test_diario_reintenta_si_el_csv_esta_abierto(self):
		d = instanciar("diario", modo_bot="vivo")
		original = d._escribir
		with mock.patch.object(d, "_escribir", side_effect=PermissionError("abierto en Excel")):
			d.al_cerrar(operacion(5))
		self.assertEqual(len(d.por_escribir), 1)
		d._escribir = original
		d.al_cerrar(operacion(-3))
		self.assertEqual(d.por_escribir, [])
		with open(d._ruta(), encoding="utf-8-sig") as f:
			self.assertEqual(len(f.read().strip().splitlines()), 3)


if __name__ == "__main__":
	unittest.main()
