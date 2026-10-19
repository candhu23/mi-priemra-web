@echo off
setlocal
title Bot de trading (SOLO SIMULACION)
cd /d "%~dp0"
chcp 65001 >nul

rem --- Buscar Python 3.11 o mas nuevo ---
set "PY=py -3"
%PY% -c "import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)" >nul 2>nul
if not errorlevel 1 goto menu
set "PY=python"
%PY% -c "import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)" >nul 2>nul
if not errorlevel 1 goto menu
goto sinpython

:menu
cls
echo ================================================================
echo   BOT DE TRADING DE CRIPTOMONEDAS  -  SOLO SIMULACION
echo   No usa dinero real ni necesita cuenta en ningun exchange.
echo ================================================================
echo.
echo   1. Probar con el pasado (los ultimos 365 dias)
echo   2. Simulacion en tiempo real (dinero de mentira)
echo   3. Ver el ultimo informe
echo   4. Ver los 15 plugins
echo   5. Cambiar los ajustes (se abre el Bloc de notas)
echo   6. Configurar los avisos por Telegram (opcional)
echo   7. Reiniciar la simulacion en tiempo real (empezar de cero)
echo   8. Comprobar que todo funciona
echo   9. Salir
echo.
set "op="
set /p "op=Escribe un numero y pulsa Enter: "
if "%op%"=="1" goto backtest
if "%op%"=="2" goto simular
if "%op%"=="3" goto informe
if "%op%"=="4" goto plugins
if "%op%"=="5" goto ajustes
if "%op%"=="6" goto telegram
if "%op%"=="7" goto reiniciar
if "%op%"=="8" goto autotest
if "%op%"=="9" goto fin
goto menu

:backtest
%PY% bot.py backtest
echo.
pause
goto menu

:simular
echo.
echo Para PARAR el bot pulsa Ctrl+C (todo queda guardado).
echo Si despues pregunta "Terminar el trabajo por lotes (S/N)?", pulsa N y Enter para volver al menu.
echo.
%PY% bot.py simular
echo.
pause
goto menu

:informe
%PY% bot.py informe
echo.
pause
goto menu

:plugins
%PY% bot.py plugins
echo.
pause
goto menu

:ajustes
start "" notepad "%~dp0ajustes.toml"
goto menu

:telegram
%PY% bot.py telegram
echo.
pause
goto menu

:reiniciar
%PY% bot.py reiniciar
echo.
pause
goto menu

:autotest
%PY% bot.py autotest
echo.
pause
goto menu

:sinpython
echo.
echo No encuentro Python 3.11 o mas nuevo en este ordenador (es gratis).
echo.
echo   1. Ahora se abrira la pagina de descarga de Python.
echo   2. Pulsa el boton amarillo "Download Python" e instalalo.
echo   3. MUY IMPORTANTE: en la primera pantalla del instalador marca
echo      la casilla "Add python.exe to PATH".
echo   4. Cuando termine, vuelve a hacer doble clic en INICIAR.bat
echo.
pause
start "" "https://www.python.org/downloads/"
exit /b 1

:fin
endlocal
exit /b 0
