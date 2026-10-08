// Genera assets/iconos.png: hoja de 8x8 iconos de 128 px (blancos, fondo transparente)
// a partir de los SVG de Lucide (licencia ISC) y escribe el índice en assets/iconos.txt.
// Uso: NODE_PATH=$(npm root -g) node tools/assets/build_icons.js
const { chromium } = require("playwright");
const fs = require("fs");
const path = require("path");

const ROOT = path.join(__dirname, "..", "..");
const SRC = path.join(__dirname, "lucide");
// El orden fija la posición en la hoja: NO lo cambies sin regenerar Config.Icons
const NAMES = [
	"menu", "map", "plane", "plane-takeoff", "plane-landing", "users", "user-round", "building-2",
	"settings", "wrench", "fuel", "landmark", "star", "package", "globe", "warehouse",
	"trending-up", "cloud-rain", "snowflake", "cloud-lightning", "sun", "clock", "gauge", "route",
	"coins", "banknote", "trophy", "languages", "volume-2", "volume-x", "x", "chevron-down",
	"check", "lock", "award", "refresh-cw", "zap", "shield-check", "thermometer-snowflake", "flame",
	"paw-print", "cpu", "mail", "apple", "container", "map-pin", "shopping-cart", "arrow-right",
	"info", "gift", "dices", "id-card", "chart-column", "circle-dollar-sign", "weight",
];
const CELL = 128, ICON = 92, COLS = 8;

(async () => {
	let cells = "";
	NAMES.forEach((name, i) => {
		const svg = fs.readFileSync(path.join(SRC, name + ".svg"), "utf8")
			.replace(/<!--.*?-->/s, "")
			.replace(/width="24"/, `width="${ICON}"`).replace(/height="24"/, `height="${ICON}"`)
			.replace(/stroke="currentColor"/, 'stroke="#ffffff"');
		const x = (i % COLS) * CELL + (CELL - ICON) / 2, y = Math.floor(i / COLS) * CELL + (CELL - ICON) / 2;
		cells += `<div style="position:absolute;left:${x}px;top:${y}px;width:${ICON}px;height:${ICON}px">${svg}</div>`;
	});
	const html = `<html><body style="margin:0;background:transparent"><div style="position:relative;width:1024px;height:1024px">${cells}</div></body></html>`;
	const browser = await chromium.launch();
	const page = await browser.newPage({ viewport: { width: 1024, height: 1024 } });
	await page.setContent(html);
	await page.screenshot({ path: path.join(ROOT, "assets", "iconos.png"), omitBackground: true });
	await browser.close();
	fs.writeFileSync(path.join(ROOT, "assets", "iconos.txt"), NAMES.map((n, i) => `${i}\t${n}`).join("\n") + "\n");
	console.log("assets/iconos.png:", NAMES.length, "iconos");
})();
