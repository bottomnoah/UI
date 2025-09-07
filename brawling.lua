-- Improved "Synapse-like" Drawing lib for Roblox (UI-backed)
-- Usage: local D = require(...); local l = D.new("Line"); l.From = Vector2.new(...); l.Color = Color3.fromRGB(255,0,0)

local coreGui = game:GetService("CoreGui")
local workspace = workspace
local camera = workspace.CurrentCamera

-- ensure there's a single Drawing UI
local drawingUI = coreGui:FindFirstChild("Drawing") or Instance.new("ScreenGui")
drawingUI.Name = "Drawing"
drawingUI.IgnoreGuiInset = true
drawingUI.DisplayOrder = 0x7fffffff
drawingUI.Parent = coreGui

-- internal bookkeeping
local drawingIndex = 0

-- base prototype (Synapse-like defaults)
local baseDrawingObj = {
	Visible = true,
	ZIndex = 0,
	Transparency = 0, -- 0 = opaque, 1 = invisible (matches Roblox UI transparency semantics)
	Color = Color3.fromRGB(255, 255, 255),
	Remove = function(self) end,
	Destroy = function(self) end
}
setmetatable(baseDrawingObj, { __index = baseDrawingObj })

-- fonts mapping (keeps your earlier Font.fromEnum usage but uses Enum.Font directly)
local drawingFontsEnum = {
	[0] = Enum.Font.Roboto,
	[1] = Enum.Font.Legacy,
	[2] = Enum.Font.SourceSans,
	[3] = Enum.Font.RobotoMono
}
local function getFontFromIndex(i)
	return drawingFontsEnum[math.clamp(i or 0, 0, #drawingFontsEnum)]
end

-- helper: clamp wrapper
local function clamp(n, a, b) return math.clamp(n, a, b) end

-- helper: ensure property exists on prototype
local function propExists(proto, k) return proto[k] ~= nil end

-- ensure we always use Roblox transparency semantics directly
local function toRobloxTransparency(t)
	return clamp(t or 0, 0, 1)
end

local DrawingLib = {}
DrawingLib.Fonts = {
	UI = 0,
	System = 1,
	Plex = 2,
	Monospace = 3
}

-- small utility to create a safe object table with metatable
local function makeDrawingObject(proto, impl)
	local state = table.clone(proto)
	return setmetatable({}, {
		__newindex = function(_, key, value)
			if state[key] == nil and impl[key] == nil then return end
			local handler = impl.__set and impl.__set[key]
			if handler then
				handler(value, state)
			else
				-- fallback generic behavior
				state[key] = value
			end
		end,
		__index = function(_, key)
			if key == "Remove" or key == "Destroy" then
				return function()
					if impl.__destroy then impl.__destroy(state) end
					if state.Remove then state:Remove() end
					if state.Destroy then state:Destroy() end
				end
			end
			-- expose some computed properties if requested
			if impl.__get and impl.__get[key] then
				return impl.__get[key](state)
			end
			return state[key]
		end,
		__tostring = function() return "Drawing" end
	})
end

function DrawingLib.new(drawingType)
	drawingIndex += 1
	drawingType = tostring(drawingType or ""):lower()

	-- LINE -----------------------------------------------------------
	if drawingType == "line" then
		local proto = ({
			From = Vector2.new(0, 0),
			To = Vector2.new(0, 0),
			Thickness = 1
		} + baseDrawingObj)

		-- create actual UI frame used to render the line
		local frame = Instance.new("Frame")
		frame.Name = tostring(drawingIndex)
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = proto.Color
		frame.BackgroundTransparency = toRobloxTransparency(proto.Transparency)
		frame.Size = UDim2.fromOffset(0, proto.Thickness)
		frame.Visible = proto.Visible
		frame.ZIndex = proto.ZIndex
		frame.Parent = drawingUI

		local function updateGeometry(s)
			local from, to = s.From, s.To
			local dir = to - from
			local center = (to + from) * 0.5
			local dist = dir.Magnitude
			local theta = math.deg(math.atan2(dir.Y, dir.X))

			frame.Position = UDim2.fromOffset(center.X, center.Y)
			frame.Rotation = theta
			frame.Size = UDim2.fromOffset(dist, math.max(1, s.Thickness))
		end

		local impl = {
			__set = {
				From = function(v, s) s.From = v; updateGeometry(s) end,
				To = function(v, s) s.To = v; updateGeometry(s) end,
				Thickness = function(v, s) s.Thickness = v; updateGeometry(s) end,
				Visible = function(v, s) s.Visible = v; frame.Visible = v end,
				ZIndex = function(v, s) s.ZIndex = v; frame.ZIndex = v end,
				Transparency = function(v, s) s.Transparency = v; frame.BackgroundTransparency = toRobloxTransparency(v) end,
				Color = function(v, s) s.Color = v; frame.BackgroundColor3 = v end
			},
			__destroy = function(s) frame:Destroy() end
		}

		local obj = makeDrawingObject(proto, impl)
		-- initialize geometry for first time
		obj.From = proto.From
		obj.To = proto.To
		return obj

	-- TEXT -----------------------------------------------------------
	elseif drawingType == "text" then
		local proto = ({
			Text = "",
			Font = DrawingLib.Fonts.UI,
			Size = 14,
			Position = Vector2.new(0, 0),
			Center = false,
			Outline = false,
			OutlineColor = Color3.new(0, 0, 0)
		} + baseDrawingObj)

		local label = Instance.new("TextLabel")
		label.Name = tostring(drawingIndex)
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.Visible = proto.Visible
		label.ZIndex = proto.ZIndex
		label.TextColor3 = proto.Color
		label.TextTransparency = toRobloxTransparency(proto.Transparency)
		label.Text = proto.Text
		label.Font = getFontFromIndex(proto.Font)
		label.TextSize = proto.Size
		label.Size = UDim2.fromOffset(1, 1)
		label.Parent = drawingUI

		local uiStroke = Instance.new("UIStroke")
		uiStroke.Thickness = 1
		uiStroke.Enabled = proto.Outline
		uiStroke.Color = proto.OutlineColor
		uiStroke.Parent = label

		-- reposition helper
		local function updatePosition(s)
			local bounds = label.TextBounds
			local pos = s.Position
			if s.Center then
				-- center on screen (viewport center)
				local vp = camera and camera.ViewportSize or Vector2.new(0, 0)
				label.Position = UDim2.fromOffset(vp.X * 0.5 + pos.X, vp.Y * 0.5 + pos.Y)
			else
				-- treat Position as top-left anchor offset by TextBounds/2 so it lines up similar to Synapse
				local offset = bounds * 0.5
				label.Position = UDim2.fromOffset(pos.X + offset.X, pos.Y + offset.Y)
			end
			label.Size = UDim2.fromOffset(bounds.X, bounds.Y)
		end

		-- auto-update when TextBounds changes
		label:GetPropertyChangedSignal("TextBounds"):Connect(function() updatePosition(proto) end)

		local impl = {
			__set = {
				Text = function(v, s) s.Text = v; label.Text = v; updatePosition(s) end,
				Font = function(v, s) s.Font = clamp(v, 0, 3); label.Font = getFontFromIndex(s.Font) end,
				Size = function(v, s) s.Size = v; label.TextSize = v; updatePosition(s) end,
				Position = function(v, s) s.Position = v; updatePosition(s) end,
				Center = function(v, s) s.Center = v; updatePosition(s) end,
				Outline = function(v, s) s.Outline = v; uiStroke.Enabled = v end,
				OutlineColor = function(v, s) s.OutlineColor = v; uiStroke.Color = v end,
				Visible = function(v, s) s.Visible = v; label.Visible = v end,
				ZIndex = function(v, s) s.ZIndex = v; label.ZIndex = v end,
				Transparency = function(v, s) s.Transparency = v; label.TextTransparency = toRobloxTransparency(v); uiStroke.Transparency = toRobloxTransparency(v) end,
				Color = function(v, s) s.Color = v; label.TextColor3 = v; uiStroke.Color = s.Outline and s.OutlineColor or uiStroke.Color end
			},
			__destroy = function(s) label:Destroy() end,
			__get = {
				TextBounds = function(s) return label.TextBounds end
			}
		}

		return makeDrawingObject(proto, impl)

	-- CIRCLE ---------------------------------------------------------
	elseif drawingType == "circle" then
		local proto = ({
			Radius = 50,
			Position = Vector2.new(0, 0),
			Thickness = 1,
			Filled = false
		} + baseDrawingObj)

		local frame = Instance.new("Frame")
		frame.Name = tostring(drawingIndex)
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.BorderSizePixel = 0
		frame.Position = UDim2.fromOffset(proto.Position.X, proto.Position.Y)
		frame.Size = UDim2.fromOffset(proto.Radius * 2, proto.Radius * 2)
		frame.BackgroundColor3 = proto.Color
		frame.BackgroundTransparency = toRobloxTransparency(proto.Transparency)
		frame.Visible = proto.Visible
		frame.ZIndex = proto.ZIndex
		frame.Parent = drawingUI

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = frame

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = math.max(1, proto.Thickness)
		stroke.Enabled = not proto.Filled
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = proto.Color
		stroke.Parent = frame

		local impl = {
			__set = {
				Radius = function(v, s) s.Radius = v; frame.Size = UDim2.fromOffset(v * 2, v * 2) end,
				Position = function(v, s) s.Position = v; frame.Position = UDim2.fromOffset(v.X, v.Y) end,
				Thickness = function(v, s) s.Thickness = v; stroke.Thickness = math.max(1, v) end,
				Filled = function(v, s) s.Filled = v; frame.BackgroundTransparency = toRobloxTransparency(s.Transparency) * (v and 1 or 0); stroke.Enabled = not v end,
				Visible = function(v, s) s.Visible = v; frame.Visible = v end,
				ZIndex = function(v, s) s.ZIndex = v; frame.ZIndex = v end,
				Transparency = function(v, s) s.Transparency = v; frame.BackgroundTransparency = toRobloxTransparency(v) * (s.Filled and 1 or 0); stroke.Transparency = toRobloxTransparency(v) end,
				Color = function(v, s) s.Color = v; frame.BackgroundColor3 = v; stroke.Color = v end
			},
			__destroy = function(s) frame:Destroy() end
		}

		return makeDrawingObject(proto, impl)

	-- SQUARE / RECT -----------------------------------------------
	elseif drawingType == "square" or drawingType == "rectangle" then
		local proto = ({
			Size = Vector2.new(50, 50),
			Position = Vector2.new(0, 0),
			Thickness = 1,
			Filled = false
		} + baseDrawingObj)

		local frame = Instance.new("Frame")
		frame.Name = tostring(drawingIndex)
		frame.BorderSizePixel = 0
		frame.AnchorPoint = Vector2.new(0, 0)
		frame.Position = UDim2.fromOffset(proto.Position.X, proto.Position.Y)
		frame.Size = UDim2.fromOffset(proto.Size.X, proto.Size.Y)
		frame.BackgroundColor3 = proto.Color
		frame.BackgroundTransparency = toRobloxTransparency(proto.Transparency)
		frame.Visible = proto.Visible
		frame.ZIndex = proto.ZIndex
		frame.Parent = drawingUI

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = math.max(1, proto.Thickness)
		stroke.Enabled = not proto.Filled
		stroke.LineJoinMode = Enum.LineJoinMode.Miter
		stroke.Color = proto.Color
		stroke.Parent = frame

		local impl = {
			__set = {
				Size = function(v, s) s.Size = v; frame.Size = UDim2.fromOffset(v.X, v.Y) end,
				Position = function(v, s) s.Position = v; frame.Position = UDim2.fromOffset(v.X, v.Y) end,
				Thickness = function(v, s) s.Thickness = v; stroke.Thickness = math.max(1, v) end,
				Filled = function(v, s) s.Filled = v; frame.BackgroundTransparency = toRobloxTransparency(s.Transparency) * (v and 1 or 0); stroke.Enabled = not v end,
				Visible = function(v, s) s.Visible = v; frame.Visible = v end,
				ZIndex = function(v, s) s.ZIndex = v; frame.ZIndex = v end,
				Transparency = function(v, s) s.Transparency = v; frame.BackgroundTransparency = toRobloxTransparency(v) * (s.Filled and 1 or 0); stroke.Transparency = toRobloxTransparency(v) end,
				Color = function(v, s) s.Color = v; frame.BackgroundColor3 = v; stroke.Color = v end
			},
			__destroy = function(s) frame:Destroy() end
		}

		return makeDrawingObject(proto, impl)

	-- IMAGE ----------------------------------------------------------
	elseif drawingType == "image" then
		local proto = ({
			Data = nil,
			DataURL = "rbxassetid://0",
			Size = Vector2.new(64, 64),
			Position = Vector2.new(0, 0),
		} + baseDrawingObj)

		local img = Instance.new("ImageLabel")
		img.Name = tostring(drawingIndex)
		img.BorderSizePixel = 0
		img.BackgroundTransparency = 1
		img.ScaleType = Enum.ScaleType.Stretch
		img.Visible = proto.Visible
		img.ZIndex = proto.ZIndex
		img.Image = proto.DataURL
		img.Size = UDim2.fromOffset(proto.Size.X, proto.Size.Y)
		img.Position = UDim2.fromOffset(proto.Position.X, proto.Position.Y)
		img.ImageTransparency = toRobloxTransparency(proto.Transparency)
		img.ImageColor3 = proto.Color
		img.Parent = drawingUI

		local impl = {
			__set = {
				Data = function(v, s) s.Data = v; -- TODO: if you want base64 -> blob handling, add here
				end,
				DataURL = function(v, s) s.DataURL = v; img.Image = v end,
				Size = function(v, s) s.Size = v; img.Size = UDim2.fromOffset(v.X, v.Y) end,
				Position = function(v, s) s.Position = v; img.Position = UDim2.fromOffset(v.X, v.Y) end,
				Visible = function(v, s) s.Visible = v; img.Visible = v end,
				ZIndex = function(v, s) s.ZIndex = v; img.ZIndex = v end,
				Transparency = function(v, s) s.Transparency = v; img.ImageTransparency = toRobloxTransparency(v) end,
				Color = function(v, s) s.Color = v; img.ImageColor3 = v end
			},
			__destroy = function(s) img:Destroy() end
		}

		return makeDrawingObject(proto, impl)

	-- QUAD -----------------------------------------------------------
	elseif drawingType == "quad" then
		-- implement as 4 connected lines (Synapse: Quad has PointA..PointD).
		local proto = ({
			PointA = Vector2.new(),
			PointB = Vector2.new(),
			PointC = Vector2.new(),
			PointD = Vector2.new(),
			Thickness = 1,
			Filled = false
		} + baseDrawingObj)

		local A = DrawingLib.new("Line")
		local B = DrawingLib.new("Line")
		local C = DrawingLib.new("Line")
		local D = DrawingLib.new("Line")

		local function setAll(k, v)
			A[k] = v; B[k] = v; C[k] = v; D[k] = v
		end

		return setmetatable({}, {
			__newindex = function(_, key, value)
				if key == "PointA" then A.From = value; B.To = value; proto.PointA = value
				elseif key == "PointB" then B.From = value; C.To = value; proto.PointB = value
				elseif key == "PointC" then C.From = value; D.To = value; proto.PointC = value
				elseif key == "PointD" then D.From = value; A.To = value; proto.PointD = value
				elseif key == "Thickness" then setAll("Thickness", value); proto.Thickness = value
				elseif key == "Color" then setAll("Color", value); proto.Color = value
				elseif key == "Visible" then setAll("Visible", value); proto.Visible = value
				elseif key == "ZIndex" then setAll("ZIndex", value); proto.ZIndex = value
				elseif key == "Filled" then proto.Filled = value; -- filled quads not implemented (would need triangulation)
				else proto[key] = value end
			end,
			__index = function(_, k)
				if k == "Remove" then
					return function()
						A:Remove(); B:Remove(); C:Remove(); D:Remove()
					end
				end
				return proto[k]
			end,
			__tostring = function() return "Drawing" end
		})

	-- TRIANGLE -------------------------------------------------------
	elseif drawingType == "triangle" then
		local proto = ({
			PointA = Vector2.new(),
			PointB = Vector2.new(),
			PointC = Vector2.new(),
			Thickness = 1,
			Filled = false
		} + baseDrawingObj)

		local A = DrawingLib.new("Line")
		local B = DrawingLib.new("Line")
		local C = DrawingLib.new("Line")

		local function setAll(k, v) A[k] = v; B[k] = v; C[k] = v end

		return setmetatable({}, {
			__newindex = function(_, key, value)
				if key == "PointA" then A.From = value; C.To = value; proto.PointA = value
				elseif key == "PointB" then B.From = value; A.To = value; proto.PointB = value
				elseif key == "PointC" then C.From = value; B.To = value; proto.PointC = value
				elseif key == "Thickness" or key == "Visible" or key == "Color" or key == "ZIndex" then
					setAll(key, value); proto[key] = value
				elseif key == "Filled" then proto.Filled = value -- not implemented
				else proto[key] = value end
			end,
			__index = function(_, k)
				if k == "Remove" then return function() A:Remove(); B:Remove(); C:Remove() end end
				return proto[k]
			end,
			__tostring = function() return "Drawing" end
		})

	else
		error(("Drawing type '%s' not supported"):format(tostring(drawingType)))
	end
end

getgenv().drawing = DrawingLib
return DrawingLib
