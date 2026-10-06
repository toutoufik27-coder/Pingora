-- Tiny UI kit: every screen is built from code with these helpers, so no
-- UI needs to be drawn in Studio. Layout direction follows the language
-- (right-to-left for Arabic).

local Locale = require(script.Parent.Parent.Locale)

local Kit = {}

Kit.colors = {
	bg = Color3.fromRGB(255, 248, 235),
	panel = Color3.fromRGB(250, 240, 220),
	header = Color3.fromRGB(120, 170, 90),
	text = Color3.fromRGB(60, 45, 30),
	muted = Color3.fromRGB(130, 115, 95),
	button = Color3.fromRGB(110, 175, 85),
	buttonAlt = Color3.fromRGB(230, 170, 80),
	danger = Color3.fromRGB(215, 95, 80),
	disabled = Color3.fromRGB(190, 180, 165),
	stroke = Color3.fromRGB(150, 120, 80),
	gold = Color3.fromRGB(240, 190, 50),
	kind = Color3.fromRGB(240, 120, 160),
}

Kit.font = Enum.Font.GothamBold
Kit.fontBody = Enum.Font.Gotham

function Kit.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	if props then
		for k, v in props do
			if k ~= "Parent" then
				(inst :: any)[k] = v
			end
		end
	end
	if children then
		for _, c in children do
			c.Parent = inst
		end
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

function Kit.corner(parent: Instance, radius: number?)
	return Kit.new("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = parent })
end

function Kit.stroke(parent: Instance, color: Color3?, thickness: number?)
	return Kit.new("UIStroke", { Color = color or Kit.colors.stroke, Thickness = thickness or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent })
end

function Kit.padding(parent: Instance, px: number)
	return Kit.new("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		Parent = parent,
	})
end

function Kit.list(parent: Instance, horizontal: boolean?, gap: number?): UIListLayout
	return Kit.new("UIListLayout", {
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		HorizontalAlignment = if horizontal and Locale.isRtl() then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, gap or 6),
		Parent = parent,
	})
end

function Kit.label(text: string, props: { [string]: any }?): TextLabel
	local l = Kit.new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = Kit.colors.text,
		Font = Kit.fontBody,
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = if Locale.isRtl() then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 22),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	if props then
		for k, v in props do
			(l :: any)[k] = v
		end
	end
	return l
end

function Kit.button(text: string, onClick: () -> (), props: { [string]: any }?): TextButton
	local b = Kit.new("TextButton", {
		Text = text,
		TextColor3 = Color3.new(1, 1, 1),
		Font = Kit.font,
		TextSize = 16,
		BackgroundColor3 = Kit.colors.button,
		AutoButtonColor = true,
		Size = UDim2.new(0, 120, 0, 36),
		TextWrapped = true,
	})
	Kit.corner(b, 8)
	if props then
		for k, v in props do
			(b :: any)[k] = v
		end
	end
	b:SetAttribute("BaseColor", b.BackgroundColor3)
	b.Activated:Connect(function()
		if b:GetAttribute("Disabled") then
			return
		end
		onClick()
	end)
	return b
end

function Kit.setEnabled(b: TextButton, enabled: boolean)
	b:SetAttribute("Disabled", not enabled)
	b.BackgroundColor3 = if enabled then (b:GetAttribute("BaseColor") or Kit.colors.button) else Kit.colors.disabled
end

-- A coloured swatch with the first letter: stands in for item icons.
function Kit.swatch(color: Color3, letter: string, size: number?): Frame
	local s = size or 36
	local f = Kit.new("Frame", { Size = UDim2.fromOffset(s, s), BackgroundColor3 = color })
	Kit.corner(f, s // 4)
	Kit.new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = letter,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.5,
		Font = Kit.font,
		TextSize = math.floor(s * 0.5),
		Parent = f,
	})
	return f
end

-- A horizontal row: [swatch] [text block] [buttons...]
function Kit.row(height: number?): Frame
	local f = Kit.new("Frame", {
		Size = UDim2.new(1, 0, 0, height or 48),
		BackgroundColor3 = Kit.colors.bg,
	})
	Kit.corner(f, 8)
	Kit.padding(f, 6)
	Kit.list(f, true, 8).VerticalAlignment = Enum.VerticalAlignment.Center
	return f
end

function Kit.progress(fraction: number, color: Color3?, height: number?): Frame
	local bar = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, height or 10), BackgroundColor3 = Color3.fromRGB(220, 205, 180) })
	Kit.corner(bar, 5)
	local fill = Kit.new("Frame", {
		Name = "Fill",
		Size = UDim2.new(math.clamp(fraction, 0, 1), 0, 1, 0),
		BackgroundColor3 = color or Kit.colors.button,
		Parent = bar,
	})
	Kit.corner(fill, 5)
	return bar
end

-- A scrolling list area that grows with its content.
function Kit.scroll(parent: Instance, size: UDim2, position: UDim2?): ScrollingFrame
	local s = Kit.new("ScrollingFrame", {
		Size = size,
		Position = position or UDim2.new(),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = parent,
	})
	Kit.list(s, false, 6)
	Kit.padding(s, 4)
	return s
end

function Kit.clear(container: Instance)
	for _, c in container:GetChildren() do
		if not c:IsA("UIListLayout") and not c:IsA("UIPadding") and not c:IsA("UIGridLayout") then
			c:Destroy()
		end
	end
end

-- A number stepper: [-] value [+]
function Kit.stepper(value: number, min: number, max: number, step: number, onChange: (number) -> ()): (Frame, () -> number)
	local current = value
	local f = Kit.new("Frame", { Size = UDim2.fromOffset(150, 36), BackgroundTransparency = 1 })
	Kit.list(f, true, 4).VerticalAlignment = Enum.VerticalAlignment.Center
	local label
	local function set(v: number)
		current = math.clamp(v, min, max)
		label.Text = tostring(current)
		onChange(current)
	end
	Kit.button("-", function()
		set(current - step)
	end, { Size = UDim2.fromOffset(36, 32), LayoutOrder = 1, Parent = f })
	label = Kit.label(tostring(current), { Size = UDim2.fromOffset(62, 32), TextXAlignment = Enum.TextXAlignment.Center, Font = Kit.font, LayoutOrder = 2, Parent = f })
	Kit.button("+", function()
		set(current + step)
	end, { Size = UDim2.fromOffset(36, 32), LayoutOrder = 3, Parent = f })
	return f, function()
		return current
	end
end

return Kit
