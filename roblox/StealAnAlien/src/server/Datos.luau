--!strict
--[[
	Guardado con DataStore y "bloqueo de sesión".

	El bloqueo evita el error clásico de Roblox: si un jugador cambia de servidor muy
	rápido, el servidor nuevo podría cargar datos viejos antes de que el antiguo
	termine de guardar, y se perdería progreso. Aquí cada servidor marca los datos
	como suyos mientras el jugador está dentro y libera la marca al salir.
]]

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Datos = {}

local NOMBRE_ALMACEN = "StealAnAlien_Jugadores_v1"
local BLOQUEO_CADUCA = 600 -- si un servidor se cae, su bloqueo caduca a los 10 min
local INTENTOS_CARGA = 6
local ESPERA_ENTRE_INTENTOS = 5

local almacen: DataStore? = nil
local disponible = false
local jobId = if game.JobId ~= "" then game.JobId else "studio"

local function iniciar()
	local ok, resultado = pcall(function()
		return DataStoreService:GetDataStore(NOMBRE_ALMACEN)
	end)
	if ok then
		almacen = resultado
		disponible = true
	else
		warn("[Datos] DataStore no disponible:", resultado)
	end
end
iniciar()

local function clave(userId: number): string
	return "u_" .. userId
end

-- En Studio sin "Enable Studio Access to API Services" todas las llamadas fallan:
-- en ese caso jugamos sin guardar en lugar de echar al jugador.
local function esErrorDeStudio(err: any): boolean
	return RunService:IsStudio() and type(err) == "string" and (string.find(err, "StudioAccessToApisNotAllowed") ~= nil or string.find(err, "API Services") ~= nil or string.find(err, "403") ~= nil or string.find(err, "publish") ~= nil)
end

export type ResultadoCarga = {
	ok: boolean,
	guardado: any, -- datos tal cual estaban en el DataStore (o nil si es nuevo)
	sinGuardado: boolean, -- true si estamos en Studio sin acceso a la API
}

function Datos.cargar(userId: number): ResultadoCarga
	if not disponible or not almacen then
		return { ok = RunService:IsStudio(), guardado = nil, sinGuardado = true }
	end
	local tienda = almacen :: DataStore
	for intento = 1, INTENTOS_CARGA do
		local bloqueadoPorOtro = false
		local ultimoIntento = intento == INTENTOS_CARGA
		local ok, resultado = pcall(function()
			return tienda:UpdateAsync(clave(userId), function(actual: any)
				actual = if type(actual) == "table" then actual else {}
				local bloqueo = actual.bloqueo
				local ahora = os.time()
				if
					type(bloqueo) == "table"
					and bloqueo.job ~= jobId
					and type(bloqueo.t) == "number"
					and ahora - bloqueo.t < BLOQUEO_CADUCA
					and not ultimoIntento -- en el último intento asumimos que el otro servidor se colgó
				then
					bloqueadoPorOtro = true
					return nil -- no escribimos nada
				end
				bloqueadoPorOtro = false
				actual.bloqueo = { job = jobId, t = ahora }
				return actual
			end)
		end)
		if not ok then
			if esErrorDeStudio(resultado) then
				warn("[Datos] Sin acceso a la API en Studio: se juega sin guardar.")
				disponible = false
				return { ok = true, guardado = nil, sinGuardado = true }
			end
			warn("[Datos] Error cargando", userId, resultado)
		elseif not bloqueadoPorOtro then
			return { ok = true, guardado = if type(resultado) == "table" then resultado.datos else nil, sinGuardado = false }
		end
		task.wait(ESPERA_ENTRE_INTENTOS)
	end
	return { ok = false, guardado = nil, sinGuardado = false }
end

-- liberar = true al salir el jugador. Devuelve true si se guardó.
function Datos.guardar(userId: number, datos: any, liberar: boolean): boolean
	if not disponible or not almacen then
		return false
	end
	local tienda = almacen :: DataStore
	local perdimosBloqueo = false
	local ok, err = pcall(function()
		tienda:UpdateAsync(clave(userId), function(actual: any)
			actual = if type(actual) == "table" then actual else {}
			local bloqueo = actual.bloqueo
			if type(bloqueo) == "table" and bloqueo.job ~= jobId then
				-- Otro servidor tiene ya al jugador: no pisamos sus datos.
				perdimosBloqueo = true
				return nil
			end
			actual.datos = datos
			actual.bloqueo = if liberar then nil else { job = jobId, t = os.time() }
			return actual
		end)
	end)
	if not ok then
		warn("[Datos] Error guardando", userId, err)
		return false
	end
	if perdimosBloqueo then
		warn("[Datos] Otro servidor tiene los datos de", userId, "- no se guarda aquí.")
		return false
	end
	return true
end

-- Quita el bloqueo sin tocar los datos (por si el jugador se va mientras se cargaba).
function Datos.liberar(userId: number)
	if not disponible or not almacen then
		return
	end
	local tienda = almacen :: DataStore
	pcall(function()
		tienda:UpdateAsync(clave(userId), function(actual: any)
			if type(actual) ~= "table" or type(actual.bloqueo) ~= "table" or actual.bloqueo.job ~= jobId then
				return nil
			end
			actual.bloqueo = nil
			return actual
		end)
	end)
end

function Datos.disponible(): boolean
	return disponible
end

---------------------------------------------------------------------
-- RANKINGS GLOBALES (OrderedDataStore)
---------------------------------------------------------------------
local rankings: { [string]: OrderedDataStore } = {}

function Datos.ranking(nombre: string): OrderedDataStore?
	if rankings[nombre] then
		return rankings[nombre]
	end
	local ok, resultado = pcall(function()
		return DataStoreService:GetOrderedDataStore("Ranking_" .. nombre .. "_v1")
	end)
	if ok then
		rankings[nombre] = resultado
		return resultado
	end
	return nil
end

return Datos
