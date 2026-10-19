"""Los indicadores dan lo mismo que la fórmula de libro, y no dependen de cómo se añadan las velas."""
import statistics
import unittest

from pruebas.utiles import generar_velas
from nucleo.indicadores import Indicadores, Velas, cruza_abajo, cruza_arriba


def ema_ref(xs, p):
	res = [None] * len(xs)
	if len(xs) < p:
		return res
	e = sum(xs[:p]) / p
	res[p - 1] = e
	k = 2 / (p + 1)
	for i in range(p, len(xs)):
		e = xs[i] * k + e * (1 - k)
		res[i] = e
	return res


def rsi_ref(xs, p):
	res = [None] * len(xs)
	gan = [max(xs[i] - xs[i - 1], 0) for i in range(1, len(xs))]
	per = [max(xs[i - 1] - xs[i], 0) for i in range(1, len(xs))]
	ag, ap = sum(gan[:p]) / p, sum(per[:p]) / p
	res[p] = 100 - 100 / (1 + ag / ap) if ap else 100.0
	for i in range(p + 1, len(xs)):
		ag = (ag * (p - 1) + gan[i - 1]) / p
		ap = (ap * (p - 1) + per[i - 1]) / p
		res[i] = 100 - 100 / (1 + ag / ap) if ap else 100.0
	return res


def atr_ref(velas, p):
	trs = []
	for i, v in enumerate(velas):
		if i == 0:
			trs.append(v.maximo - v.minimo)
		else:
			c = velas[i - 1].cierre
			trs.append(max(v.maximo - v.minimo, abs(v.maximo - c), abs(v.minimo - c)))
	res = [None] * len(velas)
	a = sum(trs[:p]) / p
	res[p - 1] = a
	for i in range(p, len(velas)):
		a = (a * (p - 1) + trs[i]) / p
		res[i] = a
	return res


class TestIndicadores(unittest.TestCase):
	@classmethod
	def setUpClass(cls):
		cls.lista = generar_velas(400, semilla=7)
		cls.cierres = [v.cierre for v in cls.lista]
		cls.v = Velas()
		for x in cls.lista:
			cls.v.agregar(x)
		cls.ind = Indicadores(cls.v)

	def serie(self, f):
		"""Valores del indicador para cada vela (de la primera a la última)."""
		n = len(self.lista)
		return [f(atras=n - 1 - i) for i in range(n)]

	def comparar(self, a, b, tol=1e-9):
		self.assertEqual(len(a), len(b))
		for i, (x, y) in enumerate(zip(a, b)):
			if y is None:
				self.assertIsNone(x, f"índice {i}")
			else:
				self.assertAlmostEqual(x, y, delta=tol * max(1, abs(y)), msg=f"índice {i}")

	def test_ema(self):
		for p in (5, 12, 26, 200):
			self.comparar(self.serie(lambda atras: self.ind.ema(p, atras)), ema_ref(self.cierres, p))

	def test_sma(self):
		ref = [None] * 19 + [sum(self.cierres[i - 19:i + 1]) / 20 for i in range(19, 400)]
		self.comparar(self.serie(lambda atras: self.ind.sma(20, atras)), ref)

	def test_rsi(self):
		self.comparar(self.serie(lambda atras: self.ind.rsi(14, atras)), rsi_ref(self.cierres, 14))

	def test_rsi_todo_sube(self):
		v = Velas()
		for k, x in enumerate(generar_velas(30)):
			v.agregar(x._replace(cierre=100 + k))
		self.assertEqual(Indicadores(v).rsi(14), 100.0)

	def test_atr(self):
		self.comparar(self.serie(lambda atras: self.ind.atr(14, atras)), atr_ref(self.lista, 14))

	def test_bollinger(self):
		for i in (19, 100, 399):
			b = self.ind.bollinger(20, 2.0, atras=399 - i)
			ventana = self.cierres[i - 19:i + 1]
			media, std = statistics.fmean(ventana), statistics.pstdev(ventana)
			self.assertAlmostEqual(b[0], media, places=9)
			self.assertAlmostEqual(b[1], media + 2 * std, places=9)
			self.assertAlmostEqual(b[2], media - 2 * std, places=9)
		self.assertIsNone(self.ind.bollinger(20, 2.0, atras=399 - 18))

	def test_macd(self):
		e12, e26 = ema_ref(self.cierres, 12), ema_ref(self.cierres, 26)
		linea = [a - b for a, b in zip(e12[25:], e26[25:])]
		senal = ema_ref(linea, 9)
		for k in range(8, len(linea)):
			m = self.ind.macd(12, 26, 9, atras=len(linea) - 1 - k)
			self.assertAlmostEqual(m[0], linea[k], places=9)
			self.assertAlmostEqual(m[1], senal[k], places=9)
			self.assertAlmostEqual(m[2], linea[k] - senal[k], places=9)

	def test_sin_datos_suficientes(self):
		v = Velas()
		for x in self.lista[:10]:
			v.agregar(x)
		ind = Indicadores(v)
		self.assertIsNone(ind.ema(20))
		self.assertIsNone(ind.rsi(14))
		self.assertIsNone(ind.macd())
		self.assertIsNone(ind.ema(3, atras=50))
		self.assertIsNone(ind.cierre(atras=10))
		self.assertIsNone(Indicadores(Velas()).cierre())

	def test_igual_vela_a_vela_que_de_golpe(self):
		"""En vivo las velas llegan de una en una: el resultado debe ser idéntico."""
		v = Velas()
		ind = Indicadores(v)
		for x in self.lista:
			v.agregar(x)
			ind.ema(26), ind.rsi(14), ind.atr(14), ind.macd(), ind.bollinger()
		for f in ("ema", "rsi", "atr"):
			arg = 26 if f == "ema" else 14
			self.assertEqual(getattr(ind, f)(arg), getattr(self.ind, f)(arg))
		self.assertEqual(ind.macd(), self.ind.macd())
		self.assertEqual(ind.bollinger(), self.ind.bollinger())

	def test_no_admite_velas_viejas_ni_repetidas(self):
		v = Velas()
		self.assertTrue(v.agregar(self.lista[5]))
		self.assertFalse(v.agregar(self.lista[5]))
		self.assertFalse(v.agregar(self.lista[2]))
		self.assertEqual(len(v), 1)

	def test_cruces(self):
		self.assertTrue(cruza_arriba(1, 3, 2, 2))
		self.assertFalse(cruza_arriba(3, 4, 2, 2))
		self.assertTrue(cruza_abajo(3, 1, 2, 2))
		self.assertFalse(cruza_arriba(None, 3, 2, 2))


if __name__ == "__main__":
	unittest.main()
