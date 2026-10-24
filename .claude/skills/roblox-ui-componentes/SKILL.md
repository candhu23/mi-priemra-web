---
name: roblox-ui-componentes
description: Biblioteca de componentes de interfaz para Roblox (UIKit.luau) lista para copiar — pantalla con escala automática PC/móvil, botón grueso con sombra que se hunde, tarjeta, ventana modal con animación, pestañas, barra de progreso, contador de monedas animado, insignia de avisos, rejilla con scroll para tiendas e inventarios, interruptor, avisos (toasts) y colores de rareza. Úsala siempre que haya que CREAR interfaz en un juego de Roblox (menús, HUD, tienda, inventario, ajustes) en vez de escribir Frames a mano, o cuando el usuario pida "botones bonitos", "una ventana", "una tienda", "un menú".
---

# roblox-ui-componentes — UIKit

`UIKit.luau` (en la carpeta de esta skill: la ruta sale al cargarla; si no, `find / -name UIKit.luau -path "*roblox-ui-componentes*" 2>/dev/null`).
Cópialo a `src/ReplicatedStorage/UIKit.luau` (Rojo) o pégalo en un ModuleScript «UIKit» en ReplicatedStorage (Studio).
No depende de nada. Con tema propio: `UIKit.usarTema(require(ReplicatedStorage.Tema))` (skill roblox-ui-estilo).

## Piezas
| Función | Qué crea | Devuelve |
|---|---|---|
| `UIKit.pantalla(nombre, orden?)` | ScreenGui (ResetOnSpawn=false, zona segura) + Frame «Lienzo» de 1280×720 con UIScale automático (mín. 0,7) que ocupa toda la pantalla | el lienzo: mete todo dentro |
| `UIKit.boton{Parent, texto, icono?, color?, tamanoTexto?, alPulsar, Size?, Position?, AnchorPoint?}` | botón grueso con sombra, brillo, hover, se hunde al pulsar, usa `.Activated` | `caja, api` (`api:texto(s)`, `api:color(c)`, `api:activo(bool)`, `api.boton`) |
| `UIKit.tarjeta{Parent, color?, colorBorde?, relleno?, Size, Position}` | panel redondeado con borde | Frame |
| `UIKit.ventana{Parent=lienzo, titulo, Size?}` | ventana modal: velo oscuro, título, botón X, abre con rebote, se encoge sola si no cabe (móvil), tocar fuera la cierra | `api` con `.contenido`, `:abrir()`, `:cerrar()`, `:abierta()`, `.alCerrar` |
| `UIKit.pestanas{Parent, nombres={…}, alCambiar?}` | fila de pestañas + una página por pestaña | `api.paginas[i]`, `api:ir(i)` |
| `UIKit.barra{Parent, Size?, color?, texto?}` | barra de progreso redondeada | `api:poner(valor, max, textoExtra?)` |
| `UIKit.contador{Parent, icono, color?, Position?}` | contador de moneda; la cifra sube animada y da un saltito | `api:poner(valor)` |
| `UIKit.insignia(boton)` | puntito rojo con número (misiones listas, regalos) | `api:poner(n)` (0 = oculto) |
| `UIKit.rejilla{Parent, celda=Vector2, Size?, Position?}` | ScrollingFrame con UIGridLayout y lienzo automático | ScrollingFrame (mete tarjetas) |
| `UIKit.interruptor{Parent, texto, valor, alCambiar}` | interruptor sí/no para ajustes | `api:poner(bool)` |
| `UIKit.aviso(lienzo, texto, "exito"|"peligro"|"aviso"|"info", seg?)` | aviso arriba en el centro que se va solo | — |
| `UIKit.texto{texto, tamano, titulo?, color?, alinear?, …}` | TextLabel con la letra del tema (títulos con contorno) | TextLabel |
| `UIKit.crear(clase, props, hijos?)` | cualquier instancia (claves en minúscula se ignoran) | instancia |
| `UIKit.numero(n)` | 1500 → «1.5K» | string |
| `UIKit.rarezas` | colores Comun…Secreto | tabla |

## Ejemplo mínimo (LocalScript en StarterPlayerScripts)
```lua
local RS = game:GetService("ReplicatedStorage")
local UIKit = require(RS:WaitForChild("UIKit"))
local lienzo = UIKit.pantalla("Juego")
local monedas = UIKit.contador({ Parent = lienzo, icono = "💰", Position = UDim2.fromOffset(16, 12) })
local tienda = UIKit.ventana({ Parent = lienzo, titulo = "🛒 Tienda" })
UIKit.boton({ Parent = lienzo, texto = "Tienda", icono = "🛒", color = UIKit.tema.aviso,
	Position = UDim2.new(0, 120, 0.5, 0), alPulsar = function() tienda:abrir() end })
-- El servidor manda el dinero: Remote.OnClientEvent:Connect(function(d) monedas:poner(d.dinero) end)
```

## Reglas
- Coloca con **Scale + AnchorPoint** para lo que se pega a bordes/centro (`UDim2.new(1, -16, 0, 12)` + AnchorPoint (1,0) = arriba a la derecha) y con offsets del lienzo para tamaños: el UIScale del lienzo los adapta.
- El cliente solo MUESTRA y PIDE. Precios, compras y premios los decide el servidor (RemoteFunction con validación).
- Botones de acción: mínimo 56 de alto en diseño (≈ 37 px reales en móvil). Texto mínimo 18.
- No metas un segundo UIScale en objetos de UIKit (ya llevan uno la ventana y el lienzo). Para animar tamaño usa roblox-ui-animaciones (crea «AnimEscala» aparte) sobre un Frame contenedor.
- Para ver cómo queda sin Studio: skill **roblox-ui-pantallas** (`probar_pantallas.luau` + `ver_interfaz.py`).
- Verificado: compila y pasa `luau-lsp` sin avisos con tipos de Roblox; probado en Lune (instancias reales) a 1280×720 y 844×390. No probado en Studio de verdad: dilo si el usuario pregunta.
