// Genera el icono (512x512) y las miniaturas (1920x1080) del juego con SVG + Chromium.
// Uso (desde roblox/StealAnAlien): node assets/generar_arte.js <carpeta-de-fuentes>
// Necesita Playwright y las fuentes Fredoka y Lilita One (licencia OFL).

const { chromium } = require("playwright");
const fs = require("fs");
const path = require("path");

const carpetaFuentes = path.resolve(process.argv[2] || ".");
const salida = path.join(__dirname);

// Generador pseudoaleatorio con semilla, para que las imágenes salgan siempre iguales.
function rng(semilla) {
  let s = semilla;
  return () => {
    s = (s * 16807) % 2147483647;
    return (s - 1) / 2147483646;
  };
}

const RAREZAS = {
  Common: "#C8C8D2",
  Rare: "#46A0FF",
  Epic: "#B450FF",
  Legendary: "#FFBE1E",
  Mythic: "#FF3C5A",
  Secret: "#28FFDC",
};

function estrellas(ancho, alto, cantidad, semilla) {
  const r = rng(semilla);
  let svg = "";
  for (let i = 0; i < cantidad; i++) {
    const x = r() * ancho, y = r() * alto, t = r() * 2.2 + 0.4, o = r() * 0.7 + 0.3;
    svg += `<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="${t.toFixed(2)}" fill="#fff" opacity="${o.toFixed(2)}"/>`;
  }
  return svg;
}

// Alien al estilo del juego: cuerpo redondo, ojos grandes, antenas con bolita de color de rareza.
function alien({ x, y, s, color, ojos = 2, extras = ["antenas"], rareza = "#fff", brillo = false, rot = 0, sonrisa = true }) {
  const oscuro = "rgba(0,0,0,0.25)";
  let g = `<g transform="translate(${x},${y}) rotate(${rot}) scale(${s / 100})">`;
  if (brillo) {
    g += `<circle cx="0" cy="0" r="95" fill="${rareza}" opacity="0.35" filter="url(#desenfoque)"/>`;
  }
  // accesorios traseros
  if (extras.includes("alas")) {
    g += `<path d="M-40,-10 C-120,-80 -150,10 -95,40 Z" fill="${rareza}" opacity="0.55" stroke="#fff" stroke-width="3"/>`;
    g += `<path d="M40,-10 C120,-80 150,10 95,40 Z" fill="${rareza}" opacity="0.55" stroke="#fff" stroke-width="3"/>`;
  }
  if (extras.includes("tentaculos")) {
    for (const dx of [-36, -12, 12, 36]) {
      g += `<path d="M${dx},35 q${dx / 3},40 ${dx / 2 + 8},62" stroke="${color}" stroke-width="16" stroke-linecap="round" fill="none"/>`;
    }
  }
  if (extras.includes("antenas")) {
    g += `<path d="M-22,-42 Q-35,-80 -45,-92" stroke="${color}" stroke-width="8" fill="none" stroke-linecap="round"/>`;
    g += `<path d="M22,-42 Q35,-80 45,-92" stroke="${color}" stroke-width="8" fill="none" stroke-linecap="round"/>`;
    g += `<circle cx="-45" cy="-95" r="11" fill="${rareza}" stroke="#000" stroke-width="3"/>`;
    g += `<circle cx="45" cy="-95" r="11" fill="${rareza}" stroke="#000" stroke-width="3"/>`;
  }
  if (extras.includes("orejas")) {
    g += `<ellipse cx="-38" cy="-40" rx="16" ry="26" transform="rotate(-25 -38 -40)" fill="${color}" stroke="#000" stroke-width="4"/>`;
    g += `<ellipse cx="38" cy="-40" rx="16" ry="26" transform="rotate(25 38 -40)" fill="${color}" stroke="#000" stroke-width="4"/>`;
  }
  if (extras.includes("cuernos")) {
    g += `<path d="M-30,-40 L-48,-85 L-14,-48 Z" fill="#FFF5DC" stroke="#000" stroke-width="4"/>`;
    g += `<path d="M30,-40 L48,-85 L14,-48 Z" fill="#FFF5DC" stroke="#000" stroke-width="4"/>`;
  }
  // cuerpo
  g += `<ellipse cx="0" cy="0" rx="55" ry="52" fill="${color}" stroke="#000" stroke-width="5"/>`;
  g += `<ellipse cx="-18" cy="-24" rx="20" ry="11" fill="#fff" opacity="0.35"/>`;
  g += `<ellipse cx="0" cy="30" rx="40" ry="14" fill="${oscuro}" opacity="0.4"/>`;
  if (extras.includes("corona")) {
    g += `<path d="M-30,-44 L-30,-72 L-15,-56 L0,-78 L15,-56 L30,-72 L30,-44 Z" fill="#FFD23C" stroke="#000" stroke-width="4"/>`;
  }
  if (extras.includes("halo")) {
    g += `<ellipse cx="0" cy="-78" rx="38" ry="9" fill="none" stroke="${rareza}" stroke-width="7"/>`;
  }
  // ojos
  const posiciones = ojos === 1 ? [0] : ojos === 2 ? [-20, 20] : [-28, 0, 28];
  const r = ojos === 1 ? 24 : ojos === 2 ? 17 : 13;
  for (const ox of posiciones) {
    g += `<circle cx="${ox}" cy="-6" r="${r}" fill="#fff" stroke="#000" stroke-width="3"/>`;
    g += `<circle cx="${ox + r * 0.15}" cy="-4" r="${r * 0.55}" fill="#140A1E"/>`;
    g += `<circle cx="${ox + r * 0.35}" cy="${-6 - r * 0.3}" r="${r * 0.2}" fill="#fff"/>`;
  }
  if (sonrisa) {
    g += `<path d="M-16,22 Q0,36 16,22" stroke="#28102A" stroke-width="5" fill="none" stroke-linecap="round"/>`;
  }
  g += `</g>`;
  return g;
}

// Personaje "de bloques" al estilo Roblox (genérico, sin marcas).
function personaje({ x, y, s, camiseta, pantalon, piel = "#F5CD9B", corriendo = true, brazosArriba = false, mirando = 1 }) {
  let g = `<g transform="translate(${x},${y}) scale(${s / 100 * mirando},${s / 100})">`;
  const piernaA = corriendo ? -18 : 0, piernaB = corriendo ? 18 : 0;
  g += `<rect x="-20" y="40" width="19" height="62" rx="4" fill="${pantalon}" stroke="#000" stroke-width="4" transform="rotate(${piernaA} -10 40)"/>`;
  g += `<rect x="1" y="40" width="19" height="62" rx="4" fill="${pantalon}" stroke="#000" stroke-width="4" transform="rotate(${piernaB} 10 40)"/>`;
  g += `<rect x="-22" y="-22" width="44" height="64" rx="5" fill="${camiseta}" stroke="#000" stroke-width="4"/>`;
  if (brazosArriba) {
    g += `<rect x="-41" y="-80" width="18" height="62" rx="4" fill="${piel}" stroke="#000" stroke-width="4" transform="rotate(10 -32 -20)"/>`;
    g += `<rect x="23" y="-80" width="18" height="62" rx="4" fill="${piel}" stroke="#000" stroke-width="4" transform="rotate(-10 32 -20)"/>`;
  } else {
    g += `<rect x="-41" y="-20" width="18" height="60" rx="4" fill="${piel}" stroke="#000" stroke-width="4" transform="rotate(${corriendo ? 35 : 0} -32 -20)"/>`;
    g += `<rect x="23" y="-20" width="18" height="60" rx="4" fill="${piel}" stroke="#000" stroke-width="4" transform="rotate(${corriendo ? -55 : 0} 32 -20)"/>`;
  }
  g += `<rect x="-19" y="-62" width="38" height="38" rx="9" fill="${piel}" stroke="#000" stroke-width="4"/>`;
  g += `<circle cx="-6" cy="-46" r="3.5" fill="#000"/><circle cx="8" cy="-46" r="3.5" fill="#000"/>`;
  g += `<path d="M-6,-35 Q2,-30 9,-35" stroke="#000" stroke-width="3" fill="none"/>`;
  g += `</g>`;
  return g;
}

function planeta(x, y, r, color, anillo) {
  let g = `<g transform="translate(${x},${y})">`;
  if (anillo) g += `<ellipse cx="0" cy="0" rx="${r * 1.8}" ry="${r * 0.42}" fill="none" stroke="#FFDCA0" stroke-width="${r * 0.12}" opacity="0.75" transform="rotate(-18)"/>`;
  g += `<circle cx="0" cy="0" r="${r}" fill="${color}"/>`;
  g += `<circle cx="${-r * 0.3}" cy="${-r * 0.3}" r="${r * 0.75}" fill="#fff" opacity="0.13"/>`;
  g += `<path d="M${-r},0 A${r},${r} 0 0,0 ${r},0" fill="#000" opacity="0.18"/>`;
  if (anillo) g += `<path d="M${-r * 1.75},${r * 0.2} A${r * 1.8},${r * 0.42} 0 0,0 ${r * 1.75},${-r * 0.2}" fill="none" stroke="#FFDCA0" stroke-width="${r * 0.12}" opacity="0.85" transform="rotate(-18)"/>`;
  g += `</g>`;
  return g;
}

function titulo(x, y, tam, lineas, ancla = "middle") {
  let g = "";
  lineas.forEach((l, i) => {
    const yy = y + i * tam * 1.02;
    const atr = `x="${x}" y="${yy}" font-family="Lilita" font-size="${tam}" text-anchor="${ancla}"`;
    g += `<text ${atr} fill="#000" stroke="#000" stroke-width="${tam * 0.22}" stroke-linejoin="round">${l.texto}</text>`;
    g += `<text ${atr} fill="url(#${l.degradado})" stroke="#fff" stroke-width="${tam * 0.035}">${l.texto}</text>`;
  });
  return g;
}

function defs() {
  return `<defs>
    <radialGradient id="fondo" cx="50%" cy="40%" r="75%">
      <stop offset="0%" stop-color="#3B1880"/><stop offset="55%" stop-color="#1A0B45"/><stop offset="100%" stop-color="#070316"/>
    </radialGradient>
    <linearGradient id="oro" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#FFF27A"/><stop offset="100%" stop-color="#FFB400"/></linearGradient>
    <linearGradient id="cian" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#B6FFF0"/><stop offset="100%" stop-color="#00E0B0"/></linearGradient>
    <linearGradient id="rayo" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#9DFFEA" stop-opacity="0.85"/><stop offset="100%" stop-color="#00FFC8" stop-opacity="0.05"/></linearGradient>
    <linearGradient id="cinta" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#2E2E44"/><stop offset="100%" stop-color="#16161F"/></linearGradient>
    <filter id="desenfoque"><feGaussianBlur stdDeviation="12"/></filter>
  </defs>`;
}

function pagina(ancho, alto, cuerpo) {
  return `<!doctype html><html><head><meta charset="utf-8"><style>
    @font-face { font-family: "Lilita"; src: url("file://${carpetaFuentes}/LilitaOne.ttf"); }
    @font-face { font-family: "Fredoka"; src: url("file://${carpetaFuentes}/Fredoka.ttf"); font-weight: 300 700; }
    html,body{margin:0;padding:0;background:#000}
    svg{display:block}
  </style></head><body>
  <svg xmlns="http://www.w3.org/2000/svg" width="${ancho}" height="${alto}" viewBox="0 0 ${ancho} ${alto}">${defs()}${cuerpo}</svg>
  </body></html>`;
}

function ovni(x, y, s) {
  let g = `<g transform="translate(${x},${y}) scale(${s / 100})">`;
  g += `<ellipse cx="0" cy="0" rx="110" ry="34" fill="#9AA4C8" stroke="#000" stroke-width="6"/>`;
  g += `<ellipse cx="0" cy="-22" rx="52" ry="42" fill="#7DF9FF" opacity="0.85" stroke="#000" stroke-width="6"/>`;
  g += `<ellipse cx="-16" cy="-38" rx="16" ry="9" fill="#fff" opacity="0.6"/>`;
  for (const lx of [-70, -35, 0, 35, 70]) g += `<circle cx="${lx}" cy="8" r="8" fill="#FFE45C" stroke="#000" stroke-width="3"/>`;
  g += `</g>`;
  return g;
}

// ---------------- ICONO 512x512 ----------------
function icono() {
  const W = 512, H = 512;
  let c = `<rect width="${W}" height="${H}" fill="url(#fondo)"/>`;
  c += estrellas(W, H, 90, 3);
  c += planeta(430, 92, 52, "#FF7A50", true);
  c += planeta(70, 440, 34, "#5AC8FF", false);
  // rayo del ovni
  c += `<path d="M196,150 L316,150 L400,470 L112,470 Z" fill="url(#rayo)"/>`;
  c += ovni(256, 132, 110);
  c += alien({ x: 256, y: 318, s: 150, color: "#78E678", extras: ["antenas"], rareza: RAREZAS.Legendary, brillo: true, rot: -6 });
  c += titulo(256, 470, 64, [{ texto: "STEAL AN ALIEN", degradado: "oro" }]);
  return pagina(W, H, c);
}

// ---------------- MINIATURA 1: robo en la cinta ----------------
function miniaturaRobo() {
  const W = 1920, H = 1080;
  let c = `<rect width="${W}" height="${H}" fill="url(#fondo)"/>`;
  c += estrellas(W, H, 260, 11);
  c += planeta(1680, 190, 120, "#FF7A50", true);
  c += planeta(110, 520, 46, "#B478FF", false);
  // suelo y cinta en perspectiva sencilla
  c += `<rect x="0" y="760" width="${W}" height="320" fill="#26203F"/>`;
  c += `<rect x="0" y="690" width="${W}" height="110" fill="url(#cinta)" stroke="#000" stroke-width="6"/>`;
  c += `<rect x="0" y="684" width="${W}" height="14" fill="#00FFC8"/>`;
  c += `<rect x="0" y="796" width="${W}" height="14" fill="#00FFC8"/>`;
  for (let i = 0; i < 12; i++) c += `<path d="M${60 + i * 170},745 l40,-14 l0,28 Z" fill="#00B496" opacity="0.6"/>`;
  // aliens en la cinta
  c += alien({ x: 260, y: 630, s: 120, color: "#78DCFF", ojos: 1, rareza: RAREZAS.Rare });
  c += alien({ x: 560, y: 610, s: 150, color: "#AA64FF", ojos: 2, extras: ["orejas", "halo"], rareza: RAREZAS.Epic, brillo: true });
  c += alien({ x: 1460, y: 600, s: 170, color: "#FF3250", ojos: 2, extras: ["alas", "cuernos"], rareza: RAREZAS.Mythic, brillo: true });
  c += alien({ x: 1760, y: 640, s: 110, color: "#78E678", extras: ["antenas"], rareza: RAREZAS.Common });
  // ladrón corriendo con un alien legendario
  c += personaje({ x: 980, y: 820, s: 230, camiseta: "#2D2D2D", pantalon: "#1E3A8A", brazosArriba: true, mirando: -1 });
  c += alien({ x: 980, y: 520, s: 190, color: "#3C78FF", ojos: 2, extras: ["halo", "antenas"], rareza: RAREZAS.Legendary, brillo: true, rot: 8 });
  // dueño persiguiendo
  c += personaje({ x: 1290, y: 860, s: 190, camiseta: "#E03C3C", pantalon: "#333", mirando: -1 });
  c += `<text x="1175" y="745" font-family="Lilita" font-size="90" text-anchor="middle" fill="#FF5050" stroke="#000" stroke-width="12" paint-order="stroke">!!</text>`;
  // etiquetas de rareza
  const etiqueta = (x, y, texto, color) =>
    `<text x="${x}" y="${y}" font-family="Lilita" font-size="44" text-anchor="middle" fill="${color}" stroke="#000" stroke-width="9" paint-order="stroke">${texto}</text>`;
  c += etiqueta(980, 300, "LEGENDARY", RAREZAS.Legendary);
  c += etiqueta(1460, 470, "MYTHIC", RAREZAS.Mythic);
  c += etiqueta(560, 500, "EPIC", RAREZAS.Epic);
  c += titulo(80, 190, 150, [{ texto: "STEAL AN", degradado: "cian" }, { texto: "ALIEN!", degradado: "oro" }], "start");
  return pagina(W, H, c);
}

// ---------------- MINIATURA 2: colección ----------------
function miniaturaColeccion() {
  const W = 1920, H = 1080;
  let c = `<rect width="${W}" height="${H}" fill="url(#fondo)"/>`;
  c += estrellas(W, H, 260, 21);
  c += planeta(120, 150, 60, "#5AC8FF", false);
  c += planeta(1800, 980, 90, "#FF7A50", true);
  c += titulo(960, 190, 130, [{ texto: "COLLECT 16 ALIENS", degradado: "oro" }]);
  const fila = [
    { color: "#78E678", extras: ["antenas"], rareza: "Common", ojos: 2 },
    { color: "#F0F0C8", extras: ["cuernos"], rareza: "Rare", ojos: 2 },
    { color: "#FF64B4", extras: ["tentaculos", "corona"], rareza: "Epic", ojos: 3 },
    { color: "#B4FF50", extras: ["halo", "antenas"], rareza: "Legendary", ojos: 1 },
    { color: "#FF3250", extras: ["alas", "cuernos"], rareza: "Mythic", ojos: 2 },
  ];
  fila.forEach((a, i) => {
    const x = 230 + i * 350;
    const y = 560 + (i % 2) * 40;
    c += alien({ x, y, s: i === 4 ? 175 : 165 + i * 10, color: a.color, ojos: a.ojos, extras: a.extras, rareza: RAREZAS[a.rareza], brillo: i >= 3 });
    c += `<text x="${x}" y="${y + 190}" font-family="Lilita" font-size="54" text-anchor="middle" fill="${RAREZAS[a.rareza]}" stroke="#000" stroke-width="10" paint-order="stroke">${a.rareza.toUpperCase()}</text>`;
  });
  // secreto en silueta
  c += `<g opacity="0.95">${alien({ x: 960, y: 900, s: 120, color: "#111", ojos: 3, extras: ["halo"], rareza: RAREZAS.Secret, brillo: true, sonrisa: false })}</g>`;
  c += `<text x="1100" y="925" font-family="Lilita" font-size="64" fill="${RAREZAS.Secret}" stroke="#000" stroke-width="10" paint-order="stroke">SECRET ???</text>`;
  return pagina(W, H, c);
}

// ---------------- MINIATURA 3: eventos ----------------
function miniaturaEventos() {
  const W = 1920, H = 1080;
  let c = `<rect width="${W}" height="${H}" fill="url(#fondo)"/>`;
  c += estrellas(W, H, 220, 31);
  c += `<defs><radialGradient id="fuego"><stop offset="0%" stop-color="#FFF6B0"/><stop offset="45%" stop-color="#FF9A3C"/><stop offset="100%" stop-color="#FF3C1E" stop-opacity="0"/></radialGradient>
    <linearGradient id="estela" x1="1" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#FF7A2A" stop-opacity="0"/><stop offset="100%" stop-color="#FFC060" stop-opacity="0.9"/></linearGradient></defs>`;
  // Meteoritos (mitad izquierda)
  const r = rng(5);
  for (let i = 0; i < 7; i++) {
    const x = 120 + r() * 760, y = 330 + r() * 300;
    c += `<line x1="${x + 230}" y1="${y - 230}" x2="${x}" y2="${y}" stroke="#FFB45A" stroke-width="30" stroke-linecap="round" opacity="0.35"/>`;
    c += `<line x1="${x + 150}" y1="${y - 150}" x2="${x}" y2="${y}" stroke="#FFE08A" stroke-width="12" stroke-linecap="round" opacity="0.7"/>`;
    c += `<circle cx="${x}" cy="${y}" r="70" fill="url(#fuego)"/>`;
    c += `<circle cx="${x}" cy="${y}" r="24" fill="#FF8C32" stroke="#000" stroke-width="5"/>`;
  }
  // suelo y cristales
  c += `<rect x="0" y="830" width="${W}" height="250" fill="#26203F"/>`;
  for (const x of [140, 330, 560, 760]) {
    c += `<circle cx="${x}" cy="800" r="60" fill="#5AE6FF" opacity="0.35" filter="url(#desenfoque)"/>`;
    c += `<path d="M${x},700 l34,70 l-34,62 l-34,-62 Z" fill="#5AE6FF" stroke="#000" stroke-width="5"/>`;
    c += `<path d="M${x},700 l12,70 l-12,62 Z" fill="#fff" opacity="0.4"/>`;
  }
  c += personaje({ x: 470, y: 760, s: 170, camiseta: "#7A3CFF", pantalon: "#222", brazosArriba: true, corriendo: false });
  // Cinta con suerte (mitad derecha)
  c += `<rect x="1000" y="700" width="920" height="100" fill="url(#cinta)" stroke="#000" stroke-width="6"/>`;
  c += `<rect x="1000" y="694" width="920" height="12" fill="#78FF78"/><rect x="1000" y="794" width="920" height="12" fill="#78FF78"/>`;
  c += alien({ x: 1150, y: 600, s: 140, color: "#AA64FF", extras: ["orejas", "halo"], rareza: RAREZAS.Epic, brillo: true });
  c += alien({ x: 1420, y: 570, s: 175, color: "#3C78FF", extras: ["halo", "antenas"], rareza: RAREZAS.Legendary, brillo: true });
  c += alien({ x: 1700, y: 600, s: 140, color: "#FF3250", extras: ["alas", "cuernos"], rareza: RAREZAS.Mythic, brillo: true });
  // trébol y x4
  c += `<g transform="translate(1180,330)">
      <circle cx="0" cy="0" r="120" fill="#78FF78" opacity="0.25" filter="url(#desenfoque)"/>
      <circle cx="-28" cy="-28" r="34" fill="#3CD25A" stroke="#000" stroke-width="5"/><circle cx="28" cy="-28" r="34" fill="#3CD25A" stroke="#000" stroke-width="5"/>
      <circle cx="-28" cy="28" r="34" fill="#3CD25A" stroke="#000" stroke-width="5"/><circle cx="28" cy="28" r="34" fill="#3CD25A" stroke="#000" stroke-width="5"/>
      <circle cx="0" cy="0" r="14" fill="#2AA845"/>
    </g>`;
  c += `<text x="1270" y="370" font-family="Lilita" font-size="110" fill="#78FF78" stroke="#000" stroke-width="14" paint-order="stroke">x4</text>`;
  c += titulo(960, 175, 120, [{ texto: "METEOR SHOWERS", degradado: "oro" }]);
  c += `<text x="1460" y="900" font-family="Lilita" font-size="70" text-anchor="middle" fill="#78FF78" stroke="#000" stroke-width="12" paint-order="stroke">LUCKY BELT</text>`;
  c += `<text x="470" y="1000" font-family="Lilita" font-size="70" text-anchor="middle" fill="#5AE6FF" stroke="#000" stroke-width="12" paint-order="stroke">SPACE CRYSTALS</text>`;
  return pagina(W, H, c);
}

(async () => {
  const navegador = await chromium.launch();
  const trabajos = [
    { nombre: "icono_512.png", html: icono(), w: 512, h: 512 },
    { nombre: "miniatura_1_robo.png", html: miniaturaRobo(), w: 1920, h: 1080 },
    { nombre: "miniatura_2_coleccion.png", html: miniaturaColeccion(), w: 1920, h: 1080 },
    { nombre: "miniatura_3_eventos.png", html: miniaturaEventos(), w: 1920, h: 1080 },
  ];
  for (const t of trabajos) {
    const pagina = await navegador.newPage({ viewport: { width: t.w, height: t.h } });
    const html = path.join(salida, "_tmp.html");
    fs.writeFileSync(html, t.html);
    await pagina.goto("file://" + html);
    await pagina.evaluate(() => document.fonts.ready);
    await pagina.waitForTimeout(300);
    await pagina.screenshot({ path: path.join(salida, t.nombre), clip: { x: 0, y: 0, width: t.w, height: t.h } });
    await pagina.close();
    console.log("Creado", t.nombre);
  }
  fs.unlinkSync(path.join(salida, "_tmp.html"));
  await navegador.close();
})();
