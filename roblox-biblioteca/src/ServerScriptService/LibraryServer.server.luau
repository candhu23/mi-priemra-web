--!strict
-- Servidor de Estanterías Hechizadas: construye la biblioteca, crea los remotes y atiende al jugador.
-- 1 jugador por servidor (Max Players = 1 en el Creator Hub). Si entrara un 2.º, se le manda a un
-- servidor reservado propio; si eso falla (Studio), mira sin poder tocar nada.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Layout = require(ReplicatedStorage:WaitForChild("Layout"))
local Lib = script.Parent:WaitForChild("Lib")
local Building = require(Lib:WaitForChild("Building"))
local Game = require(Lib:WaitForChild("Game"))
local Magic = require(Lib:WaitForChild("Magic"))
local Flow = require(Lib:WaitForChild("Flow"))
local Shop = require(Lib:WaitForChild("Shop"))
Flow.checkOption = Shop.checkOption

local library = Building.build(Layout.get("main"), Workspace)
Building.build(Layout.get("special"), Workspace)

-- Llaves cogidas y cofres abiertos desaparecen del mundo (1 jugador por servidor: vale para todos)
local function showProgress(slot: any)
	for _, color in { "red", "green", "yellow", "blue" } do
		Building.setVisible(library, "Key_" .. color, not slot.keys[color])
		Building.setVisible(library, "ChestLid_" .. color, not slot.chests[color])
		Building.setVisible(library, "ChestLock_" .. color, not slot.chests[color])
	end
end
Magic.onKey = function(s: any)
	showProgress(s.slot)
	Flow.onKey(s)
end
Magic.onChest = function(s: any)
	showProgress(s.slot)
	Flow.onChest(s)
end
Magic.onLearn = function(s: any)
	Flow.onLearn(s)
end
Flow.onProgress = function(s: any)
	showProgress(s.slot)
end

-- Remotes
local folder = Instance.new("Folder")
folder.Name = "LibRemotes"
local function remote(className: string, name: string): any
	local r = Instance.new(className)
	r.Name = name
	r.Parent = folder
	return r
end
local remotes = {
	Action = remote("RemoteFunction", "Action"),
	Snapshot = remote("RemoteEvent", "Snapshot"),
	Delta = remote("RemoteEvent", "Delta"),
	State = remote("RemoteEvent", "State"),
	Notify = remote("RemoteEvent", "Notify"),
}
folder.Parent = ReplicatedStorage
Game.remotes = remotes

remotes.Action.OnServerInvoke = function(player: Player, name: any, a: any, b: any, c: any)
	return Game.handle(player, name, a, b, c)
end

local guests: { Player } = {}

local function start(player: Player)
	local s = Game.newSession(player)
	local function onCharacter()
		task.defer(function()
			Game.applyCharacter(s)
			if s.mode == "main" and s.slot.pos then
				Game.moveTo(s, CFrame.new(s.slot.pos[1], s.slot.pos[2], s.slot.pos[3]))
			elseif s.mode == "special" then
				Game.moveTo(s, Layout.get("special").spawn)
			end
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	Shop.join(s)
	Flow.join(s)
end

local function onPlayerAdded(player: Player)
	if Game.ownerCount() >= 1 then
		table.insert(guests, player)
		remotes.Notify:FireClient(player, "error", "warn_guest", {})
		task.spawn(function()
			local ok, code = pcall(function()
				return TeleportService:ReserveServer(game.PlaceId)
			end)
			if ok and code then
				pcall(function()
					TeleportService:TeleportToPrivateServer(game.PlaceId, code, { player })
				end)
			end
		end)
		return
	end
	start(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in Players:GetPlayers() do
	onPlayerAdded(p)
end

Players.PlayerRemoving:Connect(function(player: Player)
	local idx = table.find(guests, player)
	if idx then
		table.remove(guests, idx)
		return
	end
	local s = Game.sessions[player]
	if s then
		Flow.leave(s)
		Game.removeSession(player)
		-- Si se va el dueño y queda alguien mirando, pasa a ser el dueño
		local nextPlayer = table.remove(guests, 1)
		if nextPlayer and nextPlayer.Parent then
			start(nextPlayer)
		end
	end
end)

-- Al cerrar el servidor se guarda todo (esperando lo que pida el límite de DataStore)
game:BindToClose(function()
	for _, s in Game.sessions do
		Flow.leave(s)
	end
end)

task.spawn(function()
	while true do
		task.wait(1)
		Game.tick()
		Flow.tick()
	end
end)
