--!strict
-- Garabato de mascota (pase «pet»): el gato alado vuela a tu lado. Solo se ve en tu pantalla, no choca
-- con nada ni lo alcanza la cruceta (CanCollide/CanQuery/CanTouch = false). 13 piezas.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Kit = require(script.Parent:WaitForChild("Kit"))

local Pet = {}

local FUR = Color3.fromRGB(232, 150, 70) -- atigrado naranja
local FUR2 = Color3.fromRGB(250, 236, 214)
local WING = Color3.fromRGB(196, 170, 255)
local OFFSET = Vector3.new(2.6, 0.9, -3.2) -- a tu derecha, un poco por delante (se ve en primera persona)

type Piece = { part: BasePart, at: CFrame }

local model: Model? = nil
local pieces: { Piece } = {}
local wings: { { part: BasePart, at: CFrame, side: number } } = {}
local where: CFrame? = nil
local t = 0

local function piece(parent: Instance, kind: string, size: Vector3, color: Color3, at: CFrame, shape: Enum.PartType?): BasePart
	local p: BasePart = if kind == "Wedge" then Instance.new("WedgePart") else Instance.new("Part")
	if shape then
		(p :: Part).Shape = shape
	end
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	table.insert(pieces, { part = p, at = at })
	return p
end

local function build(): Model
	local m = Instance.new("Model")
	m.Name = "Garabato"
	piece(m, "Part", Vector3.new(1.2, 1.2, 1.2), FUR, CFrame.new(0, 0, 0.35), Enum.PartType.Ball) -- cuerpo
	piece(m, "Part", Vector3.new(0.9, 0.9, 0.9), FUR, CFrame.new(0, 0.45, -0.45), Enum.PartType.Ball) -- cabeza
	piece(m, "Part", Vector3.new(0.55, 0.4, 0.4), FUR2, CFrame.new(0, 0.3, -0.82), Enum.PartType.Ball) -- hocico
	piece(m, "Wedge", Vector3.new(0.12, 0.35, 0.3), FUR, CFrame.new(-0.25, 0.95, -0.45)) -- orejas
	piece(m, "Wedge", Vector3.new(0.12, 0.35, 0.3), FUR, CFrame.new(0.25, 0.95, -0.45))
	piece(m, "Part", Vector3.new(0.16, 0.16, 0.16), Color3.fromRGB(30, 30, 40), CFrame.new(-0.2, 0.55, -0.86), Enum.PartType.Ball) -- ojos
	piece(m, "Part", Vector3.new(0.16, 0.16, 0.16), Color3.fromRGB(30, 30, 40), CFrame.new(0.2, 0.55, -0.86), Enum.PartType.Ball)
	piece(m, "Part", Vector3.new(0.1, 0.1, 0.1), Color3.fromRGB(240, 120, 140), CFrame.new(0, 0.42, -1.0), Enum.PartType.Ball) -- nariz
	piece(m, "Part", Vector3.new(0.9, 0.18, 0.18), FUR, CFrame.new(0, 0.3, 1.2) * CFrame.Angles(0, math.rad(90), math.rad(35)), Enum.PartType.Cylinder) -- cola
	piece(m, "Part", Vector3.new(0.25, 0.3, 0.25), FUR2, CFrame.new(-0.3, -0.55, 0.0), Enum.PartType.Ball) -- patitas
	piece(m, "Part", Vector3.new(0.25, 0.3, 0.25), FUR2, CFrame.new(0.3, -0.55, 0.0), Enum.PartType.Ball)
	for _, side in { -1, 1 } do
		local at = CFrame.new(side * 0.55, 0.35, 0.3)
		local w = piece(m, "Part", Vector3.new(1.3, 0.06, 0.75), WING, at)
		w.Material = Enum.Material.Neon
		w.Transparency = 0.25
		table.insert(wings, { part = w, at = at, side = side })
	end
	m.Parent = Workspace
	return m
end

local function destroy()
	if model then
		model:Destroy()
		model = nil
	end
	pieces = {}
	wings = {}
	where = nil
end

-- ¿Se ve ahora? (pase + opción + dentro de la biblioteca)
function Pet.wanted(st: { [string]: any }): boolean
	local set = st.settings or {}
	local passes = st.passes or {}
	return passes.pet == true and set.pet == true and (st.mode == "main" or st.mode == "special")
end

function Pet.build(ctx: Kit.Ctx)
	table.insert(ctx.tickers, function(dt: number)
		if not Pet.wanted(ctx.state) then
			if model then
				destroy()
			end
			return
		end
		local char = Players.LocalPlayer and Players.LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		if not model then
			model = build()
		end
		t += dt or 0
		-- Sigue al jugador con suavidad, mirando hacia donde miras
		local look = root.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		local yaw = if flat.Magnitude > 0.01 then math.atan2(-flat.X, -flat.Z) else 0
		local base = CFrame.new(root.CFrame.Position) * CFrame.Angles(0, yaw, 0)
		local goal = base * CFrame.new(OFFSET + Vector3.new(0, math.sin(t * 2.2) * 0.25, 0))
		local k = math.clamp((dt or 0) * 5, 0, 1)
		local prev = where
		if prev == nil or (prev.Position - goal.Position).Magnitude > 30 then
			where = goal
		else
			where = prev:Lerp(goal, k)
		end
		local cf = where :: CFrame
		for _, p in pieces do
			p.part.CFrame = cf * p.at
		end
		local flap = math.sin(t * 14) * 0.6
		for _, w in wings do
			w.part.CFrame = cf * w.at * CFrame.new(w.side * -0.6, 0, 0) * CFrame.Angles(0, 0, w.side * flap) * CFrame.new(w.side * 0.6, 0, 0)
		end
	end)
end

Pet.count = function(): number
	return #pieces
end

return Pet
