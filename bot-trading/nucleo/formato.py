"""Números y fechas al estilo español (1.234,56 · 19/10/2026 14:00)."""
from __future__ import annotations

import datetime as _dt


def num(x: float | None, dec: int = 2) -> str:
	if x is None:
		return "—"
	if x != x:  # NaN
		return "—"
	if x in (float("inf"), float("-inf")):
		return "∞" if x > 0 else "-∞"
	s = f"{x:,.{dec}f}"
	return s.replace(",", "\x00").replace(".", ",").replace("\x00", ".")


def precio(x: float | None) -> str:
	"""Decimales según el tamaño del precio (BTC 82.731 · SHIB 0,00001234)."""
	if x is None:
		return "—"
	a = abs(x)
	dec = 2 if a >= 100 else 3 if a >= 10 else 4 if a >= 1 else 6 if a >= 0.01 else 8
	return num(x, dec)


def pct(x: float | None, dec: int = 2, signo: bool = True) -> str:
	if x is None:
		return "—"
	s = num(x, dec)
	return (f"+{s}" if signo and x > 0 else s) + " %"


def fecha(ms: int | None, hora: bool = True) -> str:
	"""Fecha en la hora local del PC."""
	if ms is None:
		return "—"
	d = _dt.datetime.fromtimestamp(ms / 1000)
	return d.strftime("%d/%m/%Y %H:%M" if hora else "%d/%m/%Y")


def duracion(ms: float) -> str:
	minutos = int(ms // 60_000)
	if minutos < 60:
		return f"{minutos} min"
	horas = minutos // 60
	if horas < 48:
		return f"{horas} h"
	return f"{horas // 24} días"
