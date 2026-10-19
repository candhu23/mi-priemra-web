"""Info 2 · Informe visual en HTML (se abre con el navegador, sin Internet)."""
import html
import os

from nucleo import formato as F
from nucleo.config import P
from nucleo.plugins import NOMBRES_TIPO, Plugin


def _e(x):
	return html.escape(str(x))


def _clase(x):
	return "pos" if x is not None and x > 0 else "neg" if x is not None and x < 0 else ""


def _caida(x):
	return f"-{F.num(x)} %" if x >= 0.005 else "0,00 %"


def _reducir(curva, maximo=800):
	if len(curva) <= maximo:
		return list(curva)
	paso = len(curva) / maximo
	res = [curva[int(k * paso)] for k in range(maximo)]
	res.append(curva[-1])
	return res


def _svg_curva(curva, capital, cot):
	pts = _reducir(curva)
	if len(pts) < 2:
		return '<p class="vacio">Aún no hay datos suficientes para dibujar el gráfico.</p>'
	W, H, ml, mr, mt, mb = 900, 300, 74, 14, 14, 30
	ts = [p[0] for p in pts]
	vals = [p[1] for p in pts] + [p[2] for p in pts if p[2] is not None] + [capital]
	vmin, vmax = min(vals), max(vals)
	if vmax - vmin < 1e-9:
		vmax, vmin = vmax + 1, vmin - 1
	marg = (vmax - vmin) * 0.06
	vmin, vmax = vmin - marg, vmax + marg
	tmin, tmax = ts[0], ts[-1] if ts[-1] > ts[0] else ts[0] + 1

	def X(t):
		return ml + (t - tmin) / (tmax - tmin) * (W - ml - mr)

	def Y(v):
		return mt + (1 - (v - vmin) / (vmax - vmin)) * (H - mt - mb)

	partes = []
	for k in range(5):
		v = vmin + (vmax - vmin) * k / 4
		y = Y(v)
		partes.append(f'<line x1="{ml}" y1="{y:.1f}" x2="{W - mr}" y2="{y:.1f}" class="rejilla"/>'
			f'<text x="{ml - 8}" y="{y + 4:.1f}" class="eje" text-anchor="end">{_e(F.num(v, 0))}</text>')
	for k in range(5):
		t = tmin + (tmax - tmin) * k / 4
		anc = "start" if k == 0 else "end" if k == 4 else "middle"
		partes.append(f'<text x="{X(t):.1f}" y="{H - 8}" class="eje" text-anchor="{anc}">{_e(F.fecha(int(t), hora=False))}</text>')
	yc = Y(capital)
	partes.append(f'<line x1="{ml}" y1="{yc:.1f}" x2="{W - mr}" y2="{yc:.1f}" class="capital"/>')
	ref = [(p[0], p[2]) for p in pts if p[2] is not None]
	if len(ref) > 1:
		partes.append('<polyline class="linea-ref" points="' + " ".join(f"{X(t):.1f},{Y(v):.1f}" for t, v in ref) + '"/>')
	partes.append('<polyline class="linea-bot" points="' + " ".join(f"{X(p[0]):.1f},{Y(p[1]):.1f}" for p in pts) + '"/>')
	return (f'<svg viewBox="0 0 {W} {H}" role="img" aria-label="Valor de la cartera en {cot} a lo largo del tiempo">'
		+ "".join(partes) + "</svg>")


def _svg_caida(curva, capital):
	if len(curva) < 2:
		return ""
	W, H, ml, mr, mt, mb = 900, 120, 74, 14, 8, 8
	pico, todas = capital, []
	for t, v, _ in curva:   # se calcula con TODOS los puntos y luego se reduce para dibujar
		pico = max(pico, v)
		todas.append((t, (1 - v / pico) * 100 if pico > 0 else 0))
	peor = max(d for _, d in todas) or 1.0
	dds = _reducir(todas)
	pts = dds
	tmin, tmax = pts[0][0], max(pts[-1][0], pts[0][0] + 1)

	def X(t):
		return ml + (t - tmin) / (tmax - tmin) * (W - ml - mr)

	def Y(d):
		return mt + d / peor * (H - mt - mb)

	camino = f"M{X(tmin):.1f},{mt} " + " ".join(f"L{X(t):.1f},{Y(d):.1f}" for t, d in dds) + f" L{X(tmax):.1f},{mt} Z"
	return (f'<svg viewBox="0 0 {W} {H}" role="img" aria-label="Caídas desde el máximo">'
		f'<line x1="{ml}" y1="{mt}" x2="{W - mr}" y2="{mt}" class="rejilla"/>'
		f'<text x="{ml - 8}" y="{mt + 4}" class="eje" text-anchor="end">0 %</text>'
		f'<text x="{ml - 8}" y="{H - mb}" class="eje" text-anchor="end">-{_e(F.num(peor, 1))} %</text>'
		f'<path d="{camino}" class="area-caida"/></svg>')


def _veredicto(r):
	m, ref = r["metricas"], r["referencia"]
	if m["operaciones"] == 0 and not r["abiertas"]:
		return ("El bot no ha hecho ninguna operación en este periodo. Las señales no se han dado o los filtros "
			"las han bloqueado (mira «Por qué no compró» más abajo).")
	frases = [f"El bot ha {'ganado' if m['rentabilidad'] >= 0 else 'perdido'} un {F.num(abs(m['rentabilidad']))} %."]
	if ref:
		frases.append(f"Comprar al principio y no tocar nada habría dado un {F.pct(ref['rentabilidad'])}.")
		if m["rentabilidad"] >= ref["rentabilidad"]:
			extra = " y con menos caída" if m["caida_maxima"] < ref["caida_maxima"] else ""
			frases.append(f"En este periodo el bot lo ha hecho mejor que comprar y mantener{extra}.")
		else:
			extra = ", aunque con menos caída (menos sustos)" if m["caida_maxima"] < ref["caida_maxima"] else ""
			frases.append(f"En este periodo el bot lo ha hecho peor que comprar y mantener{extra}.")
	if m["operaciones"] < 30:
		frases.append(f"Ojo: con solo {m['operaciones']} operaciones cerradas el resultado puede deberse a la suerte.")
	return " ".join(frases)


CSS = """
:root{--fondo:#f6f7f9;--panel:#fff;--texto:#1b1f24;--suave:#5b6573;--borde:#e3e6ea;--pos:#0a7d43;--neg:#c02a2a;
--bot:#2563eb;--ref:#9aa3ad;--aviso-f:#fff7e0;--aviso-b:#e8c95b;--caida:rgba(192,42,42,.18)}
@media (prefers-color-scheme:dark){:root{--fondo:#0f1216;--panel:#171b21;--texto:#e7eaee;--suave:#9aa4b1;--borde:#2a3038;
--pos:#3ccf7f;--neg:#ff6b6b;--bot:#6ea0ff;--ref:#6b7480;--aviso-f:#2b2510;--aviso-b:#8a7424;--caida:rgba(255,107,107,.2)}}
*{box-sizing:border-box}body{margin:0;background:var(--fondo);color:var(--texto);
font:15px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
main{max-width:1060px;margin:0 auto;padding:20px 16px 40px}
h1{font-size:24px;margin:0 0 4px}h2{font-size:18px;margin:28px 0 10px}
.sub{color:var(--suave);margin:0 0 16px}.etiqueta{display:inline-block;background:var(--bot);color:#fff;
border-radius:999px;padding:2px 10px;font-size:12px;font-weight:600;vertical-align:middle;margin-left:6px}
.tarjetas{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:10px}
.tarjeta{background:var(--panel);border:1px solid var(--borde);border-radius:12px;padding:12px 14px}
.tarjeta .t{color:var(--suave);font-size:13px}.tarjeta .v{font-size:22px;font-weight:700;margin-top:2px}
.tarjeta .n{color:var(--suave);font-size:13px}
.pos{color:var(--pos)}.neg{color:var(--neg)}
.veredicto{background:var(--panel);border:1px solid var(--borde);border-left:4px solid var(--bot);border-radius:10px;
padding:12px 14px;margin:14px 0}
.panel{background:var(--panel);border:1px solid var(--borde);border-radius:12px;padding:12px}
svg{width:100%;height:auto;display:block}.rejilla{stroke:var(--borde);stroke-width:1}
.eje{fill:var(--suave);font-size:12px}.capital{stroke:var(--suave);stroke-dasharray:2 4;stroke-width:1}
.linea-bot{fill:none;stroke:var(--bot);stroke-width:2.2}.linea-ref{fill:none;stroke:var(--ref);stroke-width:1.6;stroke-dasharray:6 4}
.area-caida{fill:var(--caida);stroke:var(--neg);stroke-width:1}
.leyenda{display:flex;gap:16px;flex-wrap:wrap;color:var(--suave);font-size:13px;margin:6px 4px 0}
.leyenda i{display:inline-block;width:18px;height:3px;vertical-align:middle;margin-right:6px;background:var(--bot)}
.leyenda i.r{background:repeating-linear-gradient(90deg,var(--ref) 0 6px,transparent 6px 10px)}
.tabla{overflow-x:auto;background:var(--panel);border:1px solid var(--borde);border-radius:12px}
table{border-collapse:collapse;width:100%;font-size:14px}th,td{padding:7px 10px;text-align:left;white-space:nowrap;
border-bottom:1px solid var(--borde)}th{color:var(--suave);font-weight:600;font-size:13px}td.num,th.num{text-align:right}
tr:last-child td{border-bottom:0}.vacio{color:var(--suave);margin:8px 4px}
.aviso{background:var(--aviso-f);border:1px solid var(--aviso-b);border-radius:10px;padding:12px 14px;margin-top:28px;font-size:14px}
ul.plugins{list-style:none;padding:0;margin:0;display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:8px}
ul.plugins li{background:var(--panel);border:1px solid var(--borde);border-radius:10px;padding:8px 12px;font-size:14px}
ul.plugins li.off{opacity:.55}ul.plugins b{display:block}
@media (max-width:600px){.eje{font-size:26px}h1{font-size:21px}.tarjeta .v{font-size:19px}}
"""


def construir_html(r, max_ops):
	m, ref, cot = r["metricas"], r["referencia"], r["cotizacion"]
	vivo = r["modo"] == "vivo"
	titulo = "Simulación en tiempo real" if vivo else "Prueba con el pasado"
	periodo = f"{F.fecha(r['desde'])} → {F.fecha(r['hasta'])}" if r.get("desde") and r.get("hasta") else ""
	t = []
	t.append(f'<h1>{titulo} <span class="etiqueta">DINERO SIMULADO</span></h1>')
	t.append(f'<p class="sub">{_e(", ".join(r["monedas"]))} · velas de {_e(r["intervalo"])} · {_e(periodo)}'
		f' · capital inicial {_e(F.num(r["capital_inicial"]))} {cot}'
		+ (f' · actualizado {_e(F.fecha(r["generado"]))} (se recarga cada 5 min)' if vivo else "") + "</p>")

	def tarjeta(tit, valor, nota="", clase=""):
		return (f'<div class="tarjeta"><div class="t">{_e(tit)}</div><div class="v {clase}">{_e(valor)}</div>'
			f'<div class="n">{_e(nota)}</div></div>')

	fb = m["factor_beneficio"]
	tarjetas = [
		tarjeta("Resultado del bot", F.pct(m["rentabilidad"]), f"{F.num(m['valor_final'])} {cot}", _clase(m["rentabilidad"])),
		tarjeta("Comprar y mantener", F.pct(ref["rentabilidad"]) if ref else "—", "referencia para comparar",
			_clase(ref["rentabilidad"]) if ref else ""),
		tarjeta("Caída máxima", _caida(m["caida_maxima"]),
			f"comprar y mantener: {_caida(ref['caida_maxima'])}" if ref else "peor bajada desde un máximo"),
		tarjeta("Operaciones", str(m["operaciones"]),
			f"{F.num(m['aciertos'], 0)} % ganadoras" if m["aciertos"] is not None else "ninguna cerrada"),
		tarjeta("Factor de beneficio", "—" if fb is None else F.num(fb), "más de 1 = gana más de lo que pierde",
			"pos" if fb and fb > 1 else "neg" if fb is not None and fb < 1 else ""),
		tarjeta("Comisiones pagadas", f"{F.num(m['comisiones'])} {cot}", f"{F.num(r['comision'], 2)} % por operación"),
	]
	t.append('<div class="tarjetas">' + "".join(tarjetas) + "</div>")
	t.append(f'<div class="veredicto">{_e(_veredicto(r))}</div>')

	t.append("<h2>Valor de la cartera</h2>")
	t.append('<div class="panel">' + _svg_curva(r["curva"], r["capital_inicial"], cot)
		+ '<div class="leyenda"><span><i></i>Bot</span><span><i class="r"></i>Comprar y mantener</span>'
		'<span>···· Capital inicial</span></div></div>')
	caida = _svg_caida(r["curva"], r["capital_inicial"])
	if caida:
		t.append("<h2>Caídas desde el máximo</h2>")
		t.append(f'<div class="panel">{caida}</div>')

	if r["abiertas"]:
		filas = "".join(
			f"<tr><td>{_e(p['simbolo'])}</td><td>{_e(F.fecha(p['tiempo_entrada']))}</td>"
			f"<td class=num>{_e(F.precio(p['precio_entrada']))}</td><td class=num>{_e(F.precio(p['precio_actual']))}</td>"
			f"<td class=num>{_e(F.precio(p['stop']))}</td><td class=num>{_e(F.precio(p['objetivo']))}</td>"
			f"<td class='num {_clase(p['resultado'])}'>{_e(F.num(p['resultado']))}</td></tr>" for p in r["abiertas"])
		t.append("<h2>Posiciones abiertas ahora</h2>")
		t.append('<div class="tabla"><table><tr><th>Moneda</th><th>Compra</th><th class=num>Precio compra</th>'
			'<th class=num>Precio ahora</th><th class=num>Stop</th><th class=num>Objetivo</th>'
			f'<th class=num>Resultado ({cot})</th></tr>{filas}</table></div>')

	if r["por_moneda"]:
		filas = "".join(
			f"<tr><td>{_e(s)}</td><td class=num>{d['operaciones']}</td>"
			f"<td class=num>{F.num(d['ganadoras'] / d['operaciones'] * 100, 0)} %</td>"
			f"<td class='num {_clase(d['beneficio'])}'>{_e(F.num(d['beneficio']))}</td></tr>"
			for s, d in sorted(r["por_moneda"].items()))
		t.append("<h2>Por moneda</h2>")
		t.append('<div class="tabla"><table><tr><th>Moneda</th><th class=num>Operaciones</th><th class=num>Ganadoras</th>'
			f'<th class=num>Beneficio ({cot})</th></tr>{filas}</table></div>')

	if r["bloqueos"]:
		filas = "".join(f"<tr><td>{_e(k)}</td><td class=num>{v}</td></tr>" for k, v in list(r["bloqueos"].items())[:15])
		t.append("<h2>Por qué no compró</h2>")
		t.append('<p class="sub">Veces que hubo señal de compra pero algo la frenó (es normal: así se evitan malas compras).</p>')
		t.append(f'<div class="tabla"><table><tr><th>Motivo</th><th class=num>Veces</th></tr>{filas}</table></div>')

	ops = list(reversed(r["operaciones"]))[:max_ops]
	t.append(f"<h2>Operaciones ({len(r['operaciones'])})</h2>")
	if ops:
		filas = "".join(
			f"<tr><td>{_e(o['simbolo'])}</td><td>{_e(F.fecha(o['tiempo_entrada']))}</td><td>{_e(F.fecha(o['tiempo_salida']))}</td>"
			f"<td class=num>{_e(F.precio(o['precio_entrada']))}</td><td class=num>{_e(F.precio(o['precio_salida']))}</td>"
			f"<td class='num {_clase(o['beneficio'])}'>{_e(F.num(o['beneficio']))}</td>"
			f"<td class='num {_clase(o['porcentaje'])}'>{_e(F.pct(o['porcentaje']))}</td>"
			f"<td>{_e(o['motivo_salida'])}</td></tr>" for o in ops)
		nota = f'<p class="sub">Se muestran las {max_ops} últimas; todas están en el CSV.</p>' if len(r["operaciones"]) > max_ops else ""
		t.append(nota + '<div class="tabla"><table><tr><th>Moneda</th><th>Compra</th><th>Venta</th>'
			'<th class=num>Precio compra</th><th class=num>Precio venta</th>'
			f'<th class=num>Beneficio ({cot})</th><th class=num>%</th><th>Motivo de venta</th></tr>{filas}</table></div>')
	else:
		t.append('<p class="vacio">Todavía no hay operaciones cerradas.</p>')

	avisos = [a for a in r.get("avisos", []) if a[1] in ("aviso", "error")]
	if avisos:
		filas = "".join(f"<tr><td>{_e(F.fecha(a[0]))}</td><td>{_e(a[2])}</td></tr>" for a in reversed(avisos[-15:]))
		t.append("<h2>Avisos</h2>")
		t.append(f'<div class="tabla"><table><tr><th>Cuándo</th><th>Aviso</th></tr>{filas}</table></div>')

	t.append("<h2>Plugins</h2>")
	items = []
	for p in r["plugins"]:
		estado = "activo" if p["activo"] else "desactivado"
		items.append(f'<li class="{"" if p["activo"] else "off"}"><b>{_e(p["titulo"])}</b>'
			f'{_e(NOMBRES_TIPO.get(p["tipo"], p["tipo"]))} · {estado}</li>')
	t.append('<ul class="plugins">' + "".join(items) + "</ul>")

	t.append('<div class="aviso"><b>Importante:</b> esto es una simulación, no se ha usado dinero real. '
		f'Incluye una comisión del {_e(F.num(r["comision"]))} % y un deslizamiento del {_e(F.num(r["deslizamiento"]))} % '
		"en cada compra y venta. Que una estrategia haya ido bien en el pasado <b>no garantiza</b> que vaya bien en "
		"el futuro. Ningún bot puede prometer ganancias.</div>")

	refresco = '<meta http-equiv="refresh" content="300">' if vivo else ""
	return (f'<!doctype html><html lang="es"><head><meta charset="utf-8">'
		f'<meta name="viewport" content="width=device-width,initial-scale=1">{refresco}'
		f"<title>Informe del bot · {titulo}</title><style>{CSS}</style></head><body><main>"
		+ "".join(t) + "</main></body></html>")


class Informe(Plugin):
	nombre = "informe"
	orden = 14
	titulo = "Informe visual"
	tipo = "info"
	descripcion = ("Crea una página (resultados/informe_*.html) con el resultado, la comparación con comprar y "
		"mantener, gráficos, caídas, operaciones y por qué no compró. En vivo se actualiza con cada vela.")
	activo_por_defecto = True
	parametros = {
		"max_operaciones_tabla": P(300, int, 10, 100000, "Operaciones que se muestran en la tabla"),
	}

	def _ruta(self):
		nombre = "informe_backtest.html" if self.entorno.modo == "backtest" else "informe_simulacion.html"
		return self.entorno.ruta_resultado(nombre)

	def generar(self, resumen):
		ruta = self._ruta()
		tmp = ruta + ".tmp"
		with open(tmp, "w", encoding="utf-8") as f:
			f.write(construir_html(resumen, self.a["max_operaciones_tabla"]))
		os.replace(tmp, ruta)
		return ruta

	def al_actualizar(self, resumen):
		self.generar(resumen)

	def al_terminar(self, resumen):
		ruta = self.generar(resumen)
		resumen.setdefault("archivos", []).append(ruta)
		resumen["informe"] = ruta
