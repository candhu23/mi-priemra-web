---
name: arte-roblox
description: Crea el arte de la ficha y la tienda de los juegos de Roblox — iconos de Game Passes y Developer Products, icono del juego y miniaturas (thumbnails) — como PNG listos para subir, con un estilo coherente (rayos, brillo, emoji grande, texto grueso con borde) y comprobando cómo quedan recortados en círculo, que es como Roblox muestra los pases. Úsala cuando el usuario pida iconos, imágenes de pases, portada, miniatura, thumbnail, "algo para la tienda", o cuando se cree un pase/producto nuevo sin imagen. Puede subir los iconos con la skill roblox-nube.
---

# arte-roblox — iconos y miniaturas

`python3 -I .claude/skills/arte-roblox/arte.py <encargo.json> <carpeta>` → un PNG por pieza + `hoja.png`
(todas juntas; los iconos también recortados en círculo). Formato del encargo: cabecera de `arte.py`.

| tipo | Tamaño | Dónde va |
|---|---|---|
| `pase` / `producto` | 512×512 | Icono del Game Pass / Developer Product (Roblox lo enseña en **círculo**) |
| `icono` | 512×512 | Icono de la experiencia (Creator Hub → la experiencia → Places → Icon) |
| `miniatura` | 1920×1080 | Thumbnails (hasta 10; la 1.ª es la que más se ve en la portada) |

## Flujo

1. Escribe el encargo en `<juego>/docs/arte/encargo.json` (así se puede rehacer y retocar más tarde).
   Textos **en inglés** si la ficha del juego está en inglés (Web Empire), cortos: título 1–5 caracteres
   («x2», «+3», «PRO»), subtítulo 1 palabra. Un color de fondo distinto por pase para distinguirlos.
2. Genera en `<juego>/docs/arte/` y **mira `hoja.png` con Read**. Revisa: ¿se lee a 100 px? ¿cabe en el
   círculo? ¿el emoji se ve (no sale en blanco)? ¿colores distintos entre pases? Corrige y repite.
3. Enseña la hoja al usuario (SendUserFile). Pide su «sí» antes de subir nada.
4. Subir:
   - Con clave Open Cloud: `roblox_cloud.py imagen <juego> pase <id> <png> --confirmo` (y `producto`).
     Al crear un artículo nuevo: `crear-pase … --imagen <png>`.
   - Sin clave, pasos para el usuario: Creator Hub → la experiencia → **Monetization → Passes** (o
     *Developer Products*) → el artículo → **Edit/Configure** → cambiar imagen → subir el PNG → Save.
   - Icono y miniaturas (no hay API): Creator Hub → la experiencia → **Places → el lugar → Configure** /
     *Basic Settings* → Icon / Thumbnails → subir. Roblox los modera antes de mostrarlos (puede tardar).
5. Sube los PNG al repo (`docs/arte/`) para tenerlos guardados.

## Buenas prácticas de la ficha (lo que más ayuda a que entren jugadores)

- **Icono**: un objeto central reconocible + 1–2 palabras como mucho, contraste fuerte, nada de letra
  pequeña. Tiene que entenderse a 150 px en la lista de juegos.
- **Miniatura 1**: lo que se hace en el juego (captura con `disenar-interfaz` o el render del mundo) como
  fondo, título grande a la izquierda y un mensaje corto («Code websites · Get rich»). Etiqueta
  «🆕 UPDATE» solo si es verdad y es reciente.
- Nada que imite logos de otras marcas, nada de «FREE ROBUX», ni personajes o marcas con copyright.
- Cambia la miniatura 1 al sacar una actualización grande: es lo que más se nota al volver a la portada.

## Archivos

- `arte.py`: genera el HTML de cada pieza, ajusta el texto al ancho seguro y llama a `fotografiar.js`.
- `fotografiar.js`: Chromium (Playwright) → PNG y `hoja.png`.
- Fuentes de Google (Fredoka One por defecto, también Luckiest Guy, Bangers, Montserrat, Nunito) y
  emojis de Noto Color Emoji: hace falta red para `fonts.googleapis.com`.
