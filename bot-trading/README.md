# Bot de trading de criptomonedas (solo simulación)

Un bot que mira los precios de **Binance** y decide cuándo comprar y vender **con dinero de mentira**.
Sirve para probar estrategias **sin arriesgar nada**:

- **Probar con el pasado** (*backtest*): ¿qué habría pasado si el bot hubiera funcionado el último año?
- **Simulación en tiempo real** (*paper trading*): el bot funciona con precios reales y apunta
  compras y ventas ficticias. Así ves cómo se comporta día a día.

> **Importante**
> - No usa dinero real, no necesita cuenta en Binance y no tiene ninguna clave tuya.
> - **Ningún bot puede prometer ganancias.** Que una estrategia funcionara en el pasado no
>   garantiza que funcione en el futuro. Por eso el bot siempre se compara con
>   «comprar y mantener» (comprar al principio y no tocar nada).

---

## 1. Instalarlo en Windows (una sola vez)

1. **Instala Python** (gratis):
   - Entra en <https://www.python.org/downloads/> y pulsa el botón amarillo **Download Python**.
   - Abre el instalador y, **en la primera pantalla, marca la casilla «Add python.exe to PATH»**.
   - Pulsa **Install Now** y espera a que termine.
2. **Descarga el bot** (el archivo `bot-trading.zip` que te ha pasado Claude) y haz clic derecho →
   **Extraer todo…** → **Extraer**.
3. Entra en la carpeta `bot-trading` y haz **doble clic en `INICIAR.bat`**.
   - Si Windows dice «Windows protegió su PC», pulsa **Más información → Ejecutar de todas formas**
     (pasa con cualquier archivo descargado de Internet que no esté firmado).
4. Te sale un menú. **La primera vez elige la opción 8** («Comprobar que todo funciona»). Debe acabar en
   `TODO OK`.

## 2. El menú

| Opción | Qué hace |
|---|---|
| **1. Probar con el pasado** | Descarga los precios del último año (la 1.ª vez tarda unos segundos) y simula el bot. Al terminar abre el informe en el navegador. |
| **2. Simulación en tiempo real** | El bot funciona con los precios de ahora y dinero de mentira. Déjalo abierto. **Para pararlo pulsa Ctrl+C** (todo queda guardado; la próxima vez continúa). Si luego pregunta «¿Terminar el trabajo por lotes (S/N)?», pulsa **N** y Enter para volver al menú. |
| **3. Ver el último informe** | Abre en el navegador el informe más reciente. |
| **4. Ver los 15 plugins** | Lista los plugins, para qué sirve cada uno y si está encendido. |
| **5. Cambiar los ajustes** | Abre `ajustes.toml` en el Bloc de notas (ver el punto 5). |
| **6. Configurar Telegram** | Para recibir avisos en el móvil (opcional, ver el punto 6). |
| **7. Reiniciar la simulación** | Borra la simulación en tiempo real para empezar de cero. |
| **8. Comprobar que todo funciona** | Ejecuta 87 pruebas automáticas (sin Internet). |

Con las velas de 4 horas (lo que viene configurado), **el bot solo decide cada 4 horas**, cuando se cierra
una vela. Es normal que pase horas sin hacer nada.

## 3. Cómo leer el informe

| Dato | Qué significa |
|---|---|
| **Resultado del bot** | Cuánto ha ganado o perdido, ya descontadas comisiones. |
| **Comprar y mantener** | Lo que habrías ganado comprando al principio y sin hacer nada. **Si el bot no lo supera, no está aportando nada.** |
| **Caída máxima** | La peor bajada desde un máximo. Mide el «susto»: cuanto menor, mejor. |
| **Operaciones / % ganadoras** | Cuántas compras-ventas ha hecho y cuántas salieron bien. Con menos de 30, el resultado puede ser suerte. |
| **Factor de beneficio** | Lo ganado entre lo perdido. Más de 1 = gana más de lo que pierde. |
| **Por qué no compró** | Veces que hubo señal de compra pero un filtro o freno la paró. |

También se crea un **CSV para Excel** con todas las operaciones en la carpeta `resultados`.

## 4. Los 15 plugins

Cada plugin es una pieza que se enciende o apaga en `ajustes.toml` (`activo = true` / `false`).

| # | Plugin | Tipo | Encendido | Qué hace |
|---|---|---|---|---|
| 1 | Cruce de medias | Estrategia | Sí | Compra cuando la media rápida cruza hacia arriba la lenta (empieza una subida); vende al revés. |
| 2 | RSI | Estrategia | No | Compra tras una caída fuerte cuando empieza a rebotar; vende cuando está «caro». |
| 3 | Bandas de Bollinger | Estrategia | No | Compra al rebotar en la banda inferior; vende en la superior. |
| 4 | MACD | Estrategia | No | Compra cuando el impulso gira al alza; vende cuando gira a la baja. |
| 5 | Filtro de tendencia | Filtro | Sí | Solo compra si la tendencia de fondo (media de 200 velas) es alcista. |
| 6 | Filtro de volatilidad | Filtro | Sí | No compra si el precio se mueve demasiado poco (comisiones) o demasiado (ruleta). |
| 7 | Filtro de volumen | Filtro | No | Solo compra si en la señal hubo más volumen de lo normal. |
| 8 | Tamaño de posición | Riesgo | Sí | Compra la cantidad justa para perder como mucho el 1 % del capital si sale mal. |
| 9 | Stop loss | Riesgo | Sí | Venta de emergencia si el precio cae (a 2 veces su movimiento normal). |
| 10 | Take profit | Riesgo | No | Vende al llegar a un objetivo de ganancia. |
| 11 | Trailing stop | Riesgo | Sí | El stop sube con el precio para asegurar ganancias. |
| 12 | Freno de emergencia | Riesgo | Sí | Para de comprar si se pierde mucho en un día, hay varias pérdidas seguidas o la cartera cae un 20 % (entonces vende todo y descansa 7 días). |
| 13 | Diario de operaciones | Información | Sí | CSV con cada operación para abrir con Excel. |
| 14 | Informe visual | Información | Sí | Página con gráficos y resultados. En vivo se actualiza sola. |
| 15 | Avisos por Telegram | Información | Sí* | Compras, ventas, avisos y resumen diario en el móvil. *Solo funciona después de configurarlo. |

Además, el núcleo del bot ya trae, sin plugins: comisiones y deslizamiento realistas, órdenes al precio
de la vela **siguiente** (para no hacer trampa), guardado a prueba de apagones, reintentos si se va
Internet y un límite de monedas compradas a la vez.

## 5. Cambiar los ajustes

Menú → opción **5**. Se abre `ajustes.toml`. Cambia el número o texto, **guarda (Archivo → Guardar)** y vuelve a lanzar
el bot. Si te equivocas, el bot te dice qué línea está mal y no hace nada raro. Ejemplos:

- **Añadir Solana:** `monedas = ["BTC/USDT", "ETH/USDT", "SOL/USDT"]`
- **Velas de 1 hora** (decide más a menudo, más operaciones y más comisiones): `intervalo = "1h"`
- **Encender el RSI:** en `[plugins.rsi]` cambia `activo = false` por `activo = true`
- **Probar 2 años:** en `[backtest]`, `dias = 730`

Consejo: cambia **una cosa cada vez** y compara el informe. Y desconfía si algo sale espectacular en el
pasado: suele ser casualidad («sobreajuste») y no se repite.

## 6. Avisos por Telegram (opcional)

1. En Telegram, busca **@BotFather**, escríbele `/newbot` y sigue los pasos. Te dará un **token**.
2. En el menú del bot elige la opción **6** y pega el token (clic derecho o Ctrl+V en la ventana negra).
3. Escribe cualquier mensaje a tu bot nuevo en Telegram y pulsa Enter en la ventana. Te llegará un mensaje de prueba.

El token se guarda en `secretos.toml`, en tu PC. **No lo compartas con nadie ni lo pegues en ningún chat.**

## 7. Preguntas frecuentes

**¿Puedo usarlo con dinero real?** No: esta versión solo simula, a propósito. Antes de pensar en dinero
real, lo sensato es tener semanas de simulación en tiempo real que superen a «comprar y mantener».
Operar con dinero real exigiría añadir la conexión con tu cuenta (con una clave que solo permita operar,
nunca retirar) y más protecciones. Si algún día lo quieres, pídeselo a Claude y decidid juntos.

**¿Cuánto gana?** Mira el informe de la opción 1. En la prueba del último año (19/10/2025 → 19/10/2026,
BTC y ETH, velas de 4 h) el bot terminó en **+2,8 %**, mientras que comprar y mantener perdió un **30 %**.
Pero ojo: casi toda la diferencia se debe a que el bot se quedó fuera del mercado mientras caía (filtro de
tendencia). Solo el 25 % de sus operaciones fueron ganadoras y su factor de beneficio fue 1,09 (casi
empate). En un año de subidas fuertes, lo normal es que este tipo de bot gane **menos** que comprar y
mantener. No hay garantía de nada.

**¿Por qué no compra?** Porque no hay señal o porque un filtro la para (es su trabajo). El informe lo
explica en «Por qué no compró».

**¿Tengo que dejar el PC encendido?** Para la simulación en tiempo real, sí (y sin que se suspenda).
Si lo apagas, al volver continúa donde lo dejó, pero no habrá vigilado el precio mientras tanto.

**¿Se rompe algo si cierro la ventana?** No. La simulación se guarda en cada cambio en la carpeta `estado`.

**En Mac o Linux:** abre una terminal en la carpeta y usa `python3 bot.py backtest`, `python3 bot.py simular`, etc.

## 8. Carpetas

```
bot-trading/
├── INICIAR.bat          ← doble clic aquí (Windows)
├── ajustes.toml         ← todos los ajustes, comentados
├── bot.py               ← el programa
├── nucleo/              ← el motor del bot (precios, cartera, decisiones, guardado)
├── plugins/             ← los 15 plugins (un archivo cada uno)
├── pruebas/             ← 87 pruebas automáticas
├── datos/               ← precios descargados (se crea solo)
├── resultados/          ← informes, CSV y registros (se crea solo)
└── estado/              ← la simulación en tiempo real guardada (se crea solo)
```
