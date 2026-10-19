---
name: "roblox-studio-plugins"
description: "Escribir, ampliar o depurar plugins de Roblox Studio (toolbars, DockWidgets, Selection, deshacer con ChangeHistoryService, temas). Úsala cuando Jorge quiera crear o modificar un plugin de Studio, incluidos los JRT."
---

# Plugins de Roblox Studio

Jorge usa una colección propia llamada **JRT (Jorge Roblox Tools)**: 7 plugins de un solo archivo `.lua` (Alinear, Dispersar, Clonador, Plantillas, Auditor, UI Kit, VFX). Cada archivo empieza con una mini-librería compartida (`makeWidget`, `bindToolbarButton`, `newPanel`, `record`, `selectedOf`, `isMovable`, `bounds`). Si pide ampliar uno, reutiliza esa librería y su estilo en vez de inventar otro.

## Estructura mínima
1. `plugin:CreateToolbar(nombre)` → `toolbar:CreateButton(id, tooltip, icono, texto)`; `ClickableWhenViewportHidden = true`.
2. Ventana: `DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, w, h, minW, minH)` y `plugin:CreateDockWidgetPluginGui(idÚnico, info)`. El id debe ser único y estable (Studio recuerda posición por id).
3. Sincroniza el botón con `widget:GetPropertyChangedSignal("Enabled")` → `button:SetActive(widget.Enabled)`.

## Reglas que no se negocian
- **Todo cambio al juego dentro de una grabación deshacible**: `local id = ChangeHistoryService:TryBeginRecording(nombre)`, `pcall` del trabajo, `FinishRecording(id, Commit o Cancel)`. Nunca dejes una grabación abierta si hay error.
- Para borrar de forma deshacible usa `inst.Parent = nil`, no `Destroy()`.
- Colores con `settings().Studio.Theme:GetColor(Enum.StudioStyleGuideColor.X)` y re-pinta en `settings().Studio.ThemeChanged` (tema claro y oscuro).
- Mover Parts y Models igual: `GetPivot()` / `PivotTo()`. Caja de un Model: `GetBoundingBox()`. Excluye siempre `Terrain` al filtrar `BasePart`.
- Trabajo largo (recorrer miles de instancias): `task.wait()` cada pocas miles para no congelar Studio, y lánzalo con `task.spawn` desde el botón.
- Escribir `Script.Source` solo funciona desde plugins; tras crear un script, `plugin:OpenScript(s)` y `Selection:Set({s})`.
- Guarda preferencias con `plugin:SetSetting/GetSetting` (valores simples, no Instances).

## Instalación
Archivo `.lua` en la carpeta de plugins (Studio → pestaña Plugins → «Plugins Folder») y reiniciar Studio. Alternativa: Script en ServerStorage → clic derecho → «Save as Local Plugin».

## Antes de entregar
- Compila con `luau-compile --null archivo.lua` si está disponible (descarga de GitHub luau-lang/luau releases).
- Revisa: ¿todo se deshace con Ctrl+Z?, ¿funciona sin selección (mensaje claro, sin error)?, ¿funciona con Models y con Parts?, ¿se ve en tema claro y oscuro?
- Indica a Jorge tu nivel de confianza (%) y qué no has podido probar dentro de Studio.