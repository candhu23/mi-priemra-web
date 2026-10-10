--[[
	Mapa de España dibujado con Frames (franjas de MapData), sin imágenes.
	Las regiones se pintan de color al desbloquearlas; las bloqueadas salen en gris con su nivel.
	Aeropuertos con el emoji de su producto, rutas punteadas, aviones volando y dinero flotante.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Kit = require(script.Parent:WaitForChild("Kit"))
local PlaneArt = require(script.Parent:WaitForChild("PlaneArt"))
local MapData = require(ReplicatedStorage:WaitForChild("MapData"))

local Config = Kit.Config
local C = Kit.C
local ctx = Kit.ctx
local T = Kit.T
local create = Kit.create
local corner = Kit.corner

local MapView = {}

function MapView.build(parent: Instance)
	local area = create("Frame", { Parent = parent, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Name = "MapArea" })
	local map = create("Frame", {
		Parent = area, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, Name = "Map",
	}, { create("UIAspectRatioConstraint", { AspectRatio = MapData.aspect }) })
	ctx.map = map

	-- Recuadro de Canarias
	local cb = MapData.canaryBox
	create("Frame", {
		Parent = map, Position = UDim2.fromScale(cb[1] - 0.008, cb[2] - 0.01), Size = UDim2.fromScale(cb[3] + 0.016, cb[4] + 0.02),
		BackgroundColor3 = C.seaDeep, BackgroundTransparency = 0.6, BorderSizePixel = 0,
	}, { corner(12), Kit.stroke(C.white, 2, 0.3) })

	-- Franjas: primero la sombra (relieve) y luego la tierra
	local rowH = 1 / MapData.rows
	local shadowLayer = create("Frame", { Parent = map, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0, 0.006) })
	local landLayer = create("Frame", { Parent = map, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	local byRegion: { [number]: { Frame } } = {}
	local centroid: { [number]: { number } } = {}
	for _, s in MapData.spans do
		local row, x0, x1, reg = s[1], s[2], s[3], s[4]
		local pos = UDim2.fromScale(x0, row * rowH)
		local size = UDim2.fromScale(x1 - x0, rowH * 1.3) -- solape para que no haya rendijas al escalar
		create("Frame", { Parent = shadowLayer, Position = pos, Size = size, BackgroundColor3 = C.seaDeep, BorderSizePixel = 0 })
		local f = create("Frame", { Parent = landLayer, Position = pos, Size = size, BackgroundColor3 = reg == 0 and C.foreign or C.locked, BorderSizePixel = 0 })
		if reg > 0 then
			byRegion[reg] = byRegion[reg] or {}
			table.insert(byRegion[reg], f)
			local c = centroid[reg] or { 0, 0, 0 }
			local w = x1 - x0
			c[1] += (x0 + x1) / 2 * w
			c[2] += (row + 0.5) * rowH * w
			c[3] += w
			centroid[reg] = c
		end
	end

	-- Etiquetas de región (nombre y candado con nivel)
	local labelLayer = create("Frame", { Parent = map, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2 })
	local regionLabels = {}
	local regionCenter: { [string]: { number } } = {}
	for i, regionId in MapData.regions do
		local c = centroid[i]
		if c then
			regionCenter[regionId] = { c[1] / c[3], c[2] / c[3] }
			local holder = create("TextButton", {
				Parent = labelLayer, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(c[1] / c[3], c[2] / c[3]),
				Size = UDim2.fromOffset(160, 44), BackgroundTransparency = 1, Text = "", ZIndex = 2,
			})
			local name = Kit.title(holder, T("r_" .. regionId), 15, C.white, {
				Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.35,
				TextStrokeColor3 = Color3.fromRGB(60, 50, 40), ZIndex = 2, TextTransparency = 0.1,
			})
			local lock = Kit.pill(holder, "", C.ink, {
				AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 20), ZIndex = 2, TextSize = 12, Size = UDim2.fromOffset(0, 20),
			})
			holder.Activated:Connect(function()
				Kit.playSound("click")
				ctx.openPanel("spain")
			end)
			regionLabels[regionId] = { name = name, lock = lock }
		end
	end

	-- Capas de rutas, aeropuertos, aviones y efectos
	local routeLayer = create("Frame", { Parent = map, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3 })
	local pinLayer = create("Frame", { Parent = map, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4 })
	local planeLayer = create("Frame", { Parent = map, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5 })
	local fxLayer = create("Frame", { Parent = map, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 6 })

	local function airportInfo(a: any)
		local st = ctx.state
		local here = {}
		for _, p in st.planes do
			if not p.flight and p.airport == a.code then
				table.insert(here, p)
			end
		end
		ctx.openModal(a.city .. "  ·  " .. a.code, function(body: Frame)
			Kit.list(false, 10).Parent = body
			local goods = {}
			for _, g in a.goods do
				table.insert(goods, Kit.goodName(g))
			end
			Kit.label(body, T("map_products") .. ": " .. table.concat(goods, "  ·  "), 18, C.ink, Kit.FONT_BOLD, { LayoutOrder = 1, TextWrapped = true, Size = UDim2.new(1, 0, 0, 46) })
			Kit.label(body, T("map_planes_here", { n = #here }), 17, C.muted, nil, { LayoutOrder = 2 })
			if not st.regions[a.region] then
				Kit.label(body, "🔒 " .. T("map_locked"), 17, C.red, Kit.FONT_BOLD, { LayoutOrder = 3 })
			end
			local stamped = st.album and st.album.airports[a.code]
			Kit.label(body, stamped and ("🛂 " .. T("map_stamped")) or ("✨ " .. T("map_new_route")), 17, stamped and C.greenDark or C.goldDark, Kit.FONT_BOLD, {
				LayoutOrder = 4, TextWrapped = true, Size = UDim2.new(1, 0, 0, 44),
			})
			local w = st.wanted and st.wanted[a.code]
			if w then
				Kit.label(body, T("map_wanted", { mult = Kit.modText({ kind = "wanted", icon = "🔥", mult = w }) }), 17, C.orangeDark, Kit.FONT_BOLD, {
					LayoutOrder = 5, TextWrapped = true, Size = UDim2.new(1, 0, 0, 44),
				})
			end
		end, #here > 0 and {
			{ text = T("btn_close"), style = "white" },
			{ text = T("btn_see_loads"), style = "orange", onClick = function()
				ctx.selectPlane = here[1].id
				ctx.openPanel("cargo")
			end },
		} or nil)
	end

	local pins = {}
	for _, a in Config.Airports do
		local x, y = MapData.project(a.lat, a.lon)
		local pin = create("TextButton", {
			Parent = pinLayer, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y), Size = UDim2.fromOffset(30, 30),
			BackgroundColor3 = C.white, Text = "", AutoButtonColor = false, ZIndex = 4,
		}, { corner() })
		local ring = Kit.stroke(C.grey, 3)
		ring.Parent = pin
		local icon = Kit.emoji(pin, Config.GoodById[a.goods[1]].emoji, 14, {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 4,
		})
		local side = a.label or "bottom"
		local anchor, off = Vector2.new(0.5, 0), Vector2.new(0, 16)
		if side == "top" then
			anchor, off = Vector2.new(0.5, 1), Vector2.new(0, -16)
		elseif side == "left" then
			anchor, off = Vector2.new(1, 0.5), Vector2.new(-18, 0)
		elseif side == "right" then
			anchor, off = Vector2.new(0, 0.5), Vector2.new(18, 0)
		end
		local name = Kit.title(pinLayer, a.city, 13, C.ink, {
			AnchorPoint = anchor, Position = UDim2.new(x, off.X, y, off.Y), Size = UDim2.fromOffset(110, 16), ZIndex = 4,
			TextXAlignment = side == "left" and Enum.TextXAlignment.Right or (side == "right" and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center),
			TextStrokeTransparency = 0.2, TextStrokeColor3 = C.white, TextTruncate = Enum.TextTruncate.None,
		})
		local count = create("TextLabel", {
			Parent = pin, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -2, 0, 2), Size = UDim2.fromOffset(18, 18),
			BackgroundColor3 = C.orange, TextColor3 = C.white, FontFace = Kit.FONT_TITLE, TextSize = 12, Text = "", Visible = false, ZIndex = 5,
		}, { corner() })
		local glow = create("Frame", {
			Parent = pinLayer, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y), Size = UDim2.fromOffset(46, 46),
			BackgroundColor3 = C.gold, BackgroundTransparency = 0.4, Visible = false, ZIndex = 3,
		}, { corner() })
		-- Insignia arriba a la derecha: ciudad en auge 🔥 y/o evento
		local badge = Kit.pill(pinLayer, "", C.orange, {
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(x, 0, y, -15), Size = UDim2.fromOffset(0, 20), TextSize = 12,
			ZIndex = 5, Visible = false,
		})
		pin.Activated:Connect(function()
			Kit.playSound("click")
			airportInfo(a)
		end)
		pins[a.code] = { pin = pin, ring = ring, icon = icon, name = name, count = count, glow = glow, badge = badge, airport = a, x = x, y = y }
		ctx.targets["pin_" .. a.code] = pin
	end

	-- Emoji grande del evento sobre su región (tormenta, niebla, turistas…)
	local eventMark = Kit.emoji(fxLayer, "", 40, { AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, ZIndex = 6 })

	-- Aviones en vuelo
	local DOTS = 12
	local flights: { [number]: any } = {}
	local function flightVisual(plane: any, left: boolean)
		local f = flights[plane.id]
		local tint = Kit.airlineColor(ctx.state)
		if f and f.left == left and f.model == plane.model and f.tint == tint and f.startT == plane.flight.startT then
			return f
		end
		local fresh = not f or f.startT ~= plane.flight.startT
		if f then
			for _, d in f.dots do
				d:Destroy()
			end
			f.art:Destroy()
		end
		local dots = {}
		for i = 1, DOTS do
			dots[i] = create("Frame", {
				Parent = routeLayer, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(5, 5),
				BackgroundColor3 = C.white, BorderSizePixel = 0, ZIndex = 3,
			}, { corner() })
		end
		local art = PlaneArt.top(planeLayer, plane.model, 34, left, { ZIndex = 5 }, tint)
		-- Despegue: el avión «crece» desde la pista
		if fresh and Kit.serverNow() - plane.flight.startT < 3 then
			local grow = create("UIScale", { Parent = art, Scale = 0.2 })
			Kit.tween(grow, 0.6, { Scale = 1 }, Enum.EasingStyle.Back)
		end
		f = { dots = dots, art = art, left = left, model = plane.model, tint = tint, startT = plane.flight.startT }
		flights[plane.id] = f
		return f
	end

	-- Aviones de otros jugadores del servidor (semitransparentes, con su nombre)
	local others: { [string]: any } = {}
	local function trafficVisual(key: string, t: any, left: boolean)
		local v = others[key]
		if v and v.left == left then
			return v
		end
		if v then
			v.art:Destroy()
		end
		local art = PlaneArt.top(planeLayer, t.model, 28, left, { ZIndex = 5 }, Config.AirlineColors[t.color] or C.grey, true)
		Kit.title(art, t.name, 11, C.ink, {
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(90, 14),
			TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.3, TextStrokeColor3 = C.white, ZIndex = 5,
		})
		v = { art = art, left = left }
		others[key] = v
		return v
	end

	local function animate()
		local st = ctx.state
		if not st then
			return
		end
		local now = Kit.serverNow()
		local alive = {}
		for _, p in st.planes do
			local fl = p.flight
			if fl and fl.good ~= "charter" then
				alive[p.id] = true
				local a, b = pins[fl.from], pins[fl.to]
				local v = flightVisual(p, b.x < a.x)
				local t = math.clamp((now - fl.startT) / math.max(1, fl.endT - fl.startT), 0, 1)
				for i, d in v.dots do
					local k = i / (DOTS + 1)
					d.Position = UDim2.fromScale(a.x + (b.x - a.x) * k, a.y + (b.y - a.y) * k)
					d.BackgroundTransparency = k < t and 0.85 or 0.15
				end
				-- Pequeño arco: el avión sube un poco a mitad de camino
				local lift = math.sin(t * math.pi) * 0.025
				v.art.Position = UDim2.fromScale(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t - lift)
			end
		end
		for id, v in flights do
			if not alive[id] then
				for _, d in v.dots do
					d:Destroy()
				end
				v.art:Destroy()
				flights[id] = nil
			end
		end
		-- Tráfico de los demás
		local seen = {}
		for _, t in st.traffic or {} do
			local a, b = pins[t.from], pins[t.to]
			if a and b then
				local key = t.name .. ":" .. tostring(t.id) .. ":" .. t.startT
				seen[key] = true
				local v = trafficVisual(key, t, b.x < a.x)
				local k = math.clamp((now - t.startT) / math.max(1, t.endT - t.startT), 0, 1)
				v.art.Position = UDim2.fromScale(a.x + (b.x - a.x) * k, a.y + (b.y - a.y) * k - math.sin(k * math.pi) * 0.02)
			end
		end
		for key, v in others do
			if not seen[key] then
				v.art:Destroy()
				others[key] = nil
			end
		end
		if eventMark.Visible then
			eventMark.Rotation = math.sin(os.clock() * 2) * 8
		end
		-- Pulso del contrato exprés
		local ex = st.express
		local pulse = 46 + math.sin(os.clock() * 6) * 8
		for code, p in pins do
			local on = ex ~= nil and ex.code == code
			p.glow.Visible = on
			if on then
				p.glow.Size = UDim2.fromOffset(pulse, pulse)
			end
		end
	end
	table.insert(ctx.tickers, animate)

	local lastRegions = ""
	local function refresh()
		local st = ctx.state
		if not st then
			return
		end
		-- Colores de las regiones (solo si ha cambiado algo)
		local sig = ""
		for _, r in Config.Regions do
			sig ..= st.regions[r.id] and "1" or "0"
		end
		if sig ~= lastRegions then
			lastRegions = sig
			for i, regionId in MapData.regions do
				local r = Config.RegionById[regionId]
				local open = st.regions[regionId] == true
				-- Bloqueada: su color apagado (se intuye lo que se puede abrir)
				local color = open and r.color or r.color:Lerp(C.locked, 0.72)
				local frames: { Frame } = byRegion[i] or {}
				for _, f in frames do
					f.BackgroundColor3 = color
				end
			end
		end
		for regionId, l in regionLabels do
			local r = Config.RegionById[regionId]
			local open = st.regions[regionId] == true
			-- Solo se rotulan las regiones bloqueadas (las abiertas ya se ven por sus ciudades)
			l.name.Visible = not open
			l.lock.Visible = not open
			l.lock.Text = st.level >= r.level and ("🔓 " .. Kit.fmtMoney(r.cost)) or ("🔒 " .. T("top_level", { level = r.level }))
			l.lock.BackgroundColor3 = st.level >= r.level and C.green or C.ink
		end
		local idleAt = {}
		for _, p in st.planes do
			if not p.flight then
				idleAt[p.airport] = (idleAt[p.airport] or 0) + 1
			end
		end
		local ev = st.event and Config.EventById[st.event]
		for code, p in pins do
			local open = st.regions[p.airport.region] == true
			local r = Config.RegionById[p.airport.region]
			p.pin.Visible = open
			p.pin.Size = UDim2.fromOffset(26, 26)
			p.icon.Visible = open
			p.ring.Color = open and r.color or C.greyDark
			p.ring.Thickness = open and 3 or 2
			-- En pantallas bajas (móvil) solo círculos: el nombre sale al tocarlos
			p.name.Visible = open and p.airport.label ~= "none" and not ctx.compact
			local n = idleAt[code] or 0
			p.count.Visible = n > 0
			p.count.Text = tostring(n)
			-- Saturado (has volado mucho allí hace poco): anillo rojo
			local sat = st.sat and st.sat[code]
			if open and sat and sat < 0.85 then
				p.ring.Color = C.red
			end
			-- Insignia: 🔥 en auge y/o emoji del evento que le afecta
			local parts = {}
			if ev then
				local hit = (ev.to and table.find(ev.to, code)) or (ev.region == p.airport.region)
				if ev.goods then
					for _, g in p.airport.goods do
						if table.find(ev.goods, g) then
							hit = true
						end
					end
				end
				if hit then
					table.insert(parts, ev.emoji)
				end
			end
			local w = st.wanted and st.wanted[code]
			if w then
				table.insert(parts, Kit.modText({ kind = "wanted", icon = "🔥", mult = w }))
			end
			p.badge.Visible = open and #parts > 0
			p.badge.Text = table.concat(parts, " ")
			p.badge.BackgroundColor3 = w and C.orange or C.purple
		end
		-- Emoji grande del evento: solo para una región aún bloqueada (si está abierta, ya lo dicen las insignias)
		local center = ev and ev.region and not st.regions[ev.region] and regionCenter[ev.region]
		eventMark.Visible = center ~= nil
		if center then
			eventMark.Text = (ev :: any).emoji
			eventMark.Position = UDim2.fromScale(center[1], center[2] - 0.12)
		end
		animate()
	end
	table.insert(ctx.refreshers, refresh)

	-- Dinero que sube desde el aeropuerto al aterrizar
	function ctx.floatMoney(code: string, amount: number, extra: any?)
		local p = pins[code]
		if not p then
			return
		end
		local note = ""
		if extra and extra.landing == "perfect" then
			note = "🎯 " .. T("landing_perfect") .. "  "
		elseif extra and extra.landing == "good" then
			note = "👍 " .. T("landing_good") .. "  "
		elseif extra and extra.charter then
			note = "🌙 "
		end
		local text = Kit.title(fxLayer, note .. (amount >= 0 and "+" or "") .. Kit.fmtMoney(amount), 22, amount >= 0 and C.green or C.red, {
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(p.x, 0, p.y, -16), Size = UDim2.fromOffset(260, 26),
			TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0, TextStrokeColor3 = C.white, ZIndex = 6,
		})
		Kit.tween(text, 1.6, { Position = UDim2.new(p.x, 0, p.y, -70), TextTransparency = 1, TextStrokeTransparency = 1 })
		task.delay(1.7, function()
			text:Destroy()
		end)
		if amount > 0 and ctx.coinsFrom then
			ctx.coinsFrom(p.pin)
		end
	end

	return refresh
end

return MapView
