# CLAUDE.md — Bot de trading de criptomonedas (SOLO SIMULACIÓN)

Léelo entero antes de tocar `bot-trading/`. Rama de trabajo: `claude/bot-trading`.
Las normas sobre el usuario de la raíz (`../CLAUDE.md` §2) también valen aquí: español, sin jerga, pasos de
clic en clic, **da siempre tu % de confianza y lo que falta por saber**, no quiere tocar código, usa Windows.

## 1. Qué es y en qué estado está

- Bot en **Python 3.11+ solo con la biblioteca estándar** (nada de `pip install`: el usuario no programa).
- **Solo simulación**: backtest con el pasado y *paper trading* en tiempo real con precios públicos de Binance.
  **No hay código para operar con dinero real** y no hay claves de exchange. Es una decisión explícita del
  usuario (eligió «solo simulado»). No lo añadas sin que lo pida y sin hablar antes de riesgos.
- 15 plugins (4 estrategias, 3 filtros, 5 de riesgo, 3 de información). El usuario pidió «15 plugins».
- Se usa con `INICIAR.bat` (menú) en Windows. Probado en Linux; **nunca probado en un Windows real**.

## 2. Estructura

```
bot.py                 CLI: backtest | simular | informe | plugins | telegram | reiniciar | autotest
INICIAR.bat            Menú Windows. ASCII puro + CRLF (.gitattributes: -text). Lo comprueba una prueba.
ajustes.toml           Todos los ajustes comentados. Una prueba exige que documente TODOS los parámetros
                       de cada plugin con sus valores por defecto reales → si cambias un P(...), cámbialo aquí.
nucleo/config.py       Esquemas (P), validación con errores en español, sugerencias de claves mal escritas.
nucleo/datos.py        FuenteBinance (data-api.binance.vision → api.binance.com), reintentos, caché CSV en datos/.
nucleo/indicadores.py  Velas + indicadores INCREMENTALES (EMA, SMA, RSI/ATR de Wilder, Bollinger, MACD).
nucleo/cartera.py      Cartera spot simulada: comisión + deslizamiento, sin apalancamiento ni cortos.
nucleo/motor.py        Lógica común backtest/vivo: señales con memoria por TIEMPO, filtros, stop, tamaño, órdenes.
nucleo/backtest.py     Recorre el histórico; ejecuta en la apertura siguiente; stop antes que objetivo.
nucleo/vivo.py         Paper trading: consulta cada N s, decide al cerrar vela, guarda estado en estado/.
nucleo/estado.py       JSON atómico + .bak; si todo está roto NO arranca (no machaca).
nucleo/metricas.py     Métricas y resumen (siempre contra «comprar y mantener»).
plugins/*.py           Un plugin por archivo; `orden` 1-15 fija la numeración.
pruebas/               unittest, sin Internet. `python3 bot.py autotest` (87 pruebas, ~6 s).
```

## 3. Reglas de diseño (no las rompas)

- **Sin mirar el futuro**: las velas se añaden de una en una también en el backtest; las órdenes se ejecutan
  en la apertura de la vela siguiente (backtest) o al precio actual (vivo). Prueba: `test_no_mira_el_futuro`.
- **Backtest y vivo deciden igual**: `test_decide_igual_que_la_prueba_con_el_pasado` exige operaciones idénticas.
- La memoria de señales va por **tiempo de vela**, no por índice (en vivo la serie se reconstruye al reiniciar).
- Tras abrir o cerrar una posición se borra la memoria de señales de esa moneda (evita reentrar con señales viejas).
- Un plugin que falla: en backtest para (estricto); en vivo avisa y **bloquea la compra** (a prueba de fallos).
- Telegram nunca envía en backtest. Un fallo de Telegram/CSV nunca para el bot.
- Comisión 0,1 % y deslizamiento 0,05 % por lado por defecto; si una vela toca stop y objetivo, cuenta el stop.

## 4. Verificación (obligatoria antes de cada commit)

```bash
cd bot-trading && python3 bot.py autotest          # debe acabar en "TODO OK"
python3 bot.py backtest --sin-abrir                # prueba real con Binance (necesita red)
```
Para ver el informe: Chromium en `/opt/pw-browsers/chromium-*/chrome-linux/chrome --headless=new --screenshot=...`.
`api.binance.com` da 451 desde la nube; `data-api.binance.vision` funciona (el bot prueba los dos).
No pases `timeout -s INT ... | grep` (corta la cadena de comandos); redirige a un archivo.

## 5. Resultado de referencia (no es una promesa)

Backtest 19/10/2025 → 19/10/2026, BTC+ETH, 4h, ajustes por defecto: **+2,78 %** vs comprar y mantener
**−30,39 %**; caída máx. 13,9 % (vs 56 %); 44 operaciones, 25 % ganadoras, factor 1,09. La ventaja viene de
estar fuera del mercado en la caída (filtro de tendencia), no de acertar. Díselo así al usuario.

## 6. Pendiente / ideas

- [ ] Probar en el Windows del usuario (INICIAR.bat, Python de python.org, Ctrl+C, apertura del informe).
- [ ] Validación «fuera de muestra» / walk-forward para no sobreajustar si se añaden optimizaciones.
- [ ] Ejecutar 24/7 en un VPS (guía) si el usuario lo quiere.
- [ ] Dinero real: solo si el usuario lo pide explícitamente tras semanas de paper trading; claves por variable
      de entorno con permiso de solo operar (nunca retirar) y nunca en el chat.
