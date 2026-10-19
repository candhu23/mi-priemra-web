"""Prueba con el pasado y simulación en vivo de punta a punta (con precios inventados)."""
import csv
import json
import os
import tempfile
import unittest

from pruebas.utiles import H, PLUGINS, FuenteFalsa, ajustes, generar_velas, solo, todos_activos
from nucleo import estado
from nucleo.backtest import ejecutar
from nucleo.datos import ErrorDatos
from nucleo.entorno import Registro
from nucleo.estado import ErrorEstado
from nucleo.vivo import SimulacionEnVivo

SILENCIO = Registro(silencioso=True)


def datos_dos(n=1500):
	return {"AAA/USDT": generar_velas(n, semilla=11), "BBB/USDT": generar_velas(n, precio=20.0, semilla=12)}


class TestBacktest(unittest.TestCase):
	@classmethod
	def setUpClass(cls):
		cls.carpeta = tempfile.mkdtemp()
		cls.datos = datos_dos()
		cls.aj = ajustes(plugins=todos_activos())
		cls.r = ejecutar(cls.aj, PLUGINS, cls.carpeta, datos=cls.datos, registro=SILENCIO)

	def test_hace_operaciones(self):
		self.assertGreater(self.r["metricas"]["operaciones"], 5)

	def test_las_cuentas_cuadran(self):
		r = self.r
		suma = sum(o["beneficio"] for o in r["operaciones"])
		self.assertAlmostEqual(r["capital_inicial"] + suma, r["metricas"]["valor_final"], places=6)
		self.assertAlmostEqual(r["efectivo"], r["metricas"]["valor_final"], places=6)
		self.assertEqual(r["abiertas"], [], "al final se vende todo")
		self.assertTrue(all(c[1] > 0 for c in r["curva"]))

	def test_nunca_mas_posiciones_de_las_permitidas(self):
		maximo = self.aj.general["max_posiciones"]
		eventos = sorted([(o["tiempo_entrada"], 1) for o in self.r["operaciones"]] +
			[(o["tiempo_salida"], -1) for o in self.r["operaciones"]], key=lambda e: (e[0], e[1]))
		abiertas = 0
		for _, d in eventos:
			abiertas += d
			self.assertLessEqual(abiertas, maximo)

	def test_archivos(self):
		informe = os.path.join(self.carpeta, "informe_backtest.html")
		csv_ruta = os.path.join(self.carpeta, "backtest_operaciones.csv")
		self.assertTrue(os.path.exists(informe))
		html = open(informe, encoding="utf-8").read()
		for texto in ("Valor de la cartera", "Comprar y mantener", "DINERO SIMULADO", "<svg"):
			self.assertIn(texto, html)
		with open(csv_ruta, encoding="utf-8-sig") as f:
			filas = list(csv.reader(f, delimiter=";"))
		self.assertEqual(filas[0][0], "Moneda")
		self.assertEqual(len(filas) - 1, self.r["metricas"]["operaciones"])
		self.assertIn(",", filas[1][8], "coma decimal para Excel en español")

	def test_no_mira_el_futuro(self):
		"""Si se quitan las velas del final, todo lo anterior debe salir EXACTAMENTE igual."""
		corte = 1100
		recortados = {s: v[:corte] for s, v in self.datos.items()}
		r2 = ejecutar(self.aj, PLUGINS, tempfile.mkdtemp(), datos=recortados, registro=SILENCIO)
		t_corte = self.datos["AAA/USDT"][corte - 1].t
		a = [o for o in self.r["operaciones"] if o["tiempo_salida"] < t_corte]
		b = [o for o in r2["operaciones"] if o["tiempo_salida"] < t_corte and o["motivo_salida"] != "fin de la prueba"]
		self.assertGreater(len(a), 0)
		self.assertEqual(a, b)
		curva_a = [c for c in self.r["curva"] if c[0] < t_corte]
		curva_b = [c for c in r2["curva"] if c[0] < t_corte]
		self.assertEqual(curva_a, curva_b)

	def test_ajustes_por_defecto_del_archivo(self):
		"""El ajustes.toml que se entrega funciona tal cual."""
		from nucleo.config import cargar_ajustes
		aj = cargar_ajustes(os.path.join(os.path.dirname(PLUGINS), "ajustes.toml"))
		datos = {s: generar_velas(1200, paso=aj.intervalo_ms, semilla=k) for k, s in enumerate(aj.monedas)}
		r = ejecutar(aj, PLUGINS, tempfile.mkdtemp(), datos=datos, registro=SILENCIO)
		self.assertGreater(r["metricas"]["valor_final"], 0)

	def test_sin_datos_suficientes(self):
		with self.assertRaises(ErrorDatos):
			ejecutar(self.aj, PLUGINS, tempfile.mkdtemp(), datos={s: v[:255] for s, v in self.datos.items()},
				registro=SILENCIO)


class TestVivo(unittest.TestCase):
	def crear(self, aj, fuente, carpeta=None):
		carpeta = carpeta or tempfile.mkdtemp()
		sim = SimulacionEnVivo(aj, PLUGINS, os.path.join(carpeta, "res"), os.path.join(carpeta, "estado"), fuente,
			registro=SILENCIO, dormir=lambda s: None, estricto=True)
		return sim, carpeta

	def avanzar(self, sim, fuente, hasta, paso_ms=20 * 60_000):
		while fuente.ahora < hasta:
			fuente.ahora += paso_ms
			sim.paso()

	def test_funciona_y_continua_tras_reiniciar(self):
		datos = datos_dos(900)
		fuente = FuenteFalsa(datos, H, datos["AAA/USDT"][300].t + 1)
		aj = ajustes(plugins=todos_activos())
		sim, carpeta = self.crear(aj, fuente)
		sim.preparar()
		self.assertFalse(sim.continuada)
		self.avanzar(sim, fuente, datos["AAA/USDT"][600].t)
		self.assertGreater(len(sim.cartera.operaciones) + len(sim.cartera.posiciones), 0, "ha operado")
		guardado = sim.cartera.a_dict()
		self.assertAlmostEqual(sim.motor.valor_total(), sim.cartera.valor(sim.motor.ultimo_precio))

		sim.cerrojo.soltar()   # "cerrar" el programa (al salir el sistema suelta el bloqueo)
		sim2, _ = self.crear(ajustes(plugins=todos_activos()), fuente, carpeta)   # y volver a abrirlo
		sim2.preparar()
		self.assertTrue(sim2.continuada)
		self.assertEqual(sim2.cartera.a_dict()["operaciones"], guardado["operaciones"])
		self.assertEqual(sim2.cartera.efectivo, guardado["efectivo"])
		self.avanzar(sim2, fuente, datos["AAA/USDT"][800].t)
		self.assertTrue(os.path.exists(os.path.join(carpeta, "res", "informe_simulacion.html")))
		self.assertTrue(os.path.exists(os.path.join(carpeta, "estado", "simulacion.json")))
		suma = sum(o.beneficio for o in sim2.cartera.operaciones)
		invertido = sum(p.coste for p in sim2.cartera.posiciones.values())
		self.assertAlmostEqual(sim2.cartera.capital_inicial + suma, sim2.cartera.efectivo + invertido, places=6)

	def test_decide_igual_que_la_prueba_con_el_pasado(self):
		"""Mismos precios → mismas operaciones en vivo y en backtest (sin stops, que dependen de cada cuánto se mira)."""
		datos = {"AAA/USDT": generar_velas(1000, semilla=21)}
		plugins = solo("cruce_medias", "filtro_tendencia", "diario")
		aj = ajustes({"monedas": ["AAA/USDT"]}, plugins)
		r = ejecutar(aj, PLUGINS, tempfile.mkdtemp(), datos=datos, registro=SILENCIO)
		calent = aj.general["velas_calentamiento"]
		fuente = FuenteFalsa(datos, H, datos["AAA/USDT"][calent].t + 1)
		sim, _ = self.crear(ajustes({"monedas": ["AAA/USDT"]}, plugins), fuente)
		sim.preparar()
		for v in datos["AAA/USDT"][calent + 1:]:
			fuente.ahora = v.t   # justo al abrir cada vela: precio = apertura
			sim.paso()
		bt = [(round(o["precio_entrada"], 6), round(o["precio_salida"], 6), o["motivo_salida"])
			for o in r["operaciones"] if o["motivo_salida"] != "fin de la prueba"]
		vivo = [(round(o.precio_entrada, 6), round(o.precio_salida, 6), o.motivo_salida) for o in sim.cartera.operaciones]
		self.assertGreater(len(bt), 3)
		self.assertEqual(bt, vivo)

	def test_stop_con_el_precio_actual(self):
		datos = datos_dos(600)
		fuente = FuenteFalsa(datos, H, datos["AAA/USDT"][300].t + 1)
		sim, _ = self.crear(ajustes(plugins=solo("cruce_medias")), fuente)
		sim.preparar()
		precio = fuente.precio("AAA/USDT")
		pos = sim.cartera.comprar("AAA/USDT", 100, precio, fuente.ahora)
		pos.stop = precio * 1.5   # por encima del precio: debe saltar en la próxima consulta
		fuente.ahora += 60_000
		sim.paso()
		self.assertNotIn("AAA/USDT", sim.cartera.posiciones)
		self.assertEqual(sim.cartera.operaciones[-1].motivo_salida, "stop loss")

	def test_sin_internet_no_se_rompe(self):
		datos = datos_dos(600)
		fuente = FuenteFalsa(datos, H, datos["AAA/USDT"][300].t + 1)
		sim, _ = self.crear(ajustes(plugins=solo("cruce_medias")), fuente)
		sim.preparar()
		fuente.fallar = True
		r = sim.bucle(max_pasos=5)
		self.assertIsNotNone(r, "termina ordenadamente y devuelve el resumen")
		self.assertTrue(any("5 intentos sin poder leer" in a[2] for a in sim.entorno.avisos))

	def test_avisa_cuando_vuelve_la_conexion(self):
		datos = datos_dos(600)
		fuente = FuenteFalsa(datos, H, datos["AAA/USDT"][300].t + 1)
		esperas = []

		def dormir(s):   # tras 6 esperas "vuelve Internet"
			esperas.append(s)
			fuente.fallar = len(esperas) < 6

		sim = SimulacionEnVivo(ajustes(plugins=solo("cruce_medias")), PLUGINS, tempfile.mkdtemp(), tempfile.mkdtemp(),
			fuente, registro=SILENCIO, dormir=dormir, estricto=True)
		sim.preparar()
		fuente.fallar = True
		sim.bucle(max_pasos=8)
		self.assertTrue(any("Vuelvo a tener precios" in a[2] for a in sim.entorno.avisos))

	def test_moneda_quitada_se_vende(self):
		datos = datos_dos(600)
		fuente = FuenteFalsa(datos, H, datos["AAA/USDT"][300].t + 1)
		sim, carpeta = self.crear(ajustes(plugins=solo("cruce_medias")), fuente)
		sim.preparar()
		sim.cartera.comprar("BBB/USDT", 100, fuente.precio("BBB/USDT"), fuente.ahora)
		sim.guardar()
		sim.cerrojo.soltar()
		sim2, _ = self.crear(ajustes({"monedas": ["AAA/USDT"]}, solo("cruce_medias")), fuente, carpeta)
		sim2.preparar()
		self.assertEqual(sim2.cartera.posiciones, {})
		self.assertEqual(sim2.cartera.operaciones[-1].motivo_salida, "moneda quitada de los ajustes")


class TestEstado(unittest.TestCase):
	def test_no_deja_dos_simulaciones_a_la_vez(self):
		datos = datos_dos(600)
		fuente = FuenteFalsa(datos, H, datos["AAA/USDT"][300].t + 1)
		carpeta = tempfile.mkdtemp()
		crear = lambda: SimulacionEnVivo(ajustes(plugins=solo("cruce_medias")), PLUGINS, os.path.join(carpeta, "r"),
			os.path.join(carpeta, "e"), fuente, registro=SILENCIO, dormir=lambda s: None)
		a = crear()
		a.preparar()
		with self.assertRaises(ErrorEstado) as e:
			crear().preparar()
		self.assertIn("otra simulación", str(e.exception))
		a.bucle(max_pasos=1)   # al terminar suelta el bloqueo
		b = crear()
		b.preparar()
		b.cerrojo.soltar()

	def test_usa_la_copia_si_el_archivo_esta_roto(self):
		ruta = os.path.join(tempfile.mkdtemp(), "s.json")
		estado.guardar(ruta, {"cartera": {"v": 1}})
		estado.guardar(ruta, {"cartera": {"v": 2}})
		with open(ruta, "w") as f:
			f.write("{roto")
		self.assertEqual(estado.cargar(ruta)["cartera"]["v"], 1)

	def test_si_todo_esta_roto_no_arranca_ni_machaca(self):
		ruta = os.path.join(tempfile.mkdtemp(), "s.json")
		for r in (ruta, ruta + ".bak"):
			with open(r, "w") as f:
				f.write("{roto")
		with self.assertRaises(ErrorEstado):
			estado.cargar(ruta)
		self.assertEqual(open(ruta).read(), "{roto")

	def test_sin_archivo(self):
		self.assertIsNone(estado.cargar(os.path.join(tempfile.mkdtemp(), "no.json")))

	def test_simulacion_rota_no_se_sobrescribe(self):
		datos = datos_dos(600)
		fuente = FuenteFalsa(datos, H, datos["AAA/USDT"][300].t + 1)
		carpeta = tempfile.mkdtemp()
		os.makedirs(os.path.join(carpeta, "estado"))
		ruta = os.path.join(carpeta, "estado", "simulacion.json")
		for r in (ruta, ruta + ".bak"):
			with open(r, "w") as f:
				f.write("{roto")
		sim = SimulacionEnVivo(ajustes(plugins=solo("cruce_medias")), PLUGINS, os.path.join(carpeta, "res"),
			os.path.join(carpeta, "estado"), fuente, registro=SILENCIO, dormir=lambda s: None)
		with self.assertRaises(ErrorEstado):
			sim.bucle(max_pasos=1)
		self.assertEqual(open(ruta).read(), "{roto")

	def test_guardado_es_json_valido(self):
		ruta = os.path.join(tempfile.mkdtemp(), "x", "s.json")
		estado.guardar(ruta, {"cartera": {}, "ñ": "€"})
		with open(ruta, encoding="utf-8") as f:
			self.assertEqual(json.load(f)["ñ"], "€")


if __name__ == "__main__":
	unittest.main()
