// Convierte los SVG de la planta en PNG con Chromium (Playwright). Uso: node svg2png.js <carpeta>
const { chromium } = require("playwright");
const fs = require("fs");
const path = require("path");
(async () => {
	const dir = process.argv[2];
	const browser = await chromium.launch();
	const page = await browser.newPage();
	for (const f of fs.readdirSync(dir).filter((f) => f.endsWith(".svg"))) {
		await page.goto("file://" + path.resolve(dir, f));
		const el = await page.$("svg");
		await el.screenshot({ path: path.resolve(dir, f.replace(".svg", ".png")) });
	}
	await browser.close();
})();
