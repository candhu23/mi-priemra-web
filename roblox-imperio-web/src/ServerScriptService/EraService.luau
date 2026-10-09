--[[
	EraService (ModuleScript en ServerScriptService)

	v4 · Eras y Fusión (segunda capa de prestigio). Los datos están en
	TycoonConfig (Eras, Fusions, LegacyTree):
	  · fusion     → pasa a la era siguiente si has salido a bolsa bastantes
	                 veces en esta era y has ganado bastante en ella. Reinicia
	                 como salir a bolsa y además las acciones; da 🧬 Legado.
	  · buyLegacy  → sube una mejora del árbol de Legado (para siempre).

	data: era, eraIpos, eraEarned, fusions, legacy, legacyTree
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("TycoonConfig"))
local StatePatch = require(ReplicatedStorage:WaitForChild("StatePatch"))
local ServerState = require(ServerScriptService:WaitForChild("ServerState"))
local SiteService = require(ServerScriptService:WaitForChild("SiteService"))
local CareerService = require(ServerScriptService:WaitForChild("CareerService"))
local Analytics = require(ServerScriptService:WaitForChild("Analytics"))

local notifyAll = ServerState.notifyAll
local sig3 = StatePatch.sig3
type Session = ServerState.Session

local EraService = {}
local Actions = {}

-- Lo que ve el cliente
function EraService.buildState(session: Session)
	local data = session.data
	local requirement = Config.fusionRequirement(data)
	return {
		era = Config.era(data),
		ipos = data.eraIpos or 0,
		earned = sig3(data.eraEarned or 0),
		fusions = data.fusions or 0,
		legacy = data.legacy or 0,
		tree = data.legacyTree,
		gain = Config.legacyForShares(data.shares),
		needIpos = if requirement then requirement.ipos else 0,
		needEarned = if requirement then requirement.earned else 0,
	}
end

-- ¿Se puede fusionar ya? (y si no, por qué)
function EraService.canFuse(data): (boolean, string?)
	local requirement = Config.fusionRequirement(data)
	if not requirement then
		return false, "Ya estás en la última era."
	end
	if (data.eraIpos or 0) < requirement.ipos then
		return false, string.format("Necesitas salir a bolsa %d veces en esta era (llevas %d).", requirement.ipos, data.eraIpos or 0)
	end
	if (data.eraEarned or 0) < requirement.earned then
		return false, "Necesitas ganar " .. Config.formatMoney(requirement.earned) .. " en esta era."
	end
	return true, nil
end

function Actions.fusion(player: Player, session: Session)
	local data = session.data
	local ok, reason = EraService.canFuse(data)
	if not ok then
		return false, reason
	end
	SiteService.closeDeals(player, session)
	local legacy = Config.legacyForShares(data.shares)
	SiteService.resetRun(session)
	data.shares = 0
	data.legacy = (data.legacy or 0) + legacy
	data.era = Config.era(data) + 1
	data.eraIpos = 0
	data.eraEarned = 0
	data.fusions = (data.fusions or 0) + 1
	-- La reputación inicial puede abrir cosas: recalcula bonus y avisa a todos
	CareerService.refreshBonuses(session)
	local era = Config.Eras[data.era]
	Analytics.progress(player, "Eras", data.era, era.name)
	notifyAll(string.format("🧬 ¡%s ha hecho una Fusión y entra en la Era %d: %s %s!", player.DisplayName, data.era, era.emoji, era.name), "event")
	return true, string.format("🧬 ¡Fusión! Era %d: %s %s · +%d 🧬 Legado", data.era, era.emoji, era.name, legacy), { money = true }
end

function Actions.buyLegacy(_player: Player, session: Session, legacyId: any)
	local def = type(legacyId) == "string" and Config.LegacyById[legacyId]
	if not def then
		return false, nil
	end
	local data = session.data
	if def.requires and Config.legacy(data, def.requires) < 1 then
		local parent = Config.LegacyById[def.requires]
		return false, string.format("Antes necesitas %s %s.", parent.emoji, parent.name)
	end
	local level = Config.legacy(data, def.id)
	if level >= def.maxLevel then
		return false, "Nivel máximo."
	end
	local cost = Config.legacyCost(def.id, level)
	if (data.legacy or 0) < cost then
		return false, "Te falta 🧬 Legado. Se consigue con la Fusión."
	end
	data.legacy -= cost
	data.legacyTree[def.id] = level + 1
	CareerService.refreshBonuses(session)
	return true, string.format("🧬 %s %s: nivel %d", def.emoji, def.name, level + 1)
end

EraService.Actions = Actions

return EraService
