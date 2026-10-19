"""Cuentas de la cartera y reglas del motor: precios de ejecución, stops, huecos, memoria de señales…"""
import tempfile
import unittest

from pruebas.utiles import H, T0, ajustes
from nucleo.cartera import Cartera
from nucleo.datos import Vela
from nucleo.entorno import Entorno, Registro
from nucleo.motor import Motor
from nucleo.plugins import Plugin


class TestCartera(unittest.TestCase):
	def test_comprar_y_vender_al_mismo_precio_cuesta_comisiones(self):
		c = Cartera(1000, comision_pct=0.1, deslizamiento_pct=0.05)
		pos = c.comprar("A/USDT", 1000, 100.0, 0)
		self.assertAlmostEqual(pos.precio_entrada, 100.05)
		self.assertAlmostEqual(pos.cantidad, 999 / 100.05)
		self.assertEqual(c.efectivo, 0.0)
		op = c.vender("A/USDT", 100.0, 1, "prueba")
		esperado = (999 / 100.05) * 99.95 * 0.999
		self.assertAlmostEqual(op.ingreso, esperado)
		self.assertAlmostEqual(op.beneficio, esperado - 1000)
		self.assertAlmostEqual(c.efectivo, esperado)
		self.assertAlmostEqual(op.comisiones, 1.0 + (999 / 100.05) * 99.95 * 0.001)
		self.assertAlmostEqual(c.comisiones, op.comisiones)

	def test_limites(self):
		c = Cartera(100, orden_minima=10)
		self.assertIsNone(c.comprar("A/USDT", 5, 10.0, 0), "por debajo de la orden mínima")
		pos = c.comprar("A/USDT", 500, 10.0, 0)
		self.assertAlmostEqual(pos.coste, 100.0, msg="nunca gasta más del efectivo")
		self.assertIsNone(c.comprar("A/USDT", 10, 10.0, 0), "no repite posición")
		self.assertIsNone(c.comprar("B/USDT", 10, 10.0, 0), "sin efectivo")
		self.assertIsNone(c.vender("B/USDT", 10.0, 0, "x"))
		self.assertGreaterEqual(c.efectivo, 0)

	def test_stop_y_objetivo(self):
		c = Cartera(1000, deslizamiento_pct=0)
		pos = c.comprar("A/USDT", 100, 50.0, 0, stop_frac=0.1, objetivo_frac=0.2)
		self.assertAlmostEqual(pos.stop, 45.0)
		self.assertAlmostEqual(pos.objetivo, 60.0)

	def test_guardar_y_cargar(self):
		c = Cartera(1000)
		c.comprar("A/USDT", 200, 10.0, 5, 0.05)
		c.comprar("B/USDT", 200, 20.0, 6)
		c.vender("B/USDT", 22.0, 9, "x")
		d = c.a_dict()
		c2 = Cartera(1)
		c2.cargar_dict(d)
		self.assertEqual(c2.a_dict(), d)
		self.assertAlmostEqual(c2.valor({"A/USDT": 11.0}), c.valor({"A/USDT": 11.0}))


# ---------------------------------------------------------------- motor

class Guion(Plugin):
	"""Estrategia de prueba: da las señales que le digas en las velas que le digas."""
	nombre = "guion"
	titulo = "Guion"
	tipo = "estrategia"

	def __init__(self, senales, entorno, nombre="guion"):
		super().__init__({}, entorno)
		self.senales = senales
		self.nombre = nombre

	def senal(self, ctx):
		return self.senales.get(len(ctx.velas) - 1)


class StopFijo(Plugin):
	nombre = "stop_fijo"
	titulo = "Stop fijo"
	tipo = "riesgo"

	def __init__(self, entorno, frac=0.05, objetivo=None):
		super().__init__({}, entorno)
		self.frac = frac
		self.obj = objetivo

	def stop_inicial(self, ctx, precio):
		return precio * (1 - self.frac)

	def objetivo_inicial(self, ctx, precio, stop):
		return precio * (1 + self.obj) if self.obj else None


class Roto(Plugin):
	nombre = "roto"
	titulo = "Plugin roto"
	tipo = "filtro"

	def permitir_entrada(self, ctx):
		raise RuntimeError("fallo a propósito")


def vela(k, o, h=None, l=None, c=None):
	c = o if c is None else c
	return Vela(T0 + k * H, o, max(o, c) if h is None else h, min(o, c) if l is None else l, c, 100.0)


def plana(n, precio=100.0):
	return [vela(k, precio) for k in range(n)]


class TestMotor(unittest.TestCase):
	def crear(self, plugins_fn, estricto=True, **general):
		g = {"monedas": ["A/USDT", "B/USDT"], "comision": 0.0, "deslizamiento": 0.0, "max_por_operacion": 40}
		g.update(general)
		aj = ajustes(g)
		self.entorno = Entorno("backtest", aj, tempfile.mkdtemp(), Registro(silencioso=True), estricto)
		plugins = plugins_fn(self.entorno)
		self.entorno.plugins = plugins
		self.cartera = Cartera(1000, 0.0, 0.0, 10)
		self.motor = Motor(self.entorno, plugins, self.cartera)
		return self.motor

	def recorrer(self, s, velas):
		for v in velas:
			self.motor.ejecutar_pendiente(s, v.apertura, v.t)
			self.motor.revisar_stops_vela(s, v)
			self.motor.agregar_vela(s, v)

	def test_compra_en_la_apertura_siguiente_no_en_el_cierre_de_la_senal(self):
		self.crear(lambda e: [Guion({5: "comprar"}, e)])
		velas = plana(5) + [vela(5, 100, c=110), vela(6, 111, c=112)]
		self.recorrer("A/USDT", velas[:6])
		self.assertNotIn("A/USDT", self.cartera.posiciones, "la orden espera a la vela siguiente")
		self.recorrer("A/USDT", velas[6:])
		self.assertEqual(self.cartera.posiciones["A/USDT"].precio_entrada, 111)

	def test_stop_dentro_de_la_vela(self):
		self.crear(lambda e: [Guion({5: "comprar"}, e), StopFijo(e, 0.05)])
		self.recorrer("A/USDT", plana(7))   # compra a 100 en la vela 6, stop 95
		self.assertEqual(self.cartera.posiciones["A/USDT"].stop, 95.0)
		self.recorrer("A/USDT", [vela(7, 100, l=94, c=99)])
		op = self.cartera.operaciones[-1]
		self.assertEqual((op.precio_salida, op.motivo_salida), (95.0, "stop loss"))

	def test_hueco_por_debajo_del_stop_sale_a_la_apertura(self):
		self.crear(lambda e: [Guion({5: "comprar"}, e), StopFijo(e, 0.05)])
		self.recorrer("A/USDT", plana(7))
		self.recorrer("A/USDT", [vela(7, 90, l=88, c=91)])
		self.assertEqual(self.cartera.operaciones[-1].precio_salida, 90)

	def test_stop_y_objetivo_en_la_misma_vela_cuenta_el_stop(self):
		self.crear(lambda e: [Guion({5: "comprar"}, e), StopFijo(e, 0.05, objetivo=0.05)])
		self.recorrer("A/USDT", plana(7))
		self.recorrer("A/USDT", [vela(7, 100, h=106, l=94, c=100)])
		self.assertEqual(self.cartera.operaciones[-1].motivo_salida, "stop loss")

	def test_objetivo(self):
		self.crear(lambda e: [Guion({5: "comprar"}, e), StopFijo(e, 0.05, objetivo=0.05)])
		self.recorrer("A/USDT", plana(7))
		self.recorrer("A/USDT", [vela(7, 100, h=106, l=99, c=104)])
		op = self.cartera.operaciones[-1]
		self.assertEqual((op.precio_salida, op.motivo_salida), (105.0, "take profit"))

	def test_no_vuelve_a_entrar_con_una_senal_vieja(self):
		self.crear(lambda e: [Guion({5: "comprar"}, e), StopFijo(e, 0.05)], memoria_senales=5)
		self.recorrer("A/USDT", plana(7) + [vela(7, 100, l=90, c=100)] + plana(12)[8:])
		self.assertEqual(len(self.cartera.operaciones), 1)
		self.assertNotIn("A/USDT", self.cartera.posiciones)

	def test_vende_con_senal_de_venta(self):
		self.crear(lambda e: [Guion({5: "comprar", 8: "vender"}, e)])
		self.recorrer("A/USDT", plana(9) + [vela(9, 120)])
		op = self.cartera.operaciones[-1]
		self.assertEqual(op.precio_salida, 120)
		self.assertIn("señal de venta", op.motivo_salida)

	def test_maximo_de_posiciones(self):
		self.crear(lambda e: [Guion({5: "comprar"}, e)], max_posiciones=1)
		for k in range(7):
			for s in ("A/USDT", "B/USDT"):
				v = vela(k, 100)
				self.motor.ejecutar_pendiente(s, v.apertura, v.t)
				self.motor.agregar_vela(s, v)
		self.assertEqual(list(self.cartera.posiciones), ["A/USDT"])
		self.assertIn("Máximo de posiciones abiertas", self.motor.bloqueos)

	def test_consenso_todas(self):
		self.crear(lambda e: [Guion({5: "comprar"}, e, "a"), Guion({6: "comprar"}, e, "b")],
			modo_entrada="todas", memoria_senales=3)
		self.recorrer("A/USDT", plana(7))
		self.assertNotIn("A/USDT", self.cartera.posiciones)
		self.recorrer("A/USDT", plana(8)[7:])
		self.assertIn("A/USDT", self.cartera.posiciones, "las dos señales están dentro de la memoria")

	def test_consenso_todas_fuera_de_memoria(self):
		self.crear(lambda e: [Guion({2: "comprar"}, e, "a"), Guion({6: "comprar"}, e, "b")],
			modo_entrada="todas", memoria_senales=3)
		self.recorrer("A/USDT", plana(10))
		self.assertNotIn("A/USDT", self.cartera.posiciones)

	def test_plugin_roto_bloquea_la_compra_sin_parar_el_bot(self):
		self.crear(lambda e: [Guion({5: "comprar"}, e), Roto({}, e)], estricto=False)
		self.recorrer("A/USDT", plana(8))
		self.assertNotIn("A/USDT", self.cartera.posiciones)
		self.assertTrue(any("roto" in a[2] for a in self.entorno.avisos))

	def test_plugin_roto_en_modo_estricto_avisa_con_error(self):
		self.crear(lambda e: [Guion({5: "comprar"}, e), Roto({}, e)], estricto=True)
		with self.assertRaises(RuntimeError):
			self.recorrer("A/USDT", plana(8))

	def test_tamano_respeta_el_tope_por_operacion(self):
		self.crear(lambda e: [Guion({5: "comprar"}, e)], max_por_operacion=25)
		self.recorrer("A/USDT", plana(7))
		self.assertAlmostEqual(self.cartera.posiciones["A/USDT"].coste, 250.0)


if __name__ == "__main__":
	unittest.main()
