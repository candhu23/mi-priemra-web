--[[
	BadgeAwards (ModuleScript en ServerScriptService)

	Da las insignias de Roblox de Config.Badges. Solo las que tienen id
	(id = 0 → desactivada). data.badges[key] = true cuando ya se ha dado,
	para no preguntar a Roblox cada vez. Si Roblox falla, se reintenta a
	los Config.BADGE_RETRY segundos.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BadgeService = game:GetService("BadgeService")

local Config = require(ReplicatedStorage:WaitForChild("TycoonConfig"))

local BadgeAwards = {}

local byKey: { [string]: any } = {}
for _, def in Config.Badges do
	byKey[def.key] = def
end

-- [jugador] = { [key] = cuándo se puede reintentar }
local retryAt: { [Player]: { [string]: number } } = setmetatable({}, { __mode = "k" }) :: any

local function award(player: Player, data: any, def: any)
	local waits = retryAt[player] or {}
	retryAt[player] = waits
	if (waits[def.key] or 0) > os.clock() then
		return
	end
	data.badges[def.key] = true
	task.spawn(function()
		local ok, err = pcall(function()
			return BadgeService:AwardBadgeAsync(player.UserId, def.id)
		end)
		if not ok then
			data.badges[def.key] = nil
			waits[def.key] = os.clock() + Config.BADGE_RETRY
			warn("[ImperioWeb] No se pudo dar la insignia " .. def.key .. ":", err)
		end
	end)
end

-- Da la insignia "key" si está activada y no la tiene (p. ej. top semanal)
function BadgeAwards.give(player: Player, data: any, key: string)
	local def = byKey[key]
	if def and def.id ~= 0 and not data.badges[key] then
		award(player, data, def)
	end
end

-- Mira todas las que se consiguen solas
function BadgeAwards.check(player: Player, data: any)
	for _, def in Config.Badges do
		if def.id ~= 0 and def.check and not data.badges[def.key] then
			local ok, done = pcall(def.check, data)
			if ok and done then
				award(player, data, def)
			end
		end
	end
end

return BadgeAwards
