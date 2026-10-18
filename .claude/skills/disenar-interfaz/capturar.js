// Fotografía los HTML de ver_interfaz.py y audita cada pantalla en el navegador.
// Uso: node capturar.js <ancho> <alto> <escala> <umbralesJSON> <html...>
// Por cada X.html escribe X.png, X.auditoria.json y, si hay problemas, X_problemas.png.
const { chromium } = require("playwright");
const fs = require("fs");

// Se ejecuta DENTRO de la página: ajustes de maquetación que CSS no hace solo.
async function maquetar() {
	document.querySelectorAll("[data-radius]").forEach((el) => {
		// Medidas SIN escalar (offset*): el radio se aplica antes del transform del UIScale
		el.style.borderRadius = parseFloat(el.dataset.radius) * Math.min(el.offsetWidth, el.offsetHeight) + "px";
	});
	document.querySelectorAll("[data-aspect]").forEach((el) => {
		const p = el.parentElement;
		const r = parseFloat(el.dataset.aspect);
		let w = p.offsetWidth, h = w / r;
		if (h > p.offsetHeight) { h = p.offsetHeight; w = h * r; }
		el.style.width = w + "px"; el.style.height = h + "px";
	});
	// TextScaled: el mayor tamaño que cabe (como Roblox), con tope MaxTextSize
	document.querySelectorAll(".txt[data-escalado]").forEach((t) => {
		const span = t.firstElementChild;
		let lo = 1, hi = Math.min(100, parseFloat(t.dataset.escalado) || 100);
		for (let i = 0; i < 12; i++) {
			const mid = (lo + hi) / 2;
			t.style.fontSize = mid + "px";
			if (span.scrollWidth <= t.clientWidth + 1 && span.scrollHeight <= t.clientHeight + 1) lo = mid; else hi = mid;
		}
		t.style.fontSize = Math.floor(lo) + "px";
	});
	const sizes = {};
	for (const el of document.querySelectorAll("[data-img]")) {
		const url = el.dataset.img;
		try {
			if (!sizes[url]) { const im = new Image(); im.src = url; await im.decode(); sizes[url] = [im.naturalWidth, im.naturalHeight]; }
		} catch (e) { continue; }
		const [SW, SH] = sizes[url];
		const [ox, oy, rw0, rh0] = el.dataset.rect.split(",").map(Number);
		const rw = rw0 || SW, rh = rh0 || SH;
		const box = el.getBoundingClientRect();
		let w = box.width, h = box.height, x = 0, y = 0;
		if (el.dataset.fit === "Fit") { const s = Math.min(w / rw, h / rh); x = (w - rw * s) / 2; y = (h - rh * s) / 2; w = rw * s; h = rh * s; }
		const layer = document.createElement("div");
		const sx = w / rw, sy = h / rh;
		Object.assign(layer.style, { position: "absolute", left: x + "px", top: y + "px", width: w + "px", height: h + "px" });
		const props = `url("${url}") ${-ox * sx}px ${-oy * sy}px / ${SW * sx}px ${SH * sy}px no-repeat`;
		if (el.dataset.tint.startsWith("rgba(255,255,255") || el.dataset.fit === "Fit" || !rw0) layer.style.background = props;
		else { layer.style.webkitMask = props; layer.style.background = el.dataset.tint; }
		el.prepend(layer);
	}
}

// Se ejecuta DENTRO de la página: busca problemas de diseño.
function auditar(umbral) {
	const W = innerWidth, H = innerHeight;
	const problemas = [];
	const recorte = (el) => {
		const r = el.getBoundingClientRect();
		let x1 = Math.max(r.left, 0), y1 = Math.max(r.top, 0), x2 = Math.min(r.right, W), y2 = Math.min(r.bottom, H);
		for (let a = el.parentElement; a; a = a.parentElement) {
			if (a.dataset && a.dataset.recorta) {
				const b = a.getBoundingClientRect();
				x1 = Math.max(x1, b.left); y1 = Math.max(y1, b.top); x2 = Math.min(x2, b.right); y2 = Math.min(y2, b.bottom);
			}
		}
		return { r, x1, y1, x2, y2, area: Math.max(0, x2 - x1) * Math.max(0, y2 - y1) };
	};
	const caja = (el) => el.closest(".g");
	// ¿Se ve de verdad? (nada opaco encima en su centro visible)
	const seVe = (el, v) => {
		if (v.area < 4) return false;
		const top = document.elementFromPoint((v.x1 + v.x2) / 2, (v.y1 + v.y2) / 2);
		if (!top) return false;
		const g = caja(el);
		return g.contains(top) || top.contains(g) || !top.closest("[data-bg]") || top.closest("[data-bg]").contains(g);
	};
	const fondo = (el) => {
		const a = el.closest("[data-bg]");
		return a ? a.dataset.bg.split(",").map(Number) : null;
	};
	const lum = (c) => {
		const f = (v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); };
		return 0.2126 * f(c[0]) + 0.7152 * f(c[1]) + 0.0722 * f(c[2]);
	};
	const contraste = (a, b) => { const l1 = lum(a), l2 = lum(b); return (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05); };
	const add = (tipo, el, detalle, rect) => {
		const g = caja(el);
		problemas.push({ tipo, detalle, texto: (el.textContent || g.dataset.ruta.split("/").pop() || "").trim(),
			ruta: g.dataset.ruta || "", rect: [rect.left, rect.top, rect.width, rect.height].map(Math.round) });
	};

	const textos = [];
	for (const t of document.querySelectorAll(".txt")) {
		const span = t.firstElementChild;
		const v = recorte(span);
		if (!seVe(span, v)) continue;
		const g = caja(t);
		const factor = g.offsetWidth ? g.getBoundingClientRect().width / g.offsetWidth : 1;
		const tam = parseFloat(getComputedStyle(t).fontSize) * factor;
		textos.push({ t, span, v, g });
		const soloEmoji = !/[\p{L}\p{N}]/u.test(t.textContent.replace(/[\u{1F000}-\u{1FFFF}\u{2600}-\u{27BF}\uFE0F]/gu, ""));
		const peso = parseInt(getComputedStyle(t).fontWeight) || 400;
		if (tam < umbral.texto - 0.25) add("pequeno", t, `${tam.toFixed(1)} px (mínimo ${umbral.texto})`, v.r);
		const sobra = Math.max(span.scrollWidth - span.clientWidth, span.scrollHeight - span.clientHeight);
		if (!soloEmoji && sobra >= 3) add("cortado", t, `no cabe (sobran ${sobra} px)`, v.r);
		const bg = fondo(t);
		if (bg && !soloEmoji && t.dataset.borde !== "1") {
			const fg = t.dataset.fg.split(",").map(Number);
			const c = contraste(fg, bg);
			// Pautas WCAG: texto grande (≥ 24 px, o ≥ 18 px en negrita) 3:1; el resto 4,5:1
			const minimo = tam >= 24 || (tam >= 18 && peso >= 600) ? 3 : 4.5;
			if (c < minimo) add("contraste", t, `${c.toFixed(2)}:1 (mínimo ${minimo}:1)`, v.r);
		}
		if (g.dataset.gradienteTexto) add("gradiente", t, "el degradado tiñe también el texto (usa shade())", v.r);
		const r = g.getBoundingClientRect();
		if (!g.parentElement.closest("[data-recorta]") && (r.left < -4 || r.top < -4 || r.right > W + 4 || r.bottom > H + 4)) add("fuera", t, "parte del texto queda fuera de la pantalla", r);
	}
	let botones = 0;
	for (const b of document.querySelectorAll(".TextButton, .ImageButton")) {
		const v = recorte(b);
		if (!seVe(b, v) || v.area < 0.3 * v.r.width * v.r.height) continue;
		botones++;
		const lado = Math.min(v.r.width, v.r.height);
		if (lado < umbral.boton) add("boton", b, `${Math.round(v.r.width)}×${Math.round(v.r.height)} px (mínimo ${umbral.boton})`, v.r);
		const r = v.r;
		if (!b.parentElement.closest("[data-recorta]") && (r.left < -4 || r.top < -4 || r.right > W + 4 || r.bottom > H + 4)) add("fuera", b, "el botón queda fuera de la pantalla", r);
	}
	// Textos que se pisan: los dos se ven en el mismo punto (nada opaco entre ellos).
	// No cuenta insignias (emoji solo o 1-2 caracteres encima de otra cosa: suelen ser a propósito).
	const corto = (x) => x.t.textContent.trim().length <= 2 || !/[\p{L}\p{N}]{2}/u.test(x.t.textContent);
	const visibleAhi = (x, px, py) => {
		for (const el of document.elementsFromPoint(px, py)) {
			if (x.g.contains(el)) return true;
			if (el.dataset && el.dataset.bg && !el.contains(x.g)) return false; // algo opaco lo tapa
		}
		return false;
	};
	for (let i = 0; i < textos.length; i++) {
		for (let j = i + 1; j < textos.length; j++) {
			const a = textos[i], b = textos[j];
			if (a.g.contains(b.g) || b.g.contains(a.g) || corto(a) || corto(b)) continue;
			const ra = a.span.getBoundingClientRect(), rb = b.span.getBoundingClientRect();
			const ix = Math.min(ra.right, rb.right) - Math.max(ra.left, rb.left);
			const iy = Math.min(ra.bottom, rb.bottom) - Math.max(ra.top, rb.top);
			if (ix <= 2 || iy <= 2) continue;
			const menor = Math.min(ra.width * ra.height, rb.width * rb.height);
			if (ix * iy < 0.2 * menor) continue;
			const px = Math.max(ra.left, rb.left) + ix / 2, py = Math.max(ra.top, rb.top) + iy / 2;
			if (visibleAhi(a, px, py) && visibleAhi(b, px, py)) add("solape", a.t, `pisa a «${b.t.textContent.trim().slice(0, 30)}»`, ra);
		}
	}
	// Texto tapado EN PARTE por algo opaco que no es suyo (si está tapado entero, no se ve: no cuenta)
	for (const x of textos) {
		if (corto(x)) continue;
		const r = x.span.getBoundingClientRect();
		let vistos = 0, tapados = 0, quien = null;
		for (let k = 0; k < 21; k++) {
			const px = r.left + (r.width * ((k % 7) + 1)) / 8, py = r.top + (r.height * (Math.floor(k / 7) + 1)) / 4;
			if (px < 0 || py < 0 || px > W || py > H) continue;
			let estado = "nada";
			for (const el of document.elementsFromPoint(px, py)) {
				if (x.g.contains(el)) { estado = "visto"; break; }
				if (el.dataset && el.dataset.bg && !el.contains(x.g)) { estado = "tapado"; quien = quien || el; break; }
			}
			if (estado === "visto") vistos++; else if (estado === "tapado") tapados++;
		}
		// Una ventana grande encima (modal) es normal: solo cuenta si lo que tapa es pequeño
		// Lo que tapa, contando su contenedor opaco más grande (la ventana entera, no una tarjeta suya)
		let grande = quien;
		for (let a = quien && quien.parentElement; a; a = a.parentElement) {
			if (a.dataset && a.dataset.bg && !a.contains(x.g)) grande = a;
		}
		const rq = grande ? grande.getBoundingClientRect() : null;
		if (vistos > 0 && tapados > 0 && rq && rq.width * rq.height < 0.2 * W * H) {
			const nombre = (quien.textContent || "").trim().slice(0, 30) || (quien.dataset.ruta || "").split("/").pop();
			add("solape", x.t, `tapado en parte por «${nombre}»`, r);
		}
	}
	const colores = new Set();
	for (const el of document.querySelectorAll("[data-bg]")) {
		const v = recorte(el);
		if (v.area > 2000) colores.add(el.dataset.bg.split(",").map((x) => Math.round(+x / 12)).join(","));
	}
	return { problemas, textos: textos.length, botones, colores: colores.size };
}

function marcar(problemas) {
	problemas.slice(0, 40).forEach((p, i) => {
		const d = document.createElement("div");
		const [x, y, w, h] = p.rect;
		Object.assign(d.style, { position: "fixed", left: x - 2 + "px", top: y - 2 + "px", width: w + 4 + "px", height: h + 4 + "px",
			border: "2px solid #ff1744", zIndex: 99999, pointerEvents: "none", boxSizing: "border-box" });
		const n = document.createElement("div");
		n.textContent = i + 1;
		Object.assign(n.style, { position: "absolute", left: "-2px", top: "-16px", background: "#ff1744", color: "#fff",
			font: "700 11px sans-serif", padding: "1px 4px", borderRadius: "3px" });
		d.appendChild(n);
		document.body.appendChild(d);
	});
}

(async () => {
	const [w, h, scale, umbralesJson, ...files] = process.argv.slice(2);
	const umbral = JSON.parse(umbralesJson);
	const browser = await chromium.launch({ args: ["--allow-file-access-from-files"] });
	const context = await browser.newContext({ viewport: { width: +w, height: +h }, deviceScaleFactor: +scale, ignoreHTTPSErrors: true });
	const page = await context.newPage();
	for (const f of files) {
		try {
		await page.goto("file://" + f, { waitUntil: "load", timeout: 30000 }).catch(() => {});
		await page.evaluate(() => document.fonts.ready);
		await page.evaluate(maquetar);
		const png = f.replace(/\.html$/, ".png");
		await page.screenshot({ path: png });
		const res = await page.evaluate(auditar, umbral);
		fs.writeFileSync(f.replace(/\.html$/, ".auditoria.json"), JSON.stringify(res));
		if (res.problemas.length) {
			await page.evaluate(marcar, res.problemas);
			await page.screenshot({ path: f.replace(/\.html$/, "_problemas.png") });
		}
		console.log(`${png}  (${res.problemas.length} problemas)`);
		} catch (e) {
			console.log(`⚠️ ${f}: ${e.message.split("\n")[0]}`);
			fs.writeFileSync(f.replace(/\.html$/, ".auditoria.json"), JSON.stringify({ problemas: [], textos: 0, botones: 0, colores: 0, error: String(e) }));
		}
	}
	await browser.close();
})();
