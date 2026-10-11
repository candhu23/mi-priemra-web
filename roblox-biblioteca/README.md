# Estanterías Hechizadas (*Spellbound Shelves*)

Juego de Roblox para ordenar, en primera persona, los **3.072 libros** de una biblioteca mágica.
El diseño completo está en [`DISENO.md`](DISENO.md).

> **Estado:** en construcción (fase 5 de 6: el juego completo, con menú, 3 ranuras de guardado, finales y fase
> especial). Falta el pulido final (fase 6). En Studio **no se guarda** salvo que actives *API Services* (abajo).

## Probar en Roblox Studio

1. Descarga el lugar (clic derecho → *Guardar enlace como…* o ábrelo y pulsa *Download*):
   `https://github.com/candhu23/mi-priemra-web/raw/claude/biblioteca-arcana/roblox-biblioteca/Biblioteca.rbxl`
2. Ábrelo con doble clic (se abre en Roblox Studio).
3. Pulsa **Play** (arriba, en la pestaña *Home*). Sale el **menú de título**: pulsa **Nueva partida** y luego
   **Empezar aquí** en la ranura 1. Apareces en la entrada, en primera persona.
4. Qué probar:
   - Date la vuelta: junto a la puerta hay una **llave roja** brillando (aún no hace nada).
   - Mira la **carta** del atril de tu izquierda y pulsa **E**: se abre la carta de la rectora.
   - A tu izquierda, en una mesa, hay libros del **búho** y de **dragones**. Mira uno y pulsa **E** (o clic).
   - Ve a la estantería **1A** (izquierda) y coloca los 10 tomos en un estante largo, del 1 al 10.
     Cada libro bien puesto brilla **dorado**; mal puesto en su sección, **rojo**.
   - Arriba verás «Filas correctas», abajo «Libros en estanterías». **R** suelta un libro (mantén R: todos),
     **F** lo lanza, **clic derecho** pasa el de arriba al fondo, **Tab** abre la lista, **M** el mapa.
   - Con 2 filas correctas ganas tu primer **punto**: pulsa **B** (manual) y aprende un hechizo; se lanza con **1–5**.
   - **Llave roja** junto a la puerta → su **cofre** está en la esquina delantera izquierda → ya puedes **saltar** (Espacio).
   - El **cristal** del rellano de la escalera devuelve libros perdidos (por ejemplo, los lanzados encima de una estantería).
   - **P** abre la pausa: opciones (idioma, sensibilidad, campo de visión, música, **modo acogedor**…), logros y
     «Volver al menú».
5. Si algo falla, abre **View → Output** y mándame una captura de los mensajes en rojo.

### Para que se guarde la partida al probar en Studio

Hay que publicar primero (ver abajo) y después: **Home → Game Settings → Security → Enable Studio Access to API
Services → Save**. Sin eso verás el aviso «la partida NO se guardará» (es normal y no rompe nada).

## Publicar (importante)

- **File → Publish to Roblox As… → crear una experiencia NUEVA.** ¡No reemplaces *Web Empire Tycoon*!
- Más adelante: activar *Enable Studio Access to API Services*, **Max Players = 1**, crear las 12 insignias
  y rellenar el cuestionario de contenido. Los pasos detallados llegarán en la fase 6.
