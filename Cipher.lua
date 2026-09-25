local Cipher = {
	Version = "1.0.0",
	Flags = {},        -- flag -> current value
	Options = {},      -- flag -> element object
	Themes = {},
	Windows = {},
	Folder = "Cipher",
	Unloaded = false,
}

--============================================================
-- SERVICES
--============================================================
local cloneref = (typeof(cloneref) == "function" and cloneref) or function(obj) return obj end

local function getService(name)
	return cloneref(game:GetService(name))
end

local Players          = getService("Players")
local TweenService     = getService("TweenService")
local UserInputService = getService("UserInputService")
local RunService       = getService("RunService")
local HttpService      = getService("HttpService")
local CoreGui          = getService("CoreGui")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
	Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
	LocalPlayer = Players.LocalPlayer
end

--============================================================
-- EXECUTOR ENVIRONMENT (everything optional, all guarded)
--============================================================
local function envFunc(fn)
	if typeof(fn) == "function" then return fn end
	return nil
end

local FS = {
	isfile     = envFunc(isfile),
	isfolder   = envFunc(isfolder),
	readfile   = envFunc(readfile),
	writefile  = envFunc(writefile),
	makefolder = envFunc(makefolder),
	listfiles  = envFunc(listfiles),
	delfile    = envFunc(delfile),
}

local gethuiFn        = envFunc(gethui)
local identifyExecFn  = envFunc(identifyexecutor)
local setClipboardFn  = envFunc(setclipboard) or envFunc(toclipboard)

local genv = _G
if typeof(getgenv) == "function" then
	local ok, env = pcall(getgenv)
	if ok and type(env) == "table" then genv = env end
end

--============================================================
-- UTILITIES
--============================================================
local Util = {}

function Util.clamp(n, lo, hi)
	if n < lo then return lo end
	if n > hi then return hi end
	return n
end

function Util.decimals(increment)
	local s = tostring(increment)
	local frac = string.match(s, "%.(%d+)$")
	return frac and #frac or 0
end

function Util.roundTo(value, increment, min)
	min = min or 0
	if not increment or increment <= 0 then return value end
	local steps = math.floor((value - min) / increment + 0.5)
	local result = min + steps * increment
	local d = Util.decimals(increment)
	if d > 0 then
		local m = 10 ^ d
		result = math.floor(result * m + 0.5) / m
	end
	return result
end

function Util.formatNumber(value, increment)
	local d = Util.decimals(increment or 1)
	if d == 0 then
		return tostring(math.floor(value + 0.5))
	end
	return string.format("%." .. d .. "f", value)
end

function Util.toHex(color)
	return string.format("#%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5))
end

function Util.fromHex(hex)
	if typeof(hex) == "Color3" then return hex end
	if type(hex) ~= "string" then return nil end
	hex = string.gsub(hex, "[^%x]", "")
	if #hex == 3 then
		hex = string.sub(hex, 1, 1):rep(2) .. string.sub(hex, 2, 2):rep(2) .. string.sub(hex, 3, 3):rep(2)
	end
	if #hex ~= 6 then return nil end
	local r = tonumber(string.sub(hex, 1, 2), 16)
	local g = tonumber(string.sub(hex, 3, 4), 16)
	local b = tonumber(string.sub(hex, 5, 6), 16)
	if not (r and g and b) then return nil end
	return Color3.fromRGB(r, g, b)
end

function Util.escapeRich(text)
	text = tostring(text)
	text = string.gsub(text, "&", "&amp;")
	text = string.gsub(text, "<", "&lt;")
	text = string.gsub(text, ">", "&gt;")
	return text
end

function Util.stripRich(text)
	return (string.gsub(tostring(text), "<[^>]+>", ""))
end

function Util.randomName()
	local chars = {}
	for i = 1, 16 do
		chars[i] = string.char(math.random(97, 122))
	end
	return table.concat(chars)
end

function Util.copy(t)
	local out = {}
	for k, v in pairs(t) do out[k] = v end
	return out
end

function Util.find(t, value)
	for i, v in ipairs(t) do
		if v == value then return i end
	end
	return nil
end

local KEY_ALIASES = {
	LeftShift = "LShift", RightShift = "RShift",
	LeftControl = "LCtrl", RightControl = "RCtrl",
	LeftAlt = "LAlt", RightAlt = "RAlt",
	MouseButton1 = "MB1", MouseButton2 = "MB2", MouseButton3 = "MB3",
	Backquote = "`", Minus = "-", Equals = "=", Semicolon = ";",
	Quote = "'", Comma = ",", Period = ".", Slash = "/", BackSlash = "\\",
	LeftBracket = "[", RightBracket = "]",
	One = "1", Two = "2", Three = "3", Four = "4", Five = "5",
	Six = "6", Seven = "7", Eight = "8", Nine = "9", Zero = "0",
	PageUp = "PgUp", PageDown = "PgDn", Insert = "Ins", Delete = "Del",
}

function Util.keyName(key)
	if key == nil then return "none" end
	local name = key.Name
	return KEY_ALIASES[name] or name
end

-- Accepts Enum.KeyCode / Enum.UserInputType / "F" / "RightShift" / "MouseButton2"
function Util.parseKey(key)
	if key == nil or key == false or key == "none" or key == "None" or key == "" then return nil end
	if typeof(key) == "EnumItem" then
		if key.EnumType == Enum.KeyCode then
			if key == Enum.KeyCode.Unknown then return nil end
			return key
		end
		if key.EnumType == Enum.UserInputType then return key end
		return nil
	end
	if type(key) == "string" then
		for alias, real in pairs(KEY_ALIASES) do
			if real == key and alias ~= key then key = alias break end
		end
		local ok, kc = pcall(function() return Enum.KeyCode[key] end)
		if ok and kc then return kc end
		local ok2, uit = pcall(function() return Enum.UserInputType[key] end)
		if ok2 and uit then return uit end
		local ok3, kc2 = pcall(function() return Enum.KeyCode[string.upper(key)] end)
		if ok3 and kc2 then return kc2 end
	end
	return nil
end

function Util.splitArgs(str)
	local args = {}
	local i, len = 1, #str
	while i <= len do
		local c = string.sub(str, i, i)
		if c == " " then
			i = i + 1
		elseif c == '"' or c == "'" then
			local close = string.find(str, c, i + 1, true)
			if close then
				table.insert(args, string.sub(str, i + 1, close - 1))
				i = close + 1
			else
				table.insert(args, string.sub(str, i + 1))
				i = len + 1
			end
		else
			local stop = string.find(str, " ", i, true) or (len + 1)
			table.insert(args, string.sub(str, i, stop - 1))
			i = stop + 1
		end
	end
	return args
end

Cipher.Util = Util

--============================================================
-- THEMES
--============================================================
Cipher.Themes.Matrix = {
	Background   = Color3.fromRGB(6, 9, 7),
	Panel        = Color3.fromRGB(10, 14, 11),
	Element      = Color3.fromRGB(14, 20, 16),
	ElementHover = Color3.fromRGB(19, 28, 22),
	Border       = Color3.fromRGB(30, 50, 36),
	Accent       = Color3.fromRGB(0, 255, 110),
	AccentDim    = Color3.fromRGB(0, 140, 62),
	Text         = Color3.fromRGB(205, 255, 215),
	SubText      = Color3.fromRGB(110, 155, 120),
	Muted        = Color3.fromRGB(55, 82, 62),
	Success      = Color3.fromRGB(0, 255, 110),
	Warning      = Color3.fromRGB(255, 200, 50),
	Error        = Color3.fromRGB(255, 70, 95),
	Info         = Color3.fromRGB(90, 200, 255),
}

Cipher.Themes.Amber = {
	Background   = Color3.fromRGB(10, 7, 3),
	Panel        = Color3.fromRGB(15, 11, 5),
	Element      = Color3.fromRGB(21, 15, 8),
	ElementHover = Color3.fromRGB(30, 21, 10),
	Border       = Color3.fromRGB(58, 40, 16),
	Accent       = Color3.fromRGB(255, 176, 0),
	AccentDim    = Color3.fromRGB(160, 105, 0),
	Text         = Color3.fromRGB(255, 226, 170),
	SubText      = Color3.fromRGB(170, 130, 70),
	Muted        = Color3.fromRGB(90, 66, 30),
	Success      = Color3.fromRGB(160, 255, 90),
	Warning      = Color3.fromRGB(255, 176, 0),
	Error        = Color3.fromRGB(255, 80, 60),
	Info         = Color3.fromRGB(255, 210, 120),
}

Cipher.Themes.Cyber = {
	Background   = Color3.fromRGB(5, 7, 14),
	Panel        = Color3.fromRGB(9, 11, 22),
	Element      = Color3.fromRGB(13, 16, 31),
	ElementHover = Color3.fromRGB(19, 23, 44),
	Border       = Color3.fromRGB(34, 40, 78),
	Accent       = Color3.fromRGB(0, 234, 255),
	AccentDim    = Color3.fromRGB(0, 130, 160),
	Text         = Color3.fromRGB(215, 240, 255),
	SubText      = Color3.fromRGB(120, 140, 190),
	Muted        = Color3.fromRGB(60, 70, 115),
	Success      = Color3.fromRGB(0, 255, 170),
	Warning      = Color3.fromRGB(255, 220, 60),
	Error        = Color3.fromRGB(255, 45, 150),
	Info         = Color3.fromRGB(0, 234, 255),
}

Cipher.Themes.Blood = {
	Background   = Color3.fromRGB(10, 5, 6),
	Panel        = Color3.fromRGB(16, 8, 9),
	Element      = Color3.fromRGB(23, 11, 13),
	ElementHover = Color3.fromRGB(33, 15, 18),
	Border       = Color3.fromRGB(64, 24, 30),
	Accent       = Color3.fromRGB(255, 40, 70),
	AccentDim    = Color3.fromRGB(150, 20, 40),
	Text         = Color3.fromRGB(255, 215, 220),
	SubText      = Color3.fromRGB(170, 110, 118),
	Muted        = Color3.fromRGB(95, 45, 52),
	Success      = Color3.fromRGB(120, 255, 140),
	Warning      = Color3.fromRGB(255, 190, 60),
	Error        = Color3.fromRGB(255, 40, 70),
	Info         = Color3.fromRGB(255, 140, 160),
}

Cipher.Themes.Phantom = {
	Background   = Color3.fromRGB(8, 6, 13),
	Panel        = Color3.fromRGB(13, 10, 21),
	Element      = Color3.fromRGB(19, 14, 30),
	ElementHover = Color3.fromRGB(27, 20, 43),
	Border       = Color3.fromRGB(50, 36, 80),
	Accent       = Color3.fromRGB(178, 102, 255),
	AccentDim    = Color3.fromRGB(105, 55, 170),
	Text         = Color3.fromRGB(235, 222, 255),
	SubText      = Color3.fromRGB(145, 125, 180),
	Muted        = Color3.fromRGB(78, 62, 110),
	Success      = Color3.fromRGB(110, 255, 180),
	Warning      = Color3.fromRGB(255, 210, 90),
	Error        = Color3.fromRGB(255, 80, 120),
	Info         = Color3.fromRGB(150, 190, 255),
}

Cipher.Themes.Ghost = {
	Background   = Color3.fromRGB(8, 8, 9),
	Panel        = Color3.fromRGB(13, 13, 15),
	Element      = Color3.fromRGB(19, 19, 22),
	ElementHover = Color3.fromRGB(27, 27, 31),
	Border       = Color3.fromRGB(44, 44, 50),
	Accent       = Color3.fromRGB(235, 235, 240),
	AccentDim    = Color3.fromRGB(130, 130, 140),
	Text         = Color3.fromRGB(230, 230, 235),
	SubText      = Color3.fromRGB(140, 140, 150),
	Muted        = Color3.fromRGB(75, 75, 82),
	Success      = Color3.fromRGB(120, 255, 160),
	Warning      = Color3.fromRGB(255, 210, 90),
	Error        = Color3.fromRGB(255, 90, 100),
	Info         = Color3.fromRGB(140, 200, 255),
}

Cipher.ThemeOrder = { "Matrix", "Amber", "Cyber", "Blood", "Phantom", "Ghost" }
Cipher.Theme = Util.copy(Cipher.Themes.Matrix)
Cipher.ThemeName = "Matrix"

--============================================================
-- INSTANCE HELPERS
--============================================================
local FONT_FAMILY = "rbxasset://fonts/families/RobotoMono.json"
local FontCache = {}

local function getFont(weight)
	weight = weight or "Regular"
	if FontCache[weight] == nil then
		local ok, f = pcall(function()
			return Font.new(FONT_FAMILY, Enum.FontWeight[weight], Enum.FontStyle.Normal)
		end)
		FontCache[weight] = (ok and f) or false
	end
	return FontCache[weight]
end

local function applyFont(obj, weight)
	local f = getFont(weight)
	if f then
		local ok = pcall(function() obj.FontFace = f end)
		if ok then return end
	end
	obj.Font = Enum.Font.Code
end

local ThemeBinds = {}  -- { obj = Instance, props = { Property = "ThemeKey" } }
local ThemeHooks = {}  -- { obj = Instance, fn = function(theme) }

local function bind(obj, props)
	for prop, key in pairs(props) do
		obj[prop] = Cipher.Theme[key]
	end
	table.insert(ThemeBinds, { obj = obj, props = props })
	return obj
end

-- Re-run `fn` whenever the theme changes (for stateful colours). Runs once immediately.
local function onTheme(obj, fn)
	table.insert(ThemeHooks, { obj = obj, fn = fn })
	fn(Cipher.Theme, true)
end

local TEXT_CLASSES = { TextLabel = true, TextButton = true, TextBox = true }

local function New(class, props, children)
	local obj = Instance.new(class)
	props = props or {}
	if obj:IsA("GuiObject") then
		obj.BorderSizePixel = 0
	end
	if TEXT_CLASSES[class] then
		applyFont(obj, props.Weight)
		obj.BackgroundTransparency = 1
		obj.TextSize = 13
		obj.TextColor3 = Cipher.Theme.Text
		obj.Text = ""
		if class == "TextButton" then obj.AutoButtonColor = false end
		if class == "TextBox" then obj.ClearTextOnFocus = false end
	end
	if class == "ImageButton" then obj.AutoButtonColor = false end
	for k, v in pairs(props) do
		if k ~= "Parent" and k ~= "Theme" and k ~= "Weight" then
			obj[k] = v
		end
	end
	if props.Theme then bind(obj, props.Theme) end
	if children then
		for _, child in ipairs(children) do child.Parent = obj end
	end
	if props.Parent then obj.Parent = props.Parent end
	return obj
end

local function Corner(parent, radius)
	return New("UICorner", { CornerRadius = UDim.new(0, radius or 4), Parent = parent })
end

local function Stroke(parent, key, thickness, transparency)
	return New("UIStroke", {
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Theme = { Color = key or "Border" },
		Parent = parent,
	})
end

local function Padding(parent, top, right, bottom, left)
	return New("UIPadding", {
		PaddingTop = UDim.new(0, top or 0),
		PaddingRight = UDim.new(0, right or top or 0),
		PaddingBottom = UDim.new(0, bottom or top or 0),
		PaddingLeft = UDim.new(0, left or right or top or 0),
		Parent = parent,
	})
end

local function List(parent, padding, direction)
	return New("UIListLayout", {
		Padding = UDim.new(0, padding or 0),
		FillDirection = direction or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

local function tween(obj, duration, goal, style, direction)
	if not obj then return nil end
	local info = TweenInfo.new(duration or 0.25, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out)
	local ok, t = pcall(function() return TweenService:Create(obj, info, goal) end)
	if ok and t then
		t:Play()
		return t
	end
	return nil
end

--============================================================
-- CALLBACK SAFETY
--============================================================
local function safeCall(fn, ...)
	if type(fn) ~= "function" then return end
	local args = table.pack(...)
	task.spawn(function()
		local ok, err = pcall(fn, table.unpack(args, 1, args.n))
		if not ok then
			warn("[Cipher] callback error: " .. tostring(err))
			if Cipher._onCallbackError then
				pcall(Cipher._onCallbackError, tostring(err))
			end
		end
	end)
end

--============================================================
-- TYPEWRITER
--============================================================
local TypeTokens = setmetatable({}, { __mode = "k" })

local function typewrite(label, text, charsPerSecond)
	charsPerSecond = charsPerSecond or 60
	local token = {}
	TypeTokens[label] = token
	label.Text = text
	local plain = label.RichText and Util.stripRich(text) or text
	local length = utf8.len(plain) or #plain
	label.MaxVisibleGraphemes = 0
	task.spawn(function()
		local start = os.clock()
		while TypeTokens[label] == token and label.Parent do
			local shown = math.floor((os.clock() - start) * charsPerSecond)
			if shown >= length then break end
			label.MaxVisibleGraphemes = shown
			RunService.Heartbeat:Wait()
		end
		if TypeTokens[label] == token then
			label.MaxVisibleGraphemes = -1
			TypeTokens[label] = nil
		end
	end)
end

--============================================================
-- GUI PARENTING
--============================================================
local function protectGui(gui)
	if type(syn) == "table" and type(syn.protect_gui) == "function" then
		pcall(syn.protect_gui, gui)
	end
	local parented = false
	if gethuiFn then
		parented = pcall(function() gui.Parent = gethuiFn() end) and gui.Parent ~= nil
	end
	if not parented then
		parented = pcall(function() gui.Parent = CoreGui end) and gui.Parent ~= nil
	end
	if not parented then
		gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end
end

local function makeScreenGui(displayOrder)
	local gui = New("ScreenGui", {
		Name = Util.randomName(),
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = displayOrder or 100,
	})
	protectGui(gui)
	return gui
end

--============================================================
-- THEME API
--============================================================
Cipher._themeListeners = {}

function Cipher:SetTheme(theme, instant)
	local data, name
	if type(theme) == "string" then
		data = self.Themes[theme]
		name = theme
	elseif type(theme) == "table" then
		data = theme
		name = theme.Name or "Custom"
	end
	if type(data) ~= "table" then
		warn("[Cipher] unknown theme: " .. tostring(theme))
		return false
	end
	local new = Util.copy(self.Themes.Matrix)
	for k, v in pairs(data) do
		if typeof(v) == "Color3" then new[k] = v end
	end
	self.Theme = new
	self.ThemeName = name

	for i = #ThemeBinds, 1, -1 do
		local b = ThemeBinds[i]
		if b.obj.Parent == nil then
			table.remove(ThemeBinds, i)
		else
			local goal = {}
			for prop, key in pairs(b.props) do goal[prop] = new[key] end
			if instant then
				for prop, value in pairs(goal) do b.obj[prop] = value end
			else
				tween(b.obj, 0.35, goal, Enum.EasingStyle.Quad)
			end
		end
	end
	for i = #ThemeHooks, 1, -1 do
		local h = ThemeHooks[i]
		if h.obj.Parent == nil then
			table.remove(ThemeHooks, i)
		else
			local ok, err = pcall(h.fn, new, instant)
			if not ok then warn("[Cipher] theme hook error: " .. tostring(err)) end
		end
	end
	for _, fn in ipairs(self._themeListeners) do safeCall(fn, name, new) end
	return true
end

function Cipher:SetAccent(color, instant)
	color = Util.fromHex(color)
	if not color then return false end
	local custom = Util.copy(self.Theme)
	custom.Name = self.ThemeName
	custom.Accent = color
	local h, s, v = color:ToHSV()
	custom.AccentDim = Color3.fromHSV(h, s, v * 0.55)
	return self:SetTheme(custom, instant)
end

function Cipher:AddTheme(name, data)
	assert(type(name) == "string", "AddTheme: name must be a string")
	assert(type(data) == "table", "AddTheme: data must be a table")
	self.Themes[name] = data
	if not Util.find(self.ThemeOrder, name) then table.insert(self.ThemeOrder, name) end
	return data
end

function Cipher:OnThemeChanged(fn)
	table.insert(self._themeListeners, fn)
end

--============================================================
-- OVERLAY LAYER (notifications + tooltips)
--============================================================
Cipher._connections = {}

local function track(conn, list)
	table.insert(list or Cipher._connections, conn)
	return conn
end

local Overlay = { Gui = nil, Notifs = nil, Tooltip = nil, TooltipText = nil }

local function getOverlay()
	if Overlay.Gui and Overlay.Gui.Parent then return Overlay end
	Overlay.Gui = makeScreenGui(200)

	Overlay.Notifs = New("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -8),
		Size = UDim2.new(0, 310, 1, -24),
		BackgroundTransparency = 1,
		Parent = Overlay.Gui,
	})
	local layout = List(Overlay.Notifs, 0)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom

	Overlay.Tooltip = New("Frame", {
		Name = "Tooltip",
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		Visible = false,
		ZIndex = 50,
		Theme = { BackgroundColor3 = "Panel" },
		Parent = Overlay.Gui,
	})
	Corner(Overlay.Tooltip, 3)
	Stroke(Overlay.Tooltip, "AccentDim")
	Padding(Overlay.Tooltip, 5, 8, 5, 8)
	Overlay.TooltipText = New("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		TextSize = 12,
		ZIndex = 51,
		TextXAlignment = Enum.TextXAlignment.Left,
		Theme = { TextColor3 = "Text" },
		Parent = Overlay.Tooltip,
	})
	New("UISizeConstraint", { MaxSize = Vector2.new(260, math.huge), Parent = Overlay.TooltipText })
	Overlay.TooltipText.TextWrapped = true

	track(RunService.RenderStepped:Connect(function()
		local tip = Overlay.Tooltip
		if tip and tip.Visible then
			local mouse = UserInputService:GetMouseLocation()
			local cam = workspace.CurrentCamera
			local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
			local size = tip.AbsoluteSize
			local x = math.min(mouse.X + 14, vp.X - size.X - 6)
			local y = math.min(mouse.Y + 18, vp.Y - size.Y - 6)
			tip.Position = UDim2.fromOffset(x, y)
		end
	end))
	return Overlay
end

local Tooltip = { _hoverId = 0 }

function Tooltip.show(text)
	local o = getOverlay()
	o.TooltipText.Text = tostring(text)
	o.Tooltip.Visible = true
end

function Tooltip.hide()
	Tooltip._hoverId = Tooltip._hoverId + 1
	if Overlay.Tooltip then Overlay.Tooltip.Visible = false end
end

-- `getText` may be a string or a function returning a string (or nil to skip)
function Tooltip.attach(obj, getText)
	if getText == nil then return end
	obj.MouseEnter:Connect(function()
		Tooltip._hoverId = Tooltip._hoverId + 1
		local id = Tooltip._hoverId
		task.delay(0.45, function()
			if id ~= Tooltip._hoverId then return end
			local text = getText
			if type(getText) == "function" then text = getText() end
			if text ~= nil and text ~= "" then Tooltip.show(text) end
		end)
	end)
	obj.MouseLeave:Connect(Tooltip.hide)
end

--============================================================
-- NOTIFICATIONS
--============================================================
local NOTIF_TYPES = {
	info    = { Tag = "[*]", Key = "Info" },
	success = { Tag = "[+]", Key = "Success" },
	warning = { Tag = "[!]", Key = "Warning" },
	warn    = { Tag = "[!]", Key = "Warning" },
	error   = { Tag = "[x]", Key = "Error" },
}

local NotifOrder = 0
local ActiveNotifs = {}
local MAX_NOTIFS = 6

function Cipher:Notify(opts)
	if type(opts) == "string" then opts = { Content = opts } end
	opts = opts or {}
	local kind = NOTIF_TYPES[string.lower(tostring(opts.Type or "info"))] or NOTIF_TYPES.info
	local duration = tonumber(opts.Duration) or 5
	local persistent = duration <= 0
	local o = getOverlay()

	NotifOrder = NotifOrder + 1
	local notif = { Dismissed = false }

	local holder = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		LayoutOrder = NotifOrder,
		Parent = o.Notifs,
	})

	local card = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(1, 30, 0, 0),
		Theme = { BackgroundColor3 = "Panel" },
		Parent = holder,
	})
	Corner(card, 4)
	Stroke(card, "Border")

	New("Frame", {
		Size = UDim2.new(0, 2, 1, 0),
		Theme = { BackgroundColor3 = kind.Key },
		Parent = card,
	})

	local body = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = card,
	})
	Padding(body, 9, 12, 11, 14)
	List(body, 4)

	local header = New("Frame", {
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = body,
	})
	New("TextLabel", {
		Size = UDim2.new(0, 26, 1, 0),
		Text = kind.Tag,
		Weight = "Bold",
		TextXAlignment = Enum.TextXAlignment.Left,
		Theme = { TextColor3 = kind.Key },
		Parent = header,
	})
	local titleLabel = New("TextLabel", {
		Position = UDim2.fromOffset(28, 0),
		Size = UDim2.new(1, -92, 1, 0),
		Text = string.upper(tostring(opts.Title or "notification")),
		Weight = "Bold",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Theme = { TextColor3 = "Text" },
		Parent = header,
	})
	New("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 0),
		Size = UDim2.new(0, 44, 1, 0),
		Text = os.date("%H:%M"),
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right,
		Theme = { TextColor3 = "Muted" },
		Parent = header,
	})
	local closeBtn = New("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 14, 1, 0),
		Text = "x",
		TextSize = 13,
		Theme = { TextColor3 = "SubText" },
		Parent = header,
	})

	local content = New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = tostring(opts.Content or ""),
		TextSize = 12,
		TextWrapped = true,
		LineHeight = 1.1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = 2,
		Theme = { TextColor3 = "SubText" },
		Parent = body,
	})

	if type(opts.Actions) == "table" and #opts.Actions > 0 then
		local row = New("Frame", {
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			LayoutOrder = 3,
			Parent = body,
		})
		local rowLayout = List(row, 6, Enum.FillDirection.Horizontal)
		rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		for i, action in ipairs(opts.Actions) do
			local btn = New("TextButton", {
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 1, 0),
				Text = "[ " .. tostring(action.Name or "ok") .. " ]",
				TextSize = 12,
				LayoutOrder = i,
				Theme = { TextColor3 = "Accent" },
				Parent = row,
			})
			Padding(btn, 0, 4, 0, 4)
			btn.MouseEnter:Connect(function() tween(btn, 0.15, { TextColor3 = Cipher.Theme.Text }) end)
			btn.MouseLeave:Connect(function() tween(btn, 0.15, { TextColor3 = Cipher.Theme.Accent }) end)
			btn.MouseButton1Click:Connect(function()
				safeCall(action.Callback)
				notif:Dismiss()
			end)
		end
	end

	local progress = New("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundTransparency = 0.2,
		Visible = not persistent,
		Theme = { BackgroundColor3 = kind.Key },
		Parent = card,
	})

	local hovering = false
	local shown = false
	card.MouseEnter:Connect(function() hovering = true end)
	card.MouseLeave:Connect(function() hovering = false end)
	card:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if shown and not notif.Dismissed then
			holder.Size = UDim2.new(1, 0, 0, card.AbsoluteSize.Y + 8)
		end
	end)

	function notif:Dismiss()
		if self.Dismissed then return end
		self.Dismissed = true
		local idx = Util.find(ActiveNotifs, self)
		if idx then table.remove(ActiveNotifs, idx) end
		tween(card, 0.3, { Position = UDim2.new(1, 30, 0, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		task.delay(0.15, function()
			tween(holder, 0.3, { Size = UDim2.new(1, 0, 0, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
		end)
		task.delay(0.5, function() holder:Destroy() end)
		safeCall(opts.OnDismiss)
	end

	function notif:SetTitle(text)
		titleLabel.Text = string.upper(tostring(text))
	end

	function notif:SetContent(text)
		typewrite(content, tostring(text), 140)
	end

	closeBtn.MouseButton1Click:Connect(function() notif:Dismiss() end)
	closeBtn.MouseEnter:Connect(function() tween(closeBtn, 0.15, { TextColor3 = Cipher.Theme.Error }) end)
	closeBtn.MouseLeave:Connect(function() tween(closeBtn, 0.15, { TextColor3 = Cipher.Theme.SubText }) end)

	table.insert(ActiveNotifs, notif)
	if #ActiveNotifs > MAX_NOTIFS then
		ActiveNotifs[1]:Dismiss()
	end

	task.spawn(function()
		RunService.Heartbeat:Wait()
		if notif.Dismissed then return end
		shown = true
		tween(holder, 0.35, { Size = UDim2.new(1, 0, 0, card.AbsoluteSize.Y + 8) })
		tween(card, 0.5, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Quint)
		typewrite(content, tostring(opts.Content or ""), 140)
		if persistent then return end
		local remaining = duration
		while not notif.Dismissed and remaining > 0 and holder.Parent do
			local dt = RunService.Heartbeat:Wait()
			if not hovering then remaining = remaining - dt end
			progress.Size = UDim2.new(Util.clamp(remaining / duration, 0, 1), 0, 0, 2)
		end
		notif:Dismiss()
	end)

	return notif
end

--============================================================
-- WINDOW
--============================================================
local Window = {}
Window.__index = Window

local TOPBAR_H = 34
local STATUS_H = 22
local SIDEBAR_W = 164
local HEADER_H = 30
local MIN_W, MIN_H = 500, 320

local function passthrough(obj)
	pcall(function() obj.Interactable = false end)
	return obj
end

local function hex(key)
	return Util.toHex(Cipher.Theme[key])
end

local function sizeToVector(size)
	if typeof(size) == "UDim2" then
		return size.X.Offset, size.Y.Offset
	elseif typeof(size) == "Vector2" then
		return size.X, size.Y
	elseif type(size) == "table" then
		return size[1] or size.X, size[2] or size.Y
	end
	return 660, 450
end

function Cipher:CreateWindow(opts)
	opts = opts or {}
	local title = tostring(opts.Title or opts.Name or "CIPHER")
	local W, H = sizeToVector(opts.Size)
	W = math.max(MIN_W, tonumber(W) or 660)
	H = math.max(MIN_H, tonumber(H) or 450)

	-- re-executing a script replaces its old window instead of stacking a duplicate
	genv.__CIPHER_WINDOWS = genv.__CIPHER_WINDOWS or {}
	local previous = genv.__CIPHER_WINDOWS[title]
	if type(previous) == "table" and type(previous.Destroy) == "function" then
		pcall(function() previous:Destroy(true) end)
	end

	if opts.Theme then Cipher:SetTheme(opts.Theme, true) end
	if opts.ConfigFolder then Cipher.Folder = tostring(opts.ConfigFolder) end

	local self = setmetatable({}, Window)
	self.Title = title
	self.Subtitle = tostring(opts.Subtitle or ("v" .. Cipher.Version))
	self.Host = string.lower((string.gsub(title, "[^%w]", "")))
	if self.Host == "" then self.Host = "cipher" end
	self.Tabs = {}
	self.Keybinds = {}
	self.Commands = {}
	self._flags = {}
	self._connections = {}
	self.Width, self.Height = W, H
	self.Visible = true
	self.Minimized = false
	self.Destroyed = false
	self._animId = 0
	self._animating = false
	self._userScale = 1
	if opts.ToggleKey == false then
		self.ToggleKey = nil
	else
		self.ToggleKey = Util.parseKey(opts.ToggleKey) or Enum.KeyCode.RightShift
	end
	self.ConfirmClose = opts.ConfirmClose ~= false

	table.insert(Cipher.Windows, self)
	genv.__CIPHER_WINDOWS[title] = self

	local gui = makeScreenGui(100)
	self.Gui = gui

	------------------------------------------------ holder / glow / main
	local holder = New("Frame", {
		Name = "Holder",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, -math.floor(H / 2)),
		Size = UDim2.fromOffset(W, H),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	self.Holder = holder
	self._openPos = holder.Position
	self.UIScale = New("UIScale", { Parent = holder })

	local glowA = passthrough(New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = holder }))
	Corner(glowA, 6)
	Stroke(glowA, "Accent", 3, 0.88)
	local glowB = passthrough(New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = holder }))
	Corner(glowB, 8)
	Stroke(glowB, "Accent", 9, 0.96)

	local main = New("Frame", {
		Name = "Main",
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
		Theme = { BackgroundColor3 = "Background" },
		Parent = holder,
	})
	Corner(main, 5)
	Stroke(main, "AccentDim", 1, 0.25)
	self.Main = main

	local canvas = New("Frame", {
		Name = "Canvas",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(W, H),
		BackgroundTransparency = 1,
		Parent = main,
	})
	self.Canvas = canvas

	------------------------------------------------ topbar
	local topbar = New("Frame", {
		Name = "Topbar",
		Size = UDim2.new(1, 0, 0, TOPBAR_H),
		ZIndex = 2,
		Theme = { BackgroundColor3 = "Panel" },
		Parent = canvas,
	})
	Corner(topbar, 5)
	New("Frame", { Position = UDim2.new(0, 0, 1, -6), Size = UDim2.new(1, 0, 0, 6), ZIndex = 2, Theme = { BackgroundColor3 = "Panel" }, Parent = topbar })
	New("Frame", { Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), ZIndex = 3, Theme = { BackgroundColor3 = "Border" }, Parent = topbar })
	self.Topbar = topbar

	local titleGroup = New("Frame", {
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -130, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = topbar,
	})
	local titleLayout = List(titleGroup, 8, Enum.FillDirection.Horizontal)
	titleLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	local led = New("Frame", { Size = UDim2.fromOffset(7, 7), ZIndex = 3, LayoutOrder = 1, Theme = { BackgroundColor3 = "Accent" }, Parent = titleGroup })
	Corner(led, 2)
	local ledTween = TweenService:Create(led, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.75 })
	ledTween:Play()

	self.TitleLabel = New("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		Text = title,
		TextSize = 14,
		Weight = "Bold",
		ZIndex = 3,
		LayoutOrder = 2,
		Theme = { TextColor3 = "Accent" },
		Parent = titleGroup,
	})
	self.SubtitleLabel = New("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		Text = "// " .. self.Subtitle,
		TextSize = 12,
		ZIndex = 3,
		LayoutOrder = 3,
		Theme = { TextColor3 = "Muted" },
		Parent = titleGroup,
	})

	local buttons = New("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 0),
		Size = UDim2.new(0, 110, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = topbar,
	})
	local buttonsLayout = List(buttons, 4, Enum.FillDirection.Horizontal)
	buttonsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	buttonsLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	local function topButton(text, order, hoverKey, tip)
		local btn = New("TextButton", {
			Size = UDim2.fromOffset(28, 22),
			Text = text,
			TextSize = 12,
			Weight = "Bold",
			BackgroundTransparency = 1,
			ZIndex = 3,
			LayoutOrder = order,
			Theme = { BackgroundColor3 = "ElementHover" },
			Parent = buttons,
		})
		btn.TextColor3 = Cipher.Theme.SubText
		Corner(btn, 3)
		onTheme(btn, function(t) btn.TextColor3 = t.SubText end)
		btn.MouseEnter:Connect(function()
			tween(btn, 0.15, { BackgroundTransparency = 0, TextColor3 = Cipher.Theme[hoverKey] })
		end)
		btn.MouseLeave:Connect(function()
			tween(btn, 0.2, { BackgroundTransparency = 1, TextColor3 = Cipher.Theme.SubText })
		end)
		Tooltip.attach(btn, tip)
		return btn
	end

	local termBtn = topButton(">_", 1, "Accent", "terminal")
	local minBtn = topButton("-", 2, "Warning", "minimize")
	local closeBtn = topButton("x", 3, "Error", "close")
	self._minBtn = minBtn

	termBtn.MouseButton1Click:Connect(function() self:ToggleTerminal() end)
	minBtn.MouseButton1Click:Connect(function() self:SetMinimized(not self.Minimized) end)
	closeBtn.MouseButton1Click:Connect(function()
		if self.ConfirmClose then
			self:Dialog({
				Title = "terminate session",
				Content = "Close " .. title .. "? All features will be unloaded.",
				Buttons = {
					{ Name = "terminate", Primary = true, Callback = function() self:Destroy() end },
					{ Name = "cancel" },
				},
			})
		else
			self:Destroy()
		end
	end)

	------------------------------------------------ sidebar
	local sidebar = New("Frame", {
		Name = "Sidebar",
		Position = UDim2.fromOffset(0, TOPBAR_H),
		Size = UDim2.new(0, SIDEBAR_W, 1, -(TOPBAR_H + STATUS_H)),
		ZIndex = 2,
		Theme = { BackgroundColor3 = "Panel" },
		Parent = canvas,
	})
	New("Frame", { Position = UDim2.new(1, -1, 0, 0), Size = UDim2.new(0, 1, 1, 0), ZIndex = 3, Theme = { BackgroundColor3 = "Border" }, Parent = sidebar })
	self.Sidebar = sidebar

	local search = New("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 0, 26),
		ZIndex = 3,
		Theme = { BackgroundColor3 = "Background" },
		Parent = sidebar,
	})
	Corner(search, 3)
	local searchStroke = Stroke(search, "Border")
	New("TextLabel", {
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(0, 10, 1, 0),
		Text = "/",
		Weight = "Bold",
		ZIndex = 3,
		Theme = { TextColor3 = "Accent" },
		Parent = search,
	})
	local searchBox = New("TextBox", {
		Position = UDim2.fromOffset(22, 0),
		Size = UDim2.new(1, -28, 1, 0),
		PlaceholderText = "search...",
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClipsDescendants = true,
		ZIndex = 3,
		Theme = { TextColor3 = "Text", PlaceholderColor3 = "Muted" },
		Parent = search,
	})
	self.SearchBox = searchBox
	searchBox.Focused:Connect(function() tween(searchStroke, 0.2, { Color = Cipher.Theme.Accent }) end)
	searchBox.FocusLost:Connect(function() tween(searchStroke, 0.2, { Color = Cipher.Theme.Border }) end)
	searchBox:GetPropertyChangedSignal("Text"):Connect(function() self:_applySearch(searchBox.Text) end)

	New("TextLabel", {
		Position = UDim2.fromOffset(12, 44),
		Size = UDim2.new(1, -24, 0, 16),
		Text = "// MODULES",
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Theme = { TextColor3 = "Muted" },
		Parent = sidebar,
	})

	local tabList = New("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.new(1, -1, 1, -(62 + 52)),
		BackgroundTransparency = 1,
		ScrollBarThickness = 0,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 3,
		Parent = sidebar,
	})
	List(tabList, 2)
	Padding(tabList, 2, 8, 2, 8)
	self.TabList = tabList

	local userBlock = New("Frame", {
		Position = UDim2.new(0, 0, 1, -52),
		Size = UDim2.new(1, -1, 0, 52),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = sidebar,
	})
	New("Frame", { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 0, 1), ZIndex = 3, Theme = { BackgroundColor3 = "Border" }, Parent = userBlock })
	local avatar = New("ImageLabel", {
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(28, 28),
		ZIndex = 3,
		Theme = { BackgroundColor3 = "Element" },
		Parent = userBlock,
	})
	Corner(avatar, 3)
	Stroke(avatar, "Border")
	task.spawn(function()
		local ok, img = pcall(function()
			return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
		end)
		if ok and img and avatar.Parent then avatar.Image = img end
	end)
	New("TextLabel", {
		Position = UDim2.fromOffset(48, 11),
		Size = UDim2.new(1, -56, 0, 15),
		Text = LocalPlayer.DisplayName,
		TextSize = 12,
		Weight = "Bold",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Theme = { TextColor3 = "Text" },
		Parent = userBlock,
	})
	New("TextLabel", {
		Position = UDim2.fromOffset(48, 26),
		Size = UDim2.new(1, -56, 0, 14),
		Text = "@" .. LocalPlayer.Name,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Theme = { TextColor3 = "Muted" },
		Parent = userBlock,
	})

	------------------------------------------------ content
	local content = New("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(SIDEBAR_W, TOPBAR_H),
		Size = UDim2.new(1, -SIDEBAR_W, 1, -(TOPBAR_H + STATUS_H)),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = canvas,
	})
	self.Content = content

	local header = New("Frame", { Size = UDim2.new(1, 0, 0, HEADER_H), BackgroundTransparency = 1, Parent = content })
	local pathGroup = New("Frame", {
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -28, 1, 0),
		BackgroundTransparency = 1,
		Parent = header,
	})
	local pathLayout = List(pathGroup, 5, Enum.FillDirection.Horizontal)
	pathLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	self.PathLabel = New("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		RichText = true,
		TextSize = 12,
		LayoutOrder = 1,
		Parent = pathGroup,
	})
	local cursor = New("Frame", { Size = UDim2.fromOffset(7, 13), LayoutOrder = 2, Theme = { BackgroundColor3 = "Accent" }, Parent = pathGroup })
	self._cursor = cursor
	self.TabDescLabel = New("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 0),
		Size = UDim2.new(0.45, 0, 1, 0),
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Theme = { TextColor3 = "Muted" },
		Parent = header,
	})
	New("Frame", { Position = UDim2.new(0, 14, 1, -1), Size = UDim2.new(1, -28, 0, 1), BackgroundTransparency = 0.4, Theme = { BackgroundColor3 = "Border" }, Parent = header })
	onTheme(self.PathLabel, function() self:_renderPath(false) end)

	local pages = New("Frame", {
		Name = "Pages",
		Position = UDim2.fromOffset(0, HEADER_H),
		Size = UDim2.new(1, 0, 1, -HEADER_H),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = content,
	})
	self.Pages = pages
	self._fade = passthrough(New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 8,
		Theme = { BackgroundColor3 = "Background" },
		Parent = pages,
	}))

	------------------------------------------------ status bar
	local status = New("Frame", {
		Name = "Status",
		Position = UDim2.new(0, 0, 1, -STATUS_H),
		Size = UDim2.new(1, 0, 0, STATUS_H),
		ZIndex = 2,
		Theme = { BackgroundColor3 = "Panel" },
		Parent = canvas,
	})
	Corner(status, 5)
	New("Frame", { Size = UDim2.new(1, 0, 0, 6), ZIndex = 2, Theme = { BackgroundColor3 = "Panel" }, Parent = status })
	New("Frame", { Size = UDim2.new(1, 0, 0, 1), ZIndex = 3, Theme = { BackgroundColor3 = "Border" }, Parent = status })

	local statusLeft = New("Frame", {
		Position = UDim2.fromOffset(5, 0),
		Size = UDim2.new(0.62, 0, 1, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 3,
		Parent = status,
	})
	local statusLayout = List(statusLeft, 8, Enum.FillDirection.Horizontal)
	statusLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	local seg = New("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 0, 14),
		BackgroundTransparency = 0,
		Text = string.upper(self.Host),
		TextSize = 11,
		Weight = "Bold",
		ZIndex = 3,
		LayoutOrder = 1,
		Theme = { BackgroundColor3 = "Accent", TextColor3 = "Background" },
		Parent = statusLeft,
	})
	Corner(seg, 3)
	Padding(seg, 0, 6, 0, 6)
	self.StatusTabs = New("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		RichText = true,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		LayoutOrder = 2,
		Parent = statusLeft,
	})
	onTheme(self.StatusTabs, function() self:_renderStatusTabs() end)
	self.StatusStats = New("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 0),
		Size = UDim2.new(0.4, 0, 1, 0),
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 3,
		Theme = { TextColor3 = "SubText" },
		Parent = status,
	})

	------------------------------------------------ resize grip
	local grip = New("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		Size = UDim2.fromOffset(16, 16),
		BackgroundTransparency = 1,
		ZIndex = 20,
		Parent = canvas,
	})
	for _, p in ipairs({ { 11, 5 }, { 11, 8 }, { 8, 8 }, { 11, 11 }, { 8, 11 }, { 5, 11 } }) do
		New("Frame", { Position = UDim2.fromOffset(p[1] - 1, p[2] - 1), Size = UDim2.fromOffset(2, 2), ZIndex = 20, Theme = { BackgroundColor3 = "Muted" }, Parent = grip })
	end
	self._grip = grip

	------------------------------------------------ CRT sweep
	local sweep = passthrough(New("Frame", {
		Size = UDim2.new(1, 0, 0, 120),
		Position = UDim2.new(0, 0, 0, -120),
		ZIndex = 30,
		Theme = { BackgroundColor3 = "Accent" },
		Parent = canvas,
	}))
	New("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.8, 0.965),
			NumberSequenceKeypoint.new(0.97, 0.93),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = sweep,
	})
	self._sweep = sweep
	self._sweepTween = TweenService:Create(sweep, TweenInfo.new(5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false, 2.5), { Position = UDim2.new(0, 0, 1, 0) })
	self._sweepTween:Play()
	if opts.Scanline == false then self:SetScanline(false) end

	------------------------------------------------ behaviour
	self:_setupDragging()
	self:_setupResizing()
	self:_setupInput()
	self:_setupStatus()
	self:_setupAutoScale()
	self:_setupBlink()
	self:_setupMobile(opts.MobileButton)
	self:_registerBuiltinCommands()
	self:_renderPath(false)
	self:_renderStatusTabs()

	-- open animation + boot sequence
	holder.Size = UDim2.fromOffset(0, 2)
	holder.Visible = false
	task.defer(function()
		if self.Destroyed then return end
		self:_animateOpen()
		if opts.BootSequence ~= false then
			self:_boot(opts.BootLines)
		end
	end)

	return self
end

--============================================================
-- WINDOW BEHAVIOUR
--============================================================
local function isPointer(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

-- Keyboard / gamepad keys come back as KeyCode, mouse buttons as UserInputType
local function inputKey(input)
	if input.KeyCode ~= Enum.KeyCode.Unknown then return input.KeyCode end
	return input.UserInputType
end

function Window:_setupDragging()
	local dragging = false
	local dragStart, startPos

	self.Topbar.InputBegan:Connect(function(input)
		if not isPointer(input) or self._animating then return end
		dragging = true
		dragStart = input.Position
		startPos = self._dragTarget or self.Holder.Position
		local conn
		conn = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
				conn:Disconnect()
			end
		end)
	end)

	track(UserInputService.InputChanged:Connect(function(input)
		if dragging and isMove(input) then
			local delta = input.Position - dragStart
			self._dragTarget = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end), self._connections)

	track(UserInputService.InputEnded:Connect(function(input)
		if isPointer(input) then dragging = false end
	end), self._connections)

	track(RunService.RenderStepped:Connect(function(dt)
		local target = self._dragTarget
		if not target or self._animating then return end
		local current = self.Holder.Position
		local nextPos = current:Lerp(target, math.min(1, dt * 22))
		self.Holder.Position = nextPos
		self._openPos = target
		if not dragging and math.abs(nextPos.X.Offset - target.X.Offset) < 0.5 and math.abs(nextPos.Y.Offset - target.Y.Offset) < 0.5 then
			self.Holder.Position = target
			self._dragTarget = nil
		end
	end), self._connections)
end

function Window:_setupResizing()
	local resizing = false
	local startMouse, startW, startH

	self._grip.InputBegan:Connect(function(input)
		if not isPointer(input) or self.Minimized or self._animating then return end
		resizing = true
		startMouse = input.Position
		startW, startH = self.Width, self.Height
		local conn
		conn = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				resizing = false
				conn:Disconnect()
			end
		end)
	end)

	track(UserInputService.InputChanged:Connect(function(input)
		if resizing and isMove(input) then
			local scale = math.max(self.UIScale.Scale, 0.05)
			local delta = input.Position - startMouse
			self:SetSize(startW + delta.X / scale, startH + delta.Y / scale, true)
		end
	end), self._connections)

	track(UserInputService.InputEnded:Connect(function(input)
		if isPointer(input) then resizing = false end
	end), self._connections)
end

function Window:_setupInput()
	track(UserInputService.InputBegan:Connect(function(input)
		if self.Destroyed then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement then return end
		local key = inputKey(input)

		-- a keybind element is waiting for a new key
		if self._listening then
			local listener = self._listening
			self._listening = nil
			listener:_capture(input, key)
			return
		end

		if UserInputService:GetFocusedTextBox() then return end
		if self.ToggleKey and key == self.ToggleKey then
			self:Toggle()
		end
		for _, kb in ipairs(self.Keybinds) do
			local ok, err = pcall(kb._press, kb, key)
			if not ok then warn("[Cipher] keybind error: " .. tostring(err)) end
		end
	end), self._connections)

	track(UserInputService.InputEnded:Connect(function(input)
		if self.Destroyed then return end
		local key = inputKey(input)
		for _, kb in ipairs(self.Keybinds) do
			pcall(kb._release, kb, key)
		end
	end), self._connections)
end

function Window:_setupStatus()
	local frames, last = 0, os.clock()
	track(RunService.RenderStepped:Connect(function()
		frames = frames + 1
		local now = os.clock()
		if now - last < 0.5 then return end
		local fps = math.floor(frames / (now - last) + 0.5)
		frames, last = 0, now
		local ping = 0
		pcall(function() ping = math.floor(LocalPlayer:GetNetworkPing() * 1000 + 0.5) end)
		self.FPS, self.Ping = fps, ping
		self.StatusStats.Text = string.format("%d fps  |  %d ms  |  %s", fps, ping, os.date("%H:%M:%S"))
	end), self._connections)
end

function Window:_updateScale()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local vp = cam.ViewportSize
	if vp.X < 50 or vp.Y < 50 then return end
	local fit = math.min(1, (vp.X - 24) / self.Width, (vp.Y - 24) / self.Height)
	self.UIScale.Scale = math.max(0.4, fit) * self._userScale
end

function Window:_setupAutoScale()
	local camConn
	local function hook()
		if camConn then camConn:Disconnect() end
		local cam = workspace.CurrentCamera
		if cam then
			camConn = track(cam:GetPropertyChangedSignal("ViewportSize"):Connect(function() self:_updateScale() end), self._connections)
		end
		self:_updateScale()
	end
	track(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hook), self._connections)
	hook()
end

function Window:_setupBlink()
	task.spawn(function()
		local on = true
		while not self.Destroyed do
			on = not on
			local t = on and 0 or 1
			if self._cursor then self._cursor.BackgroundTransparency = t end
			task.wait(0.53)
		end
	end)
end

function Window:_setupMobile(option)
	local want = option
	if want == nil then
		want = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	end
	if not want then return end

	local btn = New("TextButton", {
		Position = UDim2.new(0, 16, 0.3, 0),
		Size = UDim2.fromOffset(46, 46),
		Text = ">_",
		TextSize = 16,
		Weight = "Bold",
		BackgroundTransparency = 0.1,
		ZIndex = 60,
		Theme = { BackgroundColor3 = "Panel", TextColor3 = "Accent" },
		Parent = self.Gui,
	})
	Corner(btn, 6)
	Stroke(btn, "AccentDim", 1, 0.2)
	self.MobileButton = btn

	local dragging, moved = false, false
	local startInput, startPos
	btn.InputBegan:Connect(function(input)
		if not isPointer(input) then return end
		dragging, moved = true, false
		startInput, startPos = input.Position, btn.Position
		local conn
		conn = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
				conn:Disconnect()
				if not moved then self:Toggle() end
			end
		end)
	end)
	track(UserInputService.InputChanged:Connect(function(input)
		if not dragging or not isMove(input) then return end
		local d = input.Position - startInput
		if d.Magnitude > 6 then moved = true end
		if moved then
			btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end), self._connections)
end

--------------------------------------------------------------- rendering helpers
function Window:_renderPath(animate)
	local tab = self.CurrentTab
	local name = tab and string.lower((string.gsub(tab.Name, "%s+", "_"))) or ""
	local text = string.format(
		'<font color="%s">%s@%s</font><font color="%s">:</font><font color="%s">~/%s</font><font color="%s">$</font>',
		hex("Accent"), Util.escapeRich(string.lower(LocalPlayer.Name)), Util.escapeRich(self.Host),
		hex("Muted"), hex("Info"), Util.escapeRich(name), hex("Muted"))
	if animate then
		typewrite(self.PathLabel, text, 110)
	else
		self.PathLabel.Text = text
	end
end

function Window:_renderStatusTabs()
	local parts = {}
	for i, tab in ipairs(self.Tabs) do
		local label = Util.escapeRich(i .. ":" .. string.lower(tab.Name))
		if tab == self.CurrentTab then
			table.insert(parts, string.format('<font color="%s">%s*</font>', hex("Accent"), label))
		else
			table.insert(parts, string.format('<font color="%s">%s</font>', hex("SubText"), label))
		end
	end
	self.StatusTabs.Text = table.concat(parts, "  ")
end

--------------------------------------------------------------- animations
function Window:_animateOpen()
	self._animId = self._animId + 1
	local id = self._animId
	self._animating = true
	local holder, canvas = self.Holder, self.Canvas
	local h = self.Minimized and TOPBAR_H or self.Height
	local half = math.floor(h / 2) - 1
	local pos = self._openPos
	holder.Visible = true
	holder.Size = UDim2.fromOffset(0, 2)
	holder.Position = pos + UDim2.fromOffset(0, half)
	canvas.Position = UDim2.new(0.5, 0, 0, -half)
	tween(holder, 0.22, { Size = UDim2.fromOffset(self.Width, 2) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	task.delay(0.22, function()
		if id ~= self._animId or self.Destroyed then return end
		tween(holder, 0.4, { Size = UDim2.fromOffset(self.Width, h), Position = pos }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		tween(canvas, 0.4, { Position = UDim2.new(0.5, 0, 0, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		task.delay(0.4, function()
			if id == self._animId then self._animating = false end
		end)
	end)
end

function Window:_animateClose(done)
	self._animId = self._animId + 1
	local id = self._animId
	if not self._animating then
		self._openPos = self._dragTarget or self.Holder.Position
	end
	self._dragTarget = nil
	self._animating = true
	local holder, canvas = self.Holder, self.Canvas
	local half = math.max(0, math.floor(holder.Size.Y.Offset / 2) - 1)
	tween(holder, 0.2, { Size = UDim2.fromOffset(self.Width, 2), Position = self._openPos + UDim2.fromOffset(0, half) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	tween(canvas, 0.2, { Position = UDim2.new(0.5, 0, 0, -half) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	task.delay(0.2, function()
		if id ~= self._animId then return end
		tween(holder, 0.16, { Size = UDim2.fromOffset(0, 2) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		task.delay(0.17, function()
			if id ~= self._animId then return end
			holder.Visible = false
			self._animating = false
			if done then done() end
		end)
	end)
end

function Window:_boot(customLines)
	local overlay = New("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 0,
		ZIndex = 40,
		Theme = { BackgroundColor3 = "Background" },
		Parent = self.Canvas,
	})
	Corner(overlay, 5)
	local list = New("Frame", {
		Position = UDim2.fromOffset(22, 20),
		Size = UDim2.new(1, -44, 1, -40),
		BackgroundTransparency = 1,
		ZIndex = 41,
		Parent = overlay,
	})
	List(list, 3)

	local labels = {}
	local function line(text, key)
		if not overlay.Parent then return nil end
		local l = New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 16),
			Text = text,
			RichText = true,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 41,
			LayoutOrder = #labels + 1,
			TextColor3 = Cipher.Theme[key or "SubText"],
			Parent = list,
		})
		table.insert(labels, l)
		return l
	end

	local steps = customLines or {
		"loading kernel modules",
		"mounting /dev/" .. self.Host,
		"spoofing client fingerprint",
		"establishing encrypted tunnel",
		"injecting interface",
	}

	task.spawn(function()
		task.wait(0.6)
		local okTag = '<font color="' .. hex("Accent") .. '">[ OK ]</font> '
		local head = line(Util.escapeRich(self.Title) .. " v" .. Cipher.Version .. " -- secure shell", "Accent")
		if not head then return end
		typewrite(head, head.Text, 140)
		task.wait(0.25)
		for _, text in ipairs(steps) do
			local l = line(okTag .. Util.escapeRich(text))
			if not l then return end
			typewrite(l, l.Text, 200)
			task.wait(0.09 + math.random() * 0.09)
		end
		local bar = line("", "Accent")
		if not bar then return end
		for i = 0, 26 do
			if not bar.Parent then return end
			bar.Text = "[" .. string.rep("#", i) .. string.rep(".", 26 - i) .. "] " .. math.floor(i / 26 * 100 + 0.5) .. "%"
			task.wait(0.016)
		end
		local welcome = line("> access granted. welcome, " .. Util.escapeRich(LocalPlayer.DisplayName), "Text")
		if not welcome then return end
		typewrite(welcome, welcome.Text, 100)
		task.wait(0.7)
		if not overlay.Parent then return end
		tween(overlay, 0.4, { BackgroundTransparency = 1 })
		for _, l in ipairs(labels) do tween(l, 0.3, { TextTransparency = 1 }) end
		task.wait(0.45)
		overlay:Destroy()
	end)
end

--------------------------------------------------------------- public window API
function Window:SetVisible(state)
	state = state and true or false
	if state == self.Visible or self.Destroyed then return end
	self.Visible = state
	Tooltip.hide()
	if state then self:_animateOpen() else self:_animateClose() end
end

function Window:Toggle()
	self:SetVisible(not self.Visible)
end

function Window:SetMinimized(state)
	state = state and true or false
	if state == self.Minimized then return end
	self.Minimized = state
	self._minBtn.Text = state and "+" or "-"
	if not self.Visible then return end
	tween(self.Holder, 0.4, { Size = UDim2.fromOffset(self.Width, state and TOPBAR_H or self.Height) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
end

function Window:SetSize(w, h, fromGrip)
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(4096, 4096)
	w = Util.clamp(math.floor(tonumber(w) or self.Width), MIN_W, math.max(MIN_W, vp.X))
	h = Util.clamp(math.floor(tonumber(h) or self.Height), MIN_H, math.max(MIN_H, vp.Y))
	self.Width, self.Height = w, h
	self.Canvas.Size = UDim2.fromOffset(w, h)
	if not self._animating then
		self.Holder.Size = UDim2.fromOffset(w, self.Minimized and TOPBAR_H or h)
	end
	if not fromGrip then self:_updateScale() end
end

function Window:SetScale(scale)
	self._userScale = Util.clamp(tonumber(scale) or 1, 0.4, 2)
	self:_updateScale()
end

function Window:Center()
	local pos = UDim2.new(0.5, 0, 0.5, -math.floor(self.Height / 2))
	self._openPos = pos
	self._dragTarget = nil
	if not self._animating then self.Holder.Position = pos end
end

function Window:SetTitle(text)
	self.Title = tostring(text)
	self.TitleLabel.Text = self.Title
end

function Window:SetSubtitle(text)
	self.Subtitle = tostring(text)
	self.SubtitleLabel.Text = "// " .. self.Subtitle
end

function Window:SetToggleKey(key)
	self.ToggleKey = Util.parseKey(key)
end

function Window:SetScanline(state)
	self._sweep.Visible = state and true or false
end

function Window:Notify(opts)
	return Cipher:Notify(opts)
end

function Window:OnDestroy(fn)
	self._onDestroy = self._onDestroy or {}
	table.insert(self._onDestroy, fn)
end

function Window:Destroy(instant)
	if self.Destroyed then return end
	self.Destroyed = true
	Tooltip.hide()

	-- release anything that's being held down
	for _, kb in ipairs(self.Keybinds) do
		if kb.Mode == "Hold" and kb.State then pcall(kb._release, kb, kb.Value) end
	end

	local function finish()
		for _, conn in ipairs(self._connections) do pcall(function() conn:Disconnect() end) end
		self._connections = {}
		for flag, element in pairs(self._flags) do
			if Cipher.Options[flag] == element then
				Cipher.Options[flag] = nil
				Cipher.Flags[flag] = nil
			end
		end
		for _, element in ipairs(self._elements or {}) do
			if element._cleanup then pcall(element._cleanup, element) end
		end
		pcall(function() self.Gui:Destroy() end)
		for _, fn in ipairs(self._onDestroy or {}) do safeCall(fn) end
	end

	local idx = Util.find(Cipher.Windows, self)
	if idx then table.remove(Cipher.Windows, idx) end
	if genv.__CIPHER_WINDOWS and genv.__CIPHER_WINDOWS[self.Title] == self then
		genv.__CIPHER_WINDOWS[self.Title] = nil
	end

	if instant or not self.Visible or not self.Holder.Visible then
		finish()
	else
		self:_animateClose(finish)
	end
end

--============================================================
-- TABS / SECTIONS / ELEMENT BASE
--============================================================
local TextService = getService("TextService")

local Tab = {}
Tab.__index = Tab
local Section = {}
Section.__index = Section
local Element = {}
Element.__index = Element

local ROW_H = 34

local function textWidth(text, size)
	local ok, v = pcall(function()
		return TextService:GetTextSize(text, size, Enum.Font.RobotoMono, Vector2.new(10000, 100)).X
	end)
	return ok and v or (#text * size * 0.6)
end

local function newClass()
	local c = setmetatable({}, { __index = Element })
	c.__index = c
	return c
end

--------------------------------------------------------------- tabs
function Window:AddTab(opts)
	if type(opts) == "string" then opts = { Name = opts } end
	opts = opts or {}
	self._elements = self._elements or {}

	local tab = setmetatable({}, Tab)
	tab.Name = tostring(opts.Name or opts.Title or ("tab" .. (#self.Tabs + 1)))
	tab.Description = opts.Description
	tab.Window = self
	tab._window = self
	tab._tab = tab
	tab._order = 0
	tab._elements = {}
	tab._sections = {}
	table.insert(self.Tabs, tab)

	local btn = New("TextButton", {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		ZIndex = 3,
		LayoutOrder = #self.Tabs,
		Theme = { BackgroundColor3 = "Accent" },
		Parent = self.TabList,
	})
	Corner(btn, 3)
	local bar = New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(2, 0),
		ZIndex = 4,
		Theme = { BackgroundColor3 = "Accent" },
		Parent = btn,
	})

	local icon, iconPad = nil, 0
	local prefix = "./"
	if opts.Icon ~= nil then
		local isImage = type(opts.Icon) == "number" or (type(opts.Icon) == "string" and string.find(opts.Icon, "rbxasset", 1, true) ~= nil)
		if isImage then
			local image = type(opts.Icon) == "number" and ("rbxassetid://" .. opts.Icon) or opts.Icon
			icon = New("ImageLabel", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 12, 0.5, 0),
				Size = UDim2.fromOffset(14, 14),
				BackgroundTransparency = 1,
				Image = image,
				ZIndex = 4,
				Parent = btn,
			})
			iconPad = 20
			prefix = ""
		else
			prefix = tostring(opts.Icon) .. " "
		end
	end

	local label = New("TextLabel", {
		Position = UDim2.fromOffset(12 + iconPad, 0),
		Size = UDim2.new(1, -(20 + iconPad), 1, 0),
		Text = prefix .. string.lower(tab.Name),
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 4,
		Parent = btn,
	})

	local hovering = false
	function tab._render(instant)
		local t = Cipher.Theme
		local selected = self.CurrentTab == tab
		local color = selected and t.Accent or (hovering and t.Text or t.SubText)
		local goals = {
			{ btn, { BackgroundTransparency = selected and 0.9 or (hovering and 0.96 or 1) } },
			{ label, { TextColor3 = color, Position = UDim2.fromOffset((selected and 16 or 12) + iconPad, 0) } },
			{ bar, { Size = UDim2.fromOffset(2, selected and 14 or 0) } },
		}
		if icon then table.insert(goals, { icon, { ImageColor3 = color } }) end
		for _, g in ipairs(goals) do
			if instant then
				for k, v in pairs(g[2]) do g[1][k] = v end
			else
				tween(g[1], 0.25, g[2])
			end
		end
	end
	onTheme(btn, function() tab._render(true) end)

	btn.MouseEnter:Connect(function() hovering = true tab._render() end)
	btn.MouseLeave:Connect(function() hovering = false tab._render() end)
	btn.MouseButton1Click:Connect(function() self:SelectTab(tab) end)
	Tooltip.attach(btn, opts.Description)
	tab.Button = btn

	local page = New("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScrollBarThickness = 3,
		ScrollBarImageTransparency = 0.2,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = false,
		Theme = { ScrollBarImageColor3 = "AccentDim" },
		Parent = self.Pages,
	})
	Padding(page, 10, 14, 14, 14)
	tab._layout = List(page, 8)
	tab.Page = page
	tab._container = page

	self:_renderStatusTabs()
	if not self.CurrentTab then self:SelectTab(tab) end
	return tab
end
Window.CreateTab = Window.AddTab

function Window:GetTab(nameOrIndex)
	if type(nameOrIndex) == "number" then return self.Tabs[nameOrIndex] end
	local wanted = string.lower(tostring(nameOrIndex))
	for _, tab in ipairs(self.Tabs) do
		if string.lower(tab.Name) == wanted then return tab end
	end
	return nil
end

function Window:SelectTab(tab)
	if type(tab) ~= "table" then tab = self:GetTab(tab) end
	if not tab or tab == self.CurrentTab or tab._window ~= self then return end
	local old = self.CurrentTab
	self.CurrentTab = tab
	if old then
		old.Page.Visible = false
		old._render()
	end
	tab.Page.Visible = true
	tab.Page.Position = UDim2.fromOffset(0, 16)
	tween(tab.Page, 0.45, { Position = UDim2.fromOffset(0, 0) })
	self._fade.BackgroundTransparency = 0
	tween(self._fade, 0.35, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
	tab._render()
	self:_renderPath(true)
	self.TabDescLabel.Text = tab.Description and ("# " .. tostring(tab.Description)) or ""
	self:_renderStatusTabs()
	self:_applySearch(self.SearchBox.Text)
end

function Window:_applySearch(query)
	local tab = self.CurrentTab
	if not tab then return end
	query = string.lower(query or "")
	local searching = query ~= ""
	for _, el in ipairs(tab._elements) do
		local match = not searching
		if searching then
			match = string.find(string.lower(el._searchText or ""), query, 1, true) ~= nil
			if not match and el._section then
				match = string.find(string.lower(el._section.Name), query, 1, true) ~= nil
			end
		end
		el._searchHidden = not match
		el:_updateVisibility()
	end
	for _, sec in ipairs(tab._sections) do
		sec._searching = searching
		sec:_updateVisibility()
	end
end

function Tab:_nextOrder()
	self._order = self._order + 1
	return self._order
end

function Tab:Select()
	self._window:SelectTab(self)
end

--------------------------------------------------------------- sections
function Tab:AddSection(opts)
	if type(opts) == "string" then opts = { Name = opts } end
	opts = opts or {}
	local window = self._window

	local sec = setmetatable({}, Section)
	sec.Name = tostring(opts.Name or opts.Title or "section")
	sec._window = window
	sec._tab = self
	sec._section = sec
	sec._order = 0
	sec._elements = {}
	sec._visible = true
	sec.Collapsed = false
	table.insert(self._sections, sec)

	local frame = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = self:_nextOrder(),
		Theme = { BackgroundColor3 = "Panel" },
		Parent = self.Page,
	})
	Corner(frame, 4)
	Stroke(frame, "Border")
	Padding(frame, 8, 8, 8, 8)
	List(frame, 6)
	sec.Frame = frame

	local header = New("TextButton", {
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		LayoutOrder = 0,
		Parent = frame,
	})
	local titleText = "// " .. string.upper(sec.Name)
	local tw = textWidth(titleText, 12)
	sec._titleLabel = New("TextLabel", {
		Position = UDim2.fromOffset(4, 0),
		Size = UDim2.new(0, tw + 4, 1, 0),
		Text = titleText,
		TextSize = 12,
		Weight = "Bold",
		TextXAlignment = Enum.TextXAlignment.Left,
		Theme = { TextColor3 = "Accent" },
		Parent = header,
	})
	sec._line = New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, tw + 16, 0.5, 0),
		Size = UDim2.new(1, -(tw + 16 + 34), 0, 1),
		BackgroundTransparency = 0.3,
		Theme = { BackgroundColor3 = "Border" },
		Parent = header,
	})
	local indicator = New("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -2, 0, 0),
		Size = UDim2.new(0, 26, 1, 0),
		Text = "[-]",
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right,
		Theme = { TextColor3 = "Muted" },
		Parent = header,
	})
	sec._indicator = indicator
	header.MouseEnter:Connect(function() tween(indicator, 0.15, { TextColor3 = Cipher.Theme.Accent }) end)
	header.MouseLeave:Connect(function() tween(indicator, 0.2, { TextColor3 = Cipher.Theme.Muted }) end)
	header.MouseButton1Click:Connect(function() sec:SetCollapsed(not sec.Collapsed) end)

	local content = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		LayoutOrder = 1,
		Parent = frame,
	})
	sec._layout = List(content, 6)
	sec._container = content

	if opts.Collapsed then sec:SetCollapsed(true, true) end
	return sec
end
Tab.CreateSection = Tab.AddSection

function Section:_nextOrder()
	self._order = self._order + 1
	return self._order
end

function Section:SetCollapsed(state, instant)
	state = state and true or false
	if state == self.Collapsed then return end
	self.Collapsed = state
	self._animId = (self._animId or 0) + 1
	local id = self._animId
	local content = self._container
	local scale = math.max(self._window.UIScale.Scale, 0.01)
	self._indicator.Text = state and "[+]" or "[-]"

	if state then
		content.AutomaticSize = Enum.AutomaticSize.None
		content.Size = UDim2.new(1, 0, 0, content.AbsoluteSize.Y / scale)
		if instant then
			content.Size = UDim2.new(1, 0, 0, 0)
			content.Visible = false
			return
		end
		tween(content, 0.3, { Size = UDim2.new(1, 0, 0, 0) })
		task.delay(0.3, function()
			if id == self._animId then content.Visible = false end
		end)
	else
		content.Visible = true
		content.AutomaticSize = Enum.AutomaticSize.None
		local full = self._layout.AbsoluteContentSize.Y / scale
		local function settle()
			if id ~= self._animId then return end
			content.AutomaticSize = Enum.AutomaticSize.Y
			content.Size = UDim2.new(1, 0, 0, 0)
		end
		if instant then settle() return end
		tween(content, 0.3, { Size = UDim2.new(1, 0, 0, full) })
		task.delay(0.3, settle)
	end
end

function Section:Toggle()
	self:SetCollapsed(not self.Collapsed)
end

function Section:SetTitle(text)
	self.Name = tostring(text)
	local titleText = "// " .. string.upper(self.Name)
	local tw = textWidth(titleText, 12)
	self._titleLabel.Text = titleText
	self._titleLabel.Size = UDim2.new(0, tw + 4, 1, 0)
	self._line.Position = UDim2.new(0, tw + 16, 0.5, 0)
	self._line.Size = UDim2.new(1, -(tw + 16 + 34), 0, 1)
end

function Section:SetVisible(state)
	self._visible = state and true or false
	self:_updateVisibility()
end

function Section:_updateVisibility()
	local show = self._visible
	if show and self._searching then
		show = false
		for _, el in ipairs(self._elements) do
			if el.Frame and el.Frame.Visible then show = true break end
		end
	end
	self.Frame.Visible = show
end

function Section:Destroy()
	for i = #self._elements, 1, -1 do
		self._elements[i]:Destroy()
	end
	local idx = Util.find(self._tab._sections, self)
	if idx then table.remove(self._tab._sections, idx) end
	self.Frame:Destroy()
end

--------------------------------------------------------------- element base
local function createRow(owner, opts, height, rightWidth, asButton)
	local desc = opts.Description
	local headerH = height or ROW_H
	if desc then headerH = headerH + 14 end
	local row = New(asButton and "TextButton" or "Frame", {
		Size = UDim2.new(1, 0, 0, headerH),
		LayoutOrder = owner:_nextOrder(),
		Theme = { BackgroundColor3 = "Element" },
		Parent = owner._container,
	})
	Corner(row, 4)
	local stroke = Stroke(row, "Border")
	local rw = rightWidth or 0
	local title = New("TextLabel", {
		Position = UDim2.fromOffset(12, desc and 7 or 0),
		Size = desc and UDim2.new(1, -(24 + rw), 0, 16) or UDim2.new(1, -(24 + rw), 0, headerH),
		Text = tostring(opts.Name or opts.Title or "element"),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Theme = { TextColor3 = "Text" },
		Parent = row,
	})
	local descLabel
	if desc then
		descLabel = New("TextLabel", {
			Position = UDim2.fromOffset(12, 24),
			Size = UDim2.new(1, -(24 + rw), 0, 14),
			Text = tostring(desc),
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Theme = { TextColor3 = "SubText" },
			Parent = row,
		})
	end
	return row, title, descLabel, stroke, headerH
end

local function hoverRow(row, stroke)
	row.MouseEnter:Connect(function()
		tween(row, 0.18, { BackgroundColor3 = Cipher.Theme.ElementHover })
		tween(stroke, 0.18, { Color = Cipher.Theme.AccentDim })
	end)
	row.MouseLeave:Connect(function()
		tween(row, 0.25, { BackgroundColor3 = Cipher.Theme.Element })
		tween(stroke, 0.25, { Color = Cipher.Theme.Border })
	end)
end

local function register(owner, el, opts)
	local window = owner._window
	window._elements = window._elements or {}
	el._owner = owner
	el._window = window
	el._tab = owner._tab
	el._section = owner._section
	el._listeners = {}
	el._visible = true
	el.Name = tostring(opts.Name or opts.Title or el.Name or el.Type)
	el._searchText = el._searchText or el.Name
	el.Callback = opts.Callback
	table.insert(owner._tab._elements, el)
	table.insert(window._elements, el)
	if el._section then table.insert(el._section._elements, el) end

	if opts.Flag ~= nil then
		local flag = tostring(opts.Flag)
		el.Flag = flag
		if Cipher.Options[flag] and Cipher.Options[flag] ~= el then
			warn("[Cipher] duplicate flag '" .. flag .. "' -- the newest element wins")
		end
		Cipher.Options[flag] = el
		Cipher.Flags[flag] = el.Value
		window._flags[flag] = el
	end
	if opts.Tooltip then Tooltip.attach(el.Frame, opts.Tooltip) end
	if opts.Locked then el:Lock(type(opts.Locked) == "string" and opts.Locked or nil) end
	if opts.Visible == false then el:SetVisible(false) end
	if window.SearchBox and window.SearchBox.Text ~= "" and window.CurrentTab == el._tab then
		window:_applySearch(window.SearchBox.Text)
	end
	return el
end

function Element:_fire(value)
	if self.Flag then Cipher.Flags[self.Flag] = value end
	safeCall(self.Callback, value)
	for _, fn in ipairs(self._listeners or {}) do safeCall(fn, value) end
end

function Element:OnChanged(fn)
	self._listeners = self._listeners or {}
	table.insert(self._listeners, fn)
	return self
end

function Element:_updateVisibility()
	if self.Frame then
		self.Frame.Visible = self._visible and not self._searchHidden
	end
end

function Element:SetVisible(state)
	self._visible = state and true or false
	self:_updateVisibility()
	if self._section then self._section:_updateVisibility() end
end

function Element:SetTitle(text)
	self.Name = tostring(text)
	self._searchText = self.Name
	if self._titleLabel then self._titleLabel.Text = self.Name end
end
Element.SetName = Element.SetTitle

function Element:SetDescription(text)
	if self._descLabel then self._descLabel.Text = tostring(text) end
end

function Element:Lock(reason)
	self.Locked = true
	if self.Close then pcall(self.Close, self) end
	local text = "[ LOCKED ]" .. (reason and ("  " .. tostring(reason)) or "")
	if self._lock then
		self._lockLabel.Text = text
		return
	end
	local overlay = New("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 15,
		Theme = { BackgroundColor3 = "Background" },
		Parent = self.Frame,
	})
	Corner(overlay, 4)
	local label = New("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextSize = 12,
		Weight = "Bold",
		TextTransparency = 1,
		ZIndex = 16,
		Theme = { TextColor3 = "Warning" },
		Parent = overlay,
	})
	self._lock, self._lockLabel = overlay, label
	tween(overlay, 0.25, { BackgroundTransparency = 0.2 })
	tween(label, 0.25, { TextTransparency = 0 })
end

function Element:Unlock()
	self.Locked = false
	local overlay, label = self._lock, self._lockLabel
	self._lock, self._lockLabel = nil, nil
	if overlay then
		tween(overlay, 0.2, { BackgroundTransparency = 1 })
		tween(label, 0.2, { TextTransparency = 1 })
		task.delay(0.22, function() overlay:Destroy() end)
	end
end

function Element:Destroy()
	if self._destroyed then return end
	self._destroyed = true
	if self._cleanup then pcall(self._cleanup, self) end
	local function remove(list)
		if not list then return end
		local i = Util.find(list, self)
		if i then table.remove(list, i) end
	end
	remove(self._tab and self._tab._elements)
	remove(self._section and self._section._elements)
	remove(self._window and self._window._elements)
	remove(self._window and self._window.Keybinds)
	if self.Flag and Cipher.Options[self.Flag] == self then
		Cipher.Options[self.Flag] = nil
		Cipher.Flags[self.Flag] = nil
	end
	if self.Frame then self.Frame:Destroy() end
end

local ElementTypes = {}

local function defineElement(name, builder)
	ElementTypes[name] = builder
	local fn = function(owner, opts)
		if type(opts) ~= "table" then opts = { Name = opts } end
		return builder(owner, opts)
	end
	Tab["Add" .. name] = fn
	Tab["Create" .. name] = fn
	Section["Add" .. name] = fn
	Section["Create" .. name] = fn
end

--============================================================
-- BUTTON
--============================================================
local Button = newClass()

defineElement("Button", function(owner, opts)
	local row, title, desc, stroke = createRow(owner, opts, ROW_H, 76, true)
	local el = setmetatable({ Type = "Button", Frame = row, _titleLabel = title, _descLabel = desc }, Button)

	local chevron = New("TextLabel", {
		Position = UDim2.fromOffset(12, title.Position.Y.Offset),
		Size = UDim2.new(0, 12, 0, title.Size.Y.Offset),
		Text = ">",
		Weight = "Bold",
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Theme = { TextColor3 = "AccentDim" },
		Parent = row,
	})
	title.Position = title.Position + UDim2.fromOffset(14, 0)
	title.Size = title.Size - UDim2.fromOffset(14, 0)
	if desc then
		desc.Position = desc.Position + UDim2.fromOffset(14, 0)
		desc.Size = desc.Size - UDim2.fromOffset(14, 0)
	end

	local hint = New("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(72, 16),
		Text = "[ run ]",
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	})
	local flash = passthrough(New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Theme = { BackgroundColor3 = "Accent" },
		Parent = row,
	}))
	Corner(flash, 4)

	local hovering, confirming = false, false
	local confirmId = 0
	local function renderHint()
		local t = Cipher.Theme
		if confirming then
			hint.Text = "confirm?"
			tween(hint, 0.15, { TextColor3 = t.Warning })
		else
			hint.Text = "[ run ]"
			tween(hint, 0.15, { TextColor3 = hovering and t.Accent or t.Muted })
		end
	end
	onTheme(hint, function(t)
		hint.TextColor3 = confirming and t.Warning or (hovering and t.Accent or t.Muted)
	end)

	hoverRow(row, stroke)
	row.MouseEnter:Connect(function()
		hovering = true
		renderHint()
		tween(chevron, 0.2, { TextColor3 = Cipher.Theme.Accent, Position = UDim2.fromOffset(15, chevron.Position.Y.Offset) })
	end)
	row.MouseLeave:Connect(function()
		hovering = false
		renderHint()
		tween(chevron, 0.25, { TextColor3 = Cipher.Theme.AccentDim, Position = UDim2.fromOffset(12, chevron.Position.Y.Offset) })
	end)

	function el:Fire()
		flash.BackgroundTransparency = 0.78
		tween(flash, 0.45, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
		safeCall(self.Callback)
		for _, fn in ipairs(self._listeners or {}) do safeCall(fn) end
	end

	row.MouseButton1Click:Connect(function()
		if el.Locked then return end
		if opts.Confirm and not confirming then
			confirming = true
			confirmId = confirmId + 1
			local id = confirmId
			renderHint()
			task.delay(2.5, function()
				if id == confirmId and confirming then
					confirming = false
					renderHint()
				end
			end)
			return
		end
		confirming = false
		renderHint()
		el:Fire()
	end)

	return register(owner, el, opts)
end)

--============================================================
-- TOGGLE
--============================================================
local Toggle = newClass()

defineElement("Toggle", function(owner, opts)
	local row, title, desc, stroke = createRow(owner, opts, ROW_H, 96, true)
	local el = setmetatable({ Type = "Toggle", Frame = row, _titleLabel = title, _descLabel = desc }, Toggle)
	el.Value = (opts.Default == true) or (opts.Value == true) or (opts.CurrentValue == true)

	local switch = New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(34, 18),
		Parent = row,
	})
	Corner(switch, 4)
	local switchStroke = New("UIStroke", { Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = switch })
	local knob = New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(12, 12),
		Parent = switch,
	})
	Corner(knob, 3)
	local stateLabel = New("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -54, 0.5, 0),
		Size = UDim2.fromOffset(40, 16),
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	})

	function el:_render(instant)
		local t = Cipher.Theme
		local on = self.Value
		local goals = {
			{ switch, { BackgroundColor3 = on and t.Accent or t.Background, BackgroundTransparency = on and 0.8 or 0 } },
			{ switchStroke, { Color = on and t.Accent or t.Border } },
			{ knob, { Position = on and UDim2.new(1, -15, 0.5, 0) or UDim2.new(0, 3, 0.5, 0), BackgroundColor3 = on and t.Accent or t.Muted } },
			{ stateLabel, { TextColor3 = on and t.Accent or t.Muted } },
		}
		stateLabel.Text = on and "true" or "false"
		for _, g in ipairs(goals) do
			if instant then
				for k, v in pairs(g[2]) do g[1][k] = v end
			else
				tween(g[1], 0.3, g[2])
			end
		end
	end
	onTheme(switch, function(_, instant) el:_render(instant) end)

	function el:Set(value, silent)
		value = value and true or false
		if value == self.Value then return end
		self.Value = value
		self:_render()
		if silent then
			if self.Flag then Cipher.Flags[self.Flag] = value end
		else
			self:_fire(value)
		end
	end

	function el:Toggle()
		self:Set(not self.Value)
	end

	function el:_serialize() return self.Value end
	function el:_deserialize(v) self:Set(v == true) end

	hoverRow(row, stroke)
	row.MouseButton1Click:Connect(function()
		if el.Locked then return end
		el:Toggle()
	end)

	return register(owner, el, opts)
end)

--============================================================
-- SLIDER
--============================================================
local Slider = newClass()

defineElement("Slider", function(owner, opts)
	local range = type(opts.Range) == "table" and opts.Range or {}
	local min = tonumber(opts.Min or range[1]) or 0
	local max = tonumber(opts.Max or range[2]) or 100
	if max < min then min, max = max, min end
	if max == min then max = min + 1 end
	local inc = tonumber(opts.Increment or opts.Step or opts.Rounding) or 1
	if inc <= 0 then inc = 1 end

	local row, title, desc, stroke, headerH = createRow(owner, opts, 30, 96, false)
	row.Size = UDim2.new(1, 0, 0, headerH + 16)

	local el = setmetatable({
		Type = "Slider", Frame = row, _titleLabel = title, _descLabel = desc,
		Min = min, Max = max, Increment = inc, Suffix = opts.Suffix and tostring(opts.Suffix) or "",
	}, Slider)
	local default = tonumber(opts.Default or opts.Value or opts.CurrentValue) or min
	el.Value = Util.clamp(Util.roundTo(default, inc, min), min, max)

	local valueBox = New("TextBox", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 7),
		Size = UDim2.fromOffset(90, 16),
		TextSize = 12,
		Weight = "Medium",
		TextXAlignment = Enum.TextXAlignment.Right,
		ClipsDescendants = true,
		Theme = { TextColor3 = "Accent" },
		Parent = row,
	})

	local bar = New("Frame", {
		Position = UDim2.new(0, 12, 0, headerH + 2),
		Size = UDim2.new(1, -24, 0, 4),
		Theme = { BackgroundColor3 = "Background" },
		Parent = row,
	})
	Corner(bar, 2)
	Stroke(bar, "Border")
	local fill = New("Frame", { Size = UDim2.new(0, 0, 1, 0), Theme = { BackgroundColor3 = "Accent" }, Parent = bar })
	Corner(fill, 2)
	local knob = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(10, 10),
		ZIndex = 2,
		Theme = { BackgroundColor3 = "Accent" },
		Parent = bar,
	})
	Corner(knob, 3)
	Stroke(knob, "Accent", 3, 0.8)

	local hit = New("TextButton", {
		Position = UDim2.new(0, 4, 0, headerH - 8),
		Size = UDim2.new(1, -8, 0, 22),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = row,
	})

	function el:_render(instant)
		local alpha = (self.Value - self.Min) / (self.Max - self.Min)
		if instant then
			fill.Size = UDim2.new(alpha, 0, 1, 0)
			knob.Position = UDim2.new(alpha, 0, 0.5, 0)
		else
			tween(fill, 0.12, { Size = UDim2.new(alpha, 0, 1, 0) }, Enum.EasingStyle.Quad)
			tween(knob, 0.12, { Position = UDim2.new(alpha, 0, 0.5, 0) }, Enum.EasingStyle.Quad)
		end
		if not valueBox:IsFocused() then
			valueBox.Text = Util.formatNumber(self.Value, self.Increment) .. self.Suffix
		end
	end

	function el:Set(value, silent)
		value = tonumber(value)
		if not value then return end
		value = Util.clamp(Util.roundTo(value, self.Increment, self.Min), self.Min, self.Max)
		local changed = value ~= self.Value
		self.Value = value
		self:_render()
		if not changed then return end
		if silent then
			if self.Flag then Cipher.Flags[self.Flag] = value end
		else
			self:_fire(value)
		end
	end

	function el:SetRange(newMin, newMax)
		newMin, newMax = tonumber(newMin) or self.Min, tonumber(newMax) or self.Max
		if newMax < newMin then newMin, newMax = newMax, newMin end
		if newMax == newMin then newMax = newMin + 1 end
		self.Min, self.Max = newMin, newMax
		self:Set(Util.clamp(self.Value, newMin, newMax))
		self:_render()
	end
	function el:SetMin(v) self:SetRange(v, self.Max) end
	function el:SetMax(v) self:SetRange(self.Min, v) end
	function el:SetIncrement(v)
		v = tonumber(v)
		if v and v > 0 then
			self.Increment = v
			self:Set(self.Value)
			self:_render()
		end
	end
	function el:SetSuffix(s)
		self.Suffix = s and tostring(s) or ""
		self:_render()
	end

	function el:_serialize() return self.Value end
	function el:_deserialize(v) self:Set(tonumber(v)) end

	local dragging = false
	local function setFromX(x)
		local width = bar.AbsoluteSize.X
		if width <= 0 then return end
		local alpha = Util.clamp((x - bar.AbsolutePosition.X) / width, 0, 1)
		el:Set(el.Min + alpha * (el.Max - el.Min))
	end
	local function stopDrag()
		if not dragging then return end
		dragging = false
		tween(knob, 0.2, { Size = UDim2.fromOffset(10, 10) })
	end

	hit.InputBegan:Connect(function(input)
		if not isPointer(input) or el.Locked then return end
		dragging = true
		tween(knob, 0.15, { Size = UDim2.fromOffset(14, 14) })
		setFromX(input.Position.X)
		local conn
		conn = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				conn:Disconnect()
				stopDrag()
			end
		end)
	end)
	local window = owner._window
	track(UserInputService.InputChanged:Connect(function(input)
		if dragging and isMove(input) then setFromX(input.Position.X) end
	end), window._connections)
	track(UserInputService.InputEnded:Connect(function(input)
		if isPointer(input) then stopDrag() end
	end), window._connections)

	valueBox.Focused:Connect(function()
		valueBox.Text = Util.formatNumber(el.Value, el.Increment)
	end)
	valueBox.FocusLost:Connect(function()
		local n = tonumber(string.match(valueBox.Text, "%-?%d*%.?%d+"))
		if n and not el.Locked then el:Set(n) end
		valueBox.Text = Util.formatNumber(el.Value, el.Increment) .. el.Suffix
	end)

	hoverRow(row, stroke)
	el:_render(true)
	return register(owner, el, opts)
end)

--============================================================
-- DROPDOWN
--============================================================
local Dropdown = newClass()
local OPTION_H = 24

defineElement("Dropdown", function(owner, opts)
	local multi = opts.Multi == true or opts.MultipleOptions == true
	local maxVisible = math.max(1, math.floor(tonumber(opts.MaxVisible) or 6))
	local row, title, desc, stroke, headerH = createRow(owner, opts, ROW_H, 0, false)
	row.ClipsDescendants = true
	title.Size = UDim2.new(0.5, -12, 0, title.Size.Y.Offset)
	if desc then desc.Size = UDim2.new(0.5, -12, 0, desc.Size.Y.Offset) end

	local el = setmetatable({
		Type = "Dropdown", Frame = row, _titleLabel = title, _descLabel = desc,
		Multi = multi, Options = {}, Opened = false,
	}, Dropdown)
	el.Value = multi and {} or nil

	local headerBtn = New("TextButton", {
		Size = UDim2.new(1, 0, 0, headerH),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = row,
	})
	local valueLabel = New("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -30, 0, 0),
		Size = UDim2.new(0.5, -30, 0, headerH),
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Theme = { TextColor3 = "SubText" },
		Parent = row,
	})
	local arrow = New("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0, math.floor(headerH / 2)),
		Size = UDim2.fromOffset(12, 12),
		Text = "v",
		TextSize = 12,
		Weight = "Bold",
		Theme = { TextColor3 = "AccentDim" },
		Parent = row,
	})

	local area = New("Frame", {
		Position = UDim2.fromOffset(8, headerH),
		Size = UDim2.new(1, -16, 0, 400),
		BackgroundTransparency = 1,
		Parent = row,
	})

	local searchFrame = New("Frame", {
		Size = UDim2.new(1, 0, 0, 24),
		Visible = false,
		Theme = { BackgroundColor3 = "Background" },
		Parent = area,
	})
	Corner(searchFrame, 3)
	local searchStroke = Stroke(searchFrame, "Border")
	New("TextLabel", {
		Position = UDim2.fromOffset(7, 0),
		Size = UDim2.new(0, 10, 1, 0),
		Text = "/",
		Weight = "Bold",
		TextSize = 12,
		Theme = { TextColor3 = "Accent" },
		Parent = searchFrame,
	})
	local searchBox = New("TextBox", {
		Position = UDim2.fromOffset(20, 0),
		Size = UDim2.new(1, -26, 1, 0),
		PlaceholderText = "filter...",
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClipsDescendants = true,
		Theme = { TextColor3 = "Text", PlaceholderColor3 = "Muted" },
		Parent = searchFrame,
	})

	local listFrame = New("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		ScrollBarThickness = 2,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Theme = { ScrollBarImageColor3 = "AccentDim" },
		Parent = area,
	})
	List(listFrame, 2)
	local emptyLabel = New("TextLabel", {
		Size = UDim2.new(1, 0, 0, OPTION_H),
		Text = "-- no results --",
		TextSize = 12,
		Visible = false,
		LayoutOrder = 100000,
		Theme = { TextColor3 = "Muted" },
		Parent = listFrame,
	})

	local buttons = {} -- option -> { btn, label, hover }

	local function isSelected(opt)
		if multi then return Util.find(el.Value, opt) ~= nil end
		return el.Value == opt
	end

	local function searchShown()
		if opts.Search == true then return true end
		return opts.Search ~= false and #el.Options > maxVisible
	end

	local function renderOption(opt, instant)
		local b = buttons[opt]
		if not b then return end
		local t = Cipher.Theme
		local sel = isSelected(opt)
		if multi then
			b.label.Text = (sel and "[x] " or "[ ] ") .. tostring(opt)
		else
			b.label.Text = (sel and "> " or "  ") .. tostring(opt)
		end
		local g1 = { BackgroundTransparency = sel and 0.88 or (b.hover and 0.94 or 1) }
		local g2 = { TextColor3 = sel and t.Accent or (b.hover and t.Text or t.SubText) }
		if instant then
			b.btn.BackgroundTransparency = g1.BackgroundTransparency
			b.label.TextColor3 = g2.TextColor3
		else
			tween(b.btn, 0.18, g1)
			tween(b.label, 0.18, g2)
		end
	end

	local function valueText()
		if multi then
			if #el.Value == 0 then return "none" end
			local names = {}
			for i, v in ipairs(el.Value) do names[i] = tostring(v) end
			return table.concat(names, ", ")
		end
		return el.Value ~= nil and tostring(el.Value) or "none"
	end

	local function renderAll(instant)
		valueLabel.Text = valueText()
		for opt in pairs(buttons) do renderOption(opt, instant) end
	end
	onTheme(valueLabel, function(_, instant) renderAll(instant) end)

	local function resize(instant)
		local showSearch = searchShown()
		searchFrame.Visible = showSearch
		local searchH = showSearch and 28 or 0
		local visible = 0
		for _, opt in ipairs(el.Options) do
			local b = buttons[opt]
			if b and b.btn.Visible then visible = visible + 1 end
		end
		emptyLabel.Visible = visible == 0
		local shown = math.min(math.max(visible, 1), maxVisible)
		local listH = shown * (OPTION_H + 2) - 2
		listFrame.Position = UDim2.fromOffset(0, searchH)
		listFrame.Size = UDim2.new(1, 0, 0, listH)
		local h = el.Opened and (headerH + searchH + listH + 8) or headerH
		if instant then
			row.Size = UDim2.new(1, 0, 0, h)
		else
			tween(row, 0.3, { Size = UDim2.new(1, 0, 0, h) })
		end
	end

	local function applyFilter()
		local q = string.lower(searchBox.Text)
		for opt, b in pairs(buttons) do
			b.btn.Visible = q == "" or string.find(string.lower(tostring(opt)), q, 1, true) ~= nil
		end
		resize()
	end
	searchBox:GetPropertyChangedSignal("Text"):Connect(applyFilter)
	searchBox.Focused:Connect(function() tween(searchStroke, 0.2, { Color = Cipher.Theme.Accent }) end)
	searchBox.FocusLost:Connect(function() tween(searchStroke, 0.2, { Color = Cipher.Theme.Border }) end)

	local function sameValue(a, b)
		if multi then
			if #a ~= #b then return false end
			for i = 1, #a do if a[i] ~= b[i] then return false end end
			return true
		end
		return a == b
	end

	function el:Set(value, silent)
		local old = self.Value
		if multi then
			local wanted = {}
			if type(value) == "table" then
				for _, v in ipairs(value) do wanted[tostring(v)] = true end
			elseif value ~= nil then
				wanted[tostring(value)] = true
			end
			local list = {}
			for _, opt in ipairs(self.Options) do
				if wanted[tostring(opt)] then table.insert(list, opt) end
			end
			self.Value = list
		else
			if type(value) == "table" then value = value[1] end
			local match = nil
			if value ~= nil then
				for _, opt in ipairs(self.Options) do
					if opt == value or tostring(opt) == tostring(value) then match = opt break end
				end
			end
			self.Value = match
		end
		renderAll()
		if sameValue(old or (multi and {} or nil), self.Value) then return end
		local out = self.Value
		if multi then out = Util.copy(self.Value) end
		if silent then
			if self.Flag then Cipher.Flags[self.Flag] = out end
		else
			self:_fire(out)
		end
	end

	local function buildOption(opt, order)
		local btn = New("TextButton", {
			Size = UDim2.new(1, -4, 0, OPTION_H),
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Theme = { BackgroundColor3 = "Accent" },
			Parent = listFrame,
		})
		Corner(btn, 3)
		local label = New("TextLabel", {
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(1, -16, 1, 0),
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = btn,
		})
		local b = { btn = btn, label = label, hover = false }
		buttons[opt] = b
		btn.MouseEnter:Connect(function() b.hover = true renderOption(opt) end)
		btn.MouseLeave:Connect(function() b.hover = false renderOption(opt) end)
		btn.MouseButton1Click:Connect(function()
			if el.Locked then return end
			if multi then
				local list = Util.copy(el.Value)
				local i = Util.find(list, opt)
				if i then table.remove(list, i) else table.insert(list, opt) end
				el:Set(list)
			else
				if el.Value == opt and opts.AllowNone then
					el:Set(nil)
				else
					el:Set(opt)
				end
				el:Close()
			end
		end)
		renderOption(opt, true)
	end

	function el:Refresh(newOptions, keepValue)
		local clean, seen = {}, {}
		for _, opt in ipairs(type(newOptions) == "table" and newOptions or {}) do
			local key = tostring(opt)
			if not seen[key] then
				seen[key] = true
				table.insert(clean, opt)
			end
		end
		for _, b in pairs(buttons) do b.btn:Destroy() end
		buttons = {}
		self.Options = clean
		for i, opt in ipairs(clean) do buildOption(opt, i) end
		applyFilter()
		if keepValue == false then
			self:Set(multi and {} or nil)
		else
			self:Set(self.Value)
		end
		renderAll(true)
		resize(true)
	end
	el.SetOptions = el.Refresh

	function el:Add(opt)
		local list = Util.copy(self.Options)
		table.insert(list, opt)
		self:Refresh(list)
	end

	function el:Remove(opt)
		local list = Util.copy(self.Options)
		local i = Util.find(list, opt)
		if i then
			table.remove(list, i)
			self:Refresh(list)
		end
	end

	function el:Clear()
		self:Set(multi and {} or nil)
	end

	function el:Open()
		if self.Opened or self.Locked then return end
		self.Opened = true
		tween(arrow, 0.3, { Rotation = 180, TextColor3 = Cipher.Theme.Accent })
		resize()
	end

	function el:Close()
		if not self.Opened then return end
		self.Opened = false
		tween(arrow, 0.3, { Rotation = 0, TextColor3 = Cipher.Theme.AccentDim })
		resize()
	end

	function el:_serialize()
		if multi then return Util.copy(self.Value) end
		return self.Value
	end
	function el:_deserialize(v) self:Set(v) end

	headerBtn.MouseButton1Click:Connect(function()
		if el.Opened then el:Close() else el:Open() end
	end)
	hoverRow(row, stroke)

	-- live player list
	local options = opts.Options or opts.Values or {}
	local playerList = opts.PlayerList == true or options == "Players"
	if playerList then
		local function names()
			local list = {}
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr ~= LocalPlayer or opts.IncludeSelf then table.insert(list, plr.Name) end
			end
			table.sort(list, function(a, b) return string.lower(a) < string.lower(b) end)
			return list
		end
		options = names()
		local window = owner._window
		track(Players.PlayerAdded:Connect(function() el:Refresh(names()) end), window._connections)
		track(Players.PlayerRemoving:Connect(function(plr)
			task.defer(function()
				local list = names()
				local i = Util.find(list, plr.Name)
				if i then table.remove(list, i) end
				el:Refresh(list)
			end)
		end), window._connections)
	end

	el:Refresh(options)
	local default = opts.Default
	if default == nil then default = opts.Value end
	if default == nil then default = opts.CurrentOption end
	if default ~= nil then el:Set(default, true) end
	renderAll(true)
	resize(true)
	return register(owner, el, opts)
end)

--============================================================
-- INPUT / TEXTBOX
--============================================================
local Input = newClass()

local function buildInput(owner, opts)
	local width = Util.clamp(tonumber(opts.Width) or 170, 60, 320)
	local row, title, desc, stroke = createRow(owner, opts, ROW_H, width + 4, false)
	local el = setmetatable({ Type = "Input", Frame = row, _titleLabel = title, _descLabel = desc, Numeric = opts.Numeric == true }, Input)
	local finished = opts.Finished ~= false

	local box = New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(width, 22),
		Theme = { BackgroundColor3 = "Background" },
		Parent = row,
	})
	Corner(box, 3)
	local boxStroke = Stroke(box, "Border")
	New("TextLabel", {
		Position = UDim2.fromOffset(7, 0),
		Size = UDim2.new(0, 10, 1, 0),
		Text = ">",
		Weight = "Bold",
		TextSize = 12,
		Theme = { TextColor3 = "Accent" },
		Parent = box,
	})
	local textBox = New("TextBox", {
		Position = UDim2.fromOffset(20, 0),
		Size = UDim2.new(1, -26, 1, 0),
		PlaceholderText = tostring(opts.Placeholder or opts.PlaceholderText or "..."),
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClipsDescendants = true,
		ClearTextOnFocus = opts.ClearOnFocus == true,
		Theme = { TextColor3 = "Text", PlaceholderColor3 = "Muted" },
		Parent = box,
	})
	el.TextBox = textBox

	local function convert(text)
		if el.Numeric then return tonumber(text) end
		return text
	end

	local function sanitize(text)
		text = tostring(text or "")
		if el.Numeric then
			local negative = string.sub(text, 1, 1) == "-"
			text = string.gsub(text, "[^%d%.]", "")
			local first = string.find(text, ".", 1, true)
			if first then
				text = string.sub(text, 1, first) .. string.gsub(string.sub(text, first + 1), "%.", "")
			end
			if negative then text = "-" .. text end
		end
		local maxLen = tonumber(opts.MaxLength)
		if maxLen and #text > maxLen then text = string.sub(text, 1, maxLen) end
		return text
	end

	local defaultText = sanitize(opts.Default or opts.Value or "")
	textBox.Text = defaultText
	el.Value = convert(defaultText)

	function el:Set(text, silent)
		text = sanitize(text)
		if textBox.Text ~= text then textBox.Text = text end
		self.Value = convert(text)
		if silent then
			if self.Flag then Cipher.Flags[self.Flag] = self.Value end
		else
			self:_fire(self.Value)
		end
	end

	function el:_serialize() return textBox.Text end
	function el:_deserialize(v) self:Set(v) end

	textBox:GetPropertyChangedSignal("Text"):Connect(function()
		local clean = sanitize(textBox.Text)
		if clean ~= textBox.Text then
			textBox.Text = clean
			return
		end
		if not finished and textBox:IsFocused() then
			el:Set(clean)
		end
	end)
	textBox.Focused:Connect(function()
		tween(boxStroke, 0.2, { Color = Cipher.Theme.Accent })
	end)
	textBox.FocusLost:Connect(function(enterPressed)
		tween(boxStroke, 0.2, { Color = Cipher.Theme.Border })
		if el.Locked then return end
		if finished then
			el:Set(textBox.Text)
		end
		if opts.ClearOnEnter and enterPressed then
			textBox.Text = ""
		end
		if enterPressed and opts.OnEnter then safeCall(opts.OnEnter, el.Value) end
	end)

	hoverRow(row, stroke)
	return register(owner, el, opts)
end

defineElement("Input", buildInput)
defineElement("Textbox", buildInput)
defineElement("TextBox", buildInput)

--============================================================
-- KEYBIND
--============================================================
local Keybind = newClass()

local function normalizeMode(mode)
	mode = string.lower(tostring(mode or "toggle"))
	if mode == "hold" then return "Hold" end
	if mode == "press" or mode == "always" or mode == "tap" then return "Press" end
	return "Toggle"
end

defineElement("Keybind", function(owner, opts)
	local window = owner._window
	local row, title, desc, stroke = createRow(owner, opts, ROW_H, 110, true)
	local el = setmetatable({
		Type = "Keybind", Frame = row, _titleLabel = title, _descLabel = desc,
		Mode = normalizeMode(opts.Mode), State = false, Listening = false,
	}, Keybind)
	el.Value = Util.parseKey(opts.Default or opts.Value or opts.CurrentKeybind)

	local holder = New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(140, 20),
		BackgroundTransparency = 1,
		Parent = row,
	})
	local layout = List(holder, 8, Enum.FillDirection.Horizontal)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Center

	local dot = New("Frame", { Size = UDim2.fromOffset(6, 6), LayoutOrder = 1, Parent = holder })
	Corner(dot, 2)
	local badge = New("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20),
		BackgroundTransparency = 0,
		TextSize = 12,
		Weight = "Medium",
		LayoutOrder = 2,
		Theme = { BackgroundColor3 = "Background" },
		Parent = holder,
	})
	Corner(badge, 3)
	Padding(badge, 0, 8, 0, 8)
	New("UISizeConstraint", { MinSize = Vector2.new(36, 20), Parent = badge })
	local badgeStroke = New("UIStroke", { Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = badge })

	function el:_render(instant)
		local t = Cipher.Theme
		badge.Text = self.Listening and "..." or Util.keyName(self.Value)
		dot.Visible = self.Mode ~= "Press"
		local goals = {
			{ badge, { TextColor3 = self.Listening and t.Warning or (self.Value and t.Accent or t.Muted) } },
			{ badgeStroke, { Color = self.Listening and t.Accent or t.Border } },
			{ dot, { BackgroundColor3 = self.State and t.Accent or t.Muted } },
		}
		for _, g in ipairs(goals) do
			if instant then
				for k, v in pairs(g[2]) do g[1][k] = v end
			else
				tween(g[1], 0.2, g[2])
			end
		end
		if window._refreshKeybindList then window:_refreshKeybindList() end
	end
	onTheme(badge, function(_, instant) el:_render(instant) end)

	local function fireState(state)
		safeCall(el.Callback, state)
		for _, fn in ipairs(el._listeners or {}) do safeCall(fn, state) end
	end

	function el:Set(key, silent)
		self.Value = Util.parseKey(key)
		if self.Flag then Cipher.Flags[self.Flag] = self.Value end
		self:_render()
		if not silent then safeCall(opts.ChangedCallback, self.Value) end
	end

	function el:SetMode(mode)
		self.Mode = normalizeMode(mode)
		self.State = false
		self:_render()
	end

	function el:SetState(state)
		state = state and true or false
		if state == self.State then return end
		self.State = state
		self:_render()
		fireState(state)
	end

	function el:GetState()
		return self.State
	end

	function el:_press(key)
		if self.Value == nil or key ~= self.Value or self.Locked then return end
		if self.Mode == "Toggle" then
			self.State = not self.State
			self:_render()
			fireState(self.State)
		elseif self.Mode == "Hold" then
			self.State = true
			self:_render()
			fireState(true)
		else
			fireState(true)
		end
	end

	function el:_release(key)
		if self.Mode == "Hold" and self.State and key == self.Value then
			self.State = false
			self:_render()
			fireState(false)
		end
	end

	function el:_capture(input, key)
		self.Listening = false
		local uit = input.UserInputType
		if key == Enum.KeyCode.Escape then
			-- cancelled
		elseif key == Enum.KeyCode.Backspace or key == Enum.KeyCode.Delete then
			self:Set(nil)
		elseif uit == Enum.UserInputType.Keyboard or uit == Enum.UserInputType.MouseButton2
			or uit == Enum.UserInputType.MouseButton3 or string.find(uit.Name, "Gamepad", 1, true) then
			self:Set(key)
		end
		self:_render()
	end

	function el:_serialize()
		return self.Value and self.Value.Name or "none"
	end
	function el:_deserialize(v) self:Set(v) end

	function el:_cleanup()
		if window._listening == self then window._listening = nil end
	end

	row.MouseButton1Click:Connect(function()
		if el.Locked then return end
		if window._listening and window._listening ~= el then
			local other = window._listening
			other.Listening = false
			other:_render()
		end
		el.Listening = true
		window._listening = el
		el:_render()
	end)
	row.MouseButton2Click:Connect(function()
		if el.Locked then return end
		el:Set(nil)
	end)

	hoverRow(row, stroke)
	table.insert(window.Keybinds, el)
	el:_render(true)
	return register(owner, el, opts)
end)

--============================================================
-- COLOR PICKER
--============================================================
local ColorPicker = newClass()
local PICK_SIZE = 110

local function rainbowSequence()
	local keys = {}
	for i = 0, 6 do
		table.insert(keys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV((i / 6) % 1, 1, 1)))
	end
	keys[7] = ColorSequenceKeypoint.new(1, Color3.fromHSV(0, 1, 1))
	return ColorSequence.new(keys)
end

defineElement("ColorPicker", function(owner, opts)
	local window = owner._window
	local row, title, desc, stroke, headerH = createRow(owner, opts, ROW_H, 130, false)
	row.ClipsDescendants = true
	local el = setmetatable({
		Type = "ColorPicker", Frame = row, _titleLabel = title, _descLabel = desc,
		Opened = false, Rainbow = false,
	}, ColorPicker)
	local defaultColor = Util.fromHex(opts.Default or opts.Value or opts.Color) or Color3.fromRGB(0, 255, 110)
	el.Value = defaultColor
	local hue, sat, val = defaultColor:ToHSV()

	local headerBtn = New("TextButton", { Size = UDim2.new(1, 0, 0, headerH), BackgroundTransparency = 1, ZIndex = 2, Parent = row })
	local swatch = New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0, math.floor(headerH / 2)),
		Size = UDim2.fromOffset(34, 18),
		BackgroundColor3 = defaultColor,
		Parent = row,
	})
	Corner(swatch, 3)
	Stroke(swatch, "Border")
	local hexLabel = New("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -54, 0, math.floor(headerH / 2)),
		Size = UDim2.fromOffset(70, 16),
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right,
		Theme = { TextColor3 = "SubText" },
		Parent = row,
	})

	local area = New("Frame", {
		Position = UDim2.fromOffset(12, headerH + 2),
		Size = UDim2.new(1, -24, 0, PICK_SIZE),
		BackgroundTransparency = 1,
		Parent = row,
	})

	local sv = New("Frame", { Size = UDim2.fromOffset(PICK_SIZE, PICK_SIZE), Parent = area })
	Corner(sv, 3)
	local white = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = sv })
	Corner(white, 3)
	New("UIGradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
		Parent = white,
	})
	local black = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), Parent = sv })
	Corner(black, 3)
	New("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }),
		Parent = black,
	})
	local svCursor = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(10, 10),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = sv,
	})
	Corner(svCursor, 5)
	New("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1), Parent = svCursor })

	local hueBar = New("Frame", {
		Position = UDim2.fromOffset(PICK_SIZE + 10, 0),
		Size = UDim2.fromOffset(12, PICK_SIZE),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = area,
	})
	Corner(hueBar, 3)
	New("UIGradient", { Rotation = 90, Color = rainbowSequence(), Parent = hueBar })
	local hueCursor = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(18, 4),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
		Parent = hueBar,
	})
	Corner(hueCursor, 2)
	New("UIStroke", { Thickness = 1, Color = Color3.new(0, 0, 0), Transparency = 0.4, Parent = hueCursor })

	local panel = New("Frame", {
		Position = UDim2.fromOffset(PICK_SIZE + 34, 0),
		Size = UDim2.new(1, -(PICK_SIZE + 34), 1, 0),
		BackgroundTransparency = 1,
		Parent = area,
	})

	local function field(y, prefix)
		local box = New("Frame", {
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(1, 0, 0, 22),
			Theme = { BackgroundColor3 = "Background" },
			Parent = panel,
		})
		Corner(box, 3)
		local s = Stroke(box, "Border")
		New("TextLabel", {
			Position = UDim2.fromOffset(7, 0),
			Size = UDim2.new(0, 28, 1, 0),
			Text = prefix,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			Theme = { TextColor3 = "Muted" },
			Parent = box,
		})
		local tb = New("TextBox", {
			Position = UDim2.fromOffset(36, 0),
			Size = UDim2.new(1, -42, 1, 0),
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			ClipsDescendants = true,
			Theme = { TextColor3 = "Text" },
			Parent = box,
		})
		tb.Focused:Connect(function() tween(s, 0.2, { Color = Cipher.Theme.Accent }) end)
		tb.FocusLost:Connect(function() tween(s, 0.2, { Color = Cipher.Theme.Border }) end)
		return tb
	end
	local hexBox = field(0, "hex")
	local rgbBox = field(28, "rgb")

	local function smallButton(x, y, w, text)
		local b = New("TextButton", {
			Position = UDim2.new(x, 0, 0, y),
			Size = UDim2.new(w, -3, 0, 22),
			Text = text,
			TextSize = 11,
			Theme = { BackgroundColor3 = "Background" },
			Parent = panel,
		})
		b.BackgroundTransparency = 0
		Corner(b, 3)
		Stroke(b, "Border")
		b.TextColor3 = Cipher.Theme.SubText
		onTheme(b, function(t) b.TextColor3 = t.SubText end)
		b.MouseEnter:Connect(function() tween(b, 0.15, { TextColor3 = Cipher.Theme.Accent }) end)
		b.MouseLeave:Connect(function() tween(b, 0.2, { TextColor3 = Cipher.Theme.SubText }) end)
		return b
	end
	local rainbowBtn = smallButton(0, 56, 1, "[ ] rainbow")
	local copyBtn = smallButton(0, 84, 0.5, "copy")
	local resetBtn = smallButton(0.5, 84, 0.5, "reset")
	resetBtn.Position = resetBtn.Position + UDim2.fromOffset(3, 0)

	local function render()
		sv.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
		svCursor.Position = UDim2.new(sat, 0, 1 - val, 0)
		hueCursor.Position = UDim2.new(0.5, 0, hue, 0)
		tween(swatch, 0.12, { BackgroundColor3 = el.Value }, Enum.EasingStyle.Quad)
		local hexText = Util.toHex(el.Value)
		hexLabel.Text = hexText
		if not hexBox:IsFocused() then hexBox.Text = string.sub(hexText, 2) end
		if not rgbBox:IsFocused() then
			rgbBox.Text = string.format("%d, %d, %d", math.floor(el.Value.R * 255 + 0.5), math.floor(el.Value.G * 255 + 0.5), math.floor(el.Value.B * 255 + 0.5))
		end
		rainbowBtn.Text = el.Rainbow and "[x] rainbow" or "[ ] rainbow"
	end

	local function commit(silent)
		el.Value = Color3.fromHSV(hue, sat, val)
		render()
		if silent then
			if el.Flag then Cipher.Flags[el.Flag] = el.Value end
		else
			el:_fire(el.Value)
		end
	end

	function el:Set(color, silent)
		color = Util.fromHex(color)
		if not color then return end
		hue, sat, val = color:ToHSV()
		commit(silent)
	end

	local rainbowConn
	function el:SetRainbow(state)
		state = state and true or false
		self.Rainbow = state
		if rainbowConn then
			rainbowConn:Disconnect()
			rainbowConn = nil
		end
		if state then
			local speed = tonumber(opts.RainbowSpeed) or 0.15
			rainbowConn = RunService.Heartbeat:Connect(function()
				hue = (os.clock() * speed) % 1
				if sat < 0.05 then sat = 1 end
				if val < 0.05 then val = 1 end
				commit()
			end)
			track(rainbowConn, window._connections)
		end
		render()
	end

	function el:Open()
		if self.Opened or self.Locked then return end
		self.Opened = true
		tween(row, 0.35, { Size = UDim2.new(1, 0, 0, headerH + PICK_SIZE + 14) })
	end

	function el:Close()
		if not self.Opened then return end
		self.Opened = false
		tween(row, 0.3, { Size = UDim2.new(1, 0, 0, headerH) })
	end

	function el:_serialize()
		return { Hex = Util.toHex(self.Value), Rainbow = self.Rainbow }
	end
	function el:_deserialize(v)
		if type(v) == "table" then
			self:Set(v.Hex)
			self:SetRainbow(v.Rainbow == true)
		else
			self:Set(v)
		end
	end
	function el:_cleanup()
		if rainbowConn then rainbowConn:Disconnect() rainbowConn = nil end
	end

	-- dragging
	local draggingSV, draggingHue = false, false
	local function updateSV(pos)
		local size = sv.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then return end
		sat = Util.clamp((pos.X - sv.AbsolutePosition.X) / size.X, 0, 1)
		val = 1 - Util.clamp((pos.Y - sv.AbsolutePosition.Y) / size.Y, 0, 1)
		commit()
	end
	local function updateHue(pos)
		local size = hueBar.AbsoluteSize
		if size.Y <= 0 then return end
		hue = Util.clamp((pos.Y - hueBar.AbsolutePosition.Y) / size.Y, 0, 0.999)
		commit()
	end
	sv.InputBegan:Connect(function(input)
		if isPointer(input) and not el.Locked then
			if el.Rainbow then el:SetRainbow(false) end
			draggingSV = true
			updateSV(input.Position)
		end
	end)
	hueBar.InputBegan:Connect(function(input)
		if isPointer(input) and not el.Locked then
			if el.Rainbow then el:SetRainbow(false) end
			draggingHue = true
			updateHue(input.Position)
		end
	end)
	track(UserInputService.InputChanged:Connect(function(input)
		if not isMove(input) then return end
		if draggingSV then updateSV(input.Position) elseif draggingHue then updateHue(input.Position) end
	end), window._connections)
	track(UserInputService.InputEnded:Connect(function(input)
		if isPointer(input) then draggingSV, draggingHue = false, false end
	end), window._connections)

	hexBox.FocusLost:Connect(function()
		local c = Util.fromHex(hexBox.Text)
		if c and not el.Locked then el:Set(c) else render() end
	end)
	rgbBox.FocusLost:Connect(function()
		local r, g, b = string.match(rgbBox.Text, "(%d+)%D+(%d+)%D+(%d+)")
		r, g, b = tonumber(r), tonumber(g), tonumber(b)
		if r and g and b and not el.Locked then
			el:Set(Color3.fromRGB(Util.clamp(r, 0, 255), Util.clamp(g, 0, 255), Util.clamp(b, 0, 255)))
		else
			render()
		end
	end)
	rainbowBtn.MouseButton1Click:Connect(function()
		if not el.Locked then el:SetRainbow(not el.Rainbow) end
	end)
	copyBtn.MouseButton1Click:Connect(function()
		if setClipboardFn then
			pcall(setClipboardFn, Util.toHex(el.Value))
			Cipher:Notify({ Title = "clipboard", Content = "Copied " .. Util.toHex(el.Value), Type = "success", Duration = 2 })
		else
			Cipher:Notify({ Title = "clipboard", Content = "setclipboard is not supported by this executor.", Type = "warning", Duration = 3 })
		end
	end)
	resetBtn.MouseButton1Click:Connect(function()
		if el.Locked then return end
		el:SetRainbow(false)
		el:Set(defaultColor)
	end)
	headerBtn.MouseButton1Click:Connect(function()
		if el.Opened then el:Close() else el:Open() end
	end)

	hoverRow(row, stroke)
	render()
	if opts.Rainbow then el:SetRainbow(true) end
	return register(owner, el, opts)
end)

--============================================================
-- LABEL
--============================================================
local Label = newClass()

defineElement("Label", function(owner, opts)
	local text = tostring(opts.Text or opts.Name or opts.Title or "")
	local align = Enum.TextXAlignment.Left
	if opts.Align then
		local ok, found = pcall(function() return Enum.TextXAlignment[tostring(opts.Align)] end)
		if ok and found then align = found end
	end
	local frame = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = owner:_nextOrder(),
		Parent = owner._container,
	})
	Padding(frame, 2, 4, 2, 4)
	local label = New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = text,
		TextSize = tonumber(opts.TextSize) or 12,
		TextWrapped = true,
		RichText = opts.RichText == true,
		TextXAlignment = align,
		Parent = frame,
	})
	local el = setmetatable({ Type = "Label", Frame = frame, Label = label, _titleLabel = label, Value = text }, Label)

	local colorKey = "SubText"
	function el:SetColor(color)
		if typeof(color) == "Color3" then
			colorKey = nil
			label.TextColor3 = color
		elseif type(color) == "string" and Cipher.Theme[color] then
			colorKey = color
			label.TextColor3 = Cipher.Theme[color]
		end
	end
	onTheme(label, function(t) if colorKey then label.TextColor3 = t[colorKey] end end)
	if opts.Color then el:SetColor(opts.Color) end

	function el:Set(newText)
		self.Value = tostring(newText)
		self.Name = self.Value
		self._searchText = self.Value
		label.Text = self.Value
	end
	el.SetText = el.Set

	return register(owner, el, { Name = text, Tooltip = opts.Tooltip, Visible = opts.Visible })
end)

--============================================================
-- PARAGRAPH
--============================================================
local Paragraph = newClass()

defineElement("Paragraph", function(owner, opts)
	local frame = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = owner:_nextOrder(),
		Theme = { BackgroundColor3 = "Element" },
		Parent = owner._container,
	})
	Corner(frame, 4)
	Stroke(frame, "Border")
	Padding(frame, 9, 12, 10, 12)
	List(frame, 4)
	local titleLabel = New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = tostring(opts.Title or opts.Name or "paragraph"),
		TextSize = 13,
		Weight = "Bold",
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
		Theme = { TextColor3 = "Text" },
		Parent = frame,
	})
	local contentLabel = New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = tostring(opts.Content or opts.Text or ""),
		TextSize = 12,
		TextWrapped = true,
		RichText = opts.RichText == true,
		LineHeight = 1.1,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
		Theme = { TextColor3 = "SubText" },
		Parent = frame,
	})
	local el = setmetatable({ Type = "Paragraph", Frame = frame, _titleLabel = titleLabel, ContentLabel = contentLabel }, Paragraph)

	function el:SetContent(text)
		contentLabel.Text = tostring(text)
	end

	function el:Set(a, b)
		if type(a) == "table" then
			if a.Title then self:SetTitle(a.Title) end
			if a.Content then self:SetContent(a.Content) end
		else
			if a ~= nil then self:SetTitle(a) end
			if b ~= nil then self:SetContent(b) end
		end
	end

	return register(owner, el, { Name = opts.Title or opts.Name or "paragraph", Tooltip = opts.Tooltip, Visible = opts.Visible })
end)

--============================================================
-- DIVIDER
--============================================================
local Divider = newClass()

defineElement("Divider", function(owner, opts)
	local text = opts.Text or opts.Name
	local frame = New("Frame", {
		Size = UDim2.new(1, 0, 0, text and 18 or 9),
		BackgroundTransparency = 1,
		LayoutOrder = owner:_nextOrder(),
		Parent = owner._container,
	})
	local el = setmetatable({ Type = "Divider", Frame = frame }, Divider)
	if text then
		text = string.lower(tostring(text))
		local half = math.floor(textWidth(text, 11) / 2) + 10
		New("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0), Size = UDim2.new(0.5, -half - 2, 0, 1), Theme = { BackgroundColor3 = "Border" }, Parent = frame })
		New("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -2, 0.5, 0), Size = UDim2.new(0.5, -half - 2, 0, 1), Theme = { BackgroundColor3 = "Border" }, Parent = frame })
		el._titleLabel = New("TextLabel", { Size = UDim2.fromScale(1, 1), Text = text, TextSize = 11, Theme = { TextColor3 = "Muted" }, Parent = frame })
	else
		New("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0), Size = UDim2.new(1, -4, 0, 1), Theme = { BackgroundColor3 = "Border" }, Parent = frame })
	end
	return register(owner, el, { Name = text or "divider", Visible = opts.Visible })
end)

--============================================================
-- CONSOLE (log output box)
--============================================================
local Console = newClass()

local LOG_KINDS = {
	info    = { "[*]", "Info" },
	success = { "[+]", "Success" },
	warn    = { "[!]", "Warning" },
	warning = { "[!]", "Warning" },
	error   = { "[x]", "Error" },
	debug   = { "[~]", "Muted" },
	print   = { ">", "SubText" },
}

local function buildConsole(parent, opts, order)
	local lines = Util.clamp(math.floor(tonumber(opts.Lines) or 8), 3, 40)
	local frame = New("Frame", {
		Size = UDim2.new(1, 0, 0, lines * 16 + 38),
		LayoutOrder = order or 0,
		Theme = { BackgroundColor3 = "Background" },
		Parent = parent,
	})
	Corner(frame, 4)
	Stroke(frame, "Border")

	local header = New("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Parent = frame })
	local titleLabel = New("TextLabel", {
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -140, 1, 0),
		Text = "~/" .. string.lower(tostring(opts.Name or opts.Title or "output")),
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Theme = { TextColor3 = "Muted" },
		Parent = header,
	})
	local tools = New("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 0),
		Size = UDim2.new(0, 130, 1, 0),
		BackgroundTransparency = 1,
		Parent = header,
	})
	local toolsLayout = List(tools, 4, Enum.FillDirection.Horizontal)
	toolsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	toolsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	local function tool(text, order)
		local b = New("TextButton", {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 18),
			Text = text,
			TextSize = 11,
			LayoutOrder = order,
			Parent = tools,
		})
		b.TextColor3 = Cipher.Theme.Muted
		onTheme(b, function(t) b.TextColor3 = t.Muted end)
		b.MouseEnter:Connect(function() tween(b, 0.15, { TextColor3 = Cipher.Theme.Accent }) end)
		b.MouseLeave:Connect(function() tween(b, 0.2, { TextColor3 = Cipher.Theme.Muted }) end)
		return b
	end
	local copyBtn = tool("[copy]", 1)
	local clearBtn = tool("[clear]", 2)
	New("Frame", { Position = UDim2.new(0, 8, 0, 24), Size = UDim2.new(1, -16, 0, 1), BackgroundTransparency = 0.4, Theme = { BackgroundColor3 = "Border" }, Parent = frame })

	local scroll = New("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 1, -28),
		BackgroundTransparency = 1,
		ScrollBarThickness = 2,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Theme = { ScrollBarImageColor3 = "AccentDim" },
		Parent = frame,
	})
	Padding(scroll, 4, 10, 4, 10)
	List(scroll, 1)

	local con = { Frame = frame, _entries = {}, _order = 0, _titleLabel = titleLabel }
	local maxLines = math.floor(tonumber(opts.MaxLines) or 200)
	local stamps = opts.Timestamps ~= false

	local function format(entry)
		local kind = LOG_KINDS[entry.kind] or LOG_KINDS.print
		local out = ""
		if stamps then out = string.format('<font color="%s">%s</font> ', hex("Muted"), entry.time) end
		out = out .. string.format('<font color="%s">%s</font> ', hex(kind[2]), kind[1])
		local textKey = entry.kind == "error" and "Error" or "Text"
		return out .. string.format('<font color="%s">%s</font>', hex(textKey), Util.escapeRich(entry.text))
	end

	function con:Log(text, kind)
		kind = string.lower(tostring(kind or "print"))
		self._order = self._order + 1
		local entry = { text = tostring(text), kind = kind, time = os.date("%H:%M:%S") }
		local nearBottom = scroll.CanvasPosition.Y >= scroll.AbsoluteCanvasSize.Y - scroll.AbsoluteWindowSize.Y - 24
		entry.label = New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			RichText = true,
			TextSize = 12,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = self._order,
			Parent = scroll,
		})
		entry.label.Text = format(entry)
		table.insert(self._entries, entry)
		while #self._entries > maxLines do
			local old = table.remove(self._entries, 1)
			old.label:Destroy()
		end
		if nearBottom then
			task.defer(function()
				RunService.Heartbeat:Wait()
				if scroll.Parent then
					scroll.CanvasPosition = Vector2.new(0, math.max(0, scroll.AbsoluteCanvasSize.Y - scroll.AbsoluteWindowSize.Y))
				end
			end)
		end
		return entry
	end
	function con:Print(t) return self:Log(t, "print") end
	function con:Info(t) return self:Log(t, "info") end
	function con:Success(t) return self:Log(t, "success") end
	function con:Warn(t) return self:Log(t, "warn") end
	function con:Error(t) return self:Log(t, "error") end
	function con:Debug(t) return self:Log(t, "debug") end

	function con:Clear()
		for _, entry in ipairs(self._entries) do entry.label:Destroy() end
		self._entries = {}
	end

	function con:GetText()
		local out = {}
		for _, entry in ipairs(self._entries) do
			local kind = LOG_KINDS[entry.kind] or LOG_KINDS.print
			table.insert(out, (stamps and (entry.time .. " ") or "") .. kind[1] .. " " .. entry.text)
		end
		return table.concat(out, "\n")
	end

	onTheme(frame, function()
		for _, entry in ipairs(con._entries) do entry.label.Text = format(entry) end
	end)

	clearBtn.MouseButton1Click:Connect(function() con:Clear() end)
	copyBtn.MouseButton1Click:Connect(function()
		if setClipboardFn then
			pcall(setClipboardFn, con:GetText())
			Cipher:Notify({ Title = "clipboard", Content = "Console output copied.", Type = "success", Duration = 2 })
		else
			Cipher:Notify({ Title = "clipboard", Content = "setclipboard is not supported by this executor.", Type = "warning", Duration = 3 })
		end
	end)
	return con, scroll
end

defineElement("Console", function(owner, opts)
	local con = buildConsole(owner._container, opts, owner:_nextOrder())
	local el = setmetatable(con, Console)
	el.Type = "Console"
	return register(owner, el, { Name = opts.Name or "console", Tooltip = opts.Tooltip, Visible = opts.Visible })
end)

--============================================================
-- DIALOG
--============================================================
function Window:Dialog(opts)
	opts = opts or {}
	if self._dialog then self._dialog:Close() end

	local overlay = New("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 45,
		Theme = { BackgroundColor3 = "Background" },
		Parent = self.Canvas,
	})
	Corner(overlay, 5)
	local box = New("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 12),
		Size = UDim2.new(0, Util.clamp(tonumber(opts.Width) or 340, 220, 520), 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0,
		ZIndex = 46,
		Theme = { BackgroundColor3 = "Panel" },
		Parent = overlay,
	})
	Corner(box, 4)
	Stroke(box, "AccentDim")
	local boxScale = New("UIScale", { Scale = 0.94, Parent = box })
	Padding(box, 14, 16, 14, 16)
	List(box, 10)

	New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = "[?] " .. string.upper(tostring(opts.Title or "confirm")),
		TextSize = 13,
		Weight = "Bold",
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 46,
		LayoutOrder = 1,
		Theme = { TextColor3 = "Accent" },
		Parent = box,
	})
	if opts.Content then
		New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = tostring(opts.Content),
			TextSize = 12,
			TextWrapped = true,
			LineHeight = 1.1,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 46,
			LayoutOrder = 2,
			Theme = { TextColor3 = "SubText" },
			Parent = box,
		})
	end

	local row = New("Frame", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		ZIndex = 46,
		LayoutOrder = 3,
		Parent = box,
	})
	local rowLayout = List(row, 8, Enum.FillDirection.Horizontal)
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right

	local dialog = { Closed = false }
	self._dialog = dialog

	function dialog.Close()
		if dialog.Closed then return end
		dialog.Closed = true
		if self._dialog == dialog then self._dialog = nil end
		tween(overlay, 0.2, { BackgroundTransparency = 1 })
		tween(box, 0.2, { Position = UDim2.new(0.5, 0, 0.5, 12) })
		tween(boxScale, 0.2, { Scale = 0.94 })
		task.delay(0.12, function() box.Visible = false end)
		task.delay(0.22, function() overlay:Destroy() end)
	end

	local buttons = opts.Buttons or { { Name = "ok", Primary = true } }
	for i, spec in ipairs(buttons) do
		local primary = spec.Primary == true
		local btn = New("TextButton", {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 26),
			Text = string.lower(tostring(spec.Name or "ok")),
			TextSize = 12,
			Weight = primary and "Bold" or "Regular",
			ZIndex = 47,
			LayoutOrder = i,
			Theme = { BackgroundColor3 = primary and "Accent" or "Element" },
			Parent = row,
		})
		btn.BackgroundTransparency = primary and 0.85 or 0
		Corner(btn, 3)
		Stroke(btn, primary and "Accent" or "Border")
		Padding(btn, 0, 14, 0, 14)
		local base = primary and "Accent" or "SubText"
		btn.TextColor3 = Cipher.Theme[base]
		onTheme(btn, function(t) btn.TextColor3 = t[base] end)
		btn.MouseEnter:Connect(function()
			tween(btn, 0.15, { BackgroundTransparency = primary and 0.7 or 0, TextColor3 = Cipher.Theme.Text })
		end)
		btn.MouseLeave:Connect(function()
			tween(btn, 0.2, { BackgroundTransparency = primary and 0.85 or 0, TextColor3 = Cipher.Theme[base] })
		end)
		btn.MouseButton1Click:Connect(function()
			dialog.Close()
			safeCall(spec.Callback)
		end)
	end

	if opts.Dismissible ~= false then
		overlay.MouseButton1Click:Connect(dialog.Close)
	end

	tween(overlay, 0.25, { BackgroundTransparency = 0.3 })
	tween(box, 0.35, { Position = UDim2.new(0.5, 0, 0.5, 0) })
	tween(boxScale, 0.35, { Scale = 1 })
	return dialog
end

--============================================================
-- TERMINAL (built-in command line)
--============================================================
local TERM_H = 206

local function parseForElement(el, args)
	local raw = table.concat(args, " ")
	if el.Type == "Toggle" then
		local l = string.lower(raw)
		return l == "true" or l == "on" or l == "1" or l == "yes"
	elseif el.Type == "Slider" then
		return tonumber(raw)
	elseif el.Type == "Dropdown" and el.Multi then
		local list = {}
		for part in string.gmatch(raw, "[^,]+") do
			table.insert(list, (string.gsub(part, "^%s*(.-)%s*$", "%1")))
		end
		return list
	end
	return raw
end

local function describeValue(value)
	if type(value) == "table" then
		local parts = {}
		for i, v in ipairs(value) do parts[i] = tostring(v) end
		return "{" .. table.concat(parts, ", ") .. "}"
	elseif typeof(value) == "Color3" then
		return Util.toHex(value)
	elseif typeof(value) == "EnumItem" then
		return value.Name
	end
	return tostring(value)
end

function Window:_buildTerminal()
	if self._terminal then return self._terminal end

	local panel = New("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, TERM_H + 4),
		Size = UDim2.new(1, 0, 0, TERM_H),
		Visible = false,
		ZIndex = 20,
		Theme = { BackgroundColor3 = "Panel" },
		Parent = self.Content,
	})
	New("Frame", { Size = UDim2.new(1, 0, 0, 1), Theme = { BackgroundColor3 = "AccentDim" }, Parent = panel })

	local con = buildConsole(panel, { Name = "terminal", Lines = 8, MaxLines = 300 })
	con.Frame.Position = UDim2.fromOffset(10, 10)
	con.Frame.Size = UDim2.new(1, -20, 0, TERM_H - 54)

	local inputRow = New("Frame", {
		Position = UDim2.new(0, 10, 1, -36),
		Size = UDim2.new(1, -20, 0, 26),
		Theme = { BackgroundColor3 = "Background" },
		Parent = panel,
	})
	Corner(inputRow, 3)
	local inputStroke = Stroke(inputRow, "Border")
	New("TextLabel", {
		Position = UDim2.fromOffset(9, 0),
		Size = UDim2.new(0, 12, 1, 0),
		Text = "$",
		Weight = "Bold",
		TextSize = 13,
		Theme = { TextColor3 = "Accent" },
		Parent = inputRow,
	})
	local box = New("TextBox", {
		Position = UDim2.fromOffset(26, 0),
		Size = UDim2.new(1, -34, 1, 0),
		PlaceholderText = "type 'help' and press enter",
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClipsDescendants = true,
		Theme = { TextColor3 = "Text", PlaceholderColor3 = "Muted" },
		Parent = inputRow,
	})

	self._terminal = { Panel = panel, Console = con, Box = box, History = {}, HistoryIndex = 0 }
	self.Terminal = con

	box.Focused:Connect(function() tween(inputStroke, 0.2, { Color = Cipher.Theme.Accent }) end)
	box.FocusLost:Connect(function(enterPressed)
		tween(inputStroke, 0.2, { Color = Cipher.Theme.Border })
		if not enterPressed then return end
		local line = box.Text
		box.Text = ""
		if string.match(line, "%S") then
			local term = self._terminal
			table.insert(term.History, line)
			term.HistoryIndex = #term.History + 1
			self:RunCommand(line)
		end
		task.defer(function()
			if self.TerminalOpen and box.Parent then box:CaptureFocus() end
		end)
	end)

	-- some clients insert a literal tab into the box; strip it
	box:GetPropertyChangedSignal("Text"):Connect(function()
		if string.find(box.Text, "\t", 1, true) then
			box.Text = string.gsub(box.Text, "\t", "")
			box.CursorPosition = #box.Text + 1
		end
	end)

	local function complete()
		local typed = string.lower((string.gsub(box.Text, "\t", "")))
		if typed == "" or string.find(typed, " ", 1, true) then return end
		local match
		for name in pairs(self.Commands) do
			if string.sub(name, 1, #typed) == typed then
				if not match or #name < #match then match = name end
			end
		end
		if match then
			box.Text = match .. " "
			box.CursorPosition = #box.Text + 1
		end
	end

	track(UserInputService.InputBegan:Connect(function(input)
		if not box:IsFocused() then return end
		local term = self._terminal
		if input.KeyCode == Enum.KeyCode.Tab then
			complete()
			return
		elseif input.KeyCode == Enum.KeyCode.Up then
			term.HistoryIndex = math.max(1, term.HistoryIndex - 1)
		elseif input.KeyCode == Enum.KeyCode.Down then
			term.HistoryIndex = math.min(#term.History + 1, term.HistoryIndex + 1)
		else
			return
		end
		box.Text = term.History[term.HistoryIndex] or ""
		box.CursorPosition = #box.Text + 1
	end), self._connections)

	con:Log(self.Title .. " terminal -- type 'help' for commands", "info")
	return self._terminal
end

function Window:ToggleTerminal(state)
	local term = self:_buildTerminal()
	if state == nil then state = not self.TerminalOpen end
	state = state and true or false
	self.TerminalOpen = state
	self._termAnim = (self._termAnim or 0) + 1
	local id = self._termAnim
	if state then
		term.Panel.Visible = true
		tween(term.Panel, 0.35, { Position = UDim2.new(0, 0, 1, 0) })
		task.delay(0.05, function()
			if self.TerminalOpen and term.Box.Parent then term.Box:CaptureFocus() end
		end)
	else
		term.Box:ReleaseFocus()
		tween(term.Panel, 0.3, { Position = UDim2.new(0, 0, 1, TERM_H + 4) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		task.delay(0.3, function()
			if id == self._termAnim then term.Panel.Visible = false end
		end)
	end
end

function Window:Log(text, kind)
	local term = self:_buildTerminal()
	return term.Console:Log(text, kind)
end

function Window:AddCommand(name, description, callback)
	local spec
	if type(name) == "table" then
		spec = name
	else
		spec = { Name = name, Description = description, Callback = callback }
		if type(description) == "function" then
			spec.Description = nil
			spec.Callback = description
		end
	end
	assert(type(spec.Name) == "string", "AddCommand: Name must be a string")
	assert(type(spec.Callback) == "function", "AddCommand: Callback must be a function")
	local key = string.lower(spec.Name)
	spec.Name = key
	self.Commands[key] = spec
	for _, alias in ipairs(spec.Aliases or {}) do
		self.Commands[string.lower(alias)] = spec
	end
	return spec
end

function Window:RunCommand(line)
	local term = self:_buildTerminal()
	local con = term.Console
	con:Log("$ " .. line, "print")
	local args = Util.splitArgs(line)
	local name = string.lower(table.remove(args, 1) or "")
	if name == "" then return end
	local cmd = self.Commands[name]
	if not cmd then
		con:Error("command not found: " .. name .. "  (try 'help')")
		return
	end
	local ok, result = pcall(cmd.Callback, args, con, line)
	if not ok then
		con:Error(tostring(result))
	elseif result ~= nil then
		con:Print(tostring(result))
	end
end

function Window:_registerBuiltinCommands()
	local win = self
	local function flagElement(con, flag)
		local el = flag and Cipher.Options[flag]
		if not el then
			for f, e in pairs(Cipher.Options) do
				if flag and string.lower(f) == string.lower(flag) then el = e break end
			end
		end
		if not el then con:Error("unknown flag: " .. tostring(flag)) end
		return el
	end

	self:AddCommand({ Name = "help", Description = "list commands", Usage = "help [command]", Callback = function(args, con)
		if args[1] then
			local cmd = win.Commands[string.lower(args[1])]
			if not cmd then con:Error("no such command") return end
			con:Info(cmd.Name .. "  --  " .. (cmd.Description or "no description"))
			if cmd.Usage then con:Print("usage: " .. cmd.Usage) end
			return
		end
		local names = {}
		for key, cmd in pairs(win.Commands) do
			if key == cmd.Name then table.insert(names, key) end
		end
		table.sort(names)
		for _, key in ipairs(names) do
			local cmd = win.Commands[key]
			con:Print(string.format("%-10s %s", key, cmd.Description or ""))
		end
	end })
	self:AddCommand({ Name = "clear", Aliases = { "cls" }, Description = "clear the terminal", Callback = function(_, con) con:Clear() end })
	self:AddCommand({ Name = "echo", Description = "print text", Usage = "echo <text>", Callback = function(args) return table.concat(args, " ") end })
	self:AddCommand({ Name = "tabs", Description = "list tabs", Callback = function(_, con)
		for i, tab in ipairs(win.Tabs) do con:Print(i .. ": " .. tab.Name .. (tab == win.CurrentTab and "  *" or "")) end
	end })
	self:AddCommand({ Name = "tab", Aliases = { "cd" }, Description = "open a tab", Usage = "tab <name|number>", Callback = function(args, con)
		local target = tonumber(args[1]) or table.concat(args, " ")
		local tab = win:GetTab(target)
		if not tab then con:Error("no such tab") return end
		win:SelectTab(tab)
		con:Success("switched to " .. tab.Name)
	end })
	self:AddCommand({ Name = "flags", Aliases = { "ls" }, Description = "list flags and values", Callback = function(_, con)
		local names = {}
		for flag in pairs(Cipher.Options) do table.insert(names, flag) end
		table.sort(names)
		if #names == 0 then con:Print("no flags registered") return end
		for _, flag in ipairs(names) do
			local el = Cipher.Options[flag]
			con:Print(string.format("%-18s %-11s %s", flag, el.Type, describeValue(el.Value)))
		end
	end })
	self:AddCommand({ Name = "get", Description = "read a flag", Usage = "get <flag>", Callback = function(args, con)
		local el = flagElement(con, args[1])
		if el then con:Print(args[1] .. " = " .. describeValue(el.Value)) end
	end })
	self:AddCommand({ Name = "set", Description = "change a flag", Usage = "set <flag> <value>", Callback = function(args, con)
		local flag = table.remove(args, 1)
		local el = flagElement(con, flag)
		if not el or not el.Set then return end
		el:Set(parseForElement(el, args))
		con:Success(flag .. " = " .. describeValue(el.Value))
	end })
	self:AddCommand({ Name = "toggle", Description = "flip a toggle flag", Usage = "toggle <flag>", Callback = function(args, con)
		local el = flagElement(con, args[1])
		if not el then return end
		if el.Type ~= "Toggle" then con:Error("flag is not a toggle") return end
		el:Set(not el.Value)
		con:Success(args[1] .. " = " .. tostring(el.Value))
	end })
	self:AddCommand({ Name = "theme", Description = "change theme", Usage = "theme <name>", Callback = function(args, con)
		if not args[1] then
			con:Print("current: " .. Cipher.ThemeName .. "   available: " .. table.concat(Cipher.ThemeOrder, ", "))
			return
		end
		for _, name in ipairs(Cipher.ThemeOrder) do
			if string.lower(name) == string.lower(args[1]) then
				Cipher:SetTheme(name)
				con:Success("theme -> " .. name)
				return
			end
		end
		con:Error("unknown theme")
	end })
	self:AddCommand({ Name = "config", Aliases = { "cfg" }, Description = "save/load/delete/list configs", Usage = "config <save|load|delete|list> [name]", Callback = function(args, con)
		local action, name = string.lower(args[1] or "list"), args[2]
		if action == "list" then
			local list = Cipher:ListConfigs()
			con:Print(#list == 0 and "no configs saved" or table.concat(list, ", "))
			return
		end
		if not name then con:Error("usage: config " .. action .. " <name>") return end
		local ok, err
		if action == "save" then ok, err = Cipher:SaveConfig(name)
		elseif action == "load" then ok, err = Cipher:LoadConfig(name)
		elseif action == "delete" then ok, err = Cipher:DeleteConfig(name)
		else con:Error("unknown action") return end
		if ok then con:Success(action .. " '" .. name .. "' ok") else con:Error(tostring(err)) end
	end })
	self:AddCommand({ Name = "notify", Description = "send a test notification", Usage = "notify <text>", Callback = function(args)
		Cipher:Notify({ Title = "terminal", Content = table.concat(args, " "), Type = "info" })
	end })
	self:AddCommand({ Name = "stats", Description = "fps, ping, server info", Callback = function(_, con)
		con:Print("fps      " .. tostring(win.FPS or "?"))
		con:Print("ping     " .. tostring(win.Ping or "?") .. " ms")
		con:Print("players  " .. #Players:GetPlayers() .. "/" .. tostring(Players.MaxPlayers))
		con:Print("place    " .. tostring(game.PlaceId) .. "  job " .. string.sub(tostring(game.JobId), 1, 8))
		con:Print("executor " .. Cipher:GetExecutor())
	end })
	self:AddCommand({ Name = "rejoin", Description = "rejoin this server", Callback = function(_, con)
		con:Info("rejoining...")
		local TeleportService = getService("TeleportService")
		local ok, err = pcall(function()
			if #Players:GetPlayers() <= 1 then
				TeleportService:Teleport(game.PlaceId, LocalPlayer)
			else
				TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
			end
		end)
		if not ok then con:Error(tostring(err)) end
	end })
	self:AddCommand({ Name = "hide", Description = "hide the window", Callback = function() win:SetVisible(false) end })
	self:AddCommand({ Name = "exit", Aliases = { "unload" }, Description = "close and unload this window", Callback = function() win:Destroy() end })
end

--============================================================
-- KEYBIND LIST (floating overlay)
--============================================================
local function makeDraggable(handle, target, connections)
	local dragging, start, startPos = false, nil, nil
	handle.InputBegan:Connect(function(input)
		if not isPointer(input) then return end
		dragging, start, startPos = true, input.Position, target.Position
		local conn
		conn = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
				conn:Disconnect()
			end
		end)
	end)
	track(UserInputService.InputChanged:Connect(function(input)
		if dragging and isMove(input) then
			local d = input.Position - start
			target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end), connections)
end

function Window:SetKeybindList(state)
	state = state and true or false
	if state and not self._kbList then
		local frame = New("Frame", {
			Position = UDim2.new(0, 16, 0.5, -80),
			Size = UDim2.fromOffset(200, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			ZIndex = 5,
			Theme = { BackgroundColor3 = "Panel" },
			Parent = self.Gui,
		})
		Corner(frame, 4)
		Stroke(frame, "AccentDim", 1, 0.3)
		Padding(frame, 0, 0, 6, 0)
		List(frame, 0)
		local header = New("TextButton", {
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundTransparency = 1,
			LayoutOrder = 0,
			Parent = frame,
		})
		New("TextLabel", {
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, -20, 1, 0),
			Text = "// KEYBINDS",
			TextSize = 11,
			Weight = "Bold",
			TextXAlignment = Enum.TextXAlignment.Left,
			Theme = { TextColor3 = "Accent" },
			Parent = header,
		})
		New("Frame", { Position = UDim2.new(0, 8, 1, -1), Size = UDim2.new(1, -16, 0, 1), Theme = { BackgroundColor3 = "Border" }, Parent = header })
		local body = New("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Parent = frame,
		})
		Padding(body, 4, 10, 0, 10)
		List(body, 2)
		makeDraggable(header, frame, self._connections)
		self._kbList = { Frame = frame, Body = body }
		onTheme(frame, function() self:_refreshKeybindList() end)
	end
	if self._kbList then
		self._kbList.Frame.Visible = state
		self.KeybindListVisible = state
		self:_refreshKeybindList()
	end
end

function Window:_refreshKeybindList()
	local list = self._kbList
	if not list or not list.Frame.Visible then return end
	for _, child in ipairs(list.Body:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	local t = Cipher.Theme
	local count = 0
	for _, kb in ipairs(self.Keybinds) do
		if kb.Value then
			count = count + 1
			local stateText, stateKey
			if kb.Mode == "Press" then
				stateText, stateKey = "press", "Muted"
			else
				stateText = kb.State and "on" or "off"
				stateKey = kb.State and "Accent" or "Muted"
			end
			local rowFrame = New("Frame", {
				Size = UDim2.new(1, 0, 0, 18),
				BackgroundTransparency = 1,
				LayoutOrder = count,
				Parent = list.Body,
			})
			New("TextLabel", {
				Size = UDim2.new(1, -38, 1, 0),
				RichText = true,
				Text = string.format('<font color="%s">[%s]</font> <font color="%s">%s</font>',
					Util.toHex(t.AccentDim), Util.escapeRich(Util.keyName(kb.Value)), Util.toHex(t.Text), Util.escapeRich(kb.Name)),
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = rowFrame,
			})
			New("TextLabel", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, 0),
				Size = UDim2.new(0, 36, 1, 0),
				Text = stateText,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = t[stateKey],
				Parent = rowFrame,
			})
		end
	end
	if count == 0 then
		New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 18),
			Text = "no keybinds set",
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = t.Muted,
			Parent = list.Body,
		})
	end
end

--============================================================
-- CONFIG SYSTEM
--============================================================
local function ensureFolder(path)
	if not (FS.isfolder and FS.makefolder) then return end
	local current = ""
	for part in string.gmatch(path, "[^/]+") do
		current = (current == "") and part or (current .. "/" .. part)
		local ok, exists = pcall(FS.isfolder, current)
		if not (ok and exists) then pcall(FS.makefolder, current) end
	end
end

local function cleanName(name)
	name = tostring(name or "")
	name = string.gsub(name, "[^%w%-_ ]", "")
	name = string.gsub(name, "^%s+", "")
	name = string.gsub(name, "%s+$", "")
	return name
end

function Cipher:HasFileSystem()
	return (FS.writefile and FS.readfile and FS.isfile) and true or false
end

function Cipher:_configDir()
	return self.Folder .. "/configs"
end

function Cipher:SaveConfig(name)
	if not self:HasFileSystem() then return false, "this executor has no file functions (writefile/readfile)" end
	name = cleanName(name)
	if name == "" then return false, "invalid config name" end
	local flags = {}
	for flag, el in pairs(self.Options) do
		if el._serialize and not el.IgnoreConfig then
			local ok, value = pcall(el._serialize, el)
			if ok then flags[flag] = { Type = el.Type, Value = value } end
		end
	end
	ensureFolder(self:_configDir())
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode({ Version = self.Version, Theme = self.ThemeName, Flags = flags })
	end)
	if not ok then return false, "could not encode config" end
	local wrote, err = pcall(FS.writefile, self:_configDir() .. "/" .. name .. ".json", encoded)
	if not wrote then return false, tostring(err) end
	return true
end

function Cipher:LoadConfig(name)
	if not self:HasFileSystem() then return false, "this executor has no file functions (writefile/readfile)" end
	name = cleanName(name)
	if name == "" then return false, "invalid config name" end
	local path = self:_configDir() .. "/" .. name .. ".json"
	local okExists, exists = pcall(FS.isfile, path)
	if not (okExists and exists) then return false, "config '" .. name .. "' not found" end
	local okRead, raw = pcall(FS.readfile, path)
	if not okRead then return false, tostring(raw) end
	local okDecode, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
	if not okDecode or type(decoded) ~= "table" then return false, "config file is corrupted" end

	local flags = type(decoded.Flags) == "table" and decoded.Flags or decoded
	local loaded = 0
	for flag, entry in pairs(flags) do
		local el = self.Options[flag]
		if el and el._deserialize and type(entry) == "table" and not el.IgnoreConfig then
			if pcall(el._deserialize, el, entry.Value) then loaded = loaded + 1 end
		end
	end
	if type(decoded.Theme) == "string" and self.Themes[decoded.Theme] and decoded.Theme ~= self.ThemeName then
		self:SetTheme(decoded.Theme)
	end
	return true, loaded
end

function Cipher:DeleteConfig(name)
	if not FS.delfile then return false, "delfile is not supported by this executor" end
	name = cleanName(name)
	local path = self:_configDir() .. "/" .. name .. ".json"
	local okExists, exists = pcall(FS.isfile, path)
	if not (okExists and exists) then return false, "config '" .. name .. "' not found" end
	local ok, err = pcall(FS.delfile, path)
	if not ok then return false, tostring(err) end
	return true
end

function Cipher:ListConfigs()
	local out = {}
	if not (FS.listfiles and FS.isfolder) then return out end
	local okFolder, exists = pcall(FS.isfolder, self:_configDir())
	if not (okFolder and exists) then return out end
	local ok, files = pcall(FS.listfiles, self:_configDir())
	if not ok or type(files) ~= "table" then return out end
	for _, file in ipairs(files) do
		local name = string.match(tostring(file), "([^/\\]+)%.json$")
		if name then table.insert(out, name) end
	end
	table.sort(out)
	return out
end

function Cipher:SetAutoload(name)
	if not FS.writefile then return false, "writefile is not supported" end
	ensureFolder(self.Folder)
	local ok, err = pcall(FS.writefile, self.Folder .. "/autoload.txt", cleanName(name))
	if not ok then return false, tostring(err) end
	return true
end

function Cipher:GetAutoload()
	if not (FS.isfile and FS.readfile) then return nil end
	local path = self.Folder .. "/autoload.txt"
	local okExists, exists = pcall(FS.isfile, path)
	if not (okExists and exists) then return nil end
	local ok, name = pcall(FS.readfile, path)
	if ok and type(name) == "string" and name ~= "" then return name end
	return nil
end

function Cipher:LoadAutoloadConfig()
	local name = self:GetAutoload()
	if not name then return false, "no autoload config set" end
	return self:LoadConfig(name)
end

--============================================================
-- SETTINGS TAB (ready-made)
--============================================================
function Window:AddSettingsTab(opts)
	opts = opts or {}
	local win = self
	local tab = self:AddTab({ Name = opts.Name or "settings", Icon = opts.Icon, Description = "interface, configs & system info" })

	------------------------------------------------ interface
	local ui = tab:AddSection("interface")
	local themeDrop = ui:AddDropdown({
		Name = "Theme",
		Options = Cipher.ThemeOrder,
		Default = Cipher.ThemeName,
		Callback = function(name)
			if name and name ~= Cipher.ThemeName then Cipher:SetTheme(name) end
		end,
	})
	local accentPicker = ui:AddColorPicker({
		Name = "Accent Color",
		Default = Cipher.Theme.Accent,
		Callback = function(color) Cipher:SetAccent(color, true) end,
	})
	Cipher:OnThemeChanged(function(name, theme)
		if win.Destroyed then return end
		if themeDrop.Value ~= name and Util.find(Cipher.ThemeOrder, name) then themeDrop:Set(name, true) end
		if not accentPicker.Rainbow and Util.toHex(accentPicker.Value) ~= Util.toHex(theme.Accent) then
			accentPicker:Set(theme.Accent, true)
		end
	end)
	ui:AddKeybind({
		Name = "Menu Keybind",
		Description = "shows / hides the window",
		Default = self.ToggleKey,
		Mode = "Press",
		ChangedCallback = function(key) win:SetToggleKey(key) end,
	})
	ui:AddToggle({ Name = "Keybind List", Default = false, Callback = function(v) win:SetKeybindList(v) end })
	ui:AddToggle({ Name = "CRT Scanline", Default = self._sweep.Visible, Callback = function(v) win:SetScanline(v) end })
	ui:AddSlider({ Name = "UI Scale", Min = 60, Max = 140, Default = 100, Increment = 5, Suffix = "%", Callback = function(v) win:SetScale(v / 100) end })
	ui:AddButton({ Name = "Center Window", Callback = function() win:Center() end })
	ui:AddButton({ Name = "Open Terminal", Callback = function() win:ToggleTerminal(true) end })
	ui:AddButton({ Name = "Unload", Description = "destroys the ui and disconnects everything", Confirm = true, Callback = function() win:Destroy() end })

	------------------------------------------------ configs
	local cfg = tab:AddSection("configs")
	if not Cipher:HasFileSystem() then
		cfg:AddParagraph({ Title = "unavailable", Content = "This executor does not expose file functions (writefile / readfile), so configs cannot be saved." })
	else
		local nameInput = cfg:AddInput({ Name = "Config Name", Placeholder = "my_config", Width = 160 })
		local list = cfg:AddDropdown({ Name = "Saved Configs", Options = Cipher:ListConfigs(), Search = true })
		local autoLabel = cfg:AddLabel({ Text = "autoload: " .. (Cipher:GetAutoload() or "none") })

		local function refresh()
			list:Refresh(Cipher:ListConfigs())
			autoLabel:Set("autoload: " .. (Cipher:GetAutoload() or "none"))
		end
		local function report(action, ok, err, name)
			if ok then
				Cipher:Notify({ Title = "config", Content = action .. " '" .. name .. "'", Type = "success", Duration = 3 })
			else
				Cipher:Notify({ Title = "config", Content = tostring(err), Type = "error", Duration = 4 })
			end
		end
		local function selected()
			local n = cleanName(nameInput.Value)
			if n == "" and list.Value then n = tostring(list.Value) end
			return n
		end

		cfg:AddButton({ Name = "Save Config", Callback = function()
			local n = selected()
			local ok, err = Cipher:SaveConfig(n)
			report("saved", ok, err, n)
			refresh()
		end })
		cfg:AddButton({ Name = "Load Config", Callback = function()
			local n = list.Value and tostring(list.Value) or selected()
			local ok, err = Cipher:LoadConfig(n)
			report("loaded", ok, err, n)
		end })
		cfg:AddButton({ Name = "Delete Config", Confirm = true, Callback = function()
			local n = list.Value and tostring(list.Value) or selected()
			local ok, err = Cipher:DeleteConfig(n)
			report("deleted", ok, err, n)
			refresh()
		end })
		cfg:AddButton({ Name = "Set As Autoload", Callback = function()
			local n = list.Value and tostring(list.Value) or selected()
			if n == "" then report("", false, "pick a config first", n) return end
			local ok, err = Cipher:SetAutoload(n)
			report("autoload set to", ok, err, n)
			refresh()
		end })
		cfg:AddButton({ Name = "Refresh List", Callback = refresh })
	end

	------------------------------------------------ about
	local about = tab:AddSection("about")
	about:AddParagraph({
		Title = "Cipher v" .. Cipher.Version,
		Content = "executor: " .. Cipher:GetExecutor()
			.. "\nplayer: " .. LocalPlayer.Name .. " (" .. LocalPlayer.UserId .. ")"
			.. "\nplace: " .. tostring(game.PlaceId)
			.. "\ntoggle: " .. Util.keyName(self.ToggleKey),
	})
	return tab
end

--============================================================
-- LIBRARY-LEVEL API
--============================================================
Cipher._unloadCallbacks = {}

function Cipher:GetExecutor()
	if identifyExecFn then
		local ok, name, version = pcall(identifyExecFn)
		if ok and name then
			return tostring(name) .. (version and (" " .. tostring(version)) or "")
		end
	end
	return "unknown"
end

function Cipher:OnUnload(fn)
	table.insert(self._unloadCallbacks, fn)
end

function Cipher:Unload()
	if self.Unloaded then return end
	self.Unloaded = true
	for i = #self.Windows, 1, -1 do
		local w = self.Windows[i]
		pcall(function() w:Destroy(true) end)
	end
	for _, conn in ipairs(self._connections) do pcall(function() conn:Disconnect() end) end
	self._connections = {}
	if Overlay.Gui then pcall(function() Overlay.Gui:Destroy() end) end
	Overlay.Gui = nil
	for _, fn in ipairs(self._unloadCallbacks) do safeCall(fn) end
end

-- callback errors are also written to any open window terminal
Cipher._onCallbackError = function(err)
	for _, w in ipairs(Cipher.Windows) do
		if w._terminal then
			pcall(function() w._terminal.Console:Error("callback: " .. err) end)
		end
	end
end

return Cipher
