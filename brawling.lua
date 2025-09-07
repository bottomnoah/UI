local CoreGui = game:GetService("CoreGui")
local Camera = workspace.CurrentCamera

-- Setup ScreenGui
local DrawingUI = Instance.new("ScreenGui")
DrawingUI.Name = "Drawing"
DrawingUI.IgnoreGuiInset = true
DrawingUI.DisplayOrder = 0x7fffffff
DrawingUI.Parent = CoreGui

-- Constants
local Fonts = {
	UI = 0,
	System = 1,
	Plex = 2,
	Monospace = 3
}

local FontMap = {
	[0] = Font.fromEnum(Enum.Font.Roboto),
	[1] = Font.fromEnum(Enum.Font.Legacy),
	[2] = Font.fromEnum(Enum.Font.SourceSans),
	[3] = Font.fromEnum(Enum.Font.RobotoMono)
}

-- Utility Functions
local function clampTransparency(transparency)
	return math.clamp(1 - transparency, 0, 1)
end

local function getFontFromIndex(fontIndex)
	return FontMap[math.clamp(fontIndex, 0, 3)]
end

-- Base Drawing Object
local BaseDrawingObj = {
	Visible = true,
	ZIndex = 0,
	Transparency = 1,
	Color = Color3.new(),
	Remove = function(self)
		setmetatable(self, nil)
	end,
	Destroy = function(self)
		setmetatable(self, nil)
	end
}

-- Drawing Library
local DrawingLib = { Fonts = Fonts }
local drawingIndex = 0

-- Shared metatable creation
local function createDrawingMetatable(obj, instance, updateFn, customProps)
	return setmetatable({}, {
		__newindex = function(_, index, value)
			if typeof(obj[index]) == "nil" then return end
			updateFn(index, value)
			obj[index] = value
		end,
		__index = function(self, index)
			if index == "Remove" or index == "Destroy" then
				return function()
					instance:Destroy()
					obj.Remove(self)
					return obj:Remove()
				end
			end
			return customProps and customProps[index] or obj[index]
		end,
		__tostring = function() return "Drawing" end
	})
end

function DrawingLib.new(drawingType)
	drawingIndex += 1
	
	if drawingType == "Line" then
		local lineObj = {
			From = Vector2.zero,
			To = Vector2.zero,
			Thickness = 1
		} + BaseDrawingObj
		
		local lineFrame = Instance.new("Frame")
		lineFrame.Name = tostring(drawingIndex)
		lineFrame.AnchorPoint = Vector2.one * 0.5
		lineFrame.BorderSizePixel = 0
		lineFrame.BackgroundColor3 = lineObj.Color
		lineFrame.Visible = lineObj.Visible
		lineFrame.ZIndex = lineObj.ZIndex
		lineFrame.BackgroundTransparency = clampTransparency(lineObj.Transparency)
		lineFrame.Size = UDim2.new()
		lineFrame.Parent = DrawingUI

		local function updateLine(index, value)
			if index == "From" or index == "To" then
				local from = (index == "From" and value or lineObj.From)
				local to = (index == "To" and value or lineObj.To)
				local direction = to - from
				local center = (to + from) / 2
				local distance = direction.Magnitude
				local theta = math.deg(math.atan2(direction.Y, direction.X))
				lineFrame.Position = UDim2.fromOffset(center.X, center.Y)
				lineFrame.Rotation = theta
				lineFrame.Size = UDim2.fromOffset(distance, lineObj.Thickness)
			elseif index == "Thickness" then
				lineFrame.Size = UDim2.fromOffset((lineObj.To - lineObj.From).Magnitude, value)
			elseif index == "Visible" then
				lineFrame.Visible = value
			elseif index == "ZIndex" then
				lineFrame.ZIndex = value
			elseif index == "Transparency" then
				lineFrame.BackgroundTransparency = clampTransparency(value)
			elseif index == "Color" then
				lineFrame.BackgroundColor3 = value
			end
		end

		return createDrawingMetatable(lineObj, lineFrame, updateLine)
		
	elseif drawingType == "Text" then
		local textObj = {
			Text = "",
			Font = Fonts.UI,
			Size = 0,
			Position = Vector2.zero,
			Center = false,
			Outline = false,
			OutlineColor = Color3.new()
		} + BaseDrawingObj

		local textLabel = Instance.new("TextLabel")
		local uiStroke = Instance.new("UIStroke")
		textLabel.Name = tostring(drawingIndex)
		textLabel.AnchorPoint = Vector2.one * 0.5
		textLabel.BorderSizePixel = 0
		textLabel.BackgroundTransparency = 1
		textLabel.Visible = textObj.Visible
		textLabel.TextColor3 = textObj.Color
		textLabel.TextTransparency = clampTransparency(textObj.Transparency)
		textLabel.ZIndex = textObj.ZIndex
		textLabel.FontFace = getFontFromIndex(textObj.Font)
		textLabel.TextSize = textObj.Size
		uiStroke.Thickness = 1
		uiStroke.Enabled = textObj.Outline
		uiStroke.Color = textObj.OutlineColor
		textLabel.Parent, uiStroke.Parent = DrawingUI, textLabel

		local function updateTextBounds()
			local textBounds = textLabel.TextBounds
			local offset = textBounds / 2
			textLabel.Size = UDim2.fromOffset(textBounds.X, textBounds.Y)
			textLabel.Position = UDim2.fromOffset(
				textObj.Position.X + (textObj.Center and 0 or offset.X),
				textObj.Position.Y + offset.Y
			)
		end
		textLabel:GetPropertyChangedSignal("TextBounds"):Connect(updateTextBounds)

		local function updateText(index, value)
			if index == "Text" then
				textLabel.Text = value
			elseif index == "Font" then
				textLabel.FontFace = getFontFromIndex(value)
			elseif index == "Size" then
				textLabel.TextSize = value
			elseif index == "Position" then
				local offset = textLabel.TextBounds / 2
				textLabel.Position = UDim2.fromOffset(
					value.X + (textObj.Center and 0 or offset.X),
					value.Y + offset.Y
				)
			elseif index == "Center" then
				local position = value and Camera.ViewportSize / 2 or textObj.Position
				textLabel.Position = UDim2.fromOffset(position.X, position.Y)
			elseif index == "Outline" then
				uiStroke.Enabled = value
			elseif index == "OutlineColor" then
				uiStroke.Color = value
			elseif index == "Visible" then
				textLabel.Visible = value
			elseif index == "ZIndex" then
				textLabel.ZIndex = value
			elseif index == "Transparency" then
				local transparency = clampTransparency(value)
				textLabel.TextTransparency = transparency
				uiStroke.Transparency = transparency
			elseif index == "Color" then
				textLabel.TextColor3 = value
			end
		end

		return createDrawingMetatable(textObj, textLabel, updateText, { TextBounds = textLabel.TextBounds })
		
	elseif drawingType == "Circle" then
		local circleObj = {
			Radius = 150,
			Position = Vector2.zero,
			Thickness = 0.7,
			Filled = false
		} + BaseDrawingObj

		local circleFrame = Instance.new("Frame")
		local uiCorner = Instance.new("UICorner")
		local uiStroke = Instance.new("UIStroke")
		circleFrame.Name = tostring(drawingIndex)
		circleFrame.AnchorPoint = Vector2.one * 0.5
		circleFrame.BorderSizePixel = 0
		circleFrame.BackgroundTransparency = circleObj.Filled and clampTransparency(circleObj.Transparency) or 1
		circleFrame.BackgroundColor3 = circleObj.Color
		circleFrame.Visible = circleObj.Visible
		circleFrame.ZIndex = circleObj.ZIndex
		uiCorner.CornerRadius = UDim.new(1, 0)
		circleFrame.Size = UDim2.fromOffset(circleObj.Radius * 2, circleObj.Radius * 2)
		uiStroke.Thickness = circleObj.Thickness
		uiStroke.Enabled = not circleObj.Filled
		uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		circleFrame.Parent, uiCorner.Parent, uiStroke.Parent = DrawingUI, circleFrame, circleFrame

		local function updateCircle(index, value)
			if index == "Radius" then
				circleFrame.Size = UDim2.fromOffset(value * 2, value * 2)
			elseif index == "Position" then
				circleFrame.Position = UDim2.fromOffset(value.X, value.Y)
			elseif index == "Thickness" then
				uiStroke.Thickness = math.clamp(value, 0.6, 0x7fffffff)
			elseif index == "Filled" then
				circleFrame.BackgroundTransparency = value and clampTransparency(circleObj.Transparency) or 1
				uiStroke.Enabled = not value
			elseif index == "Visible" then
				circleFrame.Visible = value
			elseif index == "ZIndex" then
				circleFrame.ZIndex = value
			elseif index == "Transparency" then
				local transparency = clampTransparency(value)
				circleFrame.BackgroundTransparency = circleObj.Filled and transparency or 1
				uiStroke.Transparency = transparency
			elseif index == "Color" then
				circleFrame.BackgroundColor3 = value
				uiStroke.Color = value
			end
		end

		return createDrawingMetatable(circleObj, circleFrame, updateCircle)
		
	elseif drawingType == "Square" then
		local squareObj = {
			Size = Vector2.zero,
			Position = Vector2.zero,
			Thickness = 0.7,
			Filled = false
		} + BaseDrawingObj

		local squareFrame = Instance.new("Frame")
		local uiStroke = Instance.new("UIStroke")
		squareFrame.Name = tostring(drawingIndex)
		squareFrame.BorderSizePixel = 0
		squareFrame.BackgroundTransparency = squareObj.Filled and clampTransparency(squareObj.Transparency) or 1
		squareFrame.ZIndex = squareObj.ZIndex
		squareFrame.BackgroundColor3 = squareObj.Color
		squareFrame.Visible = squareObj.Visible
		uiStroke.Thickness = squareObj.Thickness
		uiStroke.Enabled = not squareObj.Filled
		uiStroke.LineJoinMode = Enum.LineJoinMode.Miter
		squareFrame.Parent, uiStroke.Parent = DrawingUI, squareFrame

		local function updateSquare(index, value)
			if index == "Size" then
				squareFrame.Size = UDim2.fromOffset(value.X, value.Y)
			elseif index == "Position" then
				squareFrame.Position = UDim2.fromOffset(value.X, value.Y)
			elseif index == "Thickness" then
				uiStroke.Thickness = math.clamp(value, 0.6, 0x7fffffff)
			elseif index == "Filled" then
				squareFrame.BackgroundTransparency = value and clampTransparency(squareObj.Transparency) or 1
				uiStroke.Enabled = not value
			elseif index == "Visible" then
				squareFrame.Visible = value
			elseif index == "ZIndex" then
				squareFrame.ZIndex = value
			elseif index == "Transparency" then
				local transparency = clampTransparency(value)
				squareFrame.BackgroundTransparency = squareObj.Filled and transparency or 1
				uiStroke.Transparency = transparency
			elseif index == "Color" then
				squareFrame.BackgroundColor3 = value
				uiStroke.Color = value
			end
		end

		return createDrawingMetatable(squareObj, squareFrame, updateSquare)
		
	elseif drawingType == "Image" then
		local imageObj = {
			Data = "",
			DataURL = "rbxassetid://0",
			Size = Vector2.zero,
			Position = Vector2.zero
		} + BaseDrawingObj

		local imageFrame = Instance.new("ImageLabel")
		imageFrame.Name = tostring(drawingIndex)
		imageFrame.BorderSizePixel = 0
		imageFrame.ScaleType = Enum.ScaleType.Stretch
		imageFrame.BackgroundTransparency = 1
		imageFrame.Visible = imageObj.Visible
		imageFrame.ZIndex = imageObj.ZIndex
		imageFrame.ImageTransparency = clampTransparency(imageObj.Transparency)
		imageFrame.ImageColor3 = imageObj.Color
		imageFrame.Parent = DrawingUI

		local function updateImage(index, value)
			if index == "DataURL" then
				imageFrame.Image = value
			elseif index == "Size" then
				imageFrame.Size = UDim2.fromOffset(value.X, value.Y)
			elseif index == "Position" then
				imageFrame.Position = UDim2.fromOffset(value.X, value.Y)
			elseif index == "Visible" then
				imageFrame.Visible = value
			elseif index == "ZIndex" then
				imageFrame.ZIndex = value
			elseif index == "Transparency" then
				imageFrame.ImageTransparency = clampTransparency(value)
			elseif index == "Color" then
				imageFrame.ImageColor3 = value
			end
		end

		return createDrawingMetatable(imageObj, imageFrame, updateImage, { Data = nil })
		
	elseif drawingType == "Quad" then
		local quadObj = {
			Thickness = 1,
			PointA = Vector2.zero,
			PointB = Vector2.zero,
			PointC = Vector2.zero,
			PointD = Vector2.zero,
			Filled = false
		} + BaseDrawingObj

		local lines = {
			A = DrawingLib.new("Line"),
			B = DrawingLib.new("Line"),
			C = DrawingLib.new("Line"),
			D = DrawingLib.new("Line")
		}

		local function updateQuad(index, value)
			if index == "Thickness" then
				for _, line in lines do
					line.Thickness = value
				end
			elseif index == "PointA" then
				lines.A.From = value
				lines.B.To = value
			elseif index == "PointB" then
				lines.B.From = value
				lines.C.To = value
			elseif index == "PointC" then
				lines.C.From = value
				lines.D.To = value
			elseif index == "PointD" then
				lines.D.From = value
				lines.A.To = value
			elseif index == "Visible" then
				for _, line in lines do
					line.Visible = value
				end
			elseif index == "Color" then
				for _, line in lines do
					line.Color = value
				end
			elseif index == "ZIndex" then
				for _, line in lines do
					line.ZIndex = value
				end
			end
			-- Filled property to be implemented later
		end

		return createDrawingMetatable(quadObj, DrawingUI, updateQuad, {
			Remove = function()
				for _, line in lines do
					line:Remove()
				end
				quadObj:Remove()
			end,
			Destroy = function()
				for _, line in lines do
					line:Remove()
				end
				quadObj:Remove()
			end
		})
		
	elseif drawingType == "Triangle" then
		local triangleObj = {
			PointA = Vector2.zero,
			PointB = Vector2.zero,
			PointC = Vector2.zero,
			Thickness = 1,
			Filled = false
		} + BaseDrawingObj

		local lines = {
			A = DrawingLib.new("Line"),
			B = DrawingLib.new("Line"),
			C = DrawingLib.new("Line")
		}

		local function updateTriangle(index, value)
			if index == "PointA" then
				lines.A.From = value
				lines.B.To = value
			elseif index == "PointB" then
				lines.B.From = value
				lines.C.To = value
			elseif index == "PointC" then
				lines.C.From = value
				lines.A.To = value
			elseif index == "Thickness" or index == "Visible" or index == "Color" or index == "ZIndex" then
				for _, line in lines do
					line[index] = value
				end
			end
			-- Filled property to be implemented later
		end

		return createDrawingMetatable(triangleObj, DrawingUI, updateTriangle, {
			Remove = function()
				for _, line in lines do
					line:Remove()
				end
				triangleObj:Remove()
			end,
			Destroy = function()
				for _, line in lines do
					line:Remove()
				end
				triangleObj:Remove()
			end
		})
	end
end

getgenv().drawing = DrawingLib
