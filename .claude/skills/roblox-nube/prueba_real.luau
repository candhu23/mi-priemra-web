-- Prueba en un servidor REAL de Roblox (Open Cloud · Luau Execution).
-- La lanza roblox_cloud.py «probar» contra una versión GUARDADA (no publicada).
--
-- Qué hace (sirve para los dos juegos del repo):
--   1. Cuenta Scripts/LocalScripts/ModuleScripts (el .rbxl trae el código).
--   2. Carga (require) todos los ModuleScripts de ReplicatedStorage y ServerScriptService.
--   3. Si existen PlotManager/World/Building (Imperio), construye la ciudad y un rascacielos
--      con el motor de verdad (valida propiedades que Lune solo simula).
--   4. Busca las tablas GamePasses/Products de los módulos y comprueba cada ID con
--      MarketplaceService:GetProductInfo (existe, precio, a la venta).
--
-- Reglas: aquí los Scripts del juego NO se ejecutan solos y los cambios al mundo se pierden
-- al terminar. PERO los DataStores son los de verdad: no llames a nada que guarde datos.

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local fallos: { string } = {}
local avisos: { string } = {}
local function fallo(msg: string)
	table.insert(fallos, msg)
	print("❌ " .. msg)
end
local function aviso(msg: string)
	table.insert(avisos, msg)
	print("⚠️ " .. msg)
end

-- 1. Código presente -------------------------------------------------
local cuenta = { Script = 0, LocalScript = 0, ModuleScript = 0 }
for _, servicio in { ReplicatedStorage, ServerScriptService, game:GetService("StarterPlayer"), game:GetService("StarterGui") } do
	for _, d in servicio:GetDescendants() do
		if cuenta[d.ClassName] then
			cuenta[d.ClassName] += 1
		end
	end
end
print(string.format("Código: %d Script, %d LocalScript, %d ModuleScript", cuenta.Script, cuenta.LocalScript, cuenta.ModuleScript))
if cuenta.Script == 0 then
	fallo("No hay ningún Script de servidor en el lugar")
end

-- 2. Cargar módulos (con tiempo límite: un WaitForChild de algo que crea el servidor
--    al arrancar se quedaría esperando para siempre aquí; eso es un aviso, no un fallo)
local cargados: { [string]: any } = {}
local function cargar(m: ModuleScript)
	local hecho, ok, res = false, false, nil
	task.spawn(function()
		ok, res = pcall(require, m)
		hecho = true
	end)
	local inicio = os.clock()
	while not hecho and os.clock() - inicio < 8 do
		task.wait(0.1)
	end
	local nombre = m:GetFullName()
	if not hecho then
		aviso(nombre .. ": se queda esperando al cargar (normal si espera algo que crea el servidor)")
	elseif not ok then
		fallo(nombre .. ": error al cargar → " .. tostring(res))
	else
		cargados[m.Name] = res
	end
end
local total = 0
for _, servicio in { ReplicatedStorage, ServerScriptService } do
	for _, d in servicio:GetDescendants() do
		if d:IsA("ModuleScript") then
			total += 1
			cargar(d)
		end
	end
end
print(string.format("Módulos cargados: %d de %d", (function()
	local n = 0
	for _ in cargados do
		n += 1
	end
	return n
end)(), total))

-- 3. Construcción del mundo con el motor real (solo si el juego tiene esos módulos)
local Plot, World, Building = cargados.PlotManager, cargados.World, cargados.Building
if type(Plot) == "table" and type(Plot.init) == "function" then
	local ok, err = pcall(Plot.init, function() end)
	if ok then
		print("Mundo y parcelas construidos: OK")
	else
		fallo("PlotManager.init: " .. tostring(err))
	end
elseif type(World) == "table" and type(World.build) == "function" then
	local ok, err = pcall(World.build)
	if ok then
		print("Mundo construido: OK")
	else
		fallo("World.build: " .. tostring(err))
	end
end
if type(Building) == "table" and type(Building.build) == "function" then
	local ok, res = pcall(Building.build, workspace, CFrame.new(0, 0, 2000), 30, 1, "Prueba", true, 30)
	if ok then
		local piezas = 0
		if typeof(res) == "Instance" then
			piezas = #res:GetDescendants()
		end
		print(string.format("Rascacielos de 30 plantas: OK (%d piezas)", piezas))
	else
		fallo("Building.build: " .. tostring(res))
	end
end

-- 4. Pases y productos: ¿existen los IDs del código?
local tienda = { pases = {}, productos = {} }
local function revisar(lista: any, tipo: Enum.InfoType, destino: { any }, etiqueta: string)
	if type(lista) ~= "table" then
		return
	end
	for _, item in lista do
		if type(item) == "table" and type(item.id) == "number" then
			local clave = tostring(item.key or "?")
			if item.id == 0 then
				aviso(etiqueta .. " «" .. clave .. "» sin crear (id = 0)")
			else
				local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, item.id, tipo)
				if ok and type(info) == "table" then
					table.insert(destino, { key = clave, id = item.id, nombre = info.Name, precio = info.PriceInRobux, venta = info.IsForSale })
					print(string.format("%s «%s» %d: «%s» %s R$%s", etiqueta, clave, item.id, tostring(info.Name), tostring(info.PriceInRobux), info.IsForSale and "" or " (NO a la venta)"))
					if not info.IsForSale then
						aviso(etiqueta .. " «" .. clave .. "» no está a la venta")
					end
				else
					fallo(etiqueta .. " «" .. clave .. "» con id " .. item.id .. " no existe o no se puede leer: " .. tostring(info))
				end
			end
		end
	end
end
local vistos = {}
for _, modulo in cargados do
	if type(modulo) == "table" then
		for _, t in { modulo, modulo.Monetization } do
			if type(t) == "table" and not vistos[t] then
				vistos[t] = true
				revisar(t.GamePasses, Enum.InfoType.GamePass, tienda.pases, "Pase")
				revisar(t.Products, Enum.InfoType.Product, tienda.productos, "Producto")
			end
		end
	end
end

print(#fallos == 0 and "RESULTADO: OK" or ("RESULTADO: " .. #fallos .. " fallo(s)"))
return { ok = #fallos == 0, fallos = fallos, avisos = avisos, codigo = cuenta, modulos = total, tienda = tienda }
