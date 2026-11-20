--[[
	============================================================
	 THINHHACKER v2.0  |  BLOX FRUITS HUB  (Tiếng Việt)
	============================================================
	 Bản nâng cấp từ v1.0.0 - sửa lỗi + thêm chức năng
	 Yêu cầu : Executor có loadstring + writefile
	           (Delta, Xeno, Solara, Wave, Codex, Fluxus, AWP...)
	 Dùng    : dán cả file .lua này vào executor rồi Execute
	           (hoặc loadstring(game:HttpGet("link_raw"))() nếu
	            bạn up file lên GitHub/raw rồi lấy link)
	 File    : ThinhHacker_v2.0.lua  (UTF-8, không BOM)
	============================================================
	 MỞ FILE BẰNG NOTEPAD ĐỂ SỬA DANH SÁCH KEY
	============================================================

	 --- NHỮNG GÌ ĐÃ SỬA SO VỚI v1.0 ---
	 1. Tách bộ đếm thời gian riêng cho từng module (v1 dùng chung
	    lastAttack nên Auto Farm và Auto Boss giành nhau -> đánh rất chậm)
	 2. Sửa lỗi "invalid key to next" khi module bị lỗi giữa vòng lặp
	 3. TP chỉ khi ở xa quái (>6m) - hết giật/nhấp nháy nhân vật
	 4. Quét rương/trái cây có giới hạn tần suất (v1 quét 60 lần/giây -> lag)
	 5. Dropdown danh sách dài có thanh cuộn riêng, không tràn trang
	 6. ESP dùng bảng đăng ký - xoá sạch, không sót billboard
	 7. Fly mượt hơn (2 kiểu: CFrame / BodyVelocity)
	 8. Menu tự thu nhỏ trên điện thoại + nút mở nổi
	 9. Thêm: Anti-AFK, Auto Rejoin, Auto cộng điểm, Mua Haki,
	    Đi Đảo 2/3, TP người chơi, lưu cả trạng thái bật/tắt
	10. Key hệ thống: đọc thêm key từ file ngoài, hiện hạn dùng,
	    nút copy HWID để gửi cho admin
]]

--==============================================================
-- CẤU HÌNH NHANH (sửa ở đây)
--==============================================================
-- Link raw của chính file này (dùng cho Auto Rejoin). Để "" nếu không dùng.
local SCRIPT_URL = ""

-- Key có sẵn
local KEY_LIST = {
	["THINH-VIP-2026"]   = { days = 365, note = "Key VIP 1 năm" },
	["THINH-1THANG"]     = { days = 30,  note = "Key 1 tháng" },
	["THINH-TEST"]       = { days = 1,   note = "Key test 1 ngày" },
	["THINHHACKER-FREE"] = { days = 7,   note = "Key free 7 ngày" },
	["THINH-VIP-VINHVIEN"]= { days = 3650, note = "Key vĩnh viễn" },
}

local KEY_FILE    = "ThinhHacker_key.txt"
local CONFIG_FILE = "ThinhHacker_config.json"
local EXTRA_KEY_FILE = "ThinhHacker_keys.txt"  -- mỗi dòng: KEY|số_ngày|ghi_chú

--==============================================================
-- 0. DỊCH VỤ
--==============================================================
if not game:IsLoaded() then game.Loaded:Wait() end
repeat task.wait() until game:IsLoaded()

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local Lighting          = game:GetService("Lighting")
local VirtualUser       = game:GetService("VirtualUser")
local TeleportService   = game:GetService("TeleportService")
local HttpService       = game:GetService("HttpService")
local Workspace         = game:GetService("Workspace")
local StarterGui        = game:GetService("StarterGui")
local CoreGui           = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do task.wait(0.2); LocalPlayer = Players.LocalPlayer end

local cloneref = cloneref or function(o) return o end
local ggetenv  = getgenv or function() return _G end

-- dọn phiên bản cũ
pcall(function()
	if ggetenv().ThinhHacker and ggetenv().ThinhHacker.Destroy then
		ggetenv().ThinhHacker.Destroy()
	end
end)
local function cleanOldGuis(root)
	pcall(function()
		for _, g in ipairs(root:GetChildren()) do
			if string.sub(g.Name, 1, 3) == "TH_" then g:Destroy() end
		end
	end)
end
cleanOldGuis(CoreGui)
if gethui then pcall(function() cleanOldGuis(gethui()) end) end
pcall(function() cleanOldGuis(LocalPlayer:WaitForChild("PlayerGui", 2)) end)

ggetenv().ThinhHacker = { Loaded = true, Version = "2.0.1" }

-- gom các kết nối toàn cục để ngắt khi chạy lại / đóng menu
local Conns = {}
local function track(c) Conns[#Conns + 1] = c return c end
local function disconnectAll()
	for _, c in ipairs(Conns) do pcall(function() c:Disconnect() end) end
	Conns = {}
end

--==============================================================
-- 1. HỆ THỐNG KEY
--==============================================================
local function getHWID()
	local ok, id = pcall(function() return gethwid() end)
	if ok and type(id) == "string" and #id > 4 then return id end
	ok, id = pcall(function() return game:GetService("RbxAnalyticsService"):GetClientId() end)
	if ok and type(id) == "string" and #id > 4 then return id end
	return "PC-" .. tostring(LocalPlayer.UserId)
end

local HWID = getHWID()

local function canFile()
	return type(writefile) == "function" and type(readfile) == "function"
end

-- nạp key mở rộng từ file ngoài (mỗi dòng KEY|days|note)
local function loadExtraKeys()
	if not canFile() then return end
	if type(isfile) == "function" and not isfile(EXTRA_KEY_FILE) then return end
	local ok, raw = pcall(readfile, EXTRA_KEY_FILE)
	if not ok or not raw then return end
	for rawLine in string.gmatch(raw, "[^\r\n]+") do
		local line = string.gsub(rawLine, "^%s*(.-)%s*$", "%1")
		if line ~= "" and string.sub(line, 1, 1) ~= "#" then
			local k, d, n = string.match(line, "^(.-)|(%-?%d+)|?(.*)$")
			if k and d and KEY_LIST[k] == nil then
				KEY_LIST[k] = { days = tonumber(d) or 1, note = (n ~= "" and n) or "Key ngoài" }
			end
		end
	end
end
loadExtraKeys()

local function saveKey(key, expire)
	if not canFile() then return end
	pcall(function()
		writefile(KEY_FILE, key .. "|" .. tostring(expire) .. "|" .. HWID)
	end)
end

local function loadSavedKey()
	if not canFile() then return nil end
	if type(isfile) == "function" and not isfile(KEY_FILE) then return nil end
	local ok, data = pcall(readfile, KEY_FILE)
	if not ok or not data then return nil end
	local key, expire, hwid = string.match(data, "^(.-)|(%-?%d+)|(.*)$")
	if not key or not expire then return nil end
	if KEY_LIST[key] == nil then return nil end
	if tonumber(expire) <= os.time() then return nil end
	if hwid ~= HWID then return nil end
	return key, tonumber(expire)
end

local function validateKey(input)
	local key = string.gsub(tostring(input or ""), "%s", "")
	if key == "" then return false, nil, "Chưa nhập key kìa bạn!" end
	local info = KEY_LIST[key]
	if not info then return false, nil, "Key không hợp lệ hoặc đã bị xoá!" end
	local expire = os.time() + ((tonumber(info.days) or 1) * 86400)
	return true, expire, info.note or ""
end

local function fmtDate(t)
	return os.date("%d/%m/%Y", t)
end

local function daysLeft(expire)
	local d = math.floor((expire - os.time()) / 86400)
	if d < 0 then d = 0 end
	return d
end

--==============================================================
-- 2. THEME + TIỆN ÍCH DỰNG UI
--==============================================================
local Theme = {
	Bg      = Color3.fromRGB(12, 12, 16),
	Panel   = Color3.fromRGB(20, 20, 27),
	Elem    = Color3.fromRGB(27, 27, 36),
	Hover   = Color3.fromRGB(36, 36, 48),
	Accent  = Color3.fromRGB(0, 200, 255),
	Accent2 = Color3.fromRGB(160, 60, 255),
	Text    = Color3.fromRGB(240, 240, 246),
	Sub     = Color3.fromRGB(145, 145, 162),
	Stroke  = Color3.fromRGB(48, 48, 64),
	Ok      = Color3.fromRGB(0, 220, 130),
	Bad     = Color3.fromRGB(255, 70, 90),
	Warn    = Color3.fromRGB(255, 190, 60),
}

local F      = Enum.Font.GothamMedium
local F_BOLD = Enum.Font.GothamBold

local function Create(class, props)
	local obj = Instance.new(class)
	if props then
		for k, v in next, props do
			if k ~= "Parent" then obj[k] = v end
		end
		if props.Parent then obj.Parent = props.Parent end
	end
	return obj
end

local function Corner(inst, r)
	Create("UICorner", { CornerRadius = UDim.new(0, r or 8), Parent = inst })
end

local function StrokeIt(inst, color, thick)
	Create("UIStroke", { Color = color or Theme.Stroke, Thickness = thick or 1, Parent = inst })
end

local function parentGui(gui)
	local ok = pcall(function()
		if gethui then
			gui.Parent = gethui()
		elseif syn and syn.protect_gui then
			syn.protect_gui(gui)
			gui.Parent = CoreGui
		else
			gui.Parent = CoreGui
		end
	end)
	if not ok or not gui.Parent then
		pcall(function() gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end)
	end
end

local function makeGui(name)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 999
	parentGui(gui)
	return gui
end

--==============================================================
-- 3. THÔNG BÁO (xếp chồng, không đè nhau)
--==============================================================
local notifGui = makeGui("TH_Notify")
local notifSlots = {}

local function notify(title, text, duration)
	duration = duration or 3
	local idx = 0
	while notifSlots[idx] do idx = idx + 1 end
	notifSlots[idx] = true
	local yOff = 20 + idx * 66

	local holder = Create("Frame", {
		Parent = notifGui,
		Size = UDim2.fromOffset(280, 58),
		Position = UDim2.new(1, 300, 0, yOff),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
	})
	Corner(holder, 10)
	StrokeIt(holder, Theme.Accent, 1)

	Create("Frame", {
		Parent = holder,
		Size = UDim2.new(0, 3, 1, -16),
		Position = UDim2.new(0, 8, 0, 8),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
	})
	Corner(holder:FindFirstChildOfClass("Frame"), 2)

	Create("TextLabel", {
		Parent = holder,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 18, 0, 7),
		Size = UDim2.new(1, -26, 0, 16),
		Font = F_BOLD, Text = title, TextSize = 12,
		TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
	})
	Create("TextLabel", {
		Parent = holder,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 18, 0, 25),
		Size = UDim2.new(1, -26, 0, 26),
		Font = F, Text = text, TextSize = 11,
		TextColor3 = Theme.Sub, TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	})

	TweenService:Create(holder, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
		Position = UDim2.new(1, -295, 0, yOff),
	}):Play()

	task.delay(duration, function()
		TweenService:Create(holder, TweenInfo.new(0.22), {
			Position = UDim2.new(1, 300, 0, yOff),
		}):Play()
		task.wait(0.25)
		holder:Destroy()
		notifSlots[idx] = nil
	end)
end
ggetenv().ThinhHacker.Notify = notify

--==============================================================
-- 3.5. BIẾN TRẠNG THÁI (phải khai báo trước UI vì component dùng tới)
--==============================================================
local State = {
	toggles = {},
	values = {},
	boss = "Don Swan",
	stat = "Melee",
	island = "Starter Island",
	autoQuest = true,
	farmAnywhere = true,
	keepStats = true,
	syncToggle = true,
}

local Settings = {
	farmRange  = 300,
	tpDist     = 6,
	speed      = 16,
	jump       = 50,
	flySpeed   = 60,
	skillDelay = 0.45,
	antiAfk    = true,
}

--==============================================================
-- 4. UI LIBRARY
--==============================================================
local Lib = {}

function Lib.newWindow(title, subtitle, destroyFn)
	local gui = makeGui("TH_UI")

	local main = Create("Frame", {
		Parent = gui,
		Name = "Main",
		Size = UDim2.fromOffset(660, 470),
		Position = UDim2.new(0.5, -330, 0.5, -235),
		BackgroundColor3 = Theme.Bg,
		BorderSizePixel = 0,
	})
	Corner(main, 12)
	StrokeIt(main, Color3.fromRGB(60, 60, 85), 1.5)

	-- tự thu nhỏ trên màn hình nhỏ
	local scaleObj = Create("UIScale", { Parent = main })
	local function applyScale()
		local vp = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
		local s = math.min(vp.X / 720, vp.Y / 540)
		scaleObj.Scale = math.clamp(s, 0.55, 1)
	end
	applyScale()
	local vpConn
	pcall(function()
		vpConn = Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyScale)
	end)

	-- thanh tiêu đề
	local topbar = Create("Frame", {
		Parent = main,
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	})
	Corner(topbar, 12)
	Create("Frame", {
		Parent = topbar, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -14),
		BackgroundColor3 = Theme.Panel, BorderSizePixel = 0,
	})

	local gradTitle = Create("TextLabel", {
		Parent = topbar,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 16, 0, 5),
		Size = UDim2.new(0, 320, 0, 20),
		Font = F_BOLD, Text = title, TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 255, 255),
	})
	Create("UIGradient", {
		Parent = gradTitle,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 220, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 90, 255)),
		}),
	})

	local subLabel = Create("TextLabel", {
		Parent = topbar,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 16, 0, 26),
		Size = UDim2.new(0, 400, 0, 14),
		Font = F, Text = subtitle or "", TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.Sub,
	})

	local closeBtn = Create("TextButton", {
		Parent = topbar,
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.new(1, -36, 0, 10),
		BackgroundColor3 = Color3.fromRGB(45, 25, 30),
		Text = "✕", Font = F_BOLD, TextSize = 14,
		TextColor3 = Theme.Bad, AutoButtonColor = false, BorderSizePixel = 0,
	})
	Corner(closeBtn, 7)

	local minBtn = Create("TextButton", {
		Parent = topbar,
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.new(1, -68, 0, 10),
		BackgroundColor3 = Theme.Elem,
		Text = "—", Font = F_BOLD, TextSize = 13,
		TextColor3 = Theme.Sub, AutoButtonColor = false, BorderSizePixel = 0,
	})
	Corner(minBtn, 7)

	-- kéo cửa sổ
	local dragging, dragInput, dragStart, startPos
	topbar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = main.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	topbar.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and input == dragInput then
			local delta = input.Position - dragStart
			main.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)

	-- sidebar
	local sidebar = Create("Frame", {
		Parent = main,
		Size = UDim2.new(0, 152, 1, -62),
		Position = UDim2.new(0, 10, 0, 54),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
	})
	Corner(sidebar, 10)

	local tabList = Create("ScrollingFrame", {
		Parent = sidebar,
		Size = UDim2.new(1, -8, 1, -16),
		Position = UDim2.new(0, 4, 0, 8),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = Theme.Accent,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	})
	Create("UIListLayout", {
		Parent = tabList, Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	Create("UIPadding", { Parent = tabList, PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), PaddingBottom = UDim.new(0, 6) })

	-- vùng nội dung
	local contentHolder = Create("Frame", {
		Parent = main,
		Size = UDim2.new(1, -172, 1, -62),
		Position = UDim2.new(0, 162, 0, 54),
		BackgroundTransparency = 1,
	})

	local tabs, pages = {}, {}
	local selected

	local function selectTab(name)
		if selected == name then return end
		selected = name
		for n, page in next, pages do
			page.Visible = (n == name)
		end
		for n, btn in next, tabs do
			if n == name then
				TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = Theme.Elem }):Play()
				btn.TextColor3 = Theme.Accent
			else
				TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = Theme.Panel }):Play()
				btn.TextColor3 = Theme.Sub
			end
		end
	end

	local function tab(name, icon)
		local btn = Create("TextButton", {
			Parent = tabList,
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundColor3 = Theme.Panel,
			Text = (icon and (icon .. "  ") or "") .. name,
			Font = F, TextSize = 12, TextColor3 = Theme.Sub,
			TextXAlignment = Enum.TextXAlignment.Left,
			AutoButtonColor = false, BorderSizePixel = 0,
		})
		Corner(btn, 8)
		Create("UIPadding", { Parent = btn, PaddingLeft = UDim.new(0, 10) })

		local page = Create("ScrollingFrame", {
			Parent = contentHolder,
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Visible = false,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Theme.Accent,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
		})
		Create("UIListLayout", {
			Parent = page, Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
		Create("UIPadding", { Parent = page, PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 12) })

		tabs[name] = btn
		pages[name] = page
		btn.MouseButton1Click:Connect(function() selectTab(name) end)
		btn.MouseEnter:Connect(function()
			if selected ~= name then
				TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = Theme.Hover }):Play()
			end
		end)
		btn.MouseLeave:Connect(function()
			if selected ~= name then
				TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = Theme.Panel }):Play()
			end
		end)
		return page
	end

	-- nút nổi để mở lại menu sau khi thu nhỏ (điện thoại không có RightShift)
	local floatGui = makeGui("TH_Float")
	local floatBtn = Create("TextButton", {
		Parent = floatGui,
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.new(0, 12, 0.5, -22),
		BackgroundColor3 = Theme.Panel,
		Text = "TH", Font = F_BOLD, TextSize = 14,
		TextColor3 = Theme.Accent, AutoButtonColor = false, BorderSizePixel = 0,
		Visible = false,
	})
	Corner(floatBtn, 22)
	StrokeIt(floatBtn, Theme.Accent, 1.5)

	local function toggleVisible()
		main.Visible = not main.Visible
		floatBtn.Visible = not main.Visible
	end

	floatBtn.MouseButton1Click:Connect(toggleVisible)
	minBtn.MouseButton1Click:Connect(toggleVisible)
	closeBtn.MouseButton1Click:Connect(function()
		gui:Destroy()
		floatGui:Destroy()
		if vpConn then vpConn:Disconnect() end
		if destroyFn then pcall(destroyFn) end
	end)

	return {
		Gui = gui,
		Main = main,
		Tab = tab,
		Select = selectTab,
		Toggle = toggleVisible,
		SetSubtitle = function(t) subLabel.Text = t end,
		Destroy = function()
			if vpConn then vpConn:Disconnect() end
			gui:Destroy()
			floatGui:Destroy()
		end,
	}
end

--=========== COMPONENT ============
local function section(page, text)
	local holder = Create("Frame", {
		Parent = page,
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
	})
	Create("TextLabel", {
		Parent = holder,
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		Font = F_BOLD, Text = text, TextSize = 12,
		TextColor3 = Theme.Accent, TextXAlignment = Enum.TextXAlignment.Left,
	})
	Create("Frame", {
		Parent = holder,
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 0, 22),
		BackgroundColor3 = Theme.Stroke, BorderSizePixel = 0,
	})
	return holder
end

-- Toggle có key để lưu cấu hình
local function toggle(page, key, text, default, callback)
	local row = Create("Frame", {
		Parent = page,
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = Theme.Elem, BorderSizePixel = 0,
	})
	Corner(row, 8)
	StrokeIt(row)

	Create("TextLabel", {
		Parent = row,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 12, 0, 0),
		Size = UDim2.new(1, -70, 1, 0),
		Font = F, Text = text, TextSize = 12,
		TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = false,
	})

	local knobBg = Create("Frame", {
		Parent = row,
		Size = UDim2.fromOffset(38, 20),
		Position = UDim2.new(1, -50, 0.5, -10),
		BackgroundColor3 = Color3.fromRGB(50, 50, 64),
		BorderSizePixel = 0,
	})
	Corner(knobBg, 10)

	local knob = Create("Frame", {
		Parent = knobBg,
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.new(0, 3, 0.5, -7),
		BackgroundColor3 = Color3.fromRGB(150, 150, 165),
		BorderSizePixel = 0,
	})
	Corner(knob, 7)

	local state = default and true or false

	local function render()
		if state then
			TweenService:Create(knobBg, TweenInfo.new(0.15), { BackgroundColor3 = Theme.Accent }):Play()
			TweenService:Create(knob, TweenInfo.new(0.15), {
				Position = UDim2.new(0, 21, 0.5, -7),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			}):Play()
		else
			TweenService:Create(knobBg, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(50, 50, 64) }):Play()
			TweenService:Create(knob, TweenInfo.new(0.15), {
				Position = UDim2.new(0, 3, 0.5, -7),
				BackgroundColor3 = Color3.fromRGB(150, 150, 165),
			}):Play()
		end
	end
	render()

	local clickable = Create("TextButton", {
		Parent = row, Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, Text = "",
	})
	clickable.MouseButton1Click:Connect(function()
		state = not state
		render()
		if key then State[key] = state end
		if callback then pcall(callback, state) end
	end)

	local api = {
		Set = function(v, fire)
			state = v and true or false
			render()
			if key then State[key] = state end
			if fire and callback then pcall(callback, state) end
		end,
		Get = function() return state end,
		Key = key,
	}
	if key then State[key] = state end
	return api
end

local function button(page, text, callback, color, height)
	local btn = Create("TextButton", {
		Parent = page,
		Size = UDim2.new(1, 0, 0, height or 32),
		BackgroundColor3 = Theme.Elem,
		Font = F, Text = text, TextSize = 12,
		TextColor3 = color or Theme.Text,
		AutoButtonColor = false, BorderSizePixel = 0,
	})
	Corner(btn, 8)
	StrokeIt(btn)
	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = Theme.Hover }):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = Theme.Elem }):Play()
	end)
	btn.MouseButton1Click:Connect(function()
		if callback then
			local ok, err = pcall(callback)
			if not ok then notify("Lỗi", tostring(err), 4) end
		end
	end)
	return btn
end

local function label(page, text, height)
	local lbl = Create("TextLabel", {
		Parent = page,
		Size = UDim2.new(1, 0, 0, height or 44),
		BackgroundColor3 = Theme.Elem,
		Font = F, Text = text, TextSize = 11,
		TextColor3 = Theme.Sub,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true, BorderSizePixel = 0,
	})
	Corner(lbl, 8)
	Create("UIPadding", {
		Parent = lbl,
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 6),
	})
	return lbl
end

local function slider(page, text, min, max, default, callback)
	local row = Create("Frame", {
		Parent = page,
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = Theme.Elem, BorderSizePixel = 0,
	})
	Corner(row, 8)
	StrokeIt(row)

	Create("TextLabel", {
		Parent = row,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 12, 0, 4),
		Size = UDim2.new(1, -60, 0, 16),
		Font = F, Text = text, TextSize = 12,
		TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
	})

	local valLabel = Create("TextLabel", {
		Parent = row,
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -60, 0, 4),
		Size = UDim2.new(0, 48, 0, 16),
		Font = F_BOLD, Text = tostring(default), TextSize = 12,
		TextColor3 = Theme.Accent, TextXAlignment = Enum.TextXAlignment.Right,
	})

	local bar = Create("Frame", {
		Parent = row,
		Size = UDim2.new(1, -24, 0, 5),
		Position = UDim2.new(0, 12, 0, 30),
		BackgroundColor3 = Color3.fromRGB(48, 48, 62),
		BorderSizePixel = 0,
	})
	Corner(bar, 3)

	local fill = Create("Frame", {
		Parent = bar,
		Size = UDim2.new((default - min) / (max - min), 0, 1, 0),
		BackgroundColor3 = Theme.Accent, BorderSizePixel = 0,
	})
	Corner(fill, 3)

	local value = default
	local dragging = false

	local function setFromX(x)
		local abs = bar.AbsolutePosition.X
		local size = bar.AbsoluteSize.X
		if size <= 0 then return end
		local pct = math.clamp((x - abs) / size, 0, 1)
		value = math.floor(min + (max - min) * pct + 0.5)
		fill.Size = UDim2.new(pct, 0, 1, 0)
		valLabel.Text = tostring(value)
		if callback then pcall(callback, value) end
	end

	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	return {
		Set = function(v, fire)
			value = v
			valLabel.Text = tostring(v)
			fill.Size = UDim2.new((v - min) / (max - min), 0, 1, 0)
			if fire and callback then pcall(callback, v) end
		end,
		Get = function() return value end,
	}
end

-- Dropdown có thanh cuộn riêng (danh sách dài không tràn trang)
local function dropdown(page, text, options, default, callback)
	local holder = Create("Frame", {
		Parent = page,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Theme.Elem,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	})
	Corner(holder, 8)
	StrokeIt(holder)

	local head = Create("TextButton", {
		Parent = holder,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
	})
	Create("TextLabel", {
		Parent = head,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 12, 0, 0),
		Size = UDim2.new(0.45, 0, 1, 0),
		Font = F, Text = text, TextSize = 12,
		TextColor3 = Theme.Sub, TextXAlignment = Enum.TextXAlignment.Left,
	})
	local cur = Create("TextLabel", {
		Parent = head,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 118, 0, 0),
		Size = UDim2.new(1, -158, 1, 0),
		Font = F_BOLD, Text = tostring(default or (options[1] or "")), TextSize = 12,
		TextColor3 = Theme.Accent, TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	Create("TextLabel", {
		Parent = head,
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -30, 0, 0),
		Size = UDim2.new(0, 24, 1, 0),
		Font = F_BOLD, Text = "▾", TextSize = 12,
		TextColor3 = Theme.Sub,
	})

	local list = Create("ScrollingFrame", {
		Parent = holder,
		Position = UDim2.new(0, 0, 0, 34),
		Size = UDim2.new(1, 0, 1, -34),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Accent,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	})
	Create("UIListLayout", { Parent = list, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder })
	Create("UIPadding", {
		Parent = list,
		PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
	})

	local open = false
	local selected = default or options[1]
	local listHeight = math.min(#options * 29 + 8, 168)

	local function closeList()
		open = false
		TweenService:Create(holder, TweenInfo.new(0.15), { Size = UDim2.new(1, 0, 0, 34) }):Play()
	end

	for _, opt in ipairs(options) do
		local b = Create("TextButton", {
			Parent = list,
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundColor3 = Color3.fromRGB(34, 34, 45),
			Font = F, Text = tostring(opt), TextSize = 11,
			TextColor3 = Theme.Text, AutoButtonColor = false, BorderSizePixel = 0,
		})
		Corner(b, 6)
		b.MouseButton1Click:Connect(function()
			selected = opt
			cur.Text = tostring(opt)
			closeList()
			if callback then pcall(callback, opt) end
		end)
	end

	head.MouseButton1Click:Connect(function()
		if open then
			closeList()
		else
			open = true
			TweenService:Create(holder, TweenInfo.new(0.18), { Size = UDim2.new(1, 0, 0, 34 + listHeight) }):Play()
		end
	end)

	return {
		Get = function() return selected end,
		Set = function(v)
			selected = v
			cur.Text = tostring(v)
		end,
	}
end

local function textbox(page, placeholder, callback)
	local box = Create("Frame", {
		Parent = page,
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = Theme.Elem, BorderSizePixel = 0,
	})
	Corner(box, 8)
	StrokeIt(box)
	local tb = Create("TextBox", {
		Parent = box,
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.new(0, 10, 0, 0),
		BackgroundTransparency = 1,
		Font = F, Text = "", PlaceholderText = placeholder,
		PlaceholderColor3 = Theme.Sub,
		TextColor3 = Theme.Text, TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
	})
	tb.FocusLost:Connect(function(enter)
		if enter and callback then pcall(callback, tb.Text) end
	end)
	return tb
end

--==============================================================
-- 5. HÀM HỖ TRỢ GAME
--==============================================================
local function getChar()
	local c = LocalPlayer.Character
	if c and c:FindFirstChild("HumanoidRootPart") then return c end
	return nil
end

local function getHRP()
	local c = getChar()
	return c and c:FindFirstChild("HumanoidRootPart") or nil
end

local function getHum()
	local c = getChar()
	return c and c:FindFirstChildOfClass("Humanoid") or nil
end

-- R15 mặc định dùng JumpHeight; phải bật UseJumpPower thì JumpPower mới có tác dụng
local function applyJump(hum, v)
	pcall(function() hum.UseJumpPower = true end)
	hum.JumpPower = v
end

local function getLevel()
	local data = LocalPlayer:FindFirstChild("Data")
	if data then
		local lv = data:FindFirstChild("Level")
		if lv and lv.Value then return lv.Value end
	end
	local attr = LocalPlayer:GetAttribute("Level")
	if type(attr) == "number" then return attr end
	local ok, v = pcall(function()
		local txt = LocalPlayer.PlayerGui.Main.Level.LevelFrame.Text
		return tonumber(string.match(txt, "%d+"))
	end)
	if ok and v then return v end
	return 1
end

local function getCommF()
	local r = ReplicatedStorage:FindFirstChild("Remotes")
	local c = r and r:FindFirstChild("CommF_")
	if c then return c end
	return nil
end

-- quét quái: Workspace.Enemies (1 cấp con + 1 cấp cháu)
local function getEnemies()
	local out = {}
	local folder = Workspace:FindFirstChild("Enemies")
	if not folder then return out end
	local function scan(container)
		for _, m in ipairs(container:GetChildren()) do
			if m:IsA("Model") then
				local hum = m:FindFirstChildOfClass("Humanoid")
				local root = m:FindFirstChild("HumanoidRootPart")
				if hum and root and hum.Health > 0 then
					table.insert(out, { model = m, hum = hum, root = root, name = m.Name })
				end
			end
		end
	end
	scan(folder)
	local kids = folder:GetChildren()
	for _, sub in ipairs(kids) do
		if sub:IsA("Model") and sub:FindFirstChildOfClass("Humanoid") == nil then
			scan(sub)
		end
	end
	return out
end

local function findNearestEnemy(range, nameFilter)
	local hrp = getHRP()
	if not hrp then return nil end
	local best, bestDist = nil, range or 5000
	for _, e in ipairs(getEnemies()) do
		if not nameFilter or e.name == nameFilter then
			local d = (e.root.Position - hrp.Position).Magnitude
			if d < bestDist then best, bestDist = e, d end
		end
	end
	return best, bestDist
end

local function tpTo(cf)
	local char = getChar()
	if not char then return false end
	pcall(function() char:PivotTo(cf) end)
	return true
end

-- chọn vũ khí: ưu tiên kiếm/súng, tránh nhặt nhầm trái cây
local WEAPON_HINTS = { "Sword", "Blade", "Saber", "Katana", "Cutlass", "Gun", "Rifle", "Pistol", "Buso", "Haki", "Cursed", "Dark", "Dual", "Trident", "Spear" }

local function scoreTool(tool)
	local nm = tool.Name
	for i, hint in ipairs(WEAPON_HINTS) do
		if string.find(nm, hint, 1, true) then return 100 - i end
	end
	return 1
end

local function getWeapon()
	local char = getChar()
	if not char then return nil end
	local equipped, eqScore = nil, -1
	for _, t in ipairs(char:GetChildren()) do
		if t:IsA("Tool") then
			local s = scoreTool(t)
			if s > eqScore then equipped, eqScore = t, s end
		end
	end
	local bp = LocalPlayer:FindFirstChild("Backpack")
	local hum = getHum()
	if bp and hum then
		local pick, pickScore = nil, -1
		for _, t in ipairs(bp:GetChildren()) do
			if t:IsA("Tool") then
				local s = scoreTool(t)
				if s > pickScore then pick, pickScore = t, s end
			end
		end
		-- chỉ đổi khi vũ khí trong túi tốt hơn cái đang cầm
		if pick and pickScore > eqScore then
			pcall(function() hum:EquipTool(pick) end)
			return pick
		end
	end
	return equipped
end

-- tấn công: chỉ TP khi ở xa
local function attack(e, tpDist)
	if not e or not e.root then return end
	local char = getChar()
	local hrp = getHRP()
	if not char or not hrp then return end

	local dist = (hrp.Position - e.root.Position).Magnitude
	if dist > (tpDist or Settings.tpDist or 6) then
		pcall(function() char:PivotTo(e.root.CFrame * CFrame.new(0, 0, 3)) end)
	end

	local tool = getWeapon()
	if tool then
		pcall(function() tool:Activate() end)
	end

	if firetouchinterest then
		pcall(function()
			firetouchinterest(hrp, e.root, 0)
			firetouchinterest(hrp, e.root, 1)
		end)
	end

	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton1(Vector2.new(0, 0))
	end)
end

--==============================================================
-- 6. BỘ ĐIỀU PHỐI TÁC VỤ (mỗi module có nhịp riêng, lỗi tự tắt)
--==============================================================
local Tasks = {}

local function addTask(id, fn, interval)
	Tasks[id] = { fn = fn, interval = interval or 0, next = 0, errors = 0 }
end

local function stopTask(id)
	Tasks[id] = nil
end

local function stopAllTasks()
	Tasks = {}
end

local function taskRunning(id)
	return Tasks[id] ~= nil
end

track(RunService.Heartbeat:Connect(function()
	local now = os.clock()
	local broken = nil
	local snapshot = {}
	for id, t in next, Tasks do snapshot[#snapshot + 1] = { id, t } end
	for _, pair in ipairs(snapshot) do
		local id, t = pair[1], pair[2]
		if Tasks[id] == t and now >= t.next then
			t.next = now + (t.interval or 0)
			local ok, err = pcall(t.fn)
			if ok then
				t.errors = 0
			else
				t.errors = (t.errors or 0) + 1
				if t.errors >= 3 then
					broken = broken or {}
					table.insert(broken, { id = id, err = tostring(err) })
				end
			end
		end
	end
	if broken then
		for _, item in ipairs(broken) do
			if Tasks[item.id] then
				Tasks[item.id] = nil
				notify("Lỗi", item.id .. ": " .. item.err, 5)
				if State.syncToggle and State.toggles[item.id] then
					pcall(function() State.toggles[item.id].Set(false) end)
				end
			end
		end
	end
end))

--==============================================================
-- 7. DỮ LIỆU
--==============================================================
local QUESTS = {
	{ lv = 1,    name = "Bandit" },
	{ lv = 5,    name = "Monkey" },
	{ lv = 10,   name = "Gorilla" },
	{ lv = 15,   name = "Pirate" },
	{ lv = 30,   name = "Brute" },
	{ lv = 35,   name = "Desert Bandit" },
	{ lv = 40,   name = "Desert Officer" },
	{ lv = 55,   name = "Snow Bandit" },
	{ lv = 60,   name = "Snowman" },
	{ lv = 75,   name = "Chief Petty Officer" },
	{ lv = 90,   name = "Sky Bandit" },
	{ lv = 105,  name = "Dark Master" },
	{ lv = 120,  name = "Prisoner" },
	{ lv = 125,  name = "Dangerous Prisoner" },
	{ lv = 150,  name = "Toga Warrior" },
	{ lv = 175,  name = "Gladiator" },
	{ lv = 190,  name = "Military Soldier" },
	{ lv = 200,  name = "Military Spy" },
	{ lv = 225,  name = "Fishman Warrior" },
	{ lv = 250,  name = "Fishman Commando" },
	{ lv = 275,  name = "God's Guard" },
	{ lv = 300,  name = "Shanda" },
	{ lv = 325,  name = "Royal Squad" },
	{ lv = 350,  name = "Royal Soldier" },
	{ lv = 375,  name = "Galley Pirate" },
	{ lv = 400,  name = "Galley Captain" },
	{ lv = 425,  name = "Raider" },
	{ lv = 450,  name = "Mercenary" },
	{ lv = 475,  name = "Advanced Raider" },
	{ lv = 500,  name = "Fighter" },
	{ lv = 525,  name = "Sky Fighter" },
	{ lv = 550,  name = "Reborn Skeleton" },
	{ lv = 575,  name = "Living Zombie" },
	{ lv = 600,  name = "Demonic Soul" },
	{ lv = 625,  name = "Posessed Mummy" },
	{ lv = 650,  name = "Snow Trooper" },
	{ lv = 675,  name = "Winter Warrior" },
	{ lv = 700,  name = "Cursed Skeleton" },
	{ lv = 725,  name = "Ancient Vessel" },
	{ lv = 750,  name = "Reanimated Skeleton" },
	{ lv = 775,  name = "Soul Reaper" },
	{ lv = 800,  name = "Haunted Pirate" },
	{ lv = 850,  name = "Pirate Millionaire" },
	{ lv = 900,  name = "Pistol Billionaire" },
	{ lv = 950,  name = "Dragon Crew Archer" },
	{ lv = 1000, name = "Dragon Crew Warrior" },
	{ lv = 1050, name = "Hydra Enforcer" },
	{ lv = 1100, name = "Stone Pirate" },
	{ lv = 1150, name = "Lab Assistant" },
	{ lv = 1200, name = "Fenrir" },
	{ lv = 1250, name = "Reborn Pirate" },
	{ lv = 1300, name = "Reborn Soldier" },
	{ lv = 1350, name = "Marine Captain" },
	{ lv = 1400, name = "Marine Lieutenant" },
	{ lv = 1450, name = "Marine Commander" },
	{ lv = 1500, name = "Titanic Pirate" },
}

local BOSSES = {
	"Don Swan", "Cursed Captain", "rip_indra True Form", "Greybeard",
	"The Strongest", "Fajita", "Kilo Admiral", "Ice Admiral",
	"Longma", "Kitsune", "Dough King", "Soul Reaper",
}

local ISLANDS = {
	"Starter Island", "Marine Fortress", "Jungle", "Desert", "Snow Island",
	"Marineford", "Sky Island", "Prison", "Colosseum", "Underwater City",
	"Kingdom of Rose", "Green Zone", "Graveyard", "Haunted Castle",
	"Snow Mountain", "Hot and Cold", "Cursed Ship", "Ice Castle",
	"Forgotten Island", "Port Town", "Hydra Island", "Great Tree",
	"Floating Turtle", "Castle on the Sea", "Tiki Outpost", "Mansion",
	"Remote Island", "Sea of Treats",
}

local STATS = { "Melee", "Defense", "Sword", "Gun", "Demon Fruit" }

--==============================================================
-- 8. BIẾN TRẠNG THÁI (đã khai báo sớm ở trên, xem mục 3.5)
--==============================================================
State.boss = "Don Swan"
State.stat = "Melee"
State.island = "Starter Island"
State.autoQuest = true
State.farmAnywhere = true
State.keepStats = true

local lastQuestTry = 0

--==============================================================
-- 9. CHỨC NĂNG: FARM
--==============================================================
local function currentQuest()
	local lvl = getLevel()
	local pick = QUESTS[1]
	for _, q in ipairs(QUESTS) do
		if lvl >= q.lv then pick = q end
	end
	return pick
end

local function startQuest()
	local q = currentQuest()
	if not q then return end
	local commF = getCommF()
	if not commF then return end
	pcall(function() commF:InvokeServer("StartQuest", q.name, q.lv) end)
end

local function isQuestActive()
	local ok, res = pcall(function()
		local q = LocalPlayer.PlayerGui.Main.Quest
		return q and q.Visible
	end)
	return ok and res
end

local function startAutoFarm()
	if taskRunning("AutoFarm") then return end
	addTask("AutoFarm", function()
		local hrp = getHRP()
		if not hrp then return end
		local now = os.clock()

		if State.autoQuest and now - lastQuestTry > 1.5 then
			lastQuestTry = now
			if not isQuestActive() then
				startQuest()
				return
			end
		end

		local target = findNearestEnemy(Settings.farmRange)
		if not target and State.farmAnywhere then
			target = findNearestEnemy(100000)
		end
		if target then attack(target) end
	end, 0.1)
end

local CHEST_NAMES = { "Chest", "Chest1", "Chest2", "Chest3" }

local function findNearby(nameList, maxDist)
	local hrp = getHRP()
	if not hrp then return nil end
	local best, bestDist = nil, maxDist or 2000
	local function check(inst)
		local n = inst.Name
		local hit = false
		for _, cn in ipairs(nameList) do
			if n == cn then hit = true break end
		end
		if hit then
			local part = inst:IsA("BasePart") and inst
				or inst:FindFirstChild("HumanoidRootPart")
				or inst:FindFirstChild("Handle")
				or inst:FindFirstChildWhichIsA("BasePart")
			if part then
				local d = (part.Position - hrp.Position).Magnitude
				if d < bestDist then best, bestDist = part, d end
			end
		end
	end
	for _, obj in ipairs(Workspace:GetChildren()) do check(obj) end
	local folders = { "Chests", "Fruits", "Items" }
	for _, fn in ipairs(folders) do
		local f = Workspace:FindFirstChild(fn)
		if f then
			for _, obj in ipairs(f:GetChildren()) do check(obj) end
		end
	end
	return best
end

local function openPrompt(part)
	if not part then return end
	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	if prompt and fireproximityprompt then
		pcall(fireproximityprompt, prompt)
	end
end

local function startAutoChest()
	if taskRunning("AutoChest") then return end
	addTask("AutoChest", function()
		local part = findNearby(CHEST_NAMES, 3000)
		if part then
			tpTo(CFrame.new(part.Position + Vector3.new(0, 3, 0)))
			openPrompt(part)
		end
	end, 0.6)
end

local function startAutoFruit()
	if taskRunning("AutoFruit") then return end
	addTask("AutoFruit", function()
		local hrp = getHRP()
		if not hrp then return end
		for _, obj in ipairs(Workspace:GetChildren()) do
			if (obj:IsA("Tool") or obj:IsA("Model")) and string.find(obj.Name, "Fruit", 1, true) then
				local handle = obj:FindFirstChild("Handle") or obj:FindFirstChildWhichIsA("BasePart")
				if handle then
					tpTo(CFrame.new(handle.Position + Vector3.new(0, 2, 0)))
					openPrompt(handle)
				end
			end
		end
	end, 0.6)
end

local function startAutoBoss()
	if taskRunning("AutoBoss") then return end
	addTask("AutoBoss", function()
		-- đọc State.boss mỗi vòng -> đổi dropdown lúc đang chạy vẫn ăn
		local e = findNearestEnemy(100000, State.boss)
		if e then attack(e) end
	end, 0.15)
end

local function startAutoHaki()
	if taskRunning("AutoHaki") then return end
	addTask("AutoHaki", function()
		local char = getChar()
		if not char then return end
		local bp = LocalPlayer:FindFirstChild("Backpack")
		if not bp then return end
		local hum = getHum()
		for _, t in ipairs(bp:GetChildren()) do
			if t:IsA("Tool") and (string.find(t.Name, "Buso") or string.find(t.Name, "Haki")) then
				if hum then pcall(function() hum:EquipTool(t) end) end
				pcall(function() t:Activate() end)
				break
			end
		end
	end, 1)
end

local function startAutoSkill()
	if taskRunning("AutoSkill") then return end
	addTask("AutoSkill", function()
		if not getChar() then return end
		if type(keypress) ~= "function" or type(keyrelease) ~= "function" then return end
		local keys = { 0x5A, 0x58, 0x43, 0x56, 0x46 } -- Z X C V F
		for _, k in ipairs(keys) do
			pcall(keypress, k)
			pcall(keyrelease, k)
		end
	end, Settings.skillDelay)
end

--==============================================================
-- 10. CHỨC NĂNG: NHÂN VẬT
--==============================================================
local function setNoclip(state)
	if state then
		if taskRunning("Noclip") then return end
		addTask("Noclip", function()
			local char = getChar()
			if not char then return end
			for _, p in ipairs(char:GetDescendants()) do
				if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
			end
		end, 0.25)
	else
		stopTask("Noclip")
	end
end

local Fly = { on = false, speed = 60, mode = "CFrame" }

local function readFlyDir()
	local cam = Workspace.CurrentCamera
	if not cam then return nil end
	local dir = Vector3.new(0, 0, 0)
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end
	-- điện thoại (không có bàn phím): dùng cần điều khiển + nút nhảy
	if not UserInputService.KeyboardEnabled then
		local hum = getHum()
		if hum then
			dir = dir + hum.MoveDirection
			if hum.Jump then dir = dir + Vector3.new(0, 1, 0) end
		end
	end
	return dir
end

local function setFly(state)
	if not state then
		Fly.on = false
		stopTask("Fly")
		local hrp = getHRP()
		if hrp and hrp:FindFirstChild("TH_Fly") then hrp.TH_Fly:Destroy() end
		return
	end
	if Fly.on and taskRunning("Fly") then return end
	Fly.on = true

	if Fly.mode == "CFrame" then
		local last = os.clock()
		addTask("Fly", function()
			local hrp = getHRP()
			if not hrp then return end
			local dir = readFlyDir()
			if not dir then return end

			local now = os.clock()
			local dt = math.clamp(now - last, 0, 0.1)
			last = now

			pcall(function()
				if dir.Magnitude > 0 then
					hrp.CFrame = hrp.CFrame + dir.Unit * Fly.speed * dt
				end
				-- luôn triệt tiêu vận tốc để không bị rơi khi đứng yên trên không
				hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			end)
		end, 0)
	else
		addTask("Fly", function()
			local hrp = getHRP()
			if not hrp then return end
			local bv = hrp:FindFirstChild("TH_Fly")
			if not bv then
				bv = Instance.new("BodyVelocity")
				bv.Name = "TH_Fly"
				bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
				bv.Velocity = Vector3.new(0, 0, 0)
				bv.Parent = hrp
			end
			local dir = readFlyDir()
			if not dir then return end
			bv.Velocity = dir.Magnitude > 0 and dir.Unit * Fly.speed or Vector3.new(0, 0, 0)
		end, 0)
	end
end

--==============================================================
-- 11. CHỨC NĂNG: HIỂN THỊ
--==============================================================
local ESPRegistry = {}  -- [model] = { objs = {...}, label = TextLabel, kind = "player" | "mob" }

local function removeESP(model)
	local e = ESPRegistry[model]
	if not e then return end
	for _, o in ipairs(e.objs) do pcall(function() o:Destroy() end) end
	ESPRegistry[model] = nil
end

-- kind = nil -> xoá hết; "player" / "mob" -> chỉ xoá loại đó
local function clearESP(kind)
	for model, e in next, ESPRegistry do
		if not kind or e.kind == kind then removeESP(model) end
	end
end

local function addESP(model, text, color, useHighlight, kind)
	local e = ESPRegistry[model]
	if e then
		e.label.Text = text
		return e
	end
	-- BillboardGui cần Adornee (parent là Model thì không hiện)
	local adornee = model:FindFirstChild("HumanoidRootPart")
		or model:FindFirstChild("Head")
		or model.PrimaryPart
	if not adornee then return nil end

	local objs = {}
	local bb = Instance.new("BillboardGui")
	bb.Name = "TH_ESP"
	bb.Size = UDim2.fromOffset(220, 36)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = adornee
	bb.Parent = model
	table.insert(objs, bb)

	local txt = Instance.new("TextLabel")
	txt.Parent = bb
	txt.Size = UDim2.fromScale(1, 1)
	txt.BackgroundTransparency = 1
	txt.TextColor3 = color
	txt.TextStrokeTransparency = 0
	txt.TextSize = 13
	txt.Font = F_BOLD
	txt.Text = text

	if useHighlight and model:IsA("Model") then
		local hl = Instance.new("Highlight")
		hl.Name = "TH_HL"
		hl.FillColor = color
		hl.FillTransparency = 0.75
		hl.OutlineColor = color
		hl.OutlineTransparency = 0
		hl.Parent = model
		table.insert(objs, hl)
	end

	e = { objs = objs, label = txt, kind = kind }
	ESPRegistry[model] = e
	return e
end

local function setESPPlayers(state)
	if not state then
		stopTask("ESPPlayers")
		clearESP("player")
		return
	end
	if taskRunning("ESPPlayers") then return end
	addTask("ESPPlayers", function()
		local myRoot = getHRP()
		for model, e in next, ESPRegistry do
			if e.kind == "player" and not model.Parent then removeESP(model) end
		end
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LocalPlayer and p.Character then
				local hrp = p.Character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local dist = myRoot and math.floor((hrp.Position - myRoot.Position).Magnitude) or 0
					addESP(p.Character, p.Name .. " [" .. dist .. "m]", Color3.fromRGB(0, 220, 255), true, "player")
				end
			end
		end
	end, 0.5)
end

local function setESPMobs(state)
	if not state then
		stopTask("ESPMobs")
		clearESP("mob")
		return
	end
	if taskRunning("ESPMobs") then return end
	addTask("ESPMobs", function()
		local alive = {}
		for _, m in ipairs(getEnemies()) do
			alive[m.model] = true
			addESP(m.model, m.name .. " [" .. math.floor(m.hum.Health) .. "HP]", Color3.fromRGB(255, 80, 80), false, "mob")
		end
		for model, e in next, ESPRegistry do
			if e.kind == "mob" and not alive[model] then removeESP(model) end
		end
	end, 0.6)
end

local origLight = {
	Brightness = Lighting.Brightness,
	ClockTime  = Lighting.ClockTime,
	FogEnd     = Lighting.FogEnd,
	Ambient    = Lighting.Ambient,
}

local function setFullBright(state)
	if state then
		Lighting.Brightness = 2
		Lighting.ClockTime = 12
		Lighting.FogEnd = 100000
		Lighting.Ambient = Color3.fromRGB(200, 200, 200)
	else
		Lighting.Brightness = origLight.Brightness
		Lighting.ClockTime = origLight.ClockTime
		Lighting.FogEnd = origLight.FogEnd
		Lighting.Ambient = origLight.Ambient
	end
end

--==============================================================
-- 12. CHỨC NĂNG: DỊCH CHUYỂN
--==============================================================
local function tpToName(keyword)
	local hrp = getHRP()
	if not hrp then return false, "Chưa có nhân vật" end
	local kw = string.lower(tostring(keyword or ""))
	if kw == "" then return false, "Chưa chọn địa điểm" end
	local bestPart, bestDist = nil, math.huge
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("BasePart") then
			local n = string.lower(obj.Name)
			if string.find(n, kw, 1, true) then
				local d = (obj.Position - hrp.Position).Magnitude
				if d < bestDist then bestPart, bestDist = obj, d end
			end
		end
	end
	if bestPart then
		tpTo(CFrame.new(bestPart.Position + Vector3.new(0, 5, 0)))
		return true, "Đã tới " .. tostring(keyword)
	end
	return false, "Không tìm thấy: " .. tostring(keyword)
end

local function hopServer()
	local ok, res = pcall(function()
		return HttpService:JSONDecode(game:HttpGet(
			"https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
		))
	end)
	if ok and res and res.data then
		local list = {}
		for _, s in ipairs(res.data) do
			if s.playing < s.maxPlayers and s.id ~= game.JobId then
				table.insert(list, s.id)
			end
		end
		if #list > 0 then
			local id = list[math.random(1, #list)]
			pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, id, LocalPlayer) end)
			return true
		end
	end
	return false
end

local function rejoin()
	if SCRIPT_URL ~= "" then
		pcall(function()
			if queue_on_teleport then
				queue_on_teleport('loadstring(game:HttpGet("' .. SCRIPT_URL .. '"))()')
			elseif syn and syn.queue_on_teleport then
				syn.queue_on_teleport('loadstring(game:HttpGet("' .. SCRIPT_URL .. '"))()')
			end
		end)
	end
	pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
end

--==============================================================
-- 13. CHỨC NĂNG: HỆ THỐNG
--==============================================================
local function addPoint(stat, amount)
	local commF = getCommF()
	if not commF then return false end
	pcall(function() commF:InvokeServer("AddPoint", stat, amount) end)
	return true
end

local function buyHaki(kind)
	local commF = getCommF()
	if not commF then return false end
	pcall(function() commF:InvokeServer("BuyHaki", kind) end)
	return true
end

local function travel(place)
	local commF = getCommF()
	if not commF then return false end
	pcall(function() commF:InvokeServer(place) end)
	return true
end

-- Anti-AFK
track(LocalPlayer.Idled:Connect(function()
	if not Settings.antiAfk then return end
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end)
end))

--==============================================================
-- 14. LƯU / TẢI CẤU HÌNH
--==============================================================
local function saveConfig()
	if not canFile() then
		notify("ThinhHacker", "Executor không hỗ trợ lưu file", 3)
		return
	end
	local data = {
		farmRange  = Settings.farmRange,
		speed      = Settings.speed,
		jump       = Settings.jump,
		flySpeed   = Settings.flySpeed,
		antiAfk    = Settings.antiAfk,
		boss       = State.boss,
		stat       = State.stat,
		island     = State.island,
		toggles    = {},
	}
	for k, v in next, State.toggles do
		data.toggles[k] = v:Get()
	end
	pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(data)) end)
	notify("ThinhHacker", "Đã lưu cấu hình", 3)
end

local function loadConfig()
	if not canFile() then return nil end
	if type(isfile) == "function" and not isfile(CONFIG_FILE) then return nil end
	local ok, raw = pcall(readfile, CONFIG_FILE)
	if not ok or not raw then return nil end
	local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
	if not ok2 or type(data) ~= "table" then return nil end
	Settings.farmRange = data.farmRange or Settings.farmRange
	Settings.speed     = data.speed or Settings.speed
	Settings.jump      = data.jump or Settings.jump
	Settings.flySpeed  = data.flySpeed or Settings.flySpeed
	Fly.speed = Settings.flySpeed
	if data.antiAfk ~= nil then Settings.antiAfk = data.antiAfk end
	State.boss   = data.boss or State.boss
	State.stat   = data.stat or State.stat
	State.island = data.island or State.island
	return data
end

--==============================================================
-- 15. MÀN HÌNH NHẬP KEY
--==============================================================
local function requestKey(onSuccess)
	local gui = makeGui("TH_Key")

	local frame = Create("Frame", {
		Parent = gui,
		Size = UDim2.fromOffset(390, 262),
		Position = UDim2.new(0.5, -195, 0.5, -131),
		BackgroundColor3 = Theme.Bg,
		BorderSizePixel = 0,
	})
	Corner(frame, 14)
	StrokeIt(frame, Theme.Accent, 1.5)

	local head = Create("Frame", {
		Parent = frame,
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	})
	Corner(head, 14)
	Create("Frame", {
		Parent = head, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -14),
		BackgroundColor3 = Theme.Panel, BorderSizePixel = 0,
	})

	local title = Create("TextLabel", {
		Parent = head,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 12),
		Size = UDim2.new(1, 0, 0, 22),
		Font = F_BOLD, Text = "THINHHACKER", TextSize = 21,
		TextColor3 = Theme.Text,
	})
	Create("UIGradient", {
		Parent = title,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 220, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 90, 255)),
		}),
	})
	Create("TextLabel", {
		Parent = head,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 38),
		Size = UDim2.new(1, 0, 0, 16),
		Font = F, Text = "Nhập KEY KÍCH HOẠT để sử dụng menu", TextSize = 11,
		TextColor3 = Theme.Sub,
	})

	local box = Create("Frame", {
		Parent = frame,
		Size = UDim2.new(1, -40, 0, 38),
		Position = UDim2.new(0, 20, 0, 78),
		BackgroundColor3 = Theme.Elem,
		BorderSizePixel = 0,
	})
	Corner(box, 8)
	StrokeIt(box)

	local input = Create("TextBox", {
		Parent = box,
		Size = UDim2.new(1, -24, 1, 0),
		Position = UDim2.new(0, 12, 0, 0),
		BackgroundTransparency = 1,
		Font = F_BOLD,
		PlaceholderText = "Dán key vào đây...",
		PlaceholderColor3 = Theme.Sub,
		Text = "",
		TextColor3 = Theme.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
	})

	local status = Create("TextLabel", {
		Parent = frame,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 20, 0, 122),
		Size = UDim2.new(1, -40, 0, 16),
		Font = F, Text = "", TextSize = 11,
		TextColor3 = Theme.Bad, TextXAlignment = Enum.TextXAlignment.Left,
	})

	local hwidLabel = Create("TextLabel", {
		Parent = frame,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 20, 0, 142),
		Size = UDim2.new(1, -40, 0, 14),
		Font = F, Text = "HWID: " .. string.sub(HWID, 1, 30), TextSize = 10,
		TextColor3 = Theme.Sub, TextXAlignment = Enum.TextXAlignment.Left,
	})

	local function copyHwid()
		if setclipboard then
			pcall(setclipboard, HWID)
			status.TextColor3 = Theme.Ok
			status.Text = "Đã copy HWID, gửi cho admin để lấy key"
		else
			status.TextColor3 = Theme.Warn
			status.Text = "Chép tay HWID ở trên nhé"
		end
	end
	hwidLabel.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			copyHwid()
		end
	end)

	local activeBtn = Create("TextButton", {
		Parent = frame,
		Size = UDim2.new(0.5, -25, 0, 40),
		Position = UDim2.new(0, 20, 0, 178),
		BackgroundColor3 = Color3.fromRGB(0, 140, 190),
		Font = F_BOLD, Text = "KÍCH HOẠT", TextSize = 14,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		AutoButtonColor = false, BorderSizePixel = 0,
	})
	Corner(activeBtn, 9)
	StrokeIt(activeBtn, Theme.Accent, 1)

	local copyBtn = Create("TextButton", {
		Parent = frame,
		Size = UDim2.new(0.5, -25, 0, 40),
		Position = UDim2.new(0.5, 5, 0, 178),
		BackgroundColor3 = Theme.Elem,
		Font = F, Text = "Copy HWID", TextSize = 12,
		TextColor3 = Theme.Text, AutoButtonColor = false, BorderSizePixel = 0,
	})
	Corner(copyBtn, 9)
	StrokeIt(copyBtn)
	copyBtn.MouseButton1Click:Connect(copyHwid)

	local closeK = Create("TextButton", {
		Parent = frame,
		Size = UDim2.new(0, 60, 0, 22),
		Position = UDim2.new(1, -74, 0, 12),
		BackgroundColor3 = Color3.fromRGB(45, 25, 30),
		Font = F, Text = "Đóng", TextSize = 11,
		TextColor3 = Theme.Bad, AutoButtonColor = false, BorderSizePixel = 0,
	})
	Corner(closeK, 6)
	closeK.MouseButton1Click:Connect(function() gui:Destroy() end)

	local busy = false
	local function doActivate()
		if busy then return end
		busy = true
		local text = input.Text
		local ok, expire, note = validateKey(text)
		if not ok then
			status.TextColor3 = Theme.Bad
			status.Text = tostring(note or "Key sai!")
			busy = false
			return
		end
		saveKey(string.gsub(text, "%s", ""), expire)
		status.TextColor3 = Theme.Ok
		status.Text = "Kích hoạt thành công! Hạn: " .. fmtDate(expire)
		activeBtn.Text = "ĐANG VÀO..."
		task.wait(0.8)
		gui:Destroy()
		onSuccess(string.gsub(text, "%s", ""), expire)
	end

	activeBtn.MouseButton1Click:Connect(doActivate)
	input.FocusLost:Connect(function(enter)
		if enter then doActivate() end
	end)

	return gui
end

--==============================================================
-- 16. MENU CHÍNH
--==============================================================
local function buildMenu(usedKey, expire)
	local win = Lib.newWindow(
		"THINHHACKER v2.0",
		"Blox Fruits • Hạn: " .. fmtDate(expire) .. " (" .. daysLeft(expire) .. " ngày) • Key: " .. string.sub(usedKey, 1, 6) .. "***",
		function()
			stopAllTasks()
			pcall(setFly, false)
			pcall(clearESP)
			pcall(setFullBright, false)
			disconnectAll()
		end
	)

	ggetenv().ThinhHacker.Destroy = function()
		stopAllTasks()
		pcall(setFly, false)
		pcall(clearESP)
		pcall(setFullBright, false)
		disconnectAll()
		win.Destroy()
	end
	ggetenv().ThinhHacker.MenuToggle = win.Toggle

	--========================= FARM =========================
	local farm = win.Tab("Farm", "🌾")
	win.Select("Farm")

	section(farm, "AUTO FARM")
	toggle(farm, "AutoFarm", "Auto Farm Level (tự nhận nhiệm vụ)", false, function(s)
		if s then startAutoFarm() else stopTask("AutoFarm") end
	end)
	toggle(farm, "AutoQuest", "Tự động nhận nhiệm vụ", true, function(s) State.autoQuest = s end)
	toggle(farm, "FarmAnywhere", "Đi săn quái ngoài phạm vi (toàn map)", true, function(s) State.farmAnywhere = s end)
	toggle(farm, "AutoChest", "Auto Farm Rương (Chest)", false, function(s)
		if s then startAutoChest() else stopTask("AutoChest") end
	end)
	toggle(farm, "AutoFruit", "Auto Farm Trái Ác Quỷ", false, function(s)
		if s then startAutoFruit() else stopTask("AutoFruit") end
	end)
	toggle(farm, "AutoHaki", "Auto Bật Haki (Buso)", false, function(s)
		if s then startAutoHaki() else stopTask("AutoHaki") end
	end)
	toggle(farm, "AutoSkill", "Auto Dùng Chiêu (Z X C V F)", false, function(s)
		if s then startAutoSkill() else stopTask("AutoSkill") end
	end)

	section(farm, "AUTO BOSS")
	dropdown(farm, "Chọn Boss", BOSSES, State.boss, function(v) State.boss = v end)
	toggle(farm, "AutoBoss", "Auto Farm Boss", false, function(s)
		if s then startAutoBoss() else stopTask("AutoBoss") end
	end)

	section(farm, "CÀI ĐẶT FARM")
	slider(farm, "Phạm vi tìm quái", 50, 1000, Settings.farmRange, function(v) Settings.farmRange = v end)
	slider(farm, "Khoảng cách TP tới quái", 3, 20, 6, function(v) Settings.tpDist = v end)

	--========================= NHÂN VẬT =========================
	local chr = win.Tab("Nhân vật", "⚔️")
	section(chr, "DI CHUYỂN")
	local spd = slider(chr, "Tốc độ chạy", 16, 300, Settings.speed, function(v)
		Settings.speed = v
		local hum = getHum()
		if hum then hum.WalkSpeed = v end
	end)
	slider(chr, "Độ cao nhảy", 50, 300, Settings.jump, function(v)
		Settings.jump = v
		local hum = getHum()
		if hum then applyJump(hum, v) end
	end)

	section(chr, "HACK NHÂN VẬT")
	toggle(chr, "Fly", "Bay (W A S D + Space / Ctrl)", false, function(s) setFly(s) end)
	dropdown(chr, "Kiểu bay", { "CFrame", "BodyVelocity" }, Fly.mode, function(v) Fly.mode = v end)
	slider(chr, "Tốc độ bay", 20, 250, Settings.flySpeed, function(v)
		Settings.flySpeed = v
		Fly.speed = v
	end)
	toggle(chr, "Noclip", "Xuyên vật thể (Noclip)", false, function(s) setNoclip(s) end)
	toggle(chr, "KeepStats", "Giữ tốc độ/nhảy sau khi hồi sinh", true, function(s) State.keepStats = s end)

	addTask("KeepStats", function()
		if not State.keepStats then return end
		local hum = getHum()
		if not hum then return end
		if math.abs(hum.WalkSpeed - Settings.speed) > 0.5 then hum.WalkSpeed = Settings.speed end
		if math.abs(hum.JumpPower - Settings.jump) > 0.5 then applyJump(hum, Settings.jump) end
	end, 0.5)

	button(chr, "Hồi tốc độ mặc định", function()
		local hum = getHum()
		if hum then
			hum.WalkSpeed = 16
			applyJump(hum, 50)
		end
		Settings.speed = 16
		Settings.jump = 50
		spd.Set(16)
		notify("ThinhHacker", "Đã hồi tốc độ mặc định", 2)
	end)

	section(chr, "ĐIỂM KỸ NĂNG")
	dropdown(chr, "Cộng vào", STATS, State.stat, function(v) State.stat = v end)
	button(chr, "Cộng 1 điểm vào mục đã chọn", function()
		if addPoint(State.stat, 1) then
			notify("ThinhHacker", "Đã cộng 1 điểm: " .. State.stat, 2)
		else
			notify("ThinhHacker", "Không tìm thấy remote", 3)
		end
	end)
	button(chr, "Cộng hết điểm còn lại", function()
		for _ = 1, 500 do
			addPoint(State.stat, 1)
			task.wait(0.05)
		end
		notify("ThinhHacker", "Đã cộng xong (" .. State.stat .. ")", 2)
	end)
	toggle(chr, "AutoPoint", "Tự cộng điểm khi có", false, function(s)
		if s then
			addTask("AutoPoint", function()
				addPoint(State.stat, 1)
			end, 1.2)
		else
			stopTask("AutoPoint")
		end
	end)

	section(chr, "MUA HAKI / DI CHUYỂN")
	button(chr, "Mua Buso (Haki vũ trang)", function()
		buyHaki("Buso")
		notify("ThinhHacker", "Đã gửi lệnh mua Buso", 2)
	end)
	button(chr, "Mua Geppo (nhảy trên không)", function()
		buyHaki("Geppo")
		notify("ThinhHacker", "Đã gửi lệnh mua Geppo", 2)
	end)
	button(chr, "Mua Soru (chạy nhanh)", function()
		buyHaki("Soru")
		notify("ThinhHacker", "Đã gửi lệnh mua Soru", 2)
	end)
	button(chr, "Mua Ken (Haki quan sát)", function()
		buyHaki("Ken")
		notify("ThinhHacker", "Đã gửi lệnh mua Ken", 2)
	end)

	--========================= DỊCH CHUYỂN =========================
	local tp = win.Tab("Dịch chuyển", "🗺️")
	section(tp, "ĐI TỚI ĐẢO")
	local islandPick = dropdown(tp, "Chọn đảo", ISLANDS, State.island, function(v) State.island = v end)
	button(tp, "Dịch chuyển tới đảo đã chọn", function()
		local ok, msg = tpToName(islandPick.Get())
		notify("ThinhHacker", msg, ok and 2 or 3)
	end)

	section(tp, "ĐI ĐẢO 2 / ĐẢO 3")
	button(tp, "Về Đảo 1 (First Sea)", function()
		travel("TravelMain")
		notify("ThinhHacker", "Đang về Đảo 1...", 2)
	end)
	button(tp, "Tới Đảo 2 (Second Sea)", function()
		travel("TravelDressrosa")
		notify("ThinhHacker", "Đang tới Đảo 2...", 2)
	end)
	button(tp, "Tới Đảo 3 (Third Sea)", function()
		travel("TravelZou")
		notify("ThinhHacker", "Đang tới Đảo 3...", 2)
	end)

	section(tp, "ĐI TỚI BOSS / NGƯỜI CHƠI")
	local bossTP = dropdown(tp, "Chọn Boss", BOSSES, State.boss)
	button(tp, "Dịch chuyển tới Boss", function()
		local e = findNearestEnemy(100000, bossTP.Get())
		if e then
			tpTo(e.root.CFrame * CFrame.new(0, 0, 5))
			notify("ThinhHacker", "Đã tới: " .. bossTP.Get(), 2)
		else
			notify("ThinhHacker", "Boss chưa xuất hiện trên map này", 3)
		end
	end)

	local playerNames = {}
	local function refreshPlayers()
		playerNames = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LocalPlayer then table.insert(playerNames, p.Name) end
		end
		if #playerNames == 0 then table.insert(playerNames, "(trống)") end
		return playerNames
	end
	refreshPlayers()
	local playerPick = dropdown(tp, "Chọn người chơi", refreshPlayers())
	button(tp, "Làm mới danh sách người chơi", function()
		refreshPlayers()
		notify("ThinhHacker", "Đã làm mới (" .. #playerNames .. " người)", 2)
	end)
	button(tp, "Dịch chuyển tới người chơi", function()
		local target = playerPick.Get()
		local p = Players:FindFirstChild(target)
		if p and p.Character then
			local hrp = p.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				tpTo(hrp.CFrame * CFrame.new(0, 0, 4))
				notify("ThinhHacker", "Đã tới chỗ: " .. target, 2)
				return
			end
		end
		notify("ThinhHacker", "Không tìm thấy người chơi này", 3)
	end)

	section(tp, "TIỆN ÍCH")
	button(tp, "Về điểm hồi sinh (Spawn)", function()
		local spawn = Workspace:FindFirstChildOfClass("SpawnLocation")
		if spawn then
			tpTo(CFrame.new(spawn.Position + Vector3.new(0, 5, 0)))
			notify("ThinhHacker", "Đã về điểm hồi sinh", 2)
		else
			notify("ThinhHacker", "Không tìm thấy điểm hồi sinh", 3)
		end
	end)
	button(tp, "Dịch chuyển tới chuột", function()
		local mouse = LocalPlayer:GetMouse()
		if mouse and mouse.Hit then
			tpTo(mouse.Hit + Vector3.new(0, 3, 0))
		end
	end)

	--========================= HIỂN THỊ =========================
	local vis = win.Tab("Hiển thị", "👁️")
	section(vis, "ESP")
	toggle(vis, "ESPPlayers", "ESP Người chơi (tên + khoảng cách)", false, function(s) setESPPlayers(s) end)
	toggle(vis, "ESPMobs", "ESP Quái (máu)", false, function(s) setESPMobs(s) end)
	button(vis, "Xoá toàn bộ ESP", function()
		clearESP()
		if State.toggles.ESPPlayers then State.toggles.ESPPlayers.Set(false, false) end
		if State.toggles.ESPMobs then State.toggles.ESPMobs.Set(false, false) end
		stopTask("ESPPlayers")
		stopTask("ESPMobs")
		notify("ThinhHacker", "Đã xoá ESP", 2)
	end)

	section(vis, "ÁNH SÁNG")
	toggle(vis, "FullBright", "Full Bright (nhìn rõ mọi nơi)", false, function(s) setFullBright(s) end)
	button(vis, "Xoá sương mù", function()
		for _, v in ipairs(Lighting:GetChildren()) do
			if v:IsA("Atmosphere") then pcall(function() v:Destroy() end) end
		end
		Lighting.FogEnd = 100000
		notify("ThinhHacker", "Đã xoá sương mù", 2)
	end)

	--========================= SERVER =========================
	local srv = win.Tab("Server", "🌐")
	section(srv, "SERVER")
	button(srv, "Đổi server (Hop)", function()
		notify("ThinhHacker", "Đang tìm server mới...", 2)
		if not hopServer() then
			notify("ThinhHacker", "Không tìm được server, thử lại sau", 3)
		end
	end)
	button(srv, "Vào lại server hiện tại (Rejoin)", function()
		notify("ThinhHacker", "Đang vào lại...", 2)
		rejoin()
	end)

	local info = label(srv, "", 66)
	local function refreshInfo()
		local ping = 0
		pcall(function() ping = math.floor(LocalPlayer:GetNetworkPing() * 1000) end)
		info.Text = "  Người chơi: " .. #Players:GetPlayers() ..
			"  |  Server: " .. string.sub(tostring(game.JobId), 1, 8) ..
			"  |  Ping: " .. ping .. "ms" ..
			"  |  Level: " .. tostring(getLevel())
	end
	refreshInfo()
	addTask("InfoRefresh", refreshInfo, 2)

	--========================= KEY =========================
	local keyTab = win.Tab("Key", "🔑")
	section(keyTab, "THÔNG TIN KEY")
	label(keyTab, "  Key đang dùng: " .. string.sub(usedKey, 1, 4) .. "****" ..
		"\n  Hạn: " .. fmtDate(expire) .. "  (còn " .. daysLeft(expire) .. " ngày)" ..
		"\n  HWID: " .. string.sub(HWID, 1, 24) .. "...", 70)

	button(keyTab, "Copy HWID (gửi admin lấy key)", function()
		if setclipboard then
			pcall(setclipboard, HWID)
			notify("ThinhHacker", "Đã copy HWID", 2)
		else
			notify("ThinhHacker", "Executor không hỗ trợ copy", 3)
		end
	end)
	button(keyTab, "Đăng xuất key (xoá key đã lưu)", function()
		if type(delfile) == "function" then
			pcall(delfile, KEY_FILE)
			notify("ThinhHacker", "Đã xoá key, khởi động lại script để nhập key mới", 4)
		else
			notify("ThinhHacker", "Executor không hỗ trợ xoá file", 3)
		end
	end)

	section(keyTab, "DANH SÁCH KEY CÓ SẴN")
	local keyText = ""
	local count = 0
	for k, v in next, KEY_LIST do
		count = count + 1
		if count <= 12 then
			keyText = keyText .. "\n  • " .. string.sub(k, 1, 5) .. "****  (" .. tostring(v.days) .. " ngày)"
		end
	end
	label(keyTab, "  Tổng: " .. count .. " key" .. keyText, 120)

	--========================= CÀI ĐẶT =========================
	local set = win.Tab("Cài đặt", "⚙️")
	section(set, "HIỆU NĂNG")
	button(set, "Mở khoá FPS (lên 240)", function()
		if setfpscap then
			setfpscap(240)
			notify("ThinhHacker", "Đã mở khoá FPS", 2)
		else
			notify("ThinhHacker", "Executor không hỗ trợ", 3)
		end
	end)
	toggle(set, "AntiAfk", "Chống bị kick AFK", true, function(s) Settings.antiAfk = s end)

	section(set, "CẤU HÌNH")
	button(set, "Lưu cấu hình", saveConfig)
	button(set, "Tải cấu hình", function()
		local data = loadConfig()
		if not data then
			notify("ThinhHacker", "Chưa có cấu hình đã lưu", 3)
			return
		end
		if data.toggles then
			for k, v in next, data.toggles do
				local t = State.toggles[k]
				if t then pcall(function() t.Set(v, true) end) end
			end
		end
		notify("ThinhHacker", "Đã tải cấu hình", 2)
	end)

	section(set, "THÔNG TIN")
	button(set, "Tắt toàn bộ chức năng", function()
		stopAllTasks()
		setFly(false)
		pcall(clearESP)
		pcall(setFullBright, false)
		local hum = getHum()
		if hum then
			hum.WalkSpeed = 16
			applyJump(hum, 50)
		end
		for _, t in next, State.toggles do
			pcall(function() t.Set(false) end)
		end
		State.autoQuest = true
		State.farmAnywhere = true
		State.keepStats = true
		Settings.antiAfk = true
		if State.toggles.KeepStats then State.toggles.KeepStats.Set(true) end
		if State.toggles.AntiAfk then State.toggles.AntiAfk.Set(true) end
		if State.toggles.AutoQuest then State.toggles.AutoQuest.Set(true) end
		if State.toggles.FarmAnywhere then State.toggles.FarmAnywhere.Set(true) end
		addTask("KeepStats", function()
			if not State.keepStats then return end
			local h = getHum()
			if not h then return end
			if math.abs(h.WalkSpeed - Settings.speed) > 0.5 then h.WalkSpeed = Settings.speed end
			if math.abs(h.JumpPower - Settings.jump) > 0.5 then applyJump(h, Settings.jump) end
		end, 0.5)
		addTask("InfoRefresh", refreshInfo, 2)
		notify("ThinhHacker", "Đã tắt hết chức năng", 3)
	end)
	button(set, "Ẩn / hiện menu (RightShift)", function()
		win.Toggle()
	end, Theme.Accent)

	section(set, "PHÍM TẮT")
	label(set, "  RightShift : ẩn / hiện menu\n  Nút — trên thanh tiêu đề : thu nhỏ", 44)

	notify("ThinhHacker", "Đã kích hoạt v2.0! Chúc bạn chơi vui 🎮", 4)
end

--==============================================================
-- 17. KHỞI CHẠY
--==============================================================
State.autoQuest = true
State.farmAnywhere = true
State.keepStats = true

-- lưu tham chiếu toggle để đồng bộ cấu hình / tắt tất cả
local origToggle = toggle
toggle = function(page, key, text, default, callback)
	local t = origToggle(page, key, text, default, callback)
	if key then State.toggles[key] = t end
	return t
end

-- phím tắt ẩn/hiện
track(UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.RightShift then
		if ggetenv().ThinhHacker.MenuToggle then
			pcall(ggetenv().ThinhHacker.MenuToggle)
		end
	end
end))

local savedKey, savedExpire = loadSavedKey()
if savedKey and savedExpire then
	buildMenu(savedKey, savedExpire)
else
	requestKey(function(key, expire)
		buildMenu(key, expire)
	end)
end
