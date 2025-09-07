

local CoreGui = game:GetService("CoreGui")
local Workspace = workspace
local Camera = Workspace.CurrentCamera

-- Root GUI (top-most)
local drawingUI = Instance.new("ScreenGui")
drawingUI.Name = "Drawing"
drawingUI.IgnoreGuiInset = true
drawingUI.DisplayOrder = 0x7fffffff
drawingUI.Parent = CoreGui

-- Utilities
local function clamp(n, a, b) return math.clamp(n, a, b) end
local function convertTransparency(t) return clamp(1 - t, 0, 1) end
local function safeColor3(v) return typeof(v) == "Color3" and v or Color3.new(1, 1, 1) end

-- Font mapping (index -> FontFace)
local Fonts = {
	UI       = 0,
	System   = 1,
	Plex     = 2,
	Monospace= 3
}
local fontsEnum = {
	[0] = Font.fromEnum(Enum.Font.Roboto),
	[1] = Font.fromEnum(Enum.Font.Legacy),
	[2] = Font.fromEnum(Enum.Font.SourceSans),
	[3] = Font.fromEnum(Enum.Font.RobotoMono),
}
local function getFontFromIndex(idx)
	return fontsEnum[clamp(tonumber(idx) or 0, 0, #fontsEnum)]
end

-- Base object defaults and small helpers
local baseDefaults = {
	Visible = true,
	ZIndex = 0,
	Transparency = 0, -- 0..1 where 0 = opaque (we convert)
	Color = Color3.new(1,1,1),
	Remove = function() end,
	Destroy = function() end
}

local drawingIndex = 0

-- Core factory
local Drawing = {}
Drawing.Fonts = Fonts

local function makeBase(tbl)
	local base = {}
	for k,v in pairs(baseDefaults) do base[k] = v end
	for k,v in pairs(tbl or {}) do base[k] = v end
	return base
end

-- Public creation function (lowercase like Synapse: drawing.new)
function Drawing.new(drawingType)
	drawingIndex = drawingIndex + 1
	local t = (typeof(drawingType) == "string" and string.lower(drawingType)) or "unknown"

	if t == "line" then
		local obj = makeBase({ From = Vector2.new(), To = Vector2.new(), Thickness = 1 })
		local frame = Instance.new("Frame")
		frame.Name = tostring(drawingIndex)
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = obj.Color
		frame.BackgroundTransparency = convertTransparency(obj.Transparency)
		frame.ZIndex = obj.ZIndex
		frame.Visible = obj.Visible
		frame.Size = UDim2.new(0, 0, 0, 0)
		frame.Parent = drawingUI

		local function updateFromTo()
			local direction = obj.To - obj.From
			local center = (obj.To + obj.From) / 2
			local distance = direction.Magnitude
			local theta = math.deg(math.atan2(direction.Y, direction.X))
			frame.Position = UDim2.fromOffset(center.X, center.Y)
			frame.Rotation = theta
			frame.Size = UDim2.fromOffset(distance, math.max(1, obj.Thickness))
		end

		updateFromTo()

		local proxy = {}
		return setmetatable(proxy, {
			__newindex = function(_, key, value)
				if obj[key] == nil then return end
				if key == "From" or key == "To" then
					obj[key] = value
					updateFromTo()
				elseif key == "Thickness" then
					obj.Thickness = value
					updateFromTo()
				elseif key == "Visible" then
					obj.Visible = value
					frame.Visible = value
				elseif key == "ZIndex" then
					obj.ZIndex = value
					frame.ZIndex = value
				elseif key == "Transparency" then
					obj.Transparency = value
					frame.BackgroundTransparency = convertTransparency(value)
				elseif key == "Color" then
					obj.Color = safeColor3(value)
					frame.BackgroundColor3 = obj.Color
				end
			end,
			__index = function(_, key)
				if key == "Remove" or key == "Destroy" then
					return function()
						if frame and frame.Parent then frame:Destroy() end
						setmetatable(proxy, nil)
					end
				end
				return obj[key]
			end,
			__tostring = function() return "Drawing" end
		})

	elseif t == "text" then
		local obj = makeBase({
			Text = "",
			Font = Fonts.UI,
			Size = 14,
			Position = Vector2.new(),
			Center = false,
			Outline = false,
			OutlineColor = Color3.new(0,0,0)
		})
		local label = Instance.new("TextLabel")
		local stroke = Instance.new("UIStroke")
		label.Name = tostring(drawingIndex)
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.BorderSizePixel = 0
		label.BackgroundTransparency = 1
		label.Text = obj.Text
		label.FontFace = getFontFromIndex(obj.Font)
		label.TextSize = obj.Size
		label.TextColor3 = obj.Color
		label.TextTransparency = convertTransparency(obj.Transparency)
		label.ZIndex = obj.ZIndex
		label.Visible = obj.Visible

		stroke.Parent = label
		stroke.Thickness = 1
		stroke.Enabled = obj.Outline
		stroke.Color = obj.OutlineColor
		stroke.Transparency = convertTransparency(obj.Transparency)

		label.Parent = drawingUI

		-- auto resize + position update
		label:GetPropertyChangedSignal("TextBounds"):Connect(function()
			local bounds = label.TextBounds
			local offset = bounds / 2
			label.Size = UDim2.fromOffset(bounds.X, bounds.Y)
			if obj.Center then
				label.Position = UDim2.fromOffset(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
			else
				label.Position = UDim2.fromOffset(obj.Position.X + offset.X, obj.Position.Y + offset.Y)
			end
		end)

		local proxy = {}
		return setmetatable(proxy, {
			__newindex = function(_, key, value)
				if obj[key] == nil then return end
				if key == "Text" then
					obj.Text = tostring(value or "")
					label.Text = obj.Text
				elseif key == "Font" then
					obj.Font = clamp(tonumber(value) or 0, 0, 3)
					label.FontFace = getFontFromIndex(obj.Font)
				elseif key == "Size" then
					obj.Size = tonumber(value) or obj.Size
					label.TextSize = obj.Size
				elseif key == "Position" then
					obj.Position = value
					local offset = label.TextBounds / 2
					label.Position = UDim2.fromOffset(obj.Position.X + (obj.Center and 0 or offset.X), obj.Position.Y + offset.Y)
				elseif key == "Center" then
					obj.Center = value and true or false
					if obj.Center then
						label.Position = UDim2.fromOffset(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
					else
						local offset = label.TextBounds / 2
						label.Position = UDim2.fromOffset(obj.Position.X + offset.X, obj.Position.Y + offset.Y)
					end
				elseif key == "Outline" then
					obj.Outline = value and true or false
					stroke.Enabled = obj.Outline
				elseif key == "OutlineColor" then
					obj.OutlineColor = safeColor3(value)
					stroke.Color = obj.OutlineColor
				elseif key == "Visible" then
					obj.Visible = value
					label.Visible = value
				elseif key == "ZIndex" then
					obj.ZIndex = value
					label.ZIndex = value
				elseif key == "Transparency" then
					obj.Transparency = value
					label.TextTransparency = convertTransparency(value)
					stroke.Transparency = convertTransparency(value)
				elseif key == "Color" then
					obj.Color = safeColor3(value)
					label.TextColor3 = obj.Color
				end
			end,
			__index = function(_, key)
				if key == "Remove" or key == "Destroy" then
					return function()
						if label and label.Parent then label:Destroy() end
						setmetatable(proxy, nil)
					end
				elseif key == "TextBounds" then
					return label.TextBounds
				end
				return obj[key]
			end,
			__tostring = function() return "Drawing" end
		})

	elseif t == "circle" then
		local obj = makeBase({
			Radius = 50,
			Position = Vector2.new(),
			Thickness = 1,
			Filled = false
		})
		local frame = Instance.new("Frame")
		local corner = Instance.new("UICorner")
		local stroke = Instance.new("UIStroke")
		frame.Name = tostring(drawingIndex)
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = obj.Color
		frame.BackgroundTransparency = obj.Filled and convertTransparency(obj.Transparency) or 1
		frame.ZIndex = obj.ZIndex
		frame.Visible = obj.Visible
		corner.CornerRadius = UDim.new(1, 0)
		frame.Size = UDim2.fromOffset(obj.Radius*2, obj.Radius*2)

		stroke.Parent = frame
		stroke.Thickness = math.max(0.6, obj.Thickness)
		stroke.Enabled = not obj.Filled
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = obj.Color
		stroke.Transparency = convertTransparency(obj.Transparency)

		corner.Parent = frame
		frame.Parent = drawingUI

		local proxy = {}
		return setmetatable(proxy, {
			__newindex = function(_, key, value)
				if obj[key] == nil then return end
				if key == "Radius" then
					obj.Radius = tonumber(value) or obj.Radius
					local r = obj.Radius * 2
					frame.Size = UDim2.fromOffset(r, r)
				elseif key == "Position" then
					obj.Position = value
					frame.Position = UDim2.fromOffset(obj.Position.X, obj.Position.Y)
				elseif key == "Thickness" then
					obj.Thickness = math.max(0.6, tonumber(value) or obj.Thickness)
					stroke.Thickness = obj.Thickness
				elseif key == "Filled" then
					obj.Filled = value and true or false
					frame.BackgroundTransparency = obj.Filled and convertTransparency(obj.Transparency) or 1
					stroke.Enabled = not obj.Filled
				elseif key == "Visible" then
					obj.Visible = value
					frame.Visible = value
				elseif key == "ZIndex" then
					obj.ZIndex = value
					frame.ZIndex = value
				elseif key == "Transparency" then
					obj.Transparency = value
					local trans = convertTransparency(value)
					frame.BackgroundTransparency = (obj.Filled and trans) or 1
					stroke.Transparency = trans
				elseif key == "Color" then
					obj.Color = safeColor3(value)
					frame.BackgroundColor3 = obj.Color
					stroke.Color = obj.Color
				end
			end,
			__index = function(_, key)
				if key == "Remove" or key == "Destroy" then
					return function()
						if frame and frame.Parent then frame:Destroy() end
						setmetatable(proxy, nil)
					end
				end
				return obj[key]
			end,
			__tostring = function() return "Drawing" end
		})

	elseif t == "square" then
		local obj = makeBase({
			Size = Vector2.new(0,0),
			Position = Vector2.new(),
			Thickness = 1,
			Filled = false
		})
		local frame = Instance.new("Frame")
		local stroke = Instance.new("UIStroke")
		frame.Name = tostring(drawingIndex)
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = obj.Color
		frame.BackgroundTransparency = obj.Filled and convertTransparency(obj.Transparency) or 1
		frame.ZIndex = obj.ZIndex
		frame.Visible = obj.Visible

		stroke.Parent = frame
		stroke.Thickness = math.max(0.6, obj.Thickness)
		stroke.Enabled = not obj.Filled
		stroke.LineJoinMode = Enum.LineJoinMode.Miter
		stroke.Color = obj.Color
		stroke.Transparency = convertTransparency(obj.Transparency)

		frame.Parent = drawingUI

		local proxy = {}
		return setmetatable(proxy, {
			__newindex = function(_, key, value)
				if obj[key] == nil then return end
				if key == "Size" then
					obj.Size = value
					frame.Size = UDim2.fromOffset(obj.Size.X, obj.Size.Y)
				elseif key == "Position" then
					obj.Position = value
					frame.Position = UDim2.fromOffset(obj.Position.X, obj.Position.Y)
				elseif key == "Thickness" then
					obj.Thickness = math.max(0.6, tonumber(value) or obj.Thickness)
					stroke.Thickness = obj.Thickness
				elseif key == "Filled" then
					obj.Filled = value and true or false
					frame.BackgroundTransparency = obj.Filled and convertTransparency(obj.Transparency) or 1
					stroke.Enabled = not obj.Filled
				elseif key == "Visible" then
					obj.Visible = value
					frame.Visible = value
				elseif key == "ZIndex" then
					obj.ZIndex = value
					frame.ZIndex = value
				elseif key == "Transparency" then
					obj.Transparency = value
					local trans = convertTransparency(value)
					frame.BackgroundTransparency = (obj.Filled and trans) or 1
					stroke.Transparency = trans
				elseif key == "Color" then
					obj.Color = safeColor3(value)
					frame.BackgroundColor3 = obj.Color
					stroke.Color = obj.Color
				end
			end,
			__index = function(_, key)
				if key == "Remove" or key == "Destroy" then
					return function()
						if frame and frame.Parent then frame:Destroy() end
						setmetatable(proxy, nil)
					end
				end
				return obj[key]
			end,
			__tostring = function() return "Drawing" end
		})

	elseif t == "image" then
		local obj = makeBase({
			Data = "",
			DataURL = "rbxassetid://0",
			Size = Vector2.new(0,0),
			Position = Vector2.new()
		})
		local img = Instance.new("ImageLabel")
		img.Name = tostring(drawingIndex)
		img.BorderSizePixel = 0
		img.ScaleType = Enum.ScaleType.Stretch
		img.BackgroundTransparency = 1
		img.Image = obj.DataURL
		img.ImageTransparency = convertTransparency(obj.Transparency)
		img.ImageColor3 = obj.Color
		img.ZIndex = obj.ZIndex
		img.Visible = obj.Visible
		img.Parent = drawingUI

		local proxy = {}
		return setmetatable(proxy, {
			__newindex = function(_, key, value)
				if obj[key] == nil then return end
				if key == "Data" then
					-- reserved for future image decoding, currently unused
					obj.Data = value
				elseif key == "DataURL" then
					obj.DataURL = tostring(value)
					img.Image = obj.DataURL
				elseif key == "Size" then
					obj.Size = value
					img.Size = UDim2.fromOffset(obj.Size.X, obj.Size.Y)
				elseif key == "Position" then
					obj.Position = value
					img.Position = UDim2.fromOffset(obj.Position.X, obj.Position.Y)
				elseif key == "Visible" then
					obj.Visible = value
					img.Visible = value
				elseif key == "ZIndex" then
					obj.ZIndex = value
					img.ZIndex = value
				elseif key == "Transparency" then
					obj.Transparency = value
					img.ImageTransparency = convertTransparency(value)
				elseif key == "Color" then
					obj.Color = safeColor3(value)
					img.ImageColor3 = obj.Color
				end
			end,
			__index = function(_, key)
				if key == "Remove" or key == "Destroy" then
					return function()
						if img and img.Parent then img:Destroy() end
						setmetatable(proxy, nil)
					end
				elseif key == "Data" then
					return nil
				end
				return obj[key]
			end,
			__tostring = function() return "Drawing" end
		})

	elseif t == "quad" then
		-- Quad implemented as 4 lines
		local props = makeBase({
			Thickness = 1,
			PointA = Vector2.new(),
			PointB = Vector2.new(),
			PointC = Vector2.new(),
			PointD = Vector2.new(),
			Filled = false
		})
		local A = Drawing.new("line")
		local B = Drawing.new("line")
		local C = Drawing.new("line")
		local D = Drawing.new("line")

		local proxy = {}
		return setmetatable(proxy, {
			__newindex = function(_, key, value)
				if props[key] == nil and not (key == "Color" or key == "ZIndex" or key == "Visible" or key == "Thickness" or key == "Filled") then return end
				if key == "Thickness" then
					props.Thickness = value
					A.Thickness = value; B.Thickness = value; C.Thickness = value; D.Thickness = value
				elseif key == "PointA" then
					props.PointA = value
					A.From = value; D.To = value
				elseif key == "PointB" then
					props.PointB = value
					A.To = value; B.From = value
				elseif key == "PointC" then
					props.PointC = value
					B.To = value; C.From = value
				elseif key == "PointD" then
					props.PointD = value
					C.To = value; D.From = value
				elseif key == "Color" then
					props.Color = safeColor3(value)
					A.Color = props.Color; B.Color = props.Color; C.Color = props.Color; D.Color = props.Color
				elseif key == "ZIndex" then
					props.ZIndex = value
					A.ZIndex = value; B.ZIndex = value; C.ZIndex = value; D.ZIndex = value
				elseif key == "Visible" then
					props.Visible = value
					A.Visible = value; B.Visible = value; C.Visible = value; D.Visible = value
				elseif key == "Filled" then
					props.Filled = value -- not implemented (placeholder)
				end
			end,
			__index = function(_, key)
				if string.lower(tostring(key)) == "remove" or string.lower(tostring(key)) == "destroy" then
					return function()
						pcall(function() A:Remove() end)
						pcall(function() B:Remove() end)
						pcall(function() C:Remove() end)
						pcall(function() D:Remove() end)
						setmetatable(proxy, nil)
					end
				end
				return props[key]
			end,
			__tostring = function() return "Drawing" end
		})

	elseif t == "triangle" then
		local obj = makeBase({
			PointA = Vector2.new(),
			PointB = Vector2.new(),
			PointC = Vector2.new(),
			Thickness = 1,
			Filled = false
		})
		local lA = Drawing.new("line")
		local lB = Drawing.new("line")
		local lC = Drawing.new("line")

		local proxy = {}
		return setmetatable(proxy, {
			__newindex = function(_, key, value)
				if obj[key] == nil and not (key == "Color" or key == "ZIndex" or key == "Visible") then return end
				if key == "PointA" then
					obj.PointA = value
					lA.From = value; lC.To = value
				elseif key == "PointB" then
					obj.PointB = value
					lA.To = value; lB.From = value
				elseif key == "PointC" then
					obj.PointC = value
					lB.To = value; lC.From = value
				elseif key == "Thickness" or key == "Visible" or key == "Color" or key == "ZIndex" then
					obj[key] = value
					lA[key] = value; lB[key] = value; lC[key] = value
				elseif key == "Filled" then
					obj.Filled = value -- placeholder for future implementation
				end
			end,
			__index = function(_, key)
				if key == "Remove" or key == "Destroy" then
					return function()
						pcall(function() lA:Remove() end)
						pcall(function() lB:Remove() end)
						pcall(function() lC:Remove() end)
						setmetatable(proxy, nil)
					end
				end
				return obj[key]
			end,
			__tostring = function() return "Drawing" end
		})

	else
		error(("drawing.new: unsupported type '%s'"):format(t))
	end
end

getgenv().drawing = Drawing

return Drawing
