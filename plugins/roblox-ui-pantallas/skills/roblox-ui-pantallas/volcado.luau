-- Volcado de la interfaz a JSON (para Lune). Copia este archivo en <juego>/tools/harness/
-- y úsalo desde el harness del cliente:
--   local volcar = require("./volcado")   -- ruta relativa al harness
--   volcar(playerGuiReal, carpeta .. "/10_tienda.json")
-- playerGuiReal = la instancia de Lune de verdad (si el harness usa proxies, la «real», no el proxy).
-- Luego: python3 -I .claude/skills/disenar-interfaz/ver_interfaz.py <carpeta> <ancho> <alto>
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local PROPS = {
	"Size", "Position", "AnchorPoint", "BackgroundColor3", "BackgroundTransparency", "Visible", "Enabled", "ZIndex",
	"LayoutOrder", "DisplayOrder", "IgnoreGuiInset",
	"Text", "TextSize", "TextScaled", "TextColor3", "TextXAlignment", "TextYAlignment", "TextWrapped", "TextTransparency",
	"TextStrokeTransparency", "TextStrokeColor3", "RichText", "FontFace",
	"Image", "ImageRectOffset", "ImageRectSize", "ImageColor3", "ImageTransparency", "ScaleType", "Rotation",
	"ClipsDescendants", "AutomaticSize",
	"CornerRadius", "Color", "Thickness", "Transparency", "ApplyStrokeMode", "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom",
	"FillDirection", "Padding", "HorizontalAlignment", "VerticalAlignment", "CellSize", "CellPadding", "AspectRatio", "Scale",
	"MaxSize", "MinSize", "MaxTextSize", "MinTextSize",
}

local function encode(v: any): any
	local t = typeof(v)
	if t == "UDim2" then
		return { v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset }
	elseif t == "UDim" then
		return { v.Scale, v.Offset }
	elseif t == "Vector2" then
		return { v.X, v.Y }
	elseif t == "Color3" then
		return { math.floor(v.R * 255 + 0.5), math.floor(v.G * 255 + 0.5), math.floor(v.B * 255 + 0.5) }
	elseif t == "ColorSequence" then
		local out = {}
		for _, kp in v.Keypoints do
			local c = kp.Value
			table.insert(out, { math.floor(kp.Time * 1000 + 0.5) / 1000, math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) })
		end
		return out
	elseif t == "NumberSequence" then
		local out = {}
		for _, kp in v.Keypoints do
			table.insert(out, { math.floor(kp.Time * 1000 + 0.5) / 1000, math.floor(kp.Value * 1000 + 0.5) / 1000 })
		end
		return out
	elseif t == "EnumItem" then
		return v.Name
	elseif t == "Font" then
		return { v.Family, v.Weight.Name }
	elseif t == "number" then
		return if v ~= v then 0 elseif v == math.huge then 1e9 else v
	elseif t == "string" or t == "boolean" then
		return v
	end
	return nil
end

local function node(inst: any): any
	local n = { class = inst.ClassName, name = inst.Name, children = {} }
	for _, p in PROPS do
		local ok, v = pcall(function()
			return inst[p]
		end)
		if ok and v ~= nil then
			n[p] = encode(v)
		end
	end
	for _, c in inst:GetChildren() do
		if not c:IsA("Sound") and not c:IsA("LocalScript") and not c:IsA("ModuleScript") then
			table.insert(n.children, node(c))
		end
	end
	return n
end

return function(playerGui: any, path: string)
	local guis = {}
	for _, g in playerGui:GetChildren() do
		if g:IsA("ScreenGui") then
			table.insert(guis, node(g))
		end
	end
	table.sort(guis, function(a, b)
		return (a.DisplayOrder or 0) < (b.DisplayOrder or 0)
	end)
	fs.writeFile(path, serde.encode("json", guis))
end
