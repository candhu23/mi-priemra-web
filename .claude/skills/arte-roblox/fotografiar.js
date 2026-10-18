// Fotografía las piezas de arte.py y monta hoja.png con todas (iconos recortados en círculo).
// Uso: node fotografiar.js '<trabajos JSON>' <hoja.png>
const { chromium } = require("playwright");
(async () => {
	const trabajos = JSON.parse(process.argv[2]);
	const hoja = process.argv[3];
	const browser = await chromium.launch({ args: ["--allow-file-access-from-files"] });
	for (const t of trabajos) {
		const page = await (await browser.newContext({ viewport: { width: t.w, height: t.h }, ignoreHTTPSErrors: true })).newPage();
		await page.goto("file://" + t.html);
		await page.waitForSelector("body[data-ready]", { state: "attached", timeout: 20000 });
		await page.screenshot({ path: t.png });
		await page.close();
	}
	// Hoja de revisión: iconos a 256 px (tal cual y en círculo) y miniaturas a 480 px
	const celdas = trabajos.map((t) => {
		const nombre = t.png.split("/").pop();
		if (t.circulo) {
			return `<figure><div style="display:flex;gap:10px"><img src="file://${t.png}" width="256" height="256" style="border-radius:16px">` +
				`<img src="file://${t.png}" width="256" height="256" style="border-radius:50%"></div><figcaption>${nombre}</figcaption></figure>`;
		}
		return `<figure><img src="file://${t.png}" width="480" height="270" style="border-radius:12px"><figcaption>${nombre}</figcaption></figure>`;
	}).join("");
	const page = await (await browser.newContext({ viewport: { width: 1100, height: 400 } })).newPage();
	const fs = require("fs");
	const htmlHoja = hoja.replace(/\.png$/, ".html");
	fs.writeFileSync(htmlHoja, `<html><body style="margin:0;padding:20px;background:#1f2937;font:600 15px sans-serif;color:#e5e7eb;display:flex;flex-wrap:wrap;gap:22px;width:1060px">${celdas}</body></html>`);
	await page.goto("file://" + htmlHoja, { waitUntil: "load" });
	await page.screenshot({ path: hoja, fullPage: true });
	fs.unlinkSync(htmlHoja);
	await browser.close();
})();
