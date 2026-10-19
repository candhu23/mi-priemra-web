#!/usr/bin/env python3
"""Roblox Open Cloud para los juegos de este repo (solo librería estándar).

Uso:  python3 .claude/skills/roblox-nube/roblox_cloud.py <orden> <juego> [opciones]
Juegos: los de juegos.json ("imperio", "aerocarga", "biblioteca").

Órdenes que solo LEEN (seguras):
  estado    <juego>                 Clave presente, IDs y qué permisos funcionan
  pases     <juego>                 Pases en Roblox vs. IDs del código
  productos <juego>                 Developer Products en Roblox vs. IDs del código

Órdenes que NO tocan el juego en vivo:
  guardar   <juego>                 Sube el .rbxl como versión GUARDADA (no la ven los jugadores)
  probar    <juego> [--version N]   Ejecuta prueba_real.luau en un servidor real de Roblox
                                    (sin --version: primero guarda una versión nueva)

Órdenes que CAMBIAN cosas en Roblox (exigen --confirmo, y antes el «sí» del usuario):
  publicar  <juego> --confirmo [--reiniciar] [--minutos N]
  reiniciar <juego> --confirmo [--minutos N] [--todas]
  crear-producto <juego> --clave K --nombre N --precio P [--descripcion D] [--imagen F] --confirmo
  crear-pase     <juego> --clave K --nombre N --precio P [--descripcion D] [--imagen F] --confirmo
  precio <juego> pase|producto <id> <robux> --confirmo
  imagen <juego> pase|producto <id> <archivo.png> --confirmo   (icono hecho con arte-roblox)

La clave se lee de la variable de entorno ROBLOX_API_KEY. Nunca se imprime.
"""

import argparse
import json
import os
import re
import ssl
import sys
import time
import urllib.error
import urllib.request
import uuid

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.abspath(os.path.join(AQUI, "..", "..", ".."))
API = "https://apis.roblox.com"

# Permiso que pide cada familia de llamadas (para explicar los 401/403)
PERMISOS = {
    "publicar": "universe-places → Write",
    "reiniciar": "universe → Write",
    "luau": "universe.place.luau-execution-session → Read y Write",
    "pase-leer": "game-pass → Read",
    "pase-escribir": "game-pass → Write",
    "producto-leer": "developer-product → Read",
    "producto-escribir": "developer-product → Write",
}


class ErrorApi(Exception):
    def __init__(self, codigo, cuerpo, permiso=None):
        self.codigo = codigo
        self.cuerpo = cuerpo
        self.permiso = permiso
        super().__init__(f"HTTP {codigo}")

    def explicar(self):
        texto = f"Roblox respondió HTTP {self.codigo}."
        if self.codigo in (401, 403):
            texto += " La clave no es válida, caducó, su lista de IPs no incluye 0.0.0.0/0"
            if self.permiso:
                texto += f", o le falta el permiso «{self.permiso}» para esta experiencia"
            texto += "."
        elif self.codigo == 429:
            texto += " Demasiadas peticiones seguidas: espera un minuto."
        elif self.codigo == 409:
            texto += " Conflicto (¿ya existe algo con ese nombre?)."
        detalle = self.cuerpo[:600].strip()
        if detalle:
            texto += f"\nDetalle: {detalle}"
        return texto


# ---------------------------------------------------------------- utilidades

def contexto_ssl():
    for var in ("SSL_CERT_FILE", "REQUESTS_CA_BUNDLE"):
        ruta = os.environ.get(var)
        if ruta and os.path.isfile(ruta):
            return ssl.create_default_context(cafile=ruta)
    return ssl.create_default_context()


SSL = contexto_ssl()


def clave():
    k = os.environ.get("ROBLOX_API_KEY", "").strip()
    if not k:
        sys.exit(
            "Falta ROBLOX_API_KEY. El usuario debe crearla en el Creator Hub (Open Cloud → API Keys)\n"
            "y guardarla en los ajustes del entorno de Claude Code (no en el chat). Ver SKILL.md."
        )
    return k


def peticion(metodo, ruta, cuerpo=None, tipo=None, permiso=None, intentos=3):
    url = ruta if ruta.startswith("http") else API + ruta
    cabeceras = {"x-api-key": clave(), "Accept": "application/json"}
    if tipo:
        cabeceras["Content-Type"] = tipo
    for i in range(intentos):
        req = urllib.request.Request(url, data=cuerpo, headers=cabeceras, method=metodo)
        try:
            with urllib.request.urlopen(req, context=SSL, timeout=120) as r:
                datos = r.read().decode("utf-8", "replace")
                return json.loads(datos) if datos.strip() else {}
        except urllib.error.HTTPError as e:
            texto = e.read().decode("utf-8", "replace")
            # Reintentar solo errores temporales del servidor
            if e.code >= 500 and i < intentos - 1:
                time.sleep(2 * (i + 1))
                continue
            raise ErrorApi(e.code, texto, permiso) from None
        except urllib.error.URLError as e:
            if i < intentos - 1:
                time.sleep(2 * (i + 1))
                continue
            sys.exit(f"No hay conexión con {url}: {e.reason}. ¿La red del entorno permite apis.roblox.com?")
    return {}


def multipart(campos, archivo=None):
    limite = "----roblox" + uuid.uuid4().hex
    partes = []
    for nombre, valor in campos.items():
        if valor is None:
            continue
        if isinstance(valor, bool):
            valor = "true" if valor else "false"
        partes.append(
            f'--{limite}\r\nContent-Disposition: form-data; name="{nombre}"\r\n\r\n{valor}\r\n'.encode()
        )
    if archivo:
        with open(archivo, "rb") as f:
            datos = f.read()
        ext = os.path.splitext(archivo)[1].lower()
        mime = {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg"}.get(ext, "application/octet-stream")
        cab = (
            f'--{limite}\r\nContent-Disposition: form-data; name="imageFile"; '
            f'filename="{os.path.basename(archivo)}"\r\nContent-Type: {mime}\r\n\r\n'
        )
        partes.append(cab.encode() + datos + b"\r\n")
    partes.append(f"--{limite}--\r\n".encode())
    return b"".join(partes), f"multipart/form-data; boundary={limite}"


def juegos():
    with open(os.path.join(AQUI, "juegos.json"), encoding="utf-8") as f:
        return json.load(f)


def juego(nombre, necesita_ids=True):
    todos = juegos()
    if nombre not in todos:
        sys.exit(f"Juego desconocido «{nombre}». Opciones: {', '.join(todos)}")
    j = dict(todos[nombre])
    j["clave_juego"] = nombre
    j["ruta"] = os.path.join(RAIZ, j["carpeta"])
    if necesita_ids and not (j.get("universeId") and j.get("placeId")):
        sys.exit(
            f"«{j['nombre']}» aún no tiene universeId/placeId en juegos.json.\n"
            "La PRIMERA publicación de un juego nuevo se hace desde Studio (Publish to Roblox As… → nueva experiencia).\n"
            "Después, copia los IDs del Creator Hub a juegos.json."
        )
    return j


def ruta_config(j):
    ruta = os.path.join(j["ruta"], j["config"])
    if not os.path.isfile(ruta):
        sys.exit(f"No encuentro {ruta}. ¿Estás en la rama del juego ({j['rama']})?")
    return ruta


PATRON_ITEM = re.compile(r'\{\s*key\s*=\s*"(\w+)"\s*,\s*id\s*=\s*(\d+)')


def ids_en_codigo(j):
    """Devuelve {'GamePasses': {clave: id}, 'Products': {clave: id}} leyendo el archivo de config."""
    texto = open(ruta_config(j), encoding="utf-8").read()
    res = {}
    for seccion in ("GamePasses", "Products"):
        m = re.search(seccion + r"\s*=\s*\{", texto)
        if not m:
            res[seccion] = {}
            continue
        # Hasta el cierre de la tabla (contando llaves)
        nivel, i = 0, m.end() - 1
        while i < len(texto):
            if texto[i] == "{":
                nivel += 1
            elif texto[i] == "}":
                nivel -= 1
                if nivel == 0:
                    break
            i += 1
        res[seccion] = {k: int(v) for k, v in PATRON_ITEM.findall(texto[m.end() - 1 : i + 1])}
    return res


def escribir_id(j, clave_item, nuevo_id):
    ruta = ruta_config(j)
    texto = open(ruta, encoding="utf-8").read()
    patron = re.compile(r'(\{\s*key\s*=\s*"' + re.escape(clave_item) + r'"\s*,\s*id\s*=\s*)0\b')
    nuevo, n = patron.subn(lambda m: m.group(1) + str(nuevo_id), texto, count=1)
    if n != 1:
        print(f"⚠️  No he podido escribir el ID en {ruta} (¿la clave «{clave_item}» no existe o ya tenía ID?).")
        return False
    with open(ruta, "w", encoding="utf-8") as f:
        f.write(nuevo)
    print(f"✏️  ID {nuevo_id} escrito en {os.path.relpath(ruta, RAIZ)} (clave «{clave_item}»).")
    return True


def exigir_confirmacion(args, que):
    if not getattr(args, "confirmo", False):
        sys.exit(
            f"Esta orden {que}. Pide confirmación explícita al usuario y repite con --confirmo."
        )


def precio_de(info):
    p = info.get("priceInformation") or {}
    if isinstance(p, dict):
        return p.get("defaultPriceInRobux", p.get("price"))
    return p


# ---------------------------------------------------------------- órdenes

def subir(j, tipo_version):
    rbxl = os.path.join(j["ruta"], j["rbxl"])
    if not os.path.isfile(rbxl):
        sys.exit(f"No existe {rbxl}. Ejecuta antes tools/check.sh del juego.")
    with open(rbxl, "rb") as f:
        datos = f.read()
    tipo = "application/xml" if rbxl.endswith(".rbxlx") else "application/octet-stream"
    r = peticion(
        "POST",
        f"/universes/v1/{j['universeId']}/places/{j['placeId']}/versions?versionType={tipo_version}",
        datos,
        tipo,
        PERMISOS["publicar"],
    )
    version = r.get("versionNumber")
    if not version:
        sys.exit(f"Respuesta inesperada al subir: {r}")
    return version


def orden_estado(args):
    j = juego(args.juego, necesita_ids=False)
    print(f"Juego: {j['nombre']}  (carpeta {j['carpeta']}, rama {j['rama']})")
    print(f"universeId={j.get('universeId')}  placeId={j.get('placeId')}")
    print("ROBLOX_API_KEY:", "presente ✅" if os.environ.get("ROBLOX_API_KEY") else "NO configurada ❌")
    if not os.environ.get("ROBLOX_API_KEY") or not j.get("universeId"):
        return
    for nombre, ruta, permiso in (
        ("Leer pases", f"/game-passes/v1/universes/{j['universeId']}/game-passes/creator?pageSize=1", "pase-leer"),
        ("Leer productos", f"/developer-products/v2/universes/{j['universeId']}/developer-products/creator?pageSize=1", "producto-leer"),
    ):
        try:
            peticion("GET", ruta, permiso=PERMISOS[permiso])
            print(f"  {nombre}: OK")
        except ErrorApi as e:
            print(f"  {nombre}: falla (HTTP {e.codigo}) → permiso «{PERMISOS[permiso]}»")
    print("  (Publicar, reiniciar y probar no se pueden comprobar sin hacerlos: se ven al usarlos.)")


def listar(j, tipo):
    if tipo == "pase":
        ruta = f"/game-passes/v1/universes/{j['universeId']}/game-passes/creator"
        lista, ident, permiso = "gamePasses", "gamePassId", PERMISOS["pase-leer"]
    else:
        ruta = f"/developer-products/v2/universes/{j['universeId']}/developer-products/creator"
        lista, ident, permiso = "developerProducts", "productId", PERMISOS["producto-leer"]
    res, token = [], None
    while True:
        r = peticion("GET", ruta + "?pageSize=50" + (f"&pageToken={token}" if token else ""), permiso=permiso)
        res += r.get(lista) or []
        token = r.get("nextPageToken")
        if not token:
            break
    return [(int(x[ident]), x) for x in res]


def orden_listar(args, tipo):
    j = juego(args.juego)
    seccion = "GamePasses" if tipo == "pase" else "Products"
    en_codigo = ids_en_codigo(j)[seccion]
    try:
        remotos = listar(j, tipo)
    except ErrorApi as e:
        sys.exit(e.explicar())
    por_id = {i: x for i, x in remotos}
    print(f"{'Pases' if tipo == 'pase' else 'Developer Products'} de {j['nombre']}:")
    for clave_item, ident in en_codigo.items():
        if ident == 0:
            print(f"  ⚪ {clave_item}: sin crear (id = 0 en el código; no sale en el juego publicado)")
        elif ident in por_id:
            x = por_id[ident]
            venta = "a la venta" if x.get("isForSale") else "NO a la venta ⚠️"
            print(f"  ✅ {clave_item}: {ident} «{x.get('name')}» {precio_de(x)} R$ ({venta})")
        else:
            print(f"  ❌ {clave_item}: el código usa {ident}, pero no existe en esta experiencia")
    usados = set(en_codigo.values())
    for ident, x in remotos:
        if ident not in usados:
            print(f"  ❔ En Roblox pero no en el código: {ident} «{x.get('name')}» {precio_de(x)} R$")


def orden_guardar(args):
    j = juego(args.juego)
    try:
        v = subir(j, "Saved")
    except ErrorApi as e:
        sys.exit(e.explicar())
    print(f"Versión {v} GUARDADA (no publicada: los jugadores siguen en la versión anterior).")
    return v


def ejecutar_luau(j, version, script):
    base = f"/cloud/v2/universes/{j['universeId']}/places/{j['placeId']}/versions/{version}/luau-execution-session-tasks"
    tarea = peticion("POST", base, json.dumps({"script": script}).encode(), "application/json", PERMISOS["luau"])
    ruta = tarea.get("path")
    if not ruta:
        sys.exit(f"Respuesta inesperada al crear la tarea: {tarea}")
    print("Ejecutando en un servidor de Roblox", end="", flush=True)
    limite = time.time() + 6 * 60
    while tarea.get("state") not in ("COMPLETE", "FAILED", "CANCELLED"):
        if time.time() > limite:
            print()
            sys.exit("La tarea no terminó en 6 minutos.")
        time.sleep(3)
        print(".", end="", flush=True)
        tarea = peticion("GET", f"/cloud/v2/{ruta}", permiso=PERMISOS["luau"])
    print()
    registros = []
    try:
        r = peticion("GET", f"/cloud/v2/{ruta}/logs", permiso=PERMISOS["luau"])
        for trozo in r.get("luauExecutionSessionTaskLogs") or []:
            registros += trozo.get("messages") or []
    except ErrorApi:
        pass
    return tarea, registros


def orden_probar(args):
    j = juego(args.juego)
    try:
        version = args.version or subir(j, "Saved")
        if not args.version:
            print(f"Versión {version} guardada (no publicada) para la prueba.")
        script = open(os.path.join(AQUI, "prueba_real.luau"), encoding="utf-8").read()
        tarea, registros = ejecutar_luau(j, version, script)
    except ErrorApi as e:
        sys.exit(e.explicar())
    if registros:
        print("---- Salida del servidor ----")
        print("\n".join(registros))
        print("-----------------------------")
    if tarea.get("state") != "COMPLETE":
        print(f"❌ La tarea acabó en estado {tarea.get('state')}: {json.dumps(tarea.get('error'), ensure_ascii=False)}")
        sys.exit(1)
    resultados = (tarea.get("output") or {}).get("results") or []
    informe = resultados[0] if resultados and isinstance(resultados[0], dict) else {}
    if informe.get("ok"):
        print(f"PRUEBA REAL OK ✅ (versión {version})")
    else:
        print(f"PRUEBA REAL CON FALLOS ❌ (versión {version}): {json.dumps(informe.get('fallos'), ensure_ascii=False)}")
        sys.exit(1)


def reiniciar(j, minutos, todas):
    cuerpo = {"placeIds": [j["placeId"]], "closeAllVersions": bool(todas)}
    if minutos:
        cuerpo.update({"bleedOffServers": True, "bleedOffDurationMinutes": max(1, min(60, int(minutos)))})
    peticion(
        "POST",
        f"/cloud/v2/universes/{j['universeId']}:restartServers",
        json.dumps(cuerpo).encode(),
        "application/json",
        PERMISOS["reiniciar"],
    )
    if minutos:
        print(f"Servidores antiguos: dejan de recibir jugadores y se cierran en {cuerpo['bleedOffDurationMinutes']} min.")
    else:
        print("Servidores antiguos reiniciándose ya (los jugadores vuelven a entrar en la versión nueva).")


def orden_publicar(args):
    j = juego(args.juego)
    exigir_confirmacion(args, "publica una versión nueva que verán TODOS los jugadores")
    try:
        v = subir(j, "Published")
        print(f"🚀 Versión {v} PUBLICADA en «{j['nombre']}».")
        if args.reiniciar:
            reiniciar(j, args.minutos, False)
    except ErrorApi as e:
        sys.exit(e.explicar())


def orden_reiniciar(args):
    j = juego(args.juego)
    exigir_confirmacion(args, "reinicia servidores con jugadores dentro")
    try:
        reiniciar(j, args.minutos, args.todas)
    except ErrorApi as e:
        sys.exit(e.explicar())


def orden_crear(args, tipo):
    j = juego(args.juego)
    seccion = "GamePasses" if tipo == "pase" else "Products"
    en_codigo = ids_en_codigo(j)[seccion]
    if args.clave not in en_codigo:
        sys.exit(f"La clave «{args.clave}» no está en {seccion} del código. Claves: {', '.join(en_codigo)}")
    if en_codigo[args.clave] != 0:
        sys.exit(f"«{args.clave}» ya tiene ID {en_codigo[args.clave]} en el código. Usa «precio» para cambiarlo.")
    if args.imagen and not os.path.isfile(args.imagen):
        sys.exit(f"No existe la imagen {args.imagen}")
    exigir_confirmacion(args, f"crea un {'pase' if tipo == 'pase' else 'producto'} a la venta en Roblox")
    campos = {
        "name": args.nombre,
        "description": args.descripcion or "",
        "price": int(args.precio),
        "isForSale": True,
    }
    cuerpo, ctype = multipart(campos, args.imagen)
    try:
        if tipo == "pase":
            r = peticion("POST", f"/game-passes/v1/universes/{j['universeId']}/game-passes", cuerpo, ctype, PERMISOS["pase-escribir"])
            ident = r.get("gamePassId")
        else:
            r = peticion("POST", f"/developer-products/v2/universes/{j['universeId']}/developer-products", cuerpo, ctype, PERMISOS["producto-escribir"])
            ident = r.get("productId")
    except ErrorApi as e:
        sys.exit(e.explicar())
    if not ident:
        sys.exit(f"Respuesta inesperada: {r}")
    print(f"✅ Creado «{args.nombre}» → ID {ident} ({args.precio} R$).")
    escribir_id(j, args.clave, ident)


def orden_precio(args):
    j = juego(args.juego)
    exigir_confirmacion(args, "cambia un precio en la tienda en vivo")
    cuerpo, ctype = multipart({"price": int(args.robux)})
    try:
        if args.tipo == "pase":
            ruta = f"/game-passes/v1/universes/{j['universeId']}/game-passes/{args.id}"
            peticion("PATCH", ruta, cuerpo, ctype, PERMISOS["pase-escribir"])
        else:
            ruta = f"/developer-products/v2/universes/{j['universeId']}/developer-products/{args.id}"
            peticion("PATCH", ruta, cuerpo, ctype, PERMISOS["producto-escribir"])
    except ErrorApi as e:
        sys.exit(e.explicar())
    print(f"✅ Precio de {args.tipo} {args.id} cambiado a {args.robux} R$.")


def orden_imagen(args):
    j = juego(args.juego)
    if not os.path.isfile(args.archivo):
        sys.exit(f"No existe {args.archivo}")
    exigir_confirmacion(args, "cambia el icono de un artículo de la tienda en vivo")
    cuerpo, ctype = multipart({}, args.archivo)
    try:
        if args.tipo == "pase":
            peticion("PATCH", f"/game-passes/v1/universes/{j['universeId']}/game-passes/{args.id}", cuerpo, ctype, PERMISOS["pase-escribir"])
        else:
            peticion("PATCH", f"/developer-products/v2/universes/{j['universeId']}/developer-products/{args.id}", cuerpo, ctype, PERMISOS["producto-escribir"])
    except ErrorApi as e:
        sys.exit(e.explicar())
    print(f"✅ Icono de {args.tipo} {args.id} subido (Roblox lo revisa antes de mostrarlo; puede tardar).")


def main():
    p = argparse.ArgumentParser(description="Roblox Open Cloud para los juegos de este repo")
    sub = p.add_subparsers(dest="orden", required=True)

    def con_juego(nombre, ayuda):
        s = sub.add_parser(nombre, help=ayuda)
        s.add_argument("juego")
        return s

    con_juego("estado", "clave, IDs y permisos")
    con_juego("pases", "pases en Roblox vs. código")
    con_juego("productos", "productos en Roblox vs. código")
    con_juego("guardar", "subir como versión guardada (no publicada)")
    s = con_juego("probar", "prueba en un servidor real de Roblox")
    s.add_argument("--version", type=int)
    s = con_juego("publicar", "publicar para todos los jugadores")
    s.add_argument("--confirmo", action="store_true")
    s.add_argument("--reiniciar", action="store_true")
    s.add_argument("--minutos", type=int, default=0)
    s = con_juego("reiniciar", "reiniciar servidores con versión antigua")
    s.add_argument("--confirmo", action="store_true")
    s.add_argument("--minutos", type=int, default=0)
    s.add_argument("--todas", action="store_true")
    for nombre in ("crear-producto", "crear-pase"):
        s = con_juego(nombre, "crear y escribir el ID en el código")
        s.add_argument("--clave", required=True)
        s.add_argument("--nombre", required=True)
        s.add_argument("--precio", type=int, required=True)
        s.add_argument("--descripcion")
        s.add_argument("--imagen")
        s.add_argument("--confirmo", action="store_true")
    s = con_juego("precio", "cambiar el precio de un pase o producto")
    s.add_argument("tipo", choices=["pase", "producto"])
    s.add_argument("id", type=int)
    s.add_argument("robux", type=int)
    s.add_argument("--confirmo", action="store_true")

    s = con_juego("imagen", "subir el icono de un pase o producto")
    s.add_argument("tipo", choices=["pase", "producto"])
    s.add_argument("id", type=int)
    s.add_argument("archivo")
    s.add_argument("--confirmo", action="store_true")

    args = p.parse_args()
    {
        "estado": orden_estado,
        "pases": lambda a: orden_listar(a, "pase"),
        "productos": lambda a: orden_listar(a, "producto"),
        "guardar": orden_guardar,
        "probar": orden_probar,
        "publicar": orden_publicar,
        "reiniciar": orden_reiniciar,
        "crear-producto": lambda a: orden_crear(a, "producto"),
        "crear-pase": lambda a: orden_crear(a, "pase"),
        "precio": orden_precio,
        "imagen": orden_imagen,
    }[args.orden](args)


if __name__ == "__main__":
    main()
