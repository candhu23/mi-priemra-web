---
name: roblox-ui-animaciones
description: Da «jugosidad» a la interfaz de un juego de Roblox con Animar.luau — aparecer con rebote, desaparecer, pulsar, sacudir (error), latir y balancear (llamar la atención), flotar, girar rayos, contar números hacia arriba, textos flotantes «+250», brillo que cruza tarjetas legendarias, deslizar, confeti 2D y destellos — con reglas de cuándo usar cada una y cómo no romper la interfaz (un solo UIScale, UIGradient sin texto, parar los bucles). Úsala cuando el usuario diga "que se mueva", "está muy estático/aburrido", "efectos", "animación al comprar/abrir/ganar", o al pulir cualquier pantalla.
---

# roblox-ui-animaciones — Animar

`Animar.luau` (carpeta de esta skill) → ReplicatedStorage. Sin dependencias (TweenService). Se usa desde LocalScripts.

## API
| Función | Úsala para |
|---|---|
| `Animar.aparecer(obj)` / `Animar.desaparecer(obj, destruir?)` | ventanas, premios, tarjetas nuevas (rebote al entrar, encoger al salir) |
| `Animar.pulsar(obj)` | respuesta al tocar cualquier cosa (encoge 10 % y vuelve) |
| `Animar.sacudir(obj)` | «no puedes»: sin dinero, inventario lleno |
| `local parar = Animar.latir(obj)` | algo listo para reclamar (regalo, misión). Llama `parar()` al reclamar |
| `Animar.balancear(obj)` / `Animar.flotar(obj)` / `Animar.girar(obj)` | huevo a punto de abrirse / flecha de tutorial / rayos detrás de un premio (devuelven `parar`) |
| `Animar.contar(label, desde, hasta, Animar.formatoCorto)` | cifras de premios y totales |
| `Animar.textoFlotante(lienzo, "+250", UDim2, color?)` | dinero ganado al hacer clic, críticos, daño |
| `local parar = Animar.brillo(frame)` | brillo que cruza tarjetas Legendarias/destacadas (solo Frames/Imágenes, NUNCA en texto) |
| `Animar.deslizarEntrar(obj, "abajo")` | paneles que entran desde un lado |
| `Animar.confeti(lienzo, 80)` | premio grande, rareza alta, subir de nivel |
| `Animar.destello(obj, color?)` | compra hecha, golpe, cambio de estado |
| `Animar.tw(obj, seg, props, estilo?, dir?)` | cualquier tween en una línea |

## Reglas de buen gusto
- **Rápido**: entradas 0,2–0,35 s; respuestas al toque < 0,1 s. Nada bloquea al jugador más de 2 s (salvo el suspense del huevo).
- **Proporcional**: cuanto más raro/valioso, más efecto (Común: nada; Raro: destello; Épico+: confeti; Legendario+: brillo continuo). Si todo celebra, nada celebra.
- Cada acción del jugador tiene respuesta visible (pulsar) y, si gana algo, sonora (pon un sonido corto con SoundService:PlayLocalSound).
- Bucles (`latir`, `girar`, `brillo`, `flotar`, `balancear`) **siempre** con su `parar()` al cerrar la pantalla: si no, se acumulan.
- Respeta a quien se marea: nada de sacudir la pantalla entera ni parpadeos rápidos.

## Trampas
- `aparecer/latir/pulsar` usan un UIScale propio («AnimEscala»). Si el objeto YA tiene otro UIScale (escala de pantalla), anima un Frame contenedor: Roblox solo aplica un UIScale por objeto.
- `brillo` usa UIGradient: en un TextLabel/TextButton teñiría las letras (por eso se niega y avisa).
- Anima Position/Size con Scale+Offset coherentes; si el objeto está en un UIListLayout/UIGridLayout, la posición la manda el layout: anima un hijo interior.
- Probado en Lune (las animaciones se aplican al instante allí). La sensación real hay que verla en Studio: pide al usuario que lo pruebe y te diga si va «lento» o «rápido».
