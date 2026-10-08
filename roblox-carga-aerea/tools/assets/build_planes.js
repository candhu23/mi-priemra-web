// Dibuja las ilustraciones de los aviones (vista lateral) y genera assets/aviones.png:
// hoja de 2x3 celdas de 512x256 px, fondo transparente. Orden = Config.Planes.
// Uso: NODE_PATH=$(npm root -g) node tools/assets/build_planes.js
const { chromium } = require("playwright");
const path = require("path");
const ROOT = path.join(__dirname, "..", "..");

const NAVY = "#16243f", ORANGE = "#ff8a3d", GLASS = "#1d2b44";

// p: L largo, D diámetro, wing "high"|"low", eng "prop"|"jet", engines (1..4 visibles),
// tail "T"|"normal", hump (cubierta superior), upsweep (cola levantada), scale
function plane(p) {
	const L = 470 * p.scale, D = p.D, x0 = (512 - L) / 2, cy = 140;
	const top = cy - D / 2, bot = cy + D / 2;
	const nose = D * 0.9, tailLen = L * 0.26;
	const tailTop = top - (p.upsweep ? D * 0.05 : 0);
	let s = "";
	// Sombra en el suelo
	s += `<ellipse cx="${x0 + L / 2}" cy="${bot + 34}" rx="${L * 0.42}" ry="7" fill="#000" opacity="0.22"/>`;
	// Tren de aterrizaje
	const gear = (gx, h) => `<rect x="${gx - 2.5}" y="${bot - 4}" width="5" height="${h}" fill="#3b4252"/>` +
		`<circle cx="${gx}" cy="${bot + h}" r="${p.small ? 7 : 9}" fill="#1f2430"/><circle cx="${gx}" cy="${bot + h}" r="${p.small ? 3 : 4}" fill="#8a93a6"/>`;
	s += gear(x0 + nose * 0.9, 24);
	s += gear(x0 + L * 0.52, 26);
	if (!p.small) s += gear(x0 + L * 0.52 + 20, 26);
	// Estabilizador vertical (deriva)
	const finX = x0 + L - tailLen * 0.95, finH = D * (p.tail === "T" ? 1.25 : 1.15);
	s += `<path d="M ${finX} ${tailTop + 4} L ${finX + tailLen * 0.55} ${tailTop - finH} L ${finX + tailLen * 0.85} ${tailTop - finH} L ${x0 + L - 4} ${tailTop + 2} Z" fill="${NAVY}"/>`;
	s += `<circle cx="${finX + tailLen * 0.55}" cy="${tailTop - finH * 0.45}" r="${D * 0.2}" fill="${ORANGE}"/>`;
	s += `<path d="M ${finX + tailLen * 0.47} ${tailTop - finH * 0.45} l ${D * 0.08} ${-D * 0.1} l ${D * 0.08} ${D * 0.1} l ${-D * 0.08} ${D * 0.05} Z" fill="#fff"/>`;
	// Estabilizador horizontal
	if (p.tail === "T") {
		s += `<path d="M ${finX + tailLen * 0.45} ${tailTop - finH} h ${tailLen * 0.55} l -8 6 h ${-tailLen * 0.5} Z" fill="${NAVY}"/>`;
	} else {
		s += `<path d="M ${x0 + L - tailLen * 0.7} ${cy - D * 0.12} h ${tailLen * 0.62} l -6 7 h ${-tailLen * 0.62} Z" fill="#c9d1de"/>`;
	}
	// Fuselaje: morro redondeado y cola que se estrecha hacia arriba
	const body = `M ${x0 + nose} ${top}
		L ${x0 + L - tailLen} ${top}
		C ${x0 + L - tailLen * 0.4} ${top} ${x0 + L - 10} ${tailTop + D * 0.02} ${x0 + L} ${tailTop + D * 0.06}
		L ${x0 + L} ${tailTop + D * 0.15}
		C ${x0 + L - tailLen * 0.35} ${cy - D * 0.02} ${x0 + L - tailLen * 0.75} ${bot} ${x0 + L - tailLen * 1.15} ${bot}
		L ${x0 + nose} ${bot}
		C ${x0 + nose * 0.25} ${bot} ${x0} ${cy + D * 0.25} ${x0} ${cy + D * 0.05}
		C ${x0} ${top + D * 0.25} ${x0 + nose * 0.35} ${top} ${x0 + nose} ${top} Z`;
	s += `<path d="${body}" fill="url(#cuerpo)"/>`;
	// Cubierta superior (tipo jumbo)
	if (p.hump) {
		s += `<path d="M ${x0 + nose * 0.55} ${top + D * 0.08} C ${x0 + nose * 0.9} ${top - D * 0.42} ${x0 + L * 0.2} ${top - D * 0.42} ${x0 + L * 0.34} ${top - D * 0.2} C ${x0 + L * 0.38} ${top - D * 0.1} ${x0 + L * 0.4} ${top} ${x0 + L * 0.42} ${top + 1} Z" fill="url(#cuerpo)"/>`;
	}
	// Franja de color (cheatline) y vientre gris
	s += `<path d="M ${x0 + nose * 0.6} ${cy + D * 0.1} L ${x0 + L - tailLen * 0.9} ${cy + D * 0.1} L ${x0 + L - tailLen * 0.75} ${cy - D * 0.02} L ${x0 + L - tailLen * 0.6} ${cy - D * 0.02} L ${x0 + L - tailLen * 0.8} ${cy + D * 0.2} L ${x0 + nose * 0.45} ${cy + D * 0.2} Z" fill="${ORANGE}"/>`;
	// Cabina
	const cockY = (p.hump ? top - D * 0.22 : top + D * 0.2);
	const cockX = x0 + (p.hump ? nose * 0.95 : nose * 0.25);
	s += `<path d="M ${cockX} ${cockY + D * 0.16} L ${cockX + D * 0.18} ${cockY} L ${cockX + D * 0.62} ${cockY} L ${cockX + D * 0.6} ${cockY + D * 0.16} Z" fill="${GLASS}"/>`;
	// Puerta de carga
	s += `<rect x="${x0 + L * 0.3}" y="${top + D * 0.12}" width="${D * 0.85}" height="${D * 0.5}" rx="3" fill="none" stroke="#b9c3d3" stroke-width="1.5"/>`;
	// Ala (vista lateral: perfil fino) y motores
	const wingY = p.wing === "high" ? top + 3 : bot - D * 0.28;
	const wx = x0 + L * 0.36, wl = L * 0.28;
	s += `<path d="M ${wx} ${wingY} L ${wx + wl} ${wingY - (p.wing === "high" ? 2 : 6)} L ${wx + wl + 12} ${wingY + 4} L ${wx + 6} ${wingY + 8} Z" fill="#aab4c4"/>`;
	if (p.wing === "high" && !p.small) {
		// Puntal / carenado del tren en alas altas
		s += `<path d="M ${x0 + L * 0.45} ${bot - 6} h ${D * 0.9} l 6 ${D * 0.22} h ${-D * 0.9 - 12} Z" fill="#c9d1de"/>`;
	}
	if (p.wing === "low") {
		s += `<path d="M ${wx - D * 0.3} ${bot - 2} Q ${wx + wl * 0.4} ${bot + D * 0.16} ${wx + wl * 0.9} ${bot - 2} Z" fill="#c9d1de"/>`;
	}
	const engines = [];
	for (let i = 0; i < p.engines; i++) engines.push(wx + wl * (0.12 + 0.42 * i));
	engines.forEach((ex, i) => {
		const far = i > 0 && p.engines > 1;
		const ey = p.wing === "high" ? wingY + (p.eng === "prop" ? 6 : 10) : wingY + D * 0.22;
		const el = p.eng === "prop" ? D * 0.9 : D * 1.1, eh = p.eng === "prop" ? D * 0.28 : D * 0.5;
		const op = far ? 0.75 : 1;
		s += `<g opacity="${op}">`;
		if (p.eng === "jet") {
			const py = p.wing === "high" ? ey + eh / 2 : wingY;
			s += `<path d="M ${ex + el * 0.1} ${ey} L ${ex + el * 0.55} ${ey} L ${ex + el * 0.75} ${py + 2} L ${ex + el * 0.3} ${py + 2} Z" fill="#c9d1de"/>`;
		}
		s += `<rect x="${ex - el * 0.15}" y="${ey - eh / 2}" width="${el}" height="${eh}" rx="${eh / 2}" fill="url(#motor)"/>`;
		if (p.eng === "jet") {
			s += `<ellipse cx="${ex - el * 0.15 + 3}" cy="${ey}" rx="${eh * 0.18}" ry="${eh * 0.42}" fill="#0e1422"/>`;
			s += `<rect x="${ex + el * 0.15}" y="${ey - eh / 2}" width="${el * 0.25}" height="${eh}" fill="${ORANGE}" opacity="0.9"/>`;
		} else {
			s += `<ellipse cx="${ex - el * 0.18}" cy="${ey}" rx="3" ry="${D * 0.55}" fill="#3b4252" opacity="0.35"/>`;
			s += `<circle cx="${ex - el * 0.16}" cy="${ey}" r="4" fill="#2a3040"/>`;
		}
		s += `</g>`;
	});
	if (p.small) {
		// Avioneta: hélice en el morro
		s += `<ellipse cx="${x0 - 2}" cy="${cy + D * 0.05}" rx="3" ry="${D * 0.75}" fill="#3b4252" opacity="0.35"/>`;
		s += `<circle cx="${x0}" cy="${cy + D * 0.05}" r="4" fill="#2a3040"/>`;
		// Contenedor ventral (cargo pod)
		s += `<rect x="${x0 + L * 0.2}" y="${bot - 2}" width="${L * 0.42}" height="${D * 0.28}" rx="6" fill="#c9d1de"/>`;
	}
	return s;
}

const PLANES = [
	{ id: "courier", scale: 0.78, D: 34, wing: "high", eng: "prop", engines: 0, tail: "normal", small: true },
	{ id: "turboprop", scale: 0.9, D: 40, wing: "high", eng: "prop", engines: 1, tail: "T" },
	{ id: "narrowbody", scale: 0.95, D: 44, wing: "low", eng: "jet", engines: 1, tail: "normal" },
	{ id: "widebody", scale: 1, D: 54, wing: "low", eng: "jet", engines: 1, tail: "normal" },
	{ id: "jumbo", scale: 1, D: 56, wing: "low", eng: "jet", engines: 2, tail: "normal", hump: true },
	{ id: "heavy", scale: 1, D: 62, wing: "high", eng: "jet", engines: 2, tail: "normal", upsweep: true },
];

const defs = `<defs>
	<linearGradient id="cuerpo" x1="0" y1="0" x2="0" y2="1">
		<stop offset="0" stop-color="#ffffff"/><stop offset="0.55" stop-color="#eef2f7"/><stop offset="1" stop-color="#aeb8c8"/>
	</linearGradient>
	<linearGradient id="motor" x1="0" y1="0" x2="0" y2="1">
		<stop offset="0" stop-color="#e9edf3"/><stop offset="1" stop-color="#8f9aad"/>
	</linearGradient>
</defs>`;

(async () => {
	let cells = "";
	PLANES.forEach((p, i) => {
		const x = (i % 2) * 512, y = Math.floor(i / 2) * 256;
		cells += `<svg style="position:absolute;left:${x}px;top:${y}px" width="512" height="256" viewBox="0 0 512 256">${defs}${plane(p)}</svg>`;
	});
	const html = `<html><body style="margin:0;background:transparent"><div style="position:relative;width:1024px;height:768px">${cells}</div></body></html>`;
	const browser = await chromium.launch();
	const page = await browser.newPage({ viewport: { width: 1024, height: 768 } });
	await page.setContent(html);
	await page.screenshot({ path: path.join(ROOT, "assets", "aviones.png"), omitBackground: true });
	await browser.close();
	console.log("assets/aviones.png:", PLANES.map((p) => p.id).join(", "));
})();
