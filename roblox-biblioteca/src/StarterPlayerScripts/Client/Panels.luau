--!strict
-- Ventanas del juego: carta de la rectora, mensajes (notas de cofres, puerta), lista de libros en mano
-- (con ▲▼ para reordenar) y mapa de las dos plantas (mismo dibujo que los tablones de la pared).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BookData = require(ReplicatedStorage:WaitForChild("BookData"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Books = require(script.Parent:WaitForChild("Books"))
local MapArt = require(script.Parent:WaitForChild("MapArt"))

local Panels = {}
local C = Kit.C

function Panels.build(ctx: Kit.Ctx)
	local T = Kit.T

	-------------------------------------------------------------------
	-- Mensaje (carta, notas, puerta): título + texto largo en pergamino
	-------------------------------------------------------------------
	local msg = Kit.panel("message", 640, 520, "")
	local paper = Kit.frame(msg.body, UDim2.new(1, 0, 1, -60), nil, C.parchment)
	Kit.corner(paper, 10)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -20, 1, -20)
	scroll.Position = UDim2.fromOffset(10, 10)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ZIndex = 23
	scroll.Parent = paper
	local msgText = Kit.label(scroll, "", UDim2.new(1, -10, 0, 0), nil, {
		Font = Enum.Font.Garamond, TextSize = 22, TextColor3 = C.ink, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 24, Name = "Text",
	})
	local msgOk = Kit.button(msg.body, T("btn_ok"), UDim2.fromOffset(180, 46), UDim2.new(0.5, -90, 1, -48), function()
		ctx.closePanel()
	end, { ZIndex = 23, Name = "Ok" })
	ctx.targets.message_ok = msgOk
	local msgOnClose: (() -> ())? = nil
	Panels.message = function(title: string, body: string, onClose: (() -> ())?)
		msg.title.Text = title
		msgText.Text = body
		msgOnClose = onClose
		ctx.openPanel("message")
	end
	ctx.panels.message = {
		open = function()
			msg.shell.Visible = true
		end,
		close = function()
			msg.shell.Visible = false
			local f = msgOnClose
			msgOnClose = nil
			if f then
				f()
			end
		end,
	}

	-------------------------------------------------------------------
	-- Lista de libros en mano
	-------------------------------------------------------------------
	local list = Kit.panel("list", 620, 560, "")
	local hint = Kit.label(list.body, T("list_hint"), UDim2.new(1, 0, 0, 40), nil, {
		TextSize = 15, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23,
	})
	hint.Name = "Hint"
	local rows = Instance.new("ScrollingFrame")
	rows.Name = "Rows"
	rows.Size = UDim2.new(1, 0, 1, -48)
	rows.Position = UDim2.fromOffset(0, 46)
	rows.BackgroundTransparency = 1
	rows.BorderSizePixel = 0
	rows.ScrollBarThickness = 6
	rows.AutomaticCanvasSize = Enum.AutomaticSize.Y
	rows.CanvasSize = UDim2.new()
	rows.ZIndex = 23
	rows.Parent = list.body
	Kit.list(rows, true, 6)
	local function refreshList()
		local st = ctx.state
		local hand = st.hand or {}
		list.title.Text = T("list_title", { n = #hand, cap = st.cap or 10 })
		for _, c in rows:GetChildren() do
			if c:IsA("Frame") or c:IsA("TextLabel") then
				c:Destroy()
			end
		end
		local def = Books.def
		if #hand == 0 or not def then
			Kit.label(rows, T("list_empty"), UDim2.new(1, 0, 0, 40), nil, { ZIndex = 24, TextColor3 = C.muted })
			return
		end
		for pos = #hand, 1, -1 do
			local id = hand[pos]
			local info = def.books[id]
			local s = BookData.Series[info.series]
			local row = Kit.frame(rows, UDim2.new(1, -10, 0, 54), nil, BookData.color(s.cover.base))
			row.Name = "Item" .. pos
			row.LayoutOrder = #hand - pos
			row.ZIndex = 24
			Kit.corner(row, 8)
			local band = Kit.frame(row, UDim2.new(0, 12, 1, 0), nil, BookData.color(s.cover.band))
			band.ZIndex = 25
			local title = if ctx.lang == "es" then s.es else s.en
			local top = if pos == #hand then T("list_top") .. " · " else ""
			Kit.label(row, string.format("%s%s %s\n%s · %s", top, s.cover.sym, title, T("hud_vol", { v = info.vol, n = s.volumes }), T("hud_section", { code = def.seriesSection[info.series] })),
				UDim2.new(1, -120, 1, 0), UDim2.fromOffset(20, 0), {
					TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = BookData.color(s.cover.text), ZIndex = 25,
					TextStrokeTransparency = 0.6, TextTruncate = Enum.TextTruncate.AtEnd,
				})
			local up = Kit.button(row, "▲", UDim2.fromOffset(44, 44), UDim2.new(1, -96, 0, 5), function()
				if pos < #hand then
					ctx.act("reorder", pos, pos + 1)
				end
			end, { ZIndex = 25, Name = "Up" })
			local down = Kit.button(row, "▼", UDim2.fromOffset(44, 44), UDim2.new(1, -48, 0, 5), function()
				if pos > 1 then
					ctx.act("reorder", pos, pos - 1)
				end
			end, { ZIndex = 25, Name = "Down" })
			up.Visible = pos < #hand
			down.Visible = pos > 1
		end
	end
	ctx.panels.list = {
		open = function()
			refreshList()
			list.shell.Visible = true
		end,
		close = function()
			list.shell.Visible = false
		end,
	}
	table.insert(ctx.refreshers, function()
		if ctx.panel == "list" then
			refreshList()
		end
	end)

	-------------------------------------------------------------------
	-- Mapa
	-------------------------------------------------------------------
	local map = Kit.panel("map", 760, 640, T("map_title"))
	local canvas = Kit.frame(map.body, UDim2.fromOffset(300, 562), UDim2.fromOffset(0, 0), C.parchment)
	canvas.Name = "Canvas"
	Kit.corner(canvas, 6)
	local side = Kit.frame(map.body, UDim2.new(1, -320, 1, 0), UDim2.fromOffset(320, 0), C.panel, 1)
	side.ZIndex = 23
	local floor = 1
	local setYou: (Vector3?) -> () = function() end
	local legend = Kit.label(side, "", UDim2.new(1, 0, 0, 340), UDim2.fromOffset(0, 120), {
		TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 24, Name = "Legend",
	})
	local function playerPos(): Vector3?
		local char = Players.LocalPlayer and Players.LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		return if root and root:IsA("BasePart") then root.CFrame.Position else nil
	end
	local function drawMap()
		setYou = MapArt.draw(canvas, floor, Books.sectionDone, {
			stairs = T("map_stairs"), door = T("map_door"), crystal = T("map_crystal"), void = "",
		})
		setYou(playerPos())
		local lines = { T("map_floor", { f = floor }), "", T("map_hint"), "" }
		local def = Books.def
		if def and def.name == "main" then
			for _, sec in def.sections do
				if sec.floor == floor then
					table.insert(lines, (if Books.sectionDone[sec.code] then "✔ " else "· ") .. sec.code .. "  " .. BookData.sectionName(sec.theme, ctx.lang))
				end
			end
		end
		legend.Text = table.concat(lines, "\n")
	end
	local f1 = Kit.button(side, T("btn_floor1"), UDim2.fromOffset(150, 44), UDim2.fromOffset(0, 0), function()
		floor = 1
		drawMap()
	end, { ZIndex = 24, Name = "Floor1" })
	local f2 = Kit.button(side, T("btn_floor2"), UDim2.fromOffset(150, 44), UDim2.fromOffset(160, 0), function()
		floor = 2
		drawMap()
	end, { ZIndex = 24, Name = "Floor2" })
	ctx.targets.map_floor1, ctx.targets.map_floor2 = f1, f2
	Panels.openMap = function(f: number?)
		local pos = playerPos()
		floor = f or (if pos and pos.Y > 12 then 2 else 1)
		ctx.openPanel("map")
	end
	ctx.panels.map = {
		open = function()
			drawMap()
			map.shell.Visible = true
		end,
		close = function()
			map.shell.Visible = false
		end,
	}
end

-- Rellenadas en build()
Panels.message = function(_title: string, _body: string, _onClose: (() -> ())?) end
Panels.openMap = function(_f: number?) end

return Panels
