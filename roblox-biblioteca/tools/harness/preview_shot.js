// Fotografía los HTML de la vista previa con Chromium. Uso: node preview_shot.js <ancho> <alto> <escala> <html...>
const { chromium } = require("playwright");
(async () => {
	const [w, h, scale, ...files] = process.argv.slice(2);
	const browser = await chromium.launch({ args: ["--allow-file-access-from-files"] });
	const page = await browser.newPage({ viewport: { width: +w, height: +h }, deviceScaleFactor: +scale });
	for (const f of files) {
		await page.goto("file://" + f);
		await page.waitForSelector("body[data-ready]", { timeout: 15000, state: "attached" });
		await page.evaluate(() => document.fonts.ready);
		await page.screenshot({ path: f.replace(/\.html$/, ".png") });
		console.log(f.replace(/\.html$/, ".png"));
	}
	await browser.close();
})();
