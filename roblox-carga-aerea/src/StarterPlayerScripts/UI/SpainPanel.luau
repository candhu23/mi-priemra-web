--[[
	Ventana ESPAÑA: regiones para desbloquear. Al comprarlas se pintan de color en el mapa
	y aparecen sus aeropuertos y productos típicos.
]]

local Kit = require(script.Parent:WaitForChild("Kit"))
local Config = Kit.Config
local C = Kit.C
local ctx = Kit.ctx
local T = Kit.T
local create = Kit.create
local corner = Kit.corner

local SpainPanel = {}

function SpainPanel.build(content: Frame): () -> ()
	local area = Kit.scroll(content)
	Kit.list(false, 10).Parent = area
	local cache: { [any]: Kit.Entry } = {}

	local function buildRegion(r: any): Kit.Entry
		local root = Kit.card(area, { Size = UDim2.new(1, 0, 0, 96) })
		Kit.padding(14).Parent = root
		create("Frame", { Parent = root, BackgroundColor3 = r.color, Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(0, 2) }, {
			corner(18), Kit.stroke(C.white, 3),
		})
		local airports, goods, seen = {}, {}, {}
		for _, a in Config.Airports do
			if a.region == r.id then
				table.insert(airports, a.city)
				for _, g in a.goods do
					if not seen[g] then
						seen[g] = true
						table.insert(goods, Config.GoodById[g].emoji)
					end
				end
			end
		end
		Kit.title(root, T("r_" .. r.id), 24, C.ink, { Position = UDim2.fromOffset(80, 0), Size = UDim2.new(1, -340, 0, 28) })
		Kit.label(root, table.concat(airports, " · "), 15, C.muted, nil, { Position = UDim2.fromOffset(80, 30), Size = UDim2.new(1, -340, 0, 20) })
		Kit.label(root, table.concat(goods, " "), 20, C.ink, nil, { Position = UDim2.fromOffset(80, 50), Size = UDim2.new(1, -340, 0, 24) })
		local btn = Kit.button(root, "", "orange", UDim2.fromOffset(250, 54), function()
			local ok = ctx.act("buyRegion", r.id)
			if ok then
				ctx.closePanel()
				ctx.celebrateRegion(r.id)
			end
		end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5) })
		ctx.targets["region_" .. r.id] = btn
		return {
			root = root,
			update = function()
				local st = ctx.state
				if st.regions[r.id] then
					Kit.setButton(btn, "✅ " .. T("owned"), false)
				elseif st.level < r.level then
					Kit.setButton(btn, "🔒 " .. T("req_level", { level = r.level }), false)
				else
					Kit.setButton(btn, "🔓 " .. Kit.fmtMoney(r.cost), st.money >= r.cost)
				end
			end,
		}
	end

	return function()
		if ctx.state then
			Kit.syncList(cache, Config.Regions, function(r) return r.id end, buildRegion)
		end
	end
end

return SpainPanel
