--[[
    Build An Ant Empire Hub
    Auto Roll & Filter, Food Selling with Target Multiplier,
    Dungeon, Events, Snail Click, Strawberry Coins, Ant Speed,
    FPS Cap Lock, Config Manager, Anti-AFK & Performance Boost.
]]

-- ========================================================================
-- บริการหลักของ ROBLOX (Core Services)
-- ========================================================================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- โหลด WindUI Library อย่างปลอดภัย
local WindUI = nil
local windUiSuccess, windUiErr = pcall(function()
    WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
end)

if not windUiSuccess or not WindUI then
    warn("[AntEmpireHub] Failed to load WindUI library: " .. tostring(windUiErr))
    return
end

-- 1. ลงทะเบียนธีม VibrantNeon อย่างปลอดภัย (ปุ่มเปิดสวิตช์สีเขียว #00e676)
pcall(function()
    if WindUI.AddTheme then
        WindUI:AddTheme({
            Name = "VibrantNeon",
            Accent = Color3.fromHex("#00e676"),
            Dialog = Color3.fromHex("#181924"),
            Outline = Color3.fromHex("#2a2b36"),
            Text = Color3.fromHex("#ffffff"),
            Placeholder = Color3.fromHex("#888899"),
            Background = Color3.fromHex("#12131a"),
            Button = Color3.fromHex("#252738"),
            Icon = Color3.fromHex("#a1a1aa"),
            Toggle = Color3.fromHex("#00e676"),
            Slider = Color3.fromHex("#00e676"),
            Checkbox = Color3.fromHex("#00e676"),
            PanelBackground = Color3.fromHex("#14151f"),
            PanelBackgroundTransparency = 0.95,
            SliderIcon = Color3.fromHex("#00e676"),
            Primary = Color3.fromHex("#00e676"),
            LabelBackground = Color3.fromHex("#000000"),
            LabelBackgroundTransparency = 0.83,
            ElementBackground = Color3.fromHex("#1b1d28"),
            ElementBackgroundTransparency = 0
        })
    end
end)

-- 2. กำหนดธีมเริ่มต้น (Dark เป็นธีมในตัวที่มีสวิตช์เปิดสีเขียว #33C759 เป็นค่าเริ่มต้น)
local selectedTheme = "Dark"
pcall(function()
    if WindUI.Themes and WindUI.Themes["VibrantNeon"] then
        selectedTheme = "VibrantNeon"
    end
end)

-- 3. สร้างหน้าต่างหลัก (ไม่มีอิโมจิ)
local mobileUi = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local function getWindowLayout()
    local camera = Workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(780, 560)
    if not mobileUi then
        return UDim2.fromOffset(780, 560), Vector2.new(560, 350), Vector2.new(850, 560), 210
    end

    local width = math.max(240, math.min(780, viewport.X - 16))
    local height = math.max(260, math.min(820, math.floor(viewport.Y * 0.88)))
    return UDim2.fromOffset(width, height),
        Vector2.new(math.min(260, width), math.min(260, height)),
        Vector2.new(width, height),
        math.clamp(math.floor(width * 0.33), 96, 140)
end

local initialWindowSize, initialMinSize, initialMaxSize, initialSidebarWidth = getWindowLayout()
local Window = WindUI:CreateWindow({
    Title = "Ant Empire Hub",
    Author = "Pro Edition v3.0",
    Folder = "AntEmpireHub",
    Size = initialWindowSize,
    MinSize = initialMinSize,
    MaxSize = initialMaxSize,
    Resizable = not mobileUi,
    Transparent = not mobileUi,
    AutoScale = true,
    Theme = selectedTheme,
    SideBarWidth = initialSidebarWidth,
    HasOutline = true,
    ToggleKey = Enum.KeyCode.RightControl,
    User = {
        Enabled = not mobileUi,
        Anonymous = false,
        Title = LocalPlayer and LocalPlayer.DisplayName or "Player",
        Desc = LocalPlayer and ("@" .. LocalPlayer.Name) or "@Player",
        Callback = function() end
    }
})

if mobileUi then
    local function updateMobileWindowSize()
        local size, minSize, maxSize, sidebarWidth = getWindowLayout()
        Window.MinSize = minSize
        Window.MaxSize = maxSize
        Window.SideBarWidth = sidebarWidth
        Window:SetSize(size)
        local sideBar = Window.UIElements and Window.UIElements.SideBarContainer
        if sideBar then
            sideBar.Size = UDim2.new(0, sidebarWidth, 1, -Window.Topbar.Height)
        end
    end
    local camera = Workspace.CurrentCamera
    if camera then
        camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateMobileWindowSize)
    end
    Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        local nextCamera = Workspace.CurrentCamera
        if nextCamera then
            nextCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateMobileWindowSize)
            updateMobileWindowSize()
        end
    end)
end

-- ลายน้ำลอยบนจอ แตะเพื่อเปิดหรือซ่อนหน้าต่าง
local playerGui = LocalPlayer:WaitForChild("PlayerGui")
local oldMobileToggle = playerGui:FindFirstChild("AntEmpireHubMobileToggle")
if oldMobileToggle then
    oldMobileToggle:Destroy()
end
local existingWatermark = playerGui:FindFirstChild("AntEmpireHubWatermark")
if existingWatermark then
    existingWatermark:Destroy()
end

local watermarkGui = Instance.new("ScreenGui")
watermarkGui.Name = "AntEmpireHubWatermark"
watermarkGui.ResetOnSpawn = false
watermarkGui.IgnoreGuiInset = true
watermarkGui.DisplayOrder = 10000
watermarkGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
watermarkGui.Parent = playerGui

local watermark = Instance.new("TextButton")
watermark.Name = "ToggleUI"
watermark.Size = UDim2.fromOffset(56, 56)
watermark.Position = UDim2.new(0, 14, 0.5, -28)
watermark.BackgroundColor3 = Color3.fromRGB(25, 18, 29)
watermark.BackgroundTransparency = 0.08
watermark.Text = "JOJO\nHUB"
watermark.TextColor3 = Color3.fromRGB(239, 137, 211)
watermark.TextSize = 13
watermark.Font = Enum.Font.GothamSemibold
watermark.AutoButtonColor = true
watermark.ZIndex = 10
watermark.Parent = watermarkGui

local watermarkCorner = Instance.new("UICorner")
watermarkCorner.CornerRadius = UDim.new(0, 10)
watermarkCorner.Parent = watermark

local watermarkStroke = Instance.new("UIStroke")
watermarkStroke.Color = Color3.fromRGB(90, 53, 91)
watermarkStroke.Thickness = 1
watermarkStroke.Parent = watermark

local watermarkDebounce = false
local dragInput = nil
local dragStart = nil
local watermarkStart = nil
local dragMoved = false

watermark.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
        dragStart = input.Position
        watermarkStart = watermark.AbsolutePosition
        dragMoved = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragInput then
        return
    end

    local isDragging = input.UserInputType == Enum.UserInputType.MouseMovement
        or (dragInput.UserInputType == Enum.UserInputType.Touch and input == dragInput)
    if not isDragging then
        return
    end

    local delta = input.Position - dragStart
    if math.abs(delta.X) > 4 or math.abs(delta.Y) > 4 then
        dragMoved = true
    end

    local camera = Workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize
    if not viewport then
        return
    end

    local x = math.clamp(watermarkStart.X + delta.X, 0, math.max(0, viewport.X - watermark.AbsoluteSize.X))
    local y = math.clamp(watermarkStart.Y + delta.Y, 0, math.max(0, viewport.Y - watermark.AbsoluteSize.Y))
    watermark.Position = UDim2.fromOffset(x, y)
end)

UserInputService.InputEnded:Connect(function(input)
    if not dragInput then
        return
    end
    local matchingInput = input == dragInput
        or (dragInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1)
    if not matchingInput then
        return
    end

    local shouldToggle = not dragMoved
    dragInput = nil
    dragStart = nil
    watermarkStart = nil

    if shouldToggle and not watermarkDebounce then
        watermarkDebounce = true
        if Window.Closed then
            Window:Open()
        else
            Window:Close()
        end
        task.delay(0.9, function()
            watermarkDebounce = false
        end)
    end
end)

-- ========================================================================
-- ค่าตัวแปรระบบ (Flags)
-- ========================================================================
local Flags = {
    -- Rolling & Purchasing
    AutoRollAnt = false,
    DisableCloverEffect = false,
    AutoBuyAnt = false,
    AutoBuyStar = false,
    AutoBuyRollForIndex = false,
    BuyRarities = { "Epic", "Legendary", "Mythic", "Exotic", "Secret", "Divine", "OP", "Celestial" },
    BuyMutations = { "None" },
    SkipIfNotEnoughGold = true,

    -- Food & Farm
    AutoCollect = false,
    AutoSell = false,
    SellAtMultiplier = false,
    DisableSellMoneyEffect = false,
    Multiplier = 1.80,
    AutoSellToFoodBuyer = false,

    -- Ants & Upgrades
    AutoPlaceAnt = false,
    AutoEquipBest = false,
    AutoUnlockAntHole = false,
    HideAnts = false,
    AutoUpgradeEquippedAnts = false,
    AutoStrokePets = false,
    AutoUpgradeAntSpeed = false,
    AutoBuyUpgrades = false,
    UpgradeInterval = 3.0,
    SelectedUpgrades = { "Nest Layer", "Ant Speed", "Ant Atk" },

    -- Dungeon
    AutoDungeon = false,
    AutoPressDungeonStart = true,
    Auto4xAttackSpeed = false,
    AutoStarDungeon = false,

    -- Events
    AutoPickupStrawberryCoins = false,
    CoinPickupDelay = 0.10,
    AutoClickTravellingSnail = false,
    AutoStarfallEvent = false,
    AutoClaimIndex = false,
    AutoClaimPlaytimeRewards = false,

    -- Converter & Shop
    AutoResourceConverter = false,
    ConverterAnts = "None",
    KeepPerStack = 15,
    AutoBuyFood = false,
    SelectedShopItem = "None",

    -- Player & Movement
    WalkSpeed = 16,
    JumpPower = 50,
    InfiniteJump = false,
    Noclip = false,

    -- Utilities, AFK & Performance
    AntiAFK = true,
    FPSBoost = false,
    BlackScreen = false,
    LowGraphics = false,
    Fullbright = false,
    LockAFK15FPS = false,
    TargetFPS = 60,
    HideUIOnStart = false,
    AutoSaveConfig = false,
    EnteredCode = ""
}

local MultiplierLiveStatus = nil

local LegacyConfigPath = "AntEmpireHub/config.json"
local ConfigFolder = "AntEmpireHub/Configs"
local ConfigAutoloadPath = ConfigFolder .. "/autoload.txt"
local SelectedConfigName = "Default"
local ConfigControls = {}
local ShopItemIdByLabel
local ConfigNameInput
local ConfigDropdown
local ImportConfigText = ""
local RenameConfigFrom = ""
local RenameConfigTo = ""

local function validateConfigName(name)
    name = tostring(name or ""):match("^%s*(.-)%s*$")
    if name == "" or #name > 40 or not name:match("^[%w _%-]+$") then
        return nil, "Use 1-40 letters, numbers, spaces, underscores, or hyphens."
    end
    return name
end

local function ensureConfigStorage()
    if type(isfolder) ~= "function" or type(makefolder) ~= "function"
        or type(isfile) ~= "function" or type(readfile) ~= "function"
        or type(writefile) ~= "function" or type(delfile) ~= "function" then
        return false, "This executor does not support the required config file APIs."
    end

    for _, folder in ipairs({"AntEmpireHub", ConfigFolder}) do
        if not isfolder(folder) then
            makefolder(folder)
        end
    end
    return true
end

local function makeConfigSnapshot()
    return {
        version = 1,
        flags = table.clone(Flags),
    }
end

local function validConfigValue(defaultValue, value)
    if type(defaultValue) ~= type(value) then
        return false
    end
    if type(defaultValue) == "number" then
        return value == value and value ~= math.huge and value ~= -math.huge
    end
    if type(defaultValue) == "table" then
        for key, item in pairs(value) do
            if type(key) ~= "number" or key < 1 or key % 1 ~= 0 or type(item) ~= "string" then
                return false
            end
        end
        for index = 1, #value do
            if value[index] == nil then
                return false
            end
        end
    end
    return true
end

local function validateConfig(data, allowLegacy)
    if type(data) ~= "table" then
        return false, "Config must be a JSON object."
    end
    local values = data.flags
    if allowLegacy and values == nil then
        values = data
    elseif type(values) ~= "table" or data.version ~= 1 then
        return false, "Unsupported or invalid config format."
    end

    for key, value in pairs(values) do
        if Flags[key] == nil or not validConfigValue(Flags[key], value) then
            return false, "Unknown or invalid config setting: " .. tostring(key)
        end
    end
    return true, values
end

local function syncConfigControls()
    for key, control in pairs(ConfigControls) do
        local value = Flags[key]
        if key == "SelectedShopItem" and ShopItemIdByLabel then
            for label, itemId in pairs(ShopItemIdByLabel) do
                if itemId == value then
                    value = label
                    break
                end
            end
            if value == Flags.SelectedShopItem then
                value = "None"
            end
        end
        if control and (type(value) == "table" or type(value) == "string")
            and type(control.Select) == "function" then
            local ok, err = pcall(control.Select, control, value)
            if not ok then
                warn("[AntEmpireHub] Could not update config selection " .. key .. ": " .. tostring(err))
            end
        elseif control and type(control.Set) == "function" then
            local ok, err = pcall(control.Set, control, value)
            if not ok then
                warn("[AntEmpireHub] Could not update config control " .. key .. ": " .. tostring(err))
            end
        end
    end
end

local function readNamedConfig(name)
    local ready, storageError = ensureConfigStorage()
    if not ready then
        return nil, storageError
    end
    local path = ConfigFolder .. "/" .. name .. ".json"
    if not isfile(path) then
        return nil, "Config not found: " .. name
    end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)
    if not ok then
        return nil, "Could not parse config JSON: " .. tostring(data)
    end
    local valid, flagsOrError = validateConfig(data, false)
    if not valid then
        return nil, flagsOrError
    end
    return flagsOrError
end

local function saveConfig(name, silent)
    name = name or SelectedConfigName
    local validName, nameError = validateConfigName(name)
    if not validName then
        if not silent then
            WindUI:Notify({Title = "Configs", Content = nameError, Duration = 3})
        end
        return false
    end
    local ready, storageError = ensureConfigStorage()
    if not ready then
        if not silent then
            WindUI:Notify({Title = "Configs", Content = storageError, Duration = 3})
        end
        return false
    end
    local ok, err = pcall(function()
        writefile(ConfigFolder .. "/" .. validName .. ".json", HttpService:JSONEncode(makeConfigSnapshot()))
    end)
    if not ok then
        warn("[AntEmpireHub] Config save failed: " .. tostring(err))
        if not silent then
            WindUI:Notify({Title = "Configs", Content = "Could not save config: " .. tostring(err), Duration = 3})
        end
        return false
    end
    SelectedConfigName = validName
    if ConfigNameInput and type(ConfigNameInput.Set) == "function" then
        pcall(ConfigNameInput.Set, ConfigNameInput, validName)
    end
    if not silent then
        WindUI:Notify({Title = "Configs", Content = "Saved config: " .. validName, Duration = 2.5})
    end
    return true
end

local function loadConfig(silent, name)
    local flags
    local readError
    if name then
        local validName, nameError = validateConfigName(name)
        if not validName then
            readError = nameError
        else
            flags, readError = readNamedConfig(validName)
            if flags then
                SelectedConfigName = validName
            end
        end
    elseif isfile and readfile and isfile(LegacyConfigPath) then
        local ok, decoded = pcall(function()
            return HttpService:JSONDecode(readfile(LegacyConfigPath))
        end)
        if ok then
            local valid, valuesOrError = validateConfig(decoded, true)
            if valid then
                flags = valuesOrError
            else
                readError = valuesOrError
            end
        else
            readError = "Could not parse legacy config: " .. tostring(decoded)
        end
    end

    if not flags then
        if readError and not silent then
            WindUI:Notify({Title = "Configs", Content = readError, Duration = 3})
        end
        return false
    end
    for key, value in pairs(flags) do
        Flags[key] = type(value) == "table" and table.clone(value) or value
    end
    if ConfigNameInput and type(ConfigNameInput.Set) == "function" then
        pcall(ConfigNameInput.Set, ConfigNameInput, SelectedConfigName)
    end
    syncConfigControls()
    if not silent then
        WindUI:Notify({Title = "Configs", Content = "Loaded config: " .. SelectedConfigName, Duration = 2.5})
    end
    return true
end

local function loadAutoloadConfig(silent)
    local ready, storageError = ensureConfigStorage()
    if not ready then
        if not silent then
            WindUI:Notify({Title = "Configs", Content = storageError, Duration = 3})
        end
        return false
    end
    if not isfile(ConfigAutoloadPath) then
        return false
    end
    local readOk, name = pcall(readfile, ConfigAutoloadPath)
    if not readOk then
        warn("[AntEmpireHub] Could not read autoload config: " .. tostring(name))
        if not silent then
            WindUI:Notify({Title = "Configs", Content = "Could not read autoload config.", Duration = 3})
        end
        return false
    end
    local validName, nameError = validateConfigName(name)
    if not validName then
        warn("[AntEmpireHub] Invalid autoload config name: " .. tostring(nameError))
        return false
    end
    return loadConfig(silent, validName)
end

local function listSavedConfigs()
    local ready, storageError = ensureConfigStorage()
    if not ready then
        return nil, storageError
    end
    if type(listfiles) ~= "function" then
        return nil, "This executor does not support listing config files."
    end
    local ok, paths = pcall(listfiles, ConfigFolder)
    if not ok or type(paths) ~= "table" then
        return nil, "Could not list configs: " .. tostring(paths)
    end
    local names = {}
    for _, path in ipairs(paths) do
        local normalized = tostring(path):gsub("\\", "/")
        local name = normalized:match("([^/]+)%.json$")
        if name and not name:match("%.export$") and validateConfigName(name) then
            table.insert(names, name)
        end
    end
    table.sort(names, function(left, right)
        return string.lower(left) < string.lower(right)
    end)
    return names
end

local function refreshConfigDropdown()
    local names, err = listSavedConfigs()
    if not names then
        WindUI:Notify({Title = "Configs", Content = err, Duration = 3})
        return false
    end
    if ConfigDropdown and type(ConfigDropdown.Refresh) == "function" then
        local ok, refreshError = pcall(ConfigDropdown.Refresh, ConfigDropdown, names)
        if not ok then
            warn("[AntEmpireHub] Config list refresh failed: " .. tostring(refreshError))
            WindUI:Notify({Title = "Configs", Content = "Could not refresh config list.", Duration = 3})
            return false
        end
    end
    return true
end

local function resetConfig(name)
    local validName, nameError = validateConfigName(name or SelectedConfigName)
    if not validName then
        WindUI:Notify({Title = "Configs", Content = nameError, Duration = 3})
        return false
    end
    local ready, storageError = ensureConfigStorage()
    if not ready then
        WindUI:Notify({Title = "Configs", Content = storageError, Duration = 3})
        return false
    end
    local path = ConfigFolder .. "/" .. validName .. ".json"
    if isfile(path) then
        local ok, err = pcall(delfile, path)
        if not ok then
            WindUI:Notify({Title = "Configs", Content = "Could not delete config: " .. tostring(err), Duration = 3})
            return false
        end
    end
    if isfile(ConfigAutoloadPath) then
        local readOk, autoloadName = pcall(readfile, ConfigAutoloadPath)
        if not readOk then
            warn("[AntEmpireHub] Could not read autoload config before deleting profile: " .. tostring(autoloadName))
        elseif autoloadName == validName then
            local deleteOk, deleteError = pcall(delfile, ConfigAutoloadPath)
            if not deleteOk then
                WindUI:Notify({Title = "Configs", Content = "Config removed, but autoload could not be cleared: " .. tostring(deleteError), Duration = 3})
            end
        end
    end
    if SelectedConfigName == validName then
        SelectedConfigName = "Default"
        if ConfigNameInput and type(ConfigNameInput.Set) == "function" then
            pcall(ConfigNameInput.Set, ConfigNameInput, SelectedConfigName)
        end
    end
    WindUI:Notify({Title = "Configs", Content = "Removed config: " .. validName, Duration = 2.5})
    refreshConfigDropdown()
    return true
end

-- แมปชื่ออัปเกรดเป็นชื่อจริงในระบบเกม
local UpgradeMapping = {
    ["Nest Layer"] = "巢穴层数",
    ["Ant Speed"] = "蚂蚁移速",
    ["Ant Atk"] = "蚂蚁攻击力",
    ["Queen Level"] = "蚁后等级",
    ["Luck"] = "幸运值",
    ["Single Roll Count"] = "单抽数量"
}

local RarityList = {
    "Common", "Uncommon", "Rare", "Epic", "Legendary", 
    "Mythic", "Exotic", "Secret", "Divine", "OP", "Celestial"
}

local MutationList = {
    "Any", "None", "Leaf", "Bubblegum", "Candy", "Rainbow", "Petal", "Starlight"
}

local TagMapping = {
    [0] = "None",
    [1] = "Leaf",
    [2] = "Bubblegum",
    [3] = "Candy",
    [4] = "Rainbow",
    [5] = "Petal",
    [6] = "Starlight"
}

-- ========================================================================
-- Helper ฟังก์ชันระบบ และแคชการตั้งค่าเกม
-- ========================================================================
local battle_tbattribute
pcall(function()
    local gc = ReplicatedStorage:WaitForChild("_genConfigs", 3) or ReplicatedStorage:FindFirstChild("_genConfigs")
    if gc then
        local cf = gc:WaitForChild("battle_tbattribute", 2) or gc:FindFirstChild("battle_tbattribute")
        if cf then battle_tbattribute = require(cf) end
    end
end)

local battle_tbnestunlock
pcall(function()
    local gc = ReplicatedStorage:WaitForChild("_genConfigs", 3) or ReplicatedStorage:FindFirstChild("_genConfigs")
    if gc then
        local cf = gc:WaitForChild("battle_tbnestunlock", 2) or gc:FindFirstChild("battle_tbnestunlock")
        if cf then battle_tbnestunlock = require(cf) end
    end
end)

local battle_tbunit
pcall(function()
    local gc = ReplicatedStorage:WaitForChild("_genConfigs", 3) or ReplicatedStorage:FindFirstChild("_genConfigs")
    if gc then
        local cf = gc:WaitForChild("battle_tbunit", 2) or gc:FindFirstChild("battle_tbunit")
        if cf then battle_tbunit = require(cf) end
    end
end)

local battle_tbtag
pcall(function()
    local gc = ReplicatedStorage:WaitForChild("_genConfigs", 3) or ReplicatedStorage:FindFirstChild("_genConfigs")
    if gc then
        local cf = gc:WaitForChild("battle_tbtag", 2) or gc:FindFirstChild("battle_tbtag")
        if cf then battle_tbtag = require(cf) end
    end
end)

-- ----- ตัวช่วยอ่านราคาอัปเกรด (ทนต่อรูปแบบข้อมูลที่ต่างกัน) -----
local function reloadAttrConfig()
    if battle_tbattribute then return end
    pcall(function()
        local gc = ReplicatedStorage:FindFirstChild("_genConfigs")
        local cf = gc and gc:FindFirstChild("battle_tbattribute")
        if cf then battle_tbattribute = require(cf) end
    end)
end

local function extractCost(entry)
    if type(entry) ~= "table" then return nil end
    for _, k in ipairs({ "Cost", "cost", "CostGold", "Gold", "Price", "Coin", "CostFood" }) do
        local v = entry[k]
        if type(v) == "number" and v > 0 then return v end
        if type(v) == "string" and tonumber(v) and tonumber(v) > 0 then return tonumber(v) end
        if type(v) == "table" then
            local n = tonumber(v.Count or v.Amount or v.Num or v.Value)
            if not n then
                for i = #v, 1, -1 do
                    if type(v[i]) == "number" then n = v[i] break end
                end
            end
            if n and n > 0 then return n end
        end
    end
    return nil
end

-- คืนค่า: เลเวลปัจจุบัน, ราคาตาม Info[เลเวล+1], สถานะ ("ok" | "maxed" | "nocfg" | "nocost"), ราคาตาม Info[เลเวลปัจจุบัน]
local function getUpgradeInfo(attr)
    local lvl = 1
    pcall(function()
        local WuKong = require(ReplicatedStorage.WuKong)
        lvl = tonumber(WuKong:ExecuteQuery(string.format("/属性/%s?属性数量", attr))) or 1
    end)
    reloadAttrConfig()
    local cfg = battle_tbattribute and battle_tbattribute[attr]
    if type(cfg) ~= "table" or type(cfg.Info) ~= "table" then
        return lvl, nil, "nocfg"
    end
    local nextInfo = cfg.Info[lvl + 1]
    local curCost = extractCost(cfg.Info[lvl])
    if nextInfo == nil then
        local maxKey = 0
        for k in pairs(cfg.Info) do
            if type(k) == "number" and k > maxKey then maxKey = k end
        end
        if maxKey > 0 and lvl >= maxKey then
            return lvl, nil, "maxed", curCost
        end
        return lvl, nil, curCost and "ok" or "nocost", curCost
    end
    local cost = extractCost(nextInfo)
    if cost or curCost then return lvl, cost, "ok", curCost end
    return lvl, nil, "nocost", curCost
end

-- ถ้าอ่านราคาไม่ได้: ลองกดอย่างระวัง (ครั้งต่อไปเมื่อเงินเพิ่มขึ้นมากพอ หรือเลเวลขึ้นแล้วเท่านั้น)
local probeState = {}
local function probeAllowed(key, gold, lvl, interval)
    local now = os.clock()
    local st = probeState[key]
    if gold <= 0 then return false end
    if not st then return true end
    if (now - st.t) < math.max(interval, 3) then return false end
    if lvl > st.lvl then return true end
    if gold >= st.gold * 1.3 and (now - st.t) >= math.max(interval * 5, 15) then return true end
    return (now - st.t) >= 120
end
local function probeMark(key, gold, lvl)
    probeState[key] = { t = os.clock(), gold = gold, lvl = lvl }
end

-- Helper อัปเดตข้อความ Paragraph ของ WindUI อย่างเสถียร
local function updateParagraph(para, title, desc)
    if not para then return end
    pcall(function()
        if para.SetTitle then
            para:SetTitle(title)
        end
        if para.SetDesc and desc then
            para:SetDesc(desc)
        end
        local frame = para.ParagraphFrame or para.Frame
        if frame and frame.UIElements then
            if frame.UIElements.Title and title then
                frame.UIElements.Title.Text = tostring(title)
                frame.UIElements.Title.Visible = true
            end
            if frame.UIElements.Desc and desc then
                frame.UIElements.Desc.Text = tostring(desc)
                frame.UIElements.Desc.Visible = true
            end
        end
    end)
end

-- Helper ควบคุมขีดจำกัดเฟรมเรต (FPS Cap) และฟังก์ชันจำกัดเฟรมเรตสำหรับโหมด AFK
local fpsThrottleConnection = nil

local function applyFpsCap(fps)
    local target = math.floor(tonumber(fps) or 60)
    if target < 5 then target = 5 end

    -- 1. เรียกใช้งานฟังก์ชันของ Executor หลากหลายรูปแบบ
    pcall(function()
        local fn = setfpscap or set_fpscap or setfps or set_fps or (getgenv and (getgenv().setfpscap or getgenv().set_fpscap))
        if fn then
            fn(target)
        end
    end)

    -- 2. เคลียร์ RenderStepped throttle เดิม
    if fpsThrottleConnection then
        fpsThrottleConnection:Disconnect()
        fpsThrottleConnection = nil
    end

    -- 3. หากตั้งค่า <= 30 FPS (เช่น 15 FPS โหมด AFK) ให้หน่วงเวลา RenderStepped โดยตรงเพื่อให้เฟรมเรตลดลง 15 FPS จริง 100%
    if target <= 30 then
        local minDelta = 1 / target
        local lastTime = os.clock()
        fpsThrottleConnection = RunService.RenderStepped:Connect(function()
            local now = os.clock()
            local elapsed = now - lastTime
            local diff = minDelta - elapsed
            if diff > 0 then
                local t0 = os.clock()
                while (os.clock() - t0) < diff do end
            end
            lastTime = os.clock()
        end)
    end
end

local lowGraphicsOriginals = {}
local terrainDecorationOriginal

local function applyLowGraphics(enabled)
    Flags.LowGraphics = enabled
    local terrain = Workspace:FindFirstChildOfClass("Terrain")

    if enabled then
        if terrain and terrainDecorationOriginal == nil then
            terrainDecorationOriginal = terrain.Decoration
            terrain.Decoration = false
        end

        for _, root in ipairs({ Workspace, Lighting }) do
            for _, instance in ipairs(root:GetDescendants()) do
                if not lowGraphicsOriginals[instance] then
                    local original = {}
                    if instance:IsA("BasePart") then
                        original.Material = instance.Material
                        original.Reflectance = instance.Reflectance
                        original.CastShadow = instance.CastShadow
                    end
                    if instance:IsA("ParticleEmitter") or instance:IsA("Trail") or instance:IsA("Beam")
                        or instance:IsA("Fire") or instance:IsA("Smoke") or instance:IsA("Sparkles")
                        or instance:IsA("PostEffect") or instance:IsA("Highlight") then
                        original.Enabled = instance.Enabled
                    end
                    if next(original) then
                        lowGraphicsOriginals[instance] = original
                    end
                end

                if instance:IsA("BasePart") then
                    instance.Material = Enum.Material.SmoothPlastic
                    instance.Reflectance = 0
                    instance.CastShadow = false
                end
                if instance:IsA("ParticleEmitter") or instance:IsA("Trail") or instance:IsA("Beam")
                    or instance:IsA("Fire") or instance:IsA("Smoke") or instance:IsA("Sparkles")
                    or instance:IsA("PostEffect") or instance:IsA("Highlight") then
                    instance.Enabled = false
                end
            end
        end
        return
    end

    if terrain and terrainDecorationOriginal ~= nil then
        terrain.Decoration = terrainDecorationOriginal
    end
    terrainDecorationOriginal = nil

    for instance, original in pairs(lowGraphicsOriginals) do
        if instance and instance.Parent then
            pcall(function()
                for property, value in pairs(original) do
                    instance[property] = value
                end
            end)
        end
        lowGraphicsOriginals[instance] = nil
    end
end

-- ดึงจำนวนเงิน/ทองปัจจุบันของผู้เล่นอย่างแม่นยำ
local function getPlayerGold()
    local gold = 0
    pcall(function()
        local wk = ReplicatedStorage:WaitForChild("WuKong", 2) or ReplicatedStorage:FindFirstChild("WuKong")
        if wk then
            local WuKong = require(wk)
            local val = WuKong:ExecuteQuery("/货币/金币?属性数量")
            if val then gold = tonumber(val) or 0 end
        end
    end)
    if gold == 0 then
        pcall(function()
            local Battle = ReplicatedStorage:FindFirstChild("Battle")
            if Battle and Battle:FindFirstChild("Game") and Battle.Game:FindFirstChild("Helper") and Battle.Game.Helper:FindFirstChild("PlayerDataHelper") then
                local PlayerDataHelper = require(Battle.Game.Helper.PlayerDataHelper)
                gold = tonumber(PlayerDataHelper.GetPlayerGold(LocalPlayer.UserId)) or 0
            end
        end)
    end
    return gold
end

-- รับส่งแพ็กเกจ ECS Command
local function sendEcsCommand(commandName, payload)
    pcall(function()
        local EventBus = require(ReplicatedStorage.Packages.EventBus)
        EventBus.FireServer("ECS_COMMAND", commandName, payload or {})
    end)
end

-- ค้นหาห้องรังของตนเอง (My Room)
local function getMyRoom()
    local myRoomIdx = LocalPlayer:GetAttribute("RoomIndex")
    local rooms = Workspace:FindFirstChild("Rooms") or Workspace:FindFirstChild("Map")
    if not rooms then
        for _, child in ipairs(Workspace:GetChildren()) do
            if child:FindFirstChild("PlayerFood") or (child:FindFirstChild("1") and child:FindFirstChild("2")) then
                rooms = child
                break
            end
        end
    end
    if rooms then
        if myRoomIdx then
            local rm = rooms:FindFirstChild(tostring(myRoomIdx)) or rooms:FindFirstChild("Room" .. tostring(myRoomIdx))
            if rm then return rm end
        end
        for _, rm in ipairs(rooms:GetChildren()) do
            local owner = rm:GetAttribute("OwnerUserId") or rm:GetAttribute("UserId") or rm:GetAttribute("Owner")
            if owner == LocalPlayer.UserId or owner == LocalPlayer.Name then
                return rm
            end
        end
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local pos = LocalPlayer.Character.HumanoidRootPart.Position
            local closestRoom = nil
            local minDist = 999999
            for _, rm in ipairs(rooms:GetChildren()) do
                local pf = rm:FindFirstChild("PlayerFood") or rm:FindFirstChild("Spawn") or rm:FindFirstChild("Floor")
                if pf then
                    local ppos = pf:IsA("Model") and pf:GetPivot().Position or pf.Position
                    local dist = (pos - ppos).Magnitude
                    if dist < minDist then
                        minDist = dist
                        closestRoom = rm
                    end
                end
            end
            if closestRoom and minDist < 200 then
                return closestRoom
            end
        end
    end
    return nil
end

local function teleportTo(cf)
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and cf then
        LocalPlayer.Character.HumanoidRootPart.CFrame = cf + Vector3.new(0, 3, 0)
    end
end

-- ดึงค่าตัวคูณราคาขายปัจจุบันอย่างแม่นยำ (รองรับทั้ง PlayerDataHelper, FoodSellPriceService และ SellShopModel)
local function getCurrentFoodMultiplier()
    local curMul = 1.0
    
    -- วิธีที่ 1: ตรวจสอบจาก PlayerDataHelper (มีบัพ VIP, เพื่อน, สัตว์เลี้ยง ครบถ้วน)
    pcall(function()
        local PlayerDataHelper = require(ReplicatedStorage.Battle.Game.Helper.PlayerDataHelper)
        if PlayerDataHelper and PlayerDataHelper.GetPlayerFoodSellPriceState then
            local state = PlayerDataHelper.GetPlayerFoodSellPriceState(LocalPlayer.UserId)
            if state and state.GoldPerFood then
                local v = tonumber(state.GoldPerFood)
                if v and v > 0 then curMul = v return end
            end
        end
    end)
    
    -- วิธีที่ 2: ตรวจสอบจาก FoodSellPriceService ของห้อง
    if curMul == 1.0 then
        pcall(function()
            local FoodSellPriceService = require(ReplicatedStorage.Battle.Game.Helper.RoomHelper.FoodSellPriceService)
            if FoodSellPriceService and FoodSellPriceService.GetGoldPerFood then
                local v = tonumber(FoodSellPriceService.GetGoldPerFood())
                if v and v > 0 then curMul = v return end
            end
        end)
    end
    
    -- วิธีที่ 3: ตรวจสอบจาก SellShopModel
    if curMul == 1.0 then
        pcall(function()
            local sellShopModel = require(ReplicatedStorage.UI.Main.Model.SellShopModel)
            if sellShopModel then
                if not sellShopModel.Initialized then
                    sellShopModel:Init()
                end
                sellShopModel:RequestState(nil, true)
                if sellShopModel.State then
                    local v = tonumber(sellShopModel.State.GoldPerFood) or tonumber(sellShopModel.State.BaseGoldPerFood)
                    if v and v > 0 then curMul = v return end
                end
            end
        end)
    end
    
    return curMul
end

-- ตรวจสอบว่าตัวคูณราคาขายถึงเป้าหมายที่ผู้เล่นตั้งไว้หรือไม่ (เข้มงวด 100%)
local function isFoodMultiplierMet()
    if not Flags.SellAtMultiplier then
        return true
    end
    local cur = getCurrentFoodMultiplier()
    local target = tonumber(Flags.Multiplier) or 1.80
    return cur >= target
end

-- แปลงสตริงตัวเลขที่มีหน่วยย่อ (K, M, B, T, QA, QI) เป็นตัวเลขจริง
local function parseFormattedNumber(str)
    if not str or str == "" then return 0 end
    local clean = tostring(str):gsub("%$", ""):gsub(",", ""):gsub("%s+", ""):upper()
    if clean == "FREE" or clean:find("FREE") then
        return 0
    end
    
    local numStr, suffix = clean:match("^([%d%.]+)%s*([A-Z]*)$")
    if not numStr then
        numStr = clean:match("([%d%.]+)")
    end
    local val = tonumber(numStr) or 0
    if suffix and suffix ~= "" then
        if suffix == "K" then
            val = val * 1e3
        elseif suffix == "M" then
            val = val * 1e6
        elseif suffix == "B" then
            val = val * 1e9
        elseif suffix == "T" then
            val = val * 1e12
        elseif suffix == "QA" then
            val = val * 1e15
        elseif suffix == "QI" then
            val = val * 1e18
        end
    end
    return val
end

-- Helper บล็อคเอฟเฟกต์การสุ่ม (Clover / Luck / Super Roll Animation) เพื่อความรวดเร็ว
local cloverEffectFrame
local cloverEffectConnection

local function applyCloverEffectSetting()
    local success, err = pcall(function()
        local player = game:GetService("Players").LocalPlayer
        local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
        local hud = playerGui and playerGui:FindFirstChild("HUDContainer")
        local effectFrame = hud and hud:FindFirstChild("EffectFrame")
        if effectFrame and cloverEffectFrame ~= effectFrame then
            if cloverEffectConnection then
                cloverEffectConnection:Disconnect()
            end
            cloverEffectFrame = effectFrame
            cloverEffectConnection = effectFrame.ChildAdded:Connect(function(icon)
                if Flags.DisableCloverEffect and icon:GetAttribute("RollEffectIcon") then
                    icon:Destroy()
                end
            end)
        end
        if Flags.DisableCloverEffect and effectFrame then
            for _, icon in ipairs(effectFrame:GetDescendants()) do
                if icon:GetAttribute("RollEffectIcon") then
                    icon:Destroy()
                end
            end
        end

        local Battle = ReplicatedStorage:FindFirstChild("Battle")
        local gameFolder = Battle and Battle:FindFirstChild("Game")
        local helperFolder = gameFolder and gameFolder:FindFirstChild("Helper")
        local rollHelper = helperFolder and helperFolder:FindFirstChild("RollPresentationHelper")
        local presRegMod = rollHelper and rollHelper:FindFirstChild("PresentationRegistry")
        local presDir = rollHelper and rollHelper:FindFirstChild("Presentations")
        if presRegMod and presDir then
            local presReg = require(presRegMod)
            local normalModule = presDir:FindFirstChild("Normal")
            local normalPres = normalModule and require(normalModule)
            if presReg and normalPres then
                if not presReg._origResolve then
                    presReg._origResolve = presReg.Resolve
                    presReg.Resolve = function(result)
                        if Flags.DisableCloverEffect then
                            return "Normal", normalPres
                        end
                        return presReg._origResolve(result)
                    end
                end

                for _, name in ipairs({ "Luck2", "Luck4", "Luck8", "Super" }) do
                    local presentationModule = presDir:FindFirstChild(name)
                    local presentation = presentationModule and require(presentationModule)
                    if presentation and not presentation._origPlay then
                        presentation._origPlay = presentation.Play
                        presentation.Play = function(a1, a2, a3, a4, a5, a6)
                            if Flags.DisableCloverEffect then
                                if a5 then a5.SuppressRollEffects = true end
                                return normalPres.Play(a1, a2, a3, a4, a5, a6)
                            end
                            return presentation._origPlay(a1, a2, a3, a4, a5, a6)
                        end
                    end
                end
            end
        end

        local ui = ReplicatedStorage:FindFirstChild("UI")
        local main = ui and ui:FindFirstChild("Main")
        local view = main and main:FindFirstChild("View")
        local rollEffectModule = view and view:FindFirstChild("RollEffect")
        if rollEffectModule then
            local rollEffect = require(rollEffectModule)
            if rollEffect and not rollEffect._origOnRollEffect then
                rollEffect._origOnRollEffect = rollEffect.OnRollEffect
                rollEffect.OnRollEffect = function(self, payload)
                    if Flags.DisableCloverEffect and payload and payload.EffectType == "LuckRain" then
                        for _, active in pairs(self.ContinuousLuckRain or {}) do
                            active.Active = false
                        end
                        table.clear(self.ContinuousLuckRain or {})

                        local activeIcons = self.ActiveIcons or {}
                        for i = #activeIcons, 1, -1 do
                            local icon = activeIcons[i]
                            local effectKey = icon and icon:GetAttribute("RollEffectKey")
                            if type(effectKey) == "string" and effectKey:match("^LuckRain") then
                                if icon.Parent then icon:Destroy() end
                                table.remove(activeIcons, i)
                            end
                        end
                        return
                    end
                    return rollEffect._origOnRollEffect(self, payload)
                end
            end
        end
    end)
    if not success then
        warn("[AntEmpireHub] Failed to update clover effect setting: " .. tostring(err))
    end
end

local function applySellMoneyEffectSetting()
    local success, err = pcall(function()
        local ui = ReplicatedStorage:FindFirstChild("UI")
        local main = ui and ui:FindFirstChild("Main")
        local view = main and main:FindFirstChild("View")
        local playerInfoModule = view and view:FindFirstChild("PlayerInfo")
        if not playerInfoModule then return end

        local playerInfo = require(playerInfoModule)
        if not playerInfo or playerInfo._hubOriginalOnSellFoodResult then return end

        playerInfo._hubOriginalOnSellFoodResult = playerInfo.OnSellFoodResult
        playerInfo.OnSellFoodResult = function(self, result)
            if not Flags.DisableSellMoneyEffect or not result or not result.Success
                or not result.Result or result.Result.AutoSell == true then
                return playerInfo._hubOriginalOnSellFoodResult(self, result)
            end

            local originalPlayCoinBurst = self.PlayCoinBurst
            self.PlayCoinBurst = function()
                return false
            end
            local ok, callErr = pcall(playerInfo._hubOriginalOnSellFoodResult, self, result)
            self.PlayCoinBurst = originalPlayCoinBurst
            if not ok then
                error(callErr, 0)
            end
        end
    end)
    if not success then
        warn("[AntEmpireHub] Failed to update sell money effect setting: " .. tostring(err))
    end
end

-- แกะข้อมูลมดจาก RollManager หรือ ProximityPrompt อย่างแม่นยำ
local function getPromptAntInfo(prompt)
    local info = {
        Cost = 0,
        Rarity = "",
        Mutation = "None",
        DisplayName = "Ant",
        UnitId = "",
        ClaimId = nil,
        IsItem = false,
        IsStar = false
    }

    -- 1. ดึงจาก RollPresentationHelper โดยตรง (แม่นยำ 100%)
    pcall(function()
        local Battle = ReplicatedStorage:FindFirstChild("Battle")
        if Battle and Battle:FindFirstChild("Game") and Battle.Game:FindFirstChild("Helper") and Battle.Game.Helper:FindFirstChild("RollPresentationHelper") then
            local rph = require(Battle.Game.Helper.RollPresentationHelper)
            local mgr = rph.GetManager()
            if mgr and mgr.ClaimPlatforms then
                for claimId, platform in pairs(mgr.ClaimPlatforms) do
                    if platform.ClaimPrompt == prompt or (platform.ResultModel and (prompt:IsDescendantOf(platform.ResultModel) or prompt.Parent == platform.ResultModel)) then
                        info.ClaimId = claimId
                        local res = platform.Result
                        if res then
                            if res.ResultType == "Item" then
                                info.IsItem = true
                                info.IsStar = true
                                info.Cost = 0
                                return
                            end
                            info.Cost = tonumber(res.Cost) or 0
                            info.UnitId = tostring(res.UnitId or "")
                            info.Rarity = tostring(res.Rarity or "Common")
                            local tagId = tonumber(res.TagId) or 0
                            info.Mutation = TagMapping[tagId] or "None"
                            return
                        end
                    end
                end
            end
        end
    end)

    if info.ClaimId and info.Rarity ~= "" then
        return info
    end

    -- 2. Fallback: ดึงจากข้อความและโมเดล
    local actionText = tostring(prompt.ActionText or "")
    local objectText = tostring(prompt.ObjectText or "")

    if objectText:find("Star") or actionText:find("Star") or prompt.Name:find("Star") then
        info.IsItem = true
        info.IsStar = true
        info.Cost = 0
        return info
    end

    local costNum = parseFormattedNumber(objectText)
    if not costNum or costNum == 0 then
        costNum = parseFormattedNumber(actionText)
    end
    if costNum and costNum > 0 then
        info.Cost = costNum
    end

    local model = prompt:FindFirstAncestorOfClass("Model")
    if model then
        for _, rar in ipairs(RarityList) do
            if model.Name:find(rar) or (model.Parent and model.Parent.Name:find(rar)) then
                info.Rarity = rar
                break
            end
        end

        local unitAttr = model:GetAttribute("UnitId") or model:GetAttribute("Id") or model.Name
        if unitAttr and battle_tbunit and battle_tbunit[unitAttr] then
            local cfg = battle_tbunit[unitAttr]
            if info.Rarity == "" and cfg.Rarity then
                info.Rarity = tostring(cfg.Rarity)
            end
            if cfg.DisplayName then
                info.DisplayName = tostring(cfg.DisplayName)
            end
            if info.Cost == 0 and cfg.Price then
                info.Cost = tonumber(cfg.Price) or 0
            end
        end
    end

    if info.Rarity == "" then
        for _, rar in ipairs(RarityList) do
            if objectText:find(rar) or actionText:find(rar) then
                info.Rarity = rar
                break
            end
        end
    end

    return info
end

-- ตรวจสอบว่ามดตรงตามเงื่อนไขฟิลเตอร์ที่ผู้เล่นเลือกไว้หรือไม่
local function isDesiredAnt(info, currentGold)
    if info.IsItem or info.IsStar then
        return Flags.AutoBuyStar or Flags.AutoStarDungeon
    end

    local rarityPassed = false
    if type(Flags.BuyRarities) ~= "table" or #Flags.BuyRarities == 0 then
        rarityPassed = true
    else
        local antRarity = string.lower(tostring(info.Rarity or ""))
        for _, rar in ipairs(Flags.BuyRarities) do
            if string.lower(tostring(rar)) == antRarity then
                rarityPassed = true
                break
            end
        end
    end

    if not rarityPassed then
        return false
    end

    local mutationPassed = false
    if type(Flags.BuyMutations) ~= "table" or #Flags.BuyMutations == 0 or table.find(Flags.BuyMutations, "Any") then
        mutationPassed = true
    else
        local antMut = string.lower(tostring(info.Mutation or "None"))
        for _, mut in ipairs(Flags.BuyMutations) do
            if string.lower(tostring(mut)) == antMut then
                mutationPassed = true
                break
            end
        end
    end

    if not mutationPassed then
        return false
    end

    return true
end

loadConfig(true)
loadAutoloadConfig(true)
-- Migrate old saved upgrade names such as "Nest Layer (xxx)" to the new plain names
if type(Flags.SelectedUpgrades) == "table" then
    for i, v in ipairs(Flags.SelectedUpgrades) do
        Flags.SelectedUpgrades[i] = (tostring(v):gsub("%s*%b()", ""))
    end
end

local function regToggle(tab, _group, _flagName, cfg)
    local control = tab:Toggle(cfg)
    ConfigControls[_flagName] = control
    return control
end

-- ========================================================================
-- สร้างแท็บเมนู (ไม่มีอิโมจิ ออกแบบเรียบหรู คมชัด สไตล์มินิมอล)
-- ========================================================================
-- จัดกลุ่มเมนูด้านซ้าย (ถ้า WindUI เวอร์ชันนี้ไม่รองรับ Section จะใช้แบบเดิมอัตโนมัติ)
local function makeGroup(title)
    local ok, sec = pcall(function() return Window:Section({ Title = title, Opened = true }) end)
    if ok and sec and sec.Tab then return sec end
    return Window
end

local GroupFarm = makeGroup("Auto Farm")
local GroupGame = makeGroup("Activities & Shop")
local GroupTools = makeGroup("Tools")

local Tabs = {
    Roll = GroupFarm:Tab({ Title = "Roll", Icon = "sparkles" }),
    Farm = GroupFarm:Tab({ Title = "Food & Sell", Icon = "apple" }),
    Ants = GroupFarm:Tab({ Title = "Ants & Upgrades", Icon = "bug" }),
    Dungeon = GroupGame:Tab({ Title = "Dungeon", Icon = "swords" }),
    Events = GroupGame:Tab({ Title = "Events", Icon = "sparkle" }),
    Shop = GroupGame:Tab({ Title = "Convert & Shop", Icon = "recycle" }),
    Teleport = GroupTools:Tab({ Title = "Teleport & Player", Icon = "map-pin" }),
    Settings = GroupTools:Tab({ Title = "Settings", Icon = "settings" })
}

-- ========================================================================
-- 2. TAB: AUTO ROLL (ระบบสุ่มมด & ฟิลเตอร์กรองมด)
-- ========================================================================
Tabs.Roll:Paragraph({
    Title = "Ant Rolling",
    Desc = "Continuous rolling and animation skipping"
})

regToggle(Tabs.Roll, "Roll", "AutoRollAnt", {
    Title = "Auto Roll Ant",
    Value = Flags.AutoRollAnt,
    Callback = function(v) Flags.AutoRollAnt = v end
})

ConfigControls.DisableCloverEffect = Tabs.Roll:Toggle({
    Title = "Disable Clover Effect",
    Value = Flags.DisableCloverEffect,
    Callback = function(v)
        Flags.DisableCloverEffect = v
        applyCloverEffectSetting()
    end
})

Tabs.Roll:Divider()

Tabs.Roll:Paragraph({
    Title = "Buy & Claim Ants / Stars",
    Desc = "Buys and claims rolled ants that match your filters"
})

regToggle(Tabs.Roll, "Roll", "AutoBuyAnt", {
    Title = "Auto Buy Ant (Filtered)",
    Value = Flags.AutoBuyAnt,
    Callback = function(v) Flags.AutoBuyAnt = v end
})

regToggle(Tabs.Roll, "Roll", "AutoBuyStar", {
    Title = "Auto Buy Star",
    Value = Flags.AutoBuyStar,
    Callback = function(v) Flags.AutoBuyStar = v end
})

regToggle(Tabs.Roll, "Roll", "SkipIfNotEnoughGold", {
    Title = "Skip If Not Enough Gold",
    Value = Flags.SkipIfNotEnoughGold,
    Callback = function(v) Flags.SkipIfNotEnoughGold = v end
})

Tabs.Roll:Divider()

Tabs.Roll:Paragraph({
    Title = "Rarity & Mutation Filter",
    Desc = "Only ants matching these filters will be bought"
})

ConfigControls.BuyRarities = Tabs.Roll:Dropdown({
    Title = "Rarity to Buy",
    Values = RarityList,
    Value = Flags.BuyRarities,
    Multi = true,
    Callback = function(selected)
        Flags.BuyRarities = selected
    end
})

ConfigControls.BuyMutations = Tabs.Roll:Dropdown({
    Title = "Mutations to Buy",
    Values = MutationList,
    Value = Flags.BuyMutations,
    Multi = true,
    Callback = function(selected)
        Flags.BuyMutations = selected
    end
})

-- ========================================================================
-- 3. TAB: FOOD & FARM (อาหาร & การขาย)
-- ========================================================================
Tabs.Farm:Paragraph({
    Title = "Collect Food",
    Desc = "Collects nest food to the player"
})

regToggle(Tabs.Farm, "Farm", "AutoCollect", {
    Title = "Auto Collect Food",
    Value = Flags.AutoCollect,
    Callback = function(v) Flags.AutoCollect = v end
})

Tabs.Farm:Divider()

Tabs.Farm:Paragraph({
    Title = "Food Selling",
    Desc = "Sells food based on the market multiplier"
})

regToggle(Tabs.Farm, "Farm", "AutoSell", {
    Title = "Auto Sell Food",
    Value = Flags.AutoSell,
    Callback = function(v) Flags.AutoSell = v end
})

ConfigControls.DisableSellMoneyEffect = Tabs.Farm:Toggle({
    Title = "Disable Sell Money Effect",
    Value = Flags.DisableSellMoneyEffect,
    Callback = function(v)
        Flags.DisableSellMoneyEffect = v
        applySellMoneyEffectSetting()
    end
})

Tabs.Farm:Button({
    Title = "Sell All Food Now",
    Callback = function()
        local success, err = pcall(function()
            local foodCarry = require(ReplicatedStorage.Battle.Game.Helper.RoomHelper.FoodSellCarryState)
            local PlayerDataHelper = require(ReplicatedStorage.Battle.Game.Helper.PlayerDataHelper)
            local carriedFood = tonumber(LocalPlayer:GetAttribute("CarriedSellFoodAmount")) or 0
            local food = tonumber(PlayerDataHelper.GetPlayerFood(LocalPlayer.UserId)) or 0
            if food <= 0 then food = carriedFood end
            if food <= 0 then
                local snapshot = foodCarry.GetSnapshot()
                food = (snapshot and tonumber(snapshot.FoodAmount)) or 0
            end

            if food > 0 or foodCarry.HasSnapshot() or carriedFood > 0 then
                local sellAmount = math.max(food, 1)
                if not foodCarry.HasSnapshot() then
                    foodCarry.SetSnapshot({
                        Source = "PlayerFoodPrompt",
                        FoodAmount = sellAmount,
                        RoomIndex = LocalPlayer:GetAttribute("RoomIndex") or 1
                    })
                end
                foodCarry.RequestSell({
                    SendCommand = function(command, payload)
                        payload = payload or {}
                        payload.FoodAmount = payload.FoodAmount or sellAmount
                        payload.Source = "PlayerFoodSellPrompt"
                        payload.UserId = LocalPlayer.UserId
                        sendEcsCommand(command, payload)
                    end
                }, { Source = "PlayerFoodSellPrompt" })
                WindUI:Notify({
                    Title = "Quick Sell",
                    Content = "Sent sell command for " .. tostring(sellAmount) .. " unit(s)",
                    Duration = 2.5
                })
            else
                WindUI:Notify({
                    Title = "Quick Sell",
                    Content = "No food in the nest or in hand to sell.",
                    Duration = 2.5
                })
            end
        end)
        if not success then
            warn("[AntEmpireHub] Quick sell failed: " .. tostring(err))
        end
    end
})

regToggle(Tabs.Farm, "Farm", "SellAtMultiplier", {
    Title = "Sell At Multiplier",
    Value = Flags.SellAtMultiplier,
    Callback = function(v) Flags.SellAtMultiplier = v end
})

ConfigControls.Multiplier = Tabs.Farm:Slider({
    Title = "Target Multiplier",
    Step = 0.05,
    Value = { Min = 1.0, Max = 2.5, Default = 1.80 },
    Callback = function(val)
        Flags.Multiplier = tonumber(string.format("%.2f", val))
    end
})

MultiplierLiveStatus = Tabs.Farm:Paragraph({
    Title = "Multiplier Status: Loading...",
    Desc = "Live shop multiplier status"
})

task.spawn(function()
    while true do
        local success, err = pcall(function()
            local multiplier = getCurrentFoodMultiplier()
            if Flags.SellAtMultiplier then
                if multiplier >= Flags.Multiplier then
                    updateParagraph(MultiplierLiveStatus,
                        string.format("Market: %.2fX >= Target: %.2fX (collecting and selling)", multiplier, Flags.Multiplier),
                        "Target reached. Food is pulled from the nest and sold immediately."
                    )
                else
                    updateParagraph(MultiplierLiveStatus,
                        string.format("Market: %.2fX < Target: %.2fX (stockpiling food)", multiplier, Flags.Multiplier),
                        "Food stays in the nest until the multiplier reaches the target."
                    )
                end
            else
                updateParagraph(MultiplierLiveStatus,
                    string.format("Market: %.2fX (instant sell mode, no waiting)", multiplier),
                    "Food is collected and sold continuously at any multiplier."
                )
            end
        end)
        if not success then
            warn("[AntEmpireHub] Failed to refresh sell multiplier status: " .. tostring(err))
        end
        task.wait(1.2)
    end
end)

Tabs.Farm:Paragraph({
    Title = "Black Market Event",
    Desc = "Automatically sell stored food for the Black Market event price"
})

regToggle(Tabs.Farm, "Farm", "AutoSellToFoodBuyer", {
    Title = "Auto Sell During Black Market",
    Value = Flags.AutoSellToFoodBuyer,
    Callback = function(v) Flags.AutoSellToFoodBuyer = v end
})

-- ========================================================================
-- 4. TAB: ANTS & UPGRADES (ระบบมด & อัปเกรดรัง)
-- ========================================================================
Tabs.Ants:Paragraph({
    Title = "Ant Management",
    Desc = "Manage ants and expand slots when you have enough gold"
})

regToggle(Tabs.Ants, "Ants", "AutoEquipBest", {
    Title = "Auto Equip Best",
    Value = Flags.AutoEquipBest,
    Callback = function(v) Flags.AutoEquipBest = v end
})

regToggle(Tabs.Ants, "Ants", "AutoUpgradeEquippedAnts", {
    Title = "Auto Upgrade Equipped Ants",
    Value = Flags.AutoUpgradeEquippedAnts,
    Callback = function(v) Flags.AutoUpgradeEquippedAnts = v end
})

regToggle(Tabs.Ants, "Ants", "AutoUnlockAntHole", {
    Title = "Auto Unlock Ant Hole",
    Value = Flags.AutoUnlockAntHole,
    Callback = function(v) Flags.AutoUnlockAntHole = v end
})

regToggle(Tabs.Ants, "Ants", "AutoPlaceAnt", {
    Title = "Auto Place Ant",
    Value = Flags.AutoPlaceAnt,
    Callback = function(v) Flags.AutoPlaceAnt = v end
})

regToggle(Tabs.Ants, "Ants", "AutoStrokePets", {
    Title = "Auto Stroke Pets",
    Value = Flags.AutoStrokePets,
    Callback = function(v) Flags.AutoStrokePets = v end
})

regToggle(Tabs.Ants, "Ants", "HideAnts", {
    Title = "Hide Ants (Reduce Lag)",
    Value = Flags.HideAnts,
    Callback = function(v) Flags.HideAnts = v end
})

Tabs.Ants:Divider()

Tabs.Ants:Paragraph({
    Title = "Colony Upgrades",
    Desc = "Buys colony stat upgrades when you have enough gold"
})

ConfigControls.UpgradeInterval = Tabs.Ants:Slider({
    Title = "Auto Upgrade Interval (sec)",
    Step = 0.5,
    Value = { Min = 1, Max = 30, Default = math.clamp(tonumber(Flags.UpgradeInterval) or 3, 1, 30) },
    Callback = function(val)
        Flags.UpgradeInterval = tonumber(val) or 3
    end
})

Tabs.Ants:Button({
    Title = "Check Upgrade Prices",
    Callback = function()
        local lines = { "Current gold: " .. tostring(getPlayerGold()) }
        for _, uiName in ipairs(Flags.SelectedUpgrades or {}) do
            local attr = UpgradeMapping[uiName]
            if attr then
                local lvl, cost, state, curCost = getUpgradeInfo(attr)
                local detail = state == "ok" and string.format("Table Lv+1: %s | Current Lv: %s", tostring(cost or "-"), tostring(curCost or "-"))
                    or state == "maxed" and "Max level"
                    or state == "nocfg" and "No price data in game"
                    or "Price unreadable"
                table.insert(lines, string.format("%s: Lv.%s • %s", uiName:match("^[^%(]+") or uiName, tostring(lvl), detail))
            end
        end
        WindUI:Notify({ Title = "Upgrade Status", Content = table.concat(lines, "\n"), Duration = 10 })
    end
})

regToggle(Tabs.Ants, "Ants", "AutoBuyUpgrades", {
    Title = "Auto Buy Upgrades",
    Value = Flags.AutoBuyUpgrades,
    Callback = function(v) Flags.AutoBuyUpgrades = v end
})

ConfigControls.SelectedUpgrades = Tabs.Ants:Dropdown({
    Title = "Selected Upgrades",
    Values = {
        "Nest Layer",
        "Ant Speed",
        "Ant Atk",
        "Queen Level",
        "Luck",
        "Single Roll Count"
    },
    Value = Flags.SelectedUpgrades,
    Multi = true,
    Callback = function(selected)
        Flags.SelectedUpgrades = selected
    end
})

-- ========================================================================
-- 5. TAB: DUNGEON (ระบบลงดันเจี้ยน & บอส)
-- ========================================================================
Tabs.Dungeon:Divider()

Tabs.Dungeon:Paragraph({
    Title = "Dungeon Automation",
    Desc = "Automatic dungeon entry and attack speed"
})

regToggle(Tabs.Dungeon, "Dungeon", "AutoDungeon", {
    Title = "Auto Dungeon",
    Value = Flags.AutoDungeon,
    Callback = function(v) Flags.AutoDungeon = v end
})

regToggle(Tabs.Dungeon, "Dungeon", "AutoStarDungeon", {
    Title = "Auto Star Dungeon",
    Value = Flags.AutoStarDungeon,
    Callback = function(v) Flags.AutoStarDungeon = v end
})

regToggle(Tabs.Dungeon, "Dungeon", "AutoPressDungeonStart", {
    Title = "Auto Start",
    Value = Flags.AutoPressDungeonStart,
    Callback = function(v) Flags.AutoPressDungeonStart = v end
})

regToggle(Tabs.Dungeon, "Dungeon", "Auto4xAttackSpeed", {
    Title = "Auto 4x Attack Speed",
    Value = Flags.Auto4xAttackSpeed,
    Callback = function(v) Flags.Auto4xAttackSpeed = v end
})

-- ========================================================================
-- 6. TAB: EVENTS (ระบบอีเวนต์พิเศษ)
-- ========================================================================
Tabs.Events:Paragraph({
    Title = "Event Collection",
    Desc = "Strawberry coins, travelling snail and index rewards"
})

regToggle(Tabs.Events, "Events", "AutoPickupStrawberryCoins", {
    Title = "Auto Pickup Strawberry Coins",
    Value = Flags.AutoPickupStrawberryCoins,
    Callback = function(v) Flags.AutoPickupStrawberryCoins = v end
})

ConfigControls.CoinPickupDelay = Tabs.Events:Slider({
    Title = "Coin Pickup Delay",
    Step = 0.05,
    Value = { Min = 0.05, Max = 1.00, Default = 0.10 },
    Callback = function(val)
        Flags.CoinPickupDelay = tonumber(string.format("%.2f", val)) or 0.10
    end
})

Tabs.Events:Divider()

Tabs.Events:Paragraph({
    Title = "Special Events",
    Desc = "Travelling snail and index rewards"
})

regToggle(Tabs.Events, "Events", "AutoClickTravellingSnail", {
    Title = "Auto Click Travelling Snail",
    Value = Flags.AutoClickTravellingSnail,
    Callback = function(v) Flags.AutoClickTravellingSnail = v end
})

regToggle(Tabs.Events, "Events", "AutoStarfallEvent", {
    Title = "Auto Starfall Event",
    Value = Flags.AutoStarfallEvent,
    Callback = function(v) Flags.AutoStarfallEvent = v end
})

regToggle(Tabs.Events, "Events", "AutoClaimIndex", {
    Title = "Auto Claim Index",
    Value = Flags.AutoClaimIndex,
    Callback = function(v) Flags.AutoClaimIndex = v end
})

regToggle(Tabs.Events, "Events", "AutoClaimPlaytimeRewards", {
    Title = "Auto Claim Playtime Rewards",
    Value = Flags.AutoClaimPlaytimeRewards,
    Callback = function(v) Flags.AutoClaimPlaytimeRewards = v end
})

-- ========================================================================
-- 7. TAB: CONVERTER & SHOP (เครื่องย่อยปุ๋ย & ร้านค้า)
-- ========================================================================
Tabs.Shop:Paragraph({
    Title = "Resource Converter",
    Desc = "Converts unused ants into compost and upgrade materials"
})

regToggle(Tabs.Shop, "Shop", "AutoResourceConverter", {
    Title = "Auto Convert Ants",
    Value = Flags.AutoResourceConverter,
    Callback = function(v) Flags.AutoResourceConverter = v end
})

ConfigControls.ConverterAnts = Tabs.Shop:Dropdown({
    Title = "Rarities to Convert",
    Values = { "None", "Common", "Uncommon", "Rare", "Epic", "Legendary" },
    Value = Flags.ConverterAnts,
    Callback = function(v) Flags.ConverterAnts = v end
})

ConfigControls.KeepPerStack = Tabs.Shop:Slider({
    Title = "Keep Amount (Do Not Convert)",
    Step = 1,
    Value = { Min = 1, Max = 50, Default = 15 },
    Callback = function(v) Flags.KeepPerStack = v end
})

Tabs.Shop:Divider()

Tabs.Shop:Paragraph({
    Title = "Items Shop",
    Desc = "Buy stocked items with in-game gold. Robux purchases are not automated."
})

regToggle(Tabs.Shop, "Shop", "AutoBuyFood", {
    Title = "Auto Buy Selected Item",
    Value = Flags.AutoBuyFood,
    Callback = function(v) Flags.AutoBuyFood = v end
})

local GearShopModel = require(ReplicatedStorage.UI.GearShop.Model.GearShopModel)
local ShopItemOptions = { "None" }
ShopItemIdByLabel = {}
local ShopItemConfigById = {}
for _, entry in ipairs(GearShopModel:GetCatalog()) do
    local itemId = entry.ItemId
    local config = entry.Config
    local coinPrice = tonumber(config.CoinPrice) or 0
    if config.Tag ~= "EventItem" and coinPrice > 0 then
        local label = string.format("%s (%s)", tostring(config.DisplayName or itemId), itemId)
        table.insert(ShopItemOptions, label)
        ShopItemIdByLabel[label] = itemId
        ShopItemConfigById[itemId] = config
    end
end

local selectedShopItemLabel = "None"
for label, itemId in pairs(ShopItemIdByLabel) do
    if itemId == Flags.SelectedShopItem then
        selectedShopItemLabel = label
        break
    end
end

ConfigControls.SelectedShopItem = Tabs.Shop:Dropdown({
    Title = "Item to Auto Buy",
    Values = ShopItemOptions,
    Value = selectedShopItemLabel,
    Callback = function(v)
        Flags.SelectedShopItem = ShopItemIdByLabel[v] or "None"
    end
})

-- ========================================================================
-- 8. TAB: PLAYER & TELEPORTS (การเคลื่อนที่ & วาร์ป)
-- ========================================================================
Tabs.Teleport:Paragraph({
    Title = "Player Movement",
    Desc = "Adjust walk speed and jump power"
})

ConfigControls.WalkSpeed = Tabs.Teleport:Slider({
    Title = "WalkSpeed",
    Step = 2,
    Value = { Min = 16, Max = 200, Default = 16 },
    Callback = function(v)
        Flags.WalkSpeed = v
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = v
        end
    end
})

ConfigControls.JumpPower = Tabs.Teleport:Slider({
    Title = "JumpPower",
    Step = 5,
    Value = { Min = 50, Max = 300, Default = 50 },
    Callback = function(v)
        Flags.JumpPower = v
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.JumpPower = v
        end
    end
})

regToggle(Tabs.Teleport, "Teleport", "InfiniteJump", {
    Title = "Infinite Jump",
    Value = Flags.InfiniteJump,
    Callback = function(v) Flags.InfiniteJump = v end
})

regToggle(Tabs.Teleport, "Teleport", "Noclip", {
    Title = "Noclip",
    Value = Flags.Noclip,
    Callback = function(v) Flags.Noclip = v end
})

Tabs.Teleport:Divider()

Tabs.Teleport:Paragraph({
    Title = "Teleports",
    Desc = "Jump to key locations on the map"
})

Tabs.Teleport:Button({
    Title = "Teleport To My Room",
    Callback = function()
        local myRoom = getMyRoom()
        if myRoom then
            local targetPart = myRoom:FindFirstChild("Spawn") or myRoom:FindFirstChild("Floor") or myRoom:FindFirstChild("PlayerFood")
            if targetPart then
                local cf = targetPart:IsA("Model") and targetPart:GetPivot() or targetPart.CFrame
                teleportTo(cf)
            end
        end
    end
})

Tabs.Teleport:Button({
    Title = "Teleport To Roll Pad",
    Callback = function()
        local rollPad = Workspace:FindFirstChild("RollPad", true) or Workspace:FindFirstChild("RollMachine", true)
        if rollPad then
            local cf = rollPad:IsA("Model") and rollPad:GetPivot() or rollPad.CFrame
            teleportTo(cf)
        else
            teleportTo(CFrame.new(0, 10, 0))
        end
    end
})

Tabs.Teleport:Button({
    Title = "Teleport To Food Shop",
    Callback = function()
        local myRoom = getMyRoom()
        local playerFood = myRoom and myRoom:FindFirstChild("PlayerFood")
        local sellPrompt = playerFood and playerFood:FindFirstChild("SellPrompt")
        if sellPrompt then
            teleportTo(sellPrompt.CFrame)
        else
            teleportTo(CFrame.new(20, 10, 20))
        end
    end
})

Tabs.Teleport:Button({
    Title = "Teleport To Black Market",
    Callback = function()
        local bm = Workspace:FindFirstChild("BlackMarket", true) or Workspace:FindFirstChild("FoodBuyer", true)
        if bm then
            local cf = bm:IsA("Model") and bm:GetPivot() or bm.CFrame
            teleportTo(cf)
        end
    end
})

Tabs.Teleport:Button({
    Title = "Teleport To Dungeon Entrance",
    Callback = function()
        local dFolder = Workspace:FindFirstChild("DungeonEntrances")
        if dFolder and #dFolder:GetChildren() > 0 then
            local ent = dFolder:GetChildren()[1]
            local cf = ent:IsA("Model") and ent:GetPivot() or ent.CFrame
            teleportTo(cf)
        end
    end
})

-- ========================================================================
-- 9. TAB: SETTINGS (การตั้งค่า & ประสิทธิภาพ)
-- ========================================================================
Tabs.Settings:Paragraph({
    Title = "Config Manager",
    Desc = "Create, select, save, load, import, export, rename, and autoload named config profiles."
})

ConfigNameInput = Tabs.Settings:Input({
    Title = "Config Name",
    Placeholder = "Enter a config name",
    Value = SelectedConfigName,
    Callback = function(value)
        SelectedConfigName = value
    end
})

ConfigDropdown = Tabs.Settings:Dropdown({
    Title = "Saved Configs",
    Values = {},
    Value = "",
    AllowNone = true,
    Callback = function(value)
        if type(value) == "string" and value ~= "" then
            SelectedConfigName = value
            if ConfigNameInput and type(ConfigNameInput.Set) == "function" then
                pcall(ConfigNameInput.Set, ConfigNameInput, value)
            end
        end
    end
})

Tabs.Settings:Button({
    Title = "Refresh Config List",
    Callback = refreshConfigDropdown
})

Tabs.Settings:Button({
    Title = "Create / Save Config",
    Callback = function()
        if saveConfig(SelectedConfigName) then
            refreshConfigDropdown()
        end
    end
})

Tabs.Settings:Button({
    Title = "Load Config",
    Callback = function()
        loadConfig(false, SelectedConfigName)
    end
})

Tabs.Settings:Button({
    Title = "Delete Config",
    Callback = function()
        resetConfig(SelectedConfigName)
    end
})

Tabs.Settings:Input({
    Title = "Rename From",
    Placeholder = "Existing config name",
    Value = "",
    Callback = function(value)
        RenameConfigFrom = value
    end
})

Tabs.Settings:Input({
    Title = "Rename To",
    Placeholder = "New config name",
    Value = "",
    Callback = function(value)
        RenameConfigTo = value
    end
})

Tabs.Settings:Button({
    Title = "Rename Config",
    Callback = function()
        local oldName, oldNameError = validateConfigName(RenameConfigFrom)
        local newName, newNameError = validateConfigName(RenameConfigTo)
        if not oldName or not newName then
            WindUI:Notify({Title = "Configs", Content = oldNameError or newNameError, Duration = 3})
            return
        end
        local ready, storageError = ensureConfigStorage()
        if not ready then
            WindUI:Notify({Title = "Configs", Content = storageError, Duration = 3})
            return
        end
        local oldPath = ConfigFolder .. "/" .. oldName .. ".json"
        local newPath = ConfigFolder .. "/" .. newName .. ".json"
        if not isfile(oldPath) or isfile(newPath) then
            WindUI:Notify({Title = "Configs", Content = "The source must exist and the new name must be unused.", Duration = 3})
            return
        end
        local flags, readError = readNamedConfig(oldName)
        if not flags then
            WindUI:Notify({Title = "Configs", Content = readError, Duration = 3})
            return
        end
        local renamed, renameError = pcall(function()
            writefile(newPath, HttpService:JSONEncode({version = 1, flags = flags}))
            delfile(oldPath)
        end)
        if not renamed then
            WindUI:Notify({Title = "Configs", Content = "Could not rename config: " .. tostring(renameError), Duration = 3})
            return
        end
        if isfile(ConfigAutoloadPath) then
            local readOk, autoloadName = pcall(readfile, ConfigAutoloadPath)
            if not readOk then
                warn("[AntEmpireHub] Renamed config but could not read autoload: " .. tostring(autoloadName))
            elseif autoloadName == oldName then
                local updated, updateError = pcall(writefile, ConfigAutoloadPath, newName)
                if not updated then
                    warn("[AntEmpireHub] Renamed config but could not update autoload: " .. tostring(updateError))
                end
            end
        end
        if SelectedConfigName == oldName then
            SelectedConfigName = newName
            if ConfigNameInput and type(ConfigNameInput.Set) == "function" then
                pcall(ConfigNameInput.Set, ConfigNameInput, newName)
            end
        end
        WindUI:Notify({Title = "Configs", Content = "Renamed config to: " .. newName, Duration = 2.5})
        refreshConfigDropdown()
    end
})

Tabs.Settings:Button({
    Title = "Set Autoload",
    Callback = function()
        local name, nameError = validateConfigName(SelectedConfigName)
        if not name then
            WindUI:Notify({Title = "Configs", Content = nameError, Duration = 3})
            return
        end
        local flags, readError = readNamedConfig(name)
        if not flags then
            WindUI:Notify({Title = "Configs", Content = readError, Duration = 3})
            return
        end
        local saved, saveError = pcall(writefile, ConfigAutoloadPath, name)
        if not saved then
            WindUI:Notify({Title = "Configs", Content = "Could not set autoload: " .. tostring(saveError), Duration = 3})
            return
        end
        WindUI:Notify({Title = "Configs", Content = "Autoload set to: " .. name, Duration = 2.5})
    end
})

Tabs.Settings:Button({
    Title = "Clear Autoload",
    Callback = function()
        local ready, storageError = ensureConfigStorage()
        if not ready then
            WindUI:Notify({Title = "Configs", Content = storageError, Duration = 3})
            return
        end
        if isfile(ConfigAutoloadPath) then
            local cleared, clearError = pcall(delfile, ConfigAutoloadPath)
            if not cleared then
                WindUI:Notify({Title = "Configs", Content = "Could not clear autoload: " .. tostring(clearError), Duration = 3})
                return
            end
        end
        WindUI:Notify({Title = "Configs", Content = "Autoload cleared.", Duration = 2.5})
    end
})

Tabs.Settings:Input({
    Title = "Import JSON",
    Placeholder = "Paste exported config JSON here",
    Value = "",
    Callback = function(value)
        ImportConfigText = tostring(value or "")
    end
})

Tabs.Settings:Button({
    Title = "Import Config",
    Callback = function()
        local name, nameError = validateConfigName(SelectedConfigName)
        if not name then
            WindUI:Notify({Title = "Configs", Content = nameError, Duration = 3})
            return
        end
        local decoded, data = pcall(function()
            return HttpService:JSONDecode(ImportConfigText)
        end)
        if not decoded then
            WindUI:Notify({Title = "Configs", Content = "Invalid JSON: " .. tostring(data), Duration = 3})
            return
        end
        local valid, flagsOrError = validateConfig(data, true)
        if not valid then
            WindUI:Notify({Title = "Configs", Content = flagsOrError, Duration = 3})
            return
        end
        local ready, storageError = ensureConfigStorage()
        if not ready then
            WindUI:Notify({Title = "Configs", Content = storageError, Duration = 3})
            return
        end
        local imported, importError = pcall(function()
            writefile(ConfigFolder .. "/" .. name .. ".json", HttpService:JSONEncode({
                version = 1,
                flags = flagsOrError,
            }))
        end)
        if not imported then
            WindUI:Notify({Title = "Configs", Content = "Could not import config: " .. tostring(importError), Duration = 3})
            return
        end
        SelectedConfigName = name
        if ConfigNameInput and type(ConfigNameInput.Set) == "function" then
            pcall(ConfigNameInput.Set, ConfigNameInput, name)
        end
        WindUI:Notify({Title = "Configs", Content = "Imported config: " .. name, Duration = 2.5})
        refreshConfigDropdown()
    end
})

Tabs.Settings:Button({
    Title = "Export Config",
    Callback = function()
        local name, nameError = validateConfigName(SelectedConfigName)
        if not name then
            WindUI:Notify({Title = "Configs", Content = nameError, Duration = 3})
            return
        end
        local encoded = HttpService:JSONEncode(makeConfigSnapshot())
        local ready, storageError = ensureConfigStorage()
        if not ready then
            WindUI:Notify({Title = "Configs", Content = storageError, Duration = 3})
            return
        end
        local exported, exportError = pcall(writefile, ConfigFolder .. "/" .. name .. ".export.json", encoded)
        if not exported then
            WindUI:Notify({Title = "Configs", Content = "Could not export config: " .. tostring(exportError), Duration = 3})
            return
        end
        if type(setclipboard) == "function" then
            local copied, clipboardError = pcall(setclipboard, encoded)
            if copied then
                WindUI:Notify({Title = "Configs", Content = "Exported JSON file and copied it to the clipboard.", Duration = 2.5})
            else
                WindUI:Notify({Title = "Configs", Content = "Export file saved; clipboard failed: " .. tostring(clipboardError), Duration = 3})
            end
        else
            WindUI:Notify({Title = "Configs", Content = "Exported to " .. name .. ".export.json", Duration = 2.5})
        end
    end
})

regToggle(Tabs.Settings, "Settings", "AutoSaveConfig", {
    Title = "Auto Save Config",
    Value = Flags.AutoSaveConfig,
    Callback = function(v) Flags.AutoSaveConfig = v end
})

task.defer(refreshConfigDropdown)

Tabs.Settings:Divider()

Tabs.Settings:Paragraph({
    Title = "Performance & Display",
    Desc = "Tune frame rate and visuals for stable AFK farming"
})

ConfigControls.HideUIOnStart = Tabs.Settings:Toggle({
    Title = "Hide UI On Start",
    Value = Flags.HideUIOnStart,
    Callback = function(v)
        Flags.HideUIOnStart = v
        saveConfig()
    end
})

ConfigControls.LockAFK15FPS = Tabs.Settings:Toggle({
    Title = "Lock 15 FPS (AFK Mode)",
    Value = Flags.LockAFK15FPS,
    Callback = function(v)
        Flags.LockAFK15FPS = v
        if v then
            applyFpsCap(15)
        else
            applyFpsCap(Flags.TargetFPS or 60)
        end
    end
})

ConfigControls.TargetFPS = Tabs.Settings:Slider({
    Title = "FPS Limit",
    Step = 5,
    Value = { Min = 15, Max = 240, Default = Flags.TargetFPS or 60 },
    Callback = function(val)
        Flags.TargetFPS = val
        if not Flags.LockAFK15FPS then
            applyFpsCap(val)
        end
    end
})

regToggle(Tabs.Settings, "Settings", "AntiAFK", {
    Title = "Anti-AFK",
    Value = Flags.AntiAFK,
    Callback = function(v) Flags.AntiAFK = v end
})

ConfigControls.BlackScreen = Tabs.Settings:Toggle({
    Title = "GPU Saver (Black Screen Mode)",
    Value = Flags.BlackScreen,
    Callback = function(v)
        Flags.BlackScreen = v
        pcall(function()
            RunService:Set3dRenderingEnabled(not v)
        end)
    end
})

ConfigControls.LowGraphics = Tabs.Settings:Toggle({
    Title = "Low Graphics",
    Value = Flags.LowGraphics,
    Callback = function(enabled)
        applyLowGraphics(enabled)
    end
})

local originalLightingSettings
local function applyFullbright(enabled)
    if enabled then
        if not originalLightingSettings then
            originalLightingSettings = {
                Brightness = Lighting.Brightness,
                ClockTime = Lighting.ClockTime,
                FogEnd = Lighting.FogEnd,
                GlobalShadows = Lighting.GlobalShadows,
                OutdoorAmbient = Lighting.OutdoorAmbient
            }
        end
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
        Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
    elseif originalLightingSettings then
        for property, value in pairs(originalLightingSettings) do
            Lighting[property] = value
        end
        originalLightingSettings = nil
    end
end

ConfigControls.Fullbright = Tabs.Settings:Toggle({
    Title = "Fullbright",
    Value = Flags.Fullbright,
    Callback = function(v)
        Flags.Fullbright = v
        applyFullbright(v)
    end
})

Tabs.Settings:Divider()

Tabs.Settings:Paragraph({
    Title = "Codes & Server",
    Desc = "Redeem codes and manage the server connection"
})

ConfigControls.EnteredCode = Tabs.Settings:Input({
    Title = "Game Code",
    Placeholder = "Enter code here...",
    Callback = function(val) Flags.EnteredCode = val end
})

Tabs.Settings:Button({
    Title = "Redeem Code",
    Callback = function()
        if Flags.EnteredCode ~= "" then
            pcall(function()
                local codeService = require(ReplicatedStorage.Packages.CodeService)
                local success, msg = codeService.Redeem(LocalPlayer, Flags.EnteredCode)
                WindUI:Notify({
                    Title = "Redeem Code",
                    Content = msg or (success and "Success" or "Invalid code"),
                    Duration = 3
                })
            end)
        end
    end
})

Tabs.Settings:Button({
    Title = "Rejoin Server",
    Callback = function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end
})

Tabs.Settings:Button({
    Title = "Server Hop",
    Callback = function()
        pcall(function()
            local serversApi = string.format("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100", tostring(game.PlaceId))
            local body = HttpService:JSONDecode(game:HttpGet(serversApi))
            if body and body.data then
                for _, server in ipairs(body.data) do
                    if server.playing < server.maxPlayers and server.id ~= game.JobId then
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
                        break
                    end
                end
            end
        end)
    end
})

-- ========================================================================
-- BACKGROUND WORKERS (ระบบเบื้องหลังการทำงานอัตโนมัติ)
-- ========================================================================

-- Helper ตรวจสอบว่ามีมดตรงตามเงื่อนไข filter และเงินพอ กำลังรอให้เคลมอยู่หรือไม่
local function hasPendingDesiredAnt()
    local myGold = getPlayerGold()
    for _, prompt in ipairs(Workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") and prompt.Name == "ClaimRolledAntPrompt" and prompt.Enabled then
            local info = getPromptAntInfo(prompt)
            if isDesiredAnt(info, myGold) then
                if info.Cost > 0 and myGold < info.Cost and Flags.SkipIfNotEnoughGold then
                    return false
                end
                return true
            end
        end
    end
    return false
end

-- 1. Auto Roll Worker
local lastRollTriggerTime = 0
task.spawn(function()
    while true do
        if Flags.AutoRollAnt then
            pcall(function()
                local now = os.clock()
                if not hasPendingDesiredAnt() then
                    if (now - lastRollTriggerTime) >= 0.4 then
                        lastRollTriggerTime = now
                        sendEcsCommand("RollAnt", { Source = "ProximityPrompt" })
                    end
                end
            end)
        end
        task.wait(0.3)
    end
end)

-- 2. Auto Buy & Claim Ant / Star Worker (ระบบตรวจเช็คเงิน, ฟิลเตอร์ระดับและบัพ, ป้องกันการกดย้ำ)
local claimedPrompts = setmetatable({}, { __mode = "k" })

task.spawn(function()
    while true do
        if Flags.AutoBuyAnt or Flags.AutoBuyStar or Flags.AutoStarDungeon then
            pcall(function()
                local myGold = getPlayerGold()
                local now = os.clock()
                
                for p, t in pairs(claimedPrompts) do
                    if type(t) == "number" and (now - t) > 4 then
                        claimedPrompts[p] = nil
                    end
                end

                -- ค้นหา Prompt การเคลมมด
                local promptsToProcess = {}
                pcall(function()
                    local Battle = ReplicatedStorage:FindFirstChild("Battle")
                    if Battle and Battle:FindFirstChild("Game") and Battle.Game:FindFirstChild("Helper") and Battle.Game.Helper:FindFirstChild("RollPresentationHelper") then
                        local rph = require(Battle.Game.Helper.RollPresentationHelper)
                        local mgr = rph.GetManager()
                        if mgr and mgr.ClaimPlatforms then
                            for claimId, platform in pairs(mgr.ClaimPlatforms) do
                                if platform.ClaimPrompt and platform.ClaimPrompt.Enabled then
                                    table.insert(promptsToProcess, platform.ClaimPrompt)
                                end
                            end
                        end
                    end
                end)

                if #promptsToProcess == 0 then
                    for _, p in ipairs(Workspace:GetDescendants()) do
                        if p:IsA("ProximityPrompt") and p.Name == "ClaimRolledAntPrompt" and p.Enabled then
                            table.insert(promptsToProcess, p)
                        end
                    end
                end

                for _, prompt in ipairs(promptsToProcess) do
                    local claimState = claimedPrompts[prompt]
                    if claimState ~= true and (claimState == nil or (now - claimState) >= 1.5) then
                        local antInfo = getPromptAntInfo(prompt)

                        if antInfo.IsItem and (Flags.AutoBuyStar or Flags.AutoStarDungeon) then
                            if antInfo.ClaimId then
                                claimedPrompts[prompt] = true
                                sendEcsCommand("ClaimRolledAnt", { ClaimId = antInfo.ClaimId })
                            elseif fireproximityprompt then
                                claimedPrompts[prompt] = true
                                fireproximityprompt(prompt)
                            end
                        elseif Flags.AutoBuyAnt and not antInfo.IsItem then
                            local isDesired = isDesiredAnt(antInfo, myGold)

                            if not isDesired then
                                claimedPrompts[prompt] = now
                                if Flags.AutoRollAnt and (now - lastRollTriggerTime) >= 0.6 then
                                    lastRollTriggerTime = now
                                    sendEcsCommand("RollAnt", { Source = "ProximityPrompt" })
                                end
                            elseif antInfo.Cost > 0 and myGold < antInfo.Cost then
                                claimedPrompts[prompt] = now
                                if Flags.SkipIfNotEnoughGold and Flags.AutoRollAnt and (now - lastRollTriggerTime) >= 0.6 then
                                    lastRollTriggerTime = now
                                    sendEcsCommand("RollAnt", { Source = "ProximityPrompt" })
                                end
                            else
                                if antInfo.ClaimId then
                                    claimedPrompts[prompt] = true
                                    sendEcsCommand("ClaimRolledAnt", { ClaimId = antInfo.ClaimId })
                                elseif fireproximityprompt then
                                    claimedPrompts[prompt] = true
                                    fireproximityprompt(prompt)
                                end
                            end
                        end
                    end
                end
            end)
        end
        task.wait(0.2)
    end
end)

-- 3. Auto Collect Food Worker (เก็บอาหารในรังเข้าตัวผู้เล่นเมื่อตัวคูณถึงเป้าหมาย)
task.spawn(function()
    while true do
        if Flags.AutoCollect or Flags.AutoSell then
            pcall(function()
                -- ถ้าเปิดเงื่อนไขตัวคูณ จะยังไม่เก็บอาหารเข้าตัวเด็ดขาดจนกว่าตัวคูณตลาดจะถึงเป้าหมายที่ตั้งไว้
                if Flags.SellAtMultiplier and not isFoodMultiplierMet() then
                    return
                end

                local myRoom = getMyRoom()
                if myRoom and myRoom:FindFirstChild("PlayerFood") then
                    local promptPart = myRoom.PlayerFood:FindFirstChild("Prompt")
                    local prox = promptPart and promptPart:FindFirstChildOfClass("ProximityPrompt")
                    if prox and fireproximityprompt then
                        prox.MaxActivationDistance = 99999
                        prox.RequiresLineOfSight = false
                        prox.HoldDuration = 0
                        fireproximityprompt(prox, 0)
                        fireproximityprompt(prox)
                    end
                end

                local foodCarry = require(ReplicatedStorage.Battle.Game.Helper.RoomHelper.FoodSellCarryState)
                local PlayerDataHelper = require(ReplicatedStorage.Battle.Game.Helper.PlayerDataHelper)
                local nestFood = 0
                pcall(function()
                    nestFood = PlayerDataHelper.GetPlayerFood(LocalPlayer.UserId) or 0
                end)
                if nestFood <= 0 then
                    pcall(function()
                        local wk = ReplicatedStorage:WaitForChild("WuKong", 2) or ReplicatedStorage:FindFirstChild("WuKong")
                        if wk then
                            local WuKong = require(wk)
                            nestFood = tonumber(WuKong:ExecuteQuery("/货币/食物?属性数量")) or 0
                        end
                    end)
                end

                if nestFood > 0 and not foodCarry.HasSnapshot() then
                    local myRoomIdx = LocalPlayer:GetAttribute("RoomIndex") or 1
                    foodCarry.SetSnapshot({
                        Source = "PlayerFoodPrompt",
                        FoodAmount = nestFood,
                        RoomIndex = myRoomIdx
                    })
                end
            end)
        end
        task.wait(0.5)
    end
end)

-- 4. Auto Sell Worker (ขายอาหารอัตโนมัติ ตรวจสอบตัวคูณอย่างเข้มงวด)
task.spawn(function()
    while true do
        if Flags.AutoSell then
            pcall(function()
                if Flags.AutoSellToFoodBuyer then
                    local helper = ReplicatedStorage.Battle.Game:FindFirstChild("Helper")
                    local activities = helper and helper:FindFirstChild("Activities")
                    local module = activities and activities:FindFirstChild("BlackMarket")
                    local blackMarket = module and require(module)
                    if blackMarket and blackMarket.IsActive and blackMarket.IsActive() then
                        return
                    end
                end

                -- ตรวจสอบเงื่อนไขตัวคูณราคาขาย (Multiplier) ก่อนเป็นอันดับแรก
                if Flags.SellAtMultiplier and not isFoodMultiplierMet() then
                    return
                end

                local foodCarry = require(ReplicatedStorage.Battle.Game.Helper.RoomHelper.FoodSellCarryState)
                local PlayerDataHelper = require(ReplicatedStorage.Battle.Game.Helper.PlayerDataHelper)

                local carriedFood = tonumber(LocalPlayer:GetAttribute("CarriedSellFoodAmount")) or 0
                local snap = foodCarry.GetSnapshot()
                local snapFood = (snap and tonumber(snap.FoodAmount)) or 0
                local nestFood = 0
                pcall(function()
                    nestFood = PlayerDataHelper.GetPlayerFood(LocalPlayer.UserId) or 0
                end)
                if nestFood <= 0 then
                    pcall(function()
                        local wk = ReplicatedStorage:WaitForChild("WuKong", 2) or ReplicatedStorage:FindFirstChild("WuKong")
                        if wk then
                            local WuKong = require(wk)
                            nestFood = tonumber(WuKong:ExecuteQuery("/货币/食物?属性数量")) or 0
                        end
                    end)
                end

                local foodToSell = carriedFood
                if foodToSell <= 0 then foodToSell = snapFood end
                if foodToSell <= 0 then foodToSell = nestFood end

                local hasFood = (foodToSell > 0) or foodCarry.HasSnapshot() or (carriedFood > 0)
                if not hasFood then
                    return
                end

                if foodToSell <= 0 then foodToSell = 1 end

                if not foodCarry.HasSnapshot() then
                    local myRoomIdx = LocalPlayer:GetAttribute("RoomIndex") or 1
                    foodCarry.SetSnapshot({
                        Source = "PlayerFoodPrompt",
                        FoodAmount = foodToSell,
                        RoomIndex = myRoomIdx
                    })
                end

                pcall(function()
                    foodCarry.RequestSell({
                        SendCommand = function(cmd, payload)
                            payload = payload or {}
                            payload.FoodAmount = payload.FoodAmount or foodToSell
                            payload.Source = "PlayerFoodSellPrompt"
                            payload.UserId = LocalPlayer.UserId
                            sendEcsCommand(cmd, payload)
                        end
                    }, { Source = "PlayerFoodSellPrompt" })
                end)
            end)
        end
        task.wait(0.5)
    end
end)

-- 5. Auto Sell To Food Buyer (BlackMarket พ่อค้าอาหารพิเศษ)
task.spawn(function()
    local lastErrorAt = 0
    local nextAttemptAt = 0
    while true do
        if Flags.AutoSellToFoodBuyer then
            local success, err = pcall(function()
                local helper = ReplicatedStorage.Battle.Game:FindFirstChild("Helper")
                local activities = helper and helper:FindFirstChild("Activities")
                local blackMarketModule = activities and activities:FindFirstChild("BlackMarket")
                if not blackMarketModule then
                    error("BlackMarket activity module is unavailable")
                end
                local blackMarket = require(blackMarketModule)
                if not blackMarket.IsSellOpen or not blackMarket.IsSellOpen() then
                    return
                end
                if os.clock() < nextAttemptAt then return end

                local foodCarry = require(ReplicatedStorage.Battle.Game.Helper.RoomHelper.FoodSellCarryState)
                if foodCarry.IsSelling then return end

                local PlayerDataHelper = require(ReplicatedStorage.Battle.Game.Helper.PlayerDataHelper)
                local foodInNest = tonumber(PlayerDataHelper.GetPlayerFood(LocalPlayer.UserId)) or 0
                if foodInNest <= 0 then return end

                local sellPart = blackMarket.GetClientSellPart and blackMarket.GetClientSellPart()
                if not sellPart or not sellPart:IsA("BasePart") then return end

                local character = LocalPlayer.Character
                local root = character and character:FindFirstChild("HumanoidRootPart")
                if not root then return end
                if (root.Position - sellPart.Position).Magnitude > 12 then
                    teleportTo(sellPart.CFrame)
                    task.wait(0.35)
                end
                if not blackMarket.IsSellOpen() then return end

                foodInNest = tonumber(PlayerDataHelper.GetPlayerFood(LocalPlayer.UserId)) or 0
                if foodInNest <= 0 then return end
                foodCarry.SetSnapshot({
                    Source = "BlackMarket",
                    FoodAmount = foodInNest,
                    RoomIndex = LocalPlayer:GetAttribute("RoomIndex") or 1
                })

                if blackMarket.CanPlayerSell and not blackMarket.CanPlayerSell(LocalPlayer) then
                    return
                end

                nextAttemptAt = os.clock() + 4
                blackMarket.RequestSell()
            end)
            if not success and os.clock() - lastErrorAt >= 10 then
                lastErrorAt = os.clock()
                warn("[AntEmpireHub] Black Market auto-sell failed: " .. tostring(err))
            end
        end
        task.wait(0.5)
    end
end)

-- 6. Auto Equip Best Worker
task.spawn(function()
    while true do
        if Flags.AutoEquipBest then
            pcall(function()
                local backpackModel = require(ReplicatedStorage.UI.Backpack.Model.BackpackModel)
                if backpackModel and backpackModel.EquipBest then
                    backpackModel:EquipBest()
                end
            end)
        end
        task.wait(3.0)
    end
end)

-- 7. Auto Upgrade Equipped Ants Worker (ระบบตรวจสอบเงินพอจึงกด)
local antUpgradeLastSent = {}
task.spawn(function()
    while true do
        if Flags.AutoUpgradeEquippedAnts then
            pcall(function()
                local remainingGold = getPlayerGold()
                local backpackStore = require(ReplicatedStorage.WuKongHooks.BackPackStore)
                local interval = math.max(tonumber(Flags.UpgradeInterval) or 3, 0.5)
                for slot = 1, 30 do
                    local ok, hasUpgrade, info = pcall(backpackStore.GetEquippedUpgradeInfo, LocalPlayer.UserId, slot)
                    if ok and hasUpgrade and type(info) == "table" then
                        local cost = extractCost(info) or 0
                        local now = os.clock()
                        local lastAt = antUpgradeLastSent[slot]
                        local spaced = (not lastAt or (now - lastAt) >= interval)
                        if cost > 0 then
                            -- รู้ราคา: กดเมื่อเงินพอเท่านั้น ทีละตัว
                            if spaced and remainingGold >= cost then
                                antUpgradeLastSent[slot] = now
                                sendEcsCommand("UpgradeEquippedAnt", { AntIndex = slot })
                                break
                            end
                        elseif spaced and probeAllowed("ant:" .. slot, remainingGold, tonumber(info.Level or info.Lv) or 0, interval) then
                            -- อ่านราคาไม่ได้: ลองกดอย่างระวัง
                            probeMark("ant:" .. slot, remainingGold, tonumber(info.Level or info.Lv) or 0)
                            antUpgradeLastSent[slot] = now
                            sendEcsCommand("UpgradeEquippedAnt", { AntIndex = slot })
                            break
                        end
                    end
                end
            end)
        end
        task.wait(2.5)
    end
end)

-- 8. Auto Place Ant Worker
task.spawn(function()
    while true do
        if Flags.AutoPlaceAnt then
            pcall(function()
                local myRoom = getMyRoom()
                if myRoom then
                    for _, child in ipairs(myRoom:GetChildren()) do
                        if child.Name:match("^Hole%d+$") or child.Name:match("^AntSlot%d+$") then
                            local prompt = child:FindFirstChildOfClass("ProximityPrompt")
                            if prompt and prompt.ActionText:find("Place") and fireproximityprompt then
                                fireproximityprompt(prompt)
                            end
                        end
                    end
                end
            end)
        end
        task.wait(2.0)
    end
end)

-- 9. Auto Stroke Pets Worker
task.spawn(function()
    while true do
        if Flags.AutoStrokePets then
            pcall(function()
                local backpackModel = require(ReplicatedStorage.UI.Backpack.Model.BackpackModel)
                local equippedPets = backpackModel:GetData().EquippedPets or {}
                for petKey in pairs(equippedPets) do
                    sendEcsCommand("StrokePet", { PetKey = petKey })
                    task.wait(0.05)
                end
            end)
        end
        task.wait(3.0)
    end
end)

-- 10. Auto Unlock Ant Hole Worker (ระบบตรวจสอบเงินพอจึงกด ไม่กดซ้ำ)
local lastAntHoleUnlock = { SlotIndex = nil, Time = 0 }
task.spawn(function()
    while true do
        if Flags.AutoUnlockAntHole then
            local success, err = pcall(function()
                local myGold = getPlayerGold()
                local myRoom = getMyRoom()
                local roomIndex = tonumber(LocalPlayer:GetAttribute("RoomIndex"))
                local antPos = myRoom and myRoom:FindFirstChild("AntPos")
                if not myRoom or not roomIndex or not antPos then return end

                local backpackModel = require(ReplicatedStorage.UI.Backpack.Model.BackpackModel)
                backpackModel:Load(LocalPlayer)
                local unlockedSlots = backpackModel:GetUnlockedSlotList()
                local unlockedCount = #unlockedSlots
                local unlockConfig = battle_tbnestunlock and battle_tbnestunlock[unlockedCount]
                local cost = tonumber(unlockConfig and unlockConfig.Price)
                if not cost or myGold < cost then return end

                local roomSlotService = require(ReplicatedStorage.Battle.Game.Helper.RoomHelper.RoomSlotService)
                local buyableSlots = roomSlotService.GetBuyableAntSlots({
                    AntPos = antPos,
                    NestLayer = tonumber(myRoom:GetAttribute("NestLayer")) or 1
                })
                local now = os.clock()
                for _, slot in ipairs(buyableSlots) do
                    local slotIndex = tonumber(slot.SlotIndex)
                    if slotIndex and (lastAntHoleUnlock.SlotIndex ~= slotIndex or now - lastAntHoleUnlock.Time >= 5) then
                        lastAntHoleUnlock = { SlotIndex = slotIndex, Time = now }
                        sendEcsCommand("AddAntSlot", {
                            Source = "ProximityPrompt",
                            RoomIndex = roomIndex,
                            SlotIndex = slotIndex
                        })
                        break
                    end
                end
            end)
            if not success then
                warn("[AntEmpireHub] Auto unlock ant hole failed: " .. tostring(err))
            end
        end
        task.wait(2.0)
    end
end)

-- 11. Auto Buy Upgrades Worker (กดเมื่อเงินพอ ทีละอย่าง ไม่รัว)
-- หมายเหตุ: ราคาที่แสดงในเกมอาจตรงกับ Info[เลเวลปัจจุบัน] หรือ Info[เลเวล+1] ขึ้นกับตารางข้อมูล
-- ระบบจึงลองแบบแรกก่อน แล้วเรียนรู้เองต่ออัปเกรดว่าแบบไหนซื้อสำเร็จจริง (เลเวลขึ้น)
local upgradeLastSent = {}      -- [attr] = { lvl, t }
local upgradePending = {}       -- [attr] = { lvl, t, mode, testing }
local upgradeCostMode = {}      -- [attr] = "cur" | "next"
local upgradeModeConfirmed = {} -- [attr] = true เมื่อยืนยันแล้วว่าโหมดนั้นถูก
task.spawn(function()
    while true do
        if Flags.AutoBuyUpgrades and #Flags.SelectedUpgrades > 0 then
            pcall(function()
                local myGold = getPlayerGold()
                local interval = math.max(tonumber(Flags.UpgradeInterval) or 3, 0.5)
                for _, uiName in ipairs(Flags.SelectedUpgrades) do
                    local internalAttr = UpgradeMapping[uiName]
                    if internalAttr then
                        local lvl, nextCost, state, curCost = getUpgradeInfo(internalAttr)
                        local now = os.clock()

                        -- ตรวจผลการกดครั้งก่อน (รอ 3 วินาทีให้เซิร์ฟเวอร์ตอบ)
                        local pend = upgradePending[internalAttr]
                        local waiting = false
                        if pend then
                            if (now - pend.t) < 3 then
                                waiting = true
                            else
                                if lvl > pend.lvl then
                                    upgradeCostMode[internalAttr] = pend.mode
                                    upgradeModeConfirmed[internalAttr] = true
                                elseif pend.testing then
                                    upgradeCostMode[internalAttr] = "next" -- ซื้อไม่สำเร็จ แปลว่าราคาจริงสูงกว่าที่เดา
                                end
                                upgradePending[internalAttr] = nil
                            end
                        end

                        if waiting or state == "maxed" then
                            -- ข้าม
                        elseif state == "ok" then
                            local mode = upgradeCostMode[internalAttr] or "cur"
                            local cost
                            if mode == "next" then
                                cost = nextCost or curCost
                            else
                                cost = curCost or nextCost
                            end
                            local last = upgradeLastSent[internalAttr]
                            local sinceLast = last and (now - last.t) or math.huge
                            local canSend = sinceLast >= interval
                            -- กดไปแล้วแต่เลเวลไม่ขึ้น ให้รอนานขึ้นแทนการกดซ้ำ
                            if canSend and last and last.lvl == lvl and sinceLast < interval * 5 then
                                canSend = false
                            end
                            if canSend and cost and myGold >= cost then
                                upgradeLastSent[internalAttr] = { lvl = lvl, t = now }
                                upgradePending[internalAttr] = {
                                    lvl = lvl, t = now, mode = mode,
                                    testing = (mode == "cur") and not upgradeModeConfirmed[internalAttr]
                                }
                                sendEcsCommand("UpgradePlayerAttribute", { AttributeName = internalAttr })
                                break -- ซื้อทีละอย่าง รอบถัดไปค่อยเช็คเงินใหม่
                            end
                        else
                            -- อ่านราคาไม่ได้: ลองกดอย่างระวัง ไม่รัว
                            if probeAllowed("up:" .. internalAttr, myGold, lvl, interval) then
                                probeMark("up:" .. internalAttr, myGold, lvl)
                                sendEcsCommand("UpgradePlayerAttribute", { AttributeName = internalAttr })
                                break
                            end
                        end
                    end
                end
            end)
        end
        task.wait(1.5)
    end
end)

-- 12. Hide Ants Worker (ซ่อนตัวมดจริงในรังและแมพ พร้อมคืนค่าเมื่อปิด)
local hiddenAntModels = {}
task.spawn(function()
    while true do
        pcall(function()
            if Flags.HideAnts then
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    if obj:IsA("Model") and (obj:GetAttribute("UnitId") ~= nil or obj:GetAttribute("AntIndex") ~= nil or (obj.Parent and obj.Parent.Name == "Unit")) then
                        if not hiddenAntModels[obj] then
                            hiddenAntModels[obj] = true
                        end
                        for _, p in ipairs(obj:GetDescendants()) do
                            if p:IsA("BasePart") then
                                p.LocalTransparencyModifier = 1
                            elseif p:IsA("Decal") or p:IsA("Texture") then
                                p.Transparency = 1
                            elseif p:IsA("ParticleEmitter") or p:IsA("Trail") or p:IsA("Beam") or p:IsA("BillboardGui") then
                                p.Enabled = false
                            end
                        end
                    end
                end
            else
                if next(hiddenAntModels) ~= nil then
                    for model in pairs(hiddenAntModels) do
                        if model and model.Parent then
                            for _, p in ipairs(model:GetDescendants()) do
                                if p:IsA("BasePart") then
                                    p.LocalTransparencyModifier = 0
                                elseif p:IsA("Decal") or p:IsA("Texture") then
                                    p.Transparency = 0
                                elseif p:IsA("ParticleEmitter") or p:IsA("Trail") or p:IsA("Beam") or p:IsA("BillboardGui") then
                                    p.Enabled = true
                                end
                            end
                        end
                        hiddenAntModels[model] = nil
                    end
                end
            end
        end)
        task.wait(Flags.HideAnts and 1.0 or 2.0)
    end
end)

-- ตัวช่วยกดปุ่ม Start ใน GUI ของดันเจี้ยน
local GuiService = game:GetService("GuiService")
local DUNGEON_START_TEXTS = { ["start"] = true, ["start dungeon"] = true, ["begin"] = true, ["เริ่ม"] = true, ["เริ่มดัน"] = true, ["เริ่มดันเจี้ยน"] = true }
local lastStartBtnClickAt = 0

local function isGuiReallyVisible(obj)
    local cur = obj
    while cur and cur ~= game do
        if cur:IsA("GuiObject") and not cur.Visible then return false end
        if cur:IsA("LayerCollector") and cur.Enabled == false then return false end
        cur = cur.Parent
    end
    return true
end

local function cleanText(t)
    t = tostring(t or ""):gsub("<[^>]->", "")
    t = t:gsub("^%s+", ""):gsub("%s+$", "")
    return t:lower()
end

-- คืน GuiObject ที่ควรกด (ปุ่มที่ครอบข้อความ Start หรือตัวข้อความเอง)
local function findDungeonStartButton()
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not pg then return nil end
    for _, d in ipairs(pg:GetDescendants()) do
        if (d:IsA("TextLabel") or d:IsA("TextButton")) and DUNGEON_START_TEXTS[cleanText(d.Text)] and isGuiReallyVisible(d) then
            -- หา ImageButton/TextButton ที่ครอบอยู่ ถ้าไม่มีก็ใช้ตัว GuiObject เอง
            local target = d
            local cur = d
            while cur and not cur:IsA("LayerCollector") do
                if cur:IsA("ImageButton") or cur:IsA("TextButton") then target = cur break end
                cur = cur.Parent
            end
            if target.AbsoluteSize.X > 0 and target.AbsoluteSize.Y > 0 then
                return target
            end
        end
    end
    return nil
end

local function clickGuiButton(btn)
    -- 1) ยิง event ของปุ่มโดยตรง (ถ้า executor รองรับ)
    if btn:IsA("GuiButton") then
        if getconnections then
            for _, sig in ipairs({ btn.MouseButton1Click, btn.Activated, btn.MouseButton1Down, btn.MouseButton1Up }) do
                pcall(function()
                    for _, c in ipairs(getconnections(sig)) do
                        pcall(function() c:Fire() end)
                    end
                end)
            end
        elseif firesignal then
            pcall(function() firesignal(btn.MouseButton1Click) end)
            pcall(function() firesignal(btn.Activated) end)
        end
    end
    -- 2) จำลองการคลิกเมาส์จริงที่กลางปุ่ม (ครอบคลุมกรณีเกมใช้ InputBegan)
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        local pos, size = btn.AbsolutePosition, btn.AbsoluteSize
        local inset = Vector2.new(0, 0)
        local sg = btn:FindFirstAncestorWhichIsA("ScreenGui")
        if not (sg and sg.IgnoreGuiInset) then
            inset = GuiService:GetGuiInset()
        end
        local x = pos.X + size.X / 2 + inset.X
        local y = pos.Y + size.Y / 2 + inset.Y
        vim:SendMouseMoveEvent(x, y, game)
        vim:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.05)
        vim:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
end

-- 14. Dungeon Automation & 4x Attack Speed Worker
local lastStarDungeonPromptAt = 0
task.spawn(function()
    while true do
        if Flags.AutoDungeon or Flags.AutoStarDungeon or Flags.Auto4xAttackSpeed then
            pcall(function()
                local sessionId = LocalPlayer:GetAttribute("DungeonSessionId")
                if sessionId then
                    if Flags.Auto4xAttackSpeed or Flags.AutoDungeon or Flags.AutoStarDungeon then
                        for _ = 1, 3 do
                            sendEcsCommand("DungeonCommand", { Action = "Click", SessionId = sessionId })
                            task.wait(0.04)
                        end
                    end
                else
                    if Flags.AutoStarDungeon then
                        local starEvent = Workspace:FindFirstChild("StarEvent")
                        local submitPart = starEvent and starEvent:FindFirstChild("Flippromt")
                        local enterPart = starEvent and starEvent:FindFirstChild("Enterpromt")
                        local submitPrompt = submitPart and (submitPart:IsA("ProximityPrompt") and submitPart or submitPart:FindFirstChildWhichIsA("ProximityPrompt", true))
                        local enterPrompt = enterPart and (enterPart:IsA("ProximityPrompt") and enterPart or enterPart:FindFirstChildWhichIsA("ProximityPrompt", true))
                        local holdingStar = LocalPlayer:GetAttribute("BackpackHeldKind") == "Item"
                            and LocalPlayer:GetAttribute("BackpackHeldItemId") == "Star"
                            and LocalPlayer:GetAttribute("BackpackHeldEntryKey") == "Item:Star"
                        local now = os.clock()

                        if holdingStar and submitPrompt and submitPrompt.Enabled and (now - lastStarDungeonPromptAt) >= 0.5 then
                            lastStarDungeonPromptAt = now
                            local anchor = submitPrompt.Parent
                            if anchor and anchor:IsA("BasePart") then
                                teleportTo(anchor.CFrame)
                            end
                            if fireproximityprompt then
                                fireproximityprompt(submitPrompt, 0)
                            end
                        elseif enterPrompt and enterPrompt.Enabled and (now - lastStarDungeonPromptAt) >= 2.1 then
                            lastStarDungeonPromptAt = now
                            local anchor = enterPrompt.Parent
                            if anchor and anchor:IsA("BasePart") then
                                teleportTo(anchor.CFrame)
                            end
                            if fireproximityprompt then
                                fireproximityprompt(enterPrompt, 0)
                            end
                        end
                    end
                    if Flags.AutoDungeon then
                        local dungeonFolder = Workspace:FindFirstChild("DungeonEntrances")
                        if dungeonFolder then
                            for _, entrance in ipairs(dungeonFolder:GetChildren()) do
                                local prompt = entrance:FindFirstChildOfClass("ProximityPrompt") or entrance:FindFirstChild("ProximityPrompt", true)
                                if prompt and prompt.Enabled and fireproximityprompt then
                                    fireproximityprompt(prompt, 0)
                                    fireproximityprompt(prompt)
                                    break
                                end
                            end
                        end
                    end
                end
                -- กดปุ่ม Start อัตโนมัติ (ทำงานทั้งก่อนและหลังเข้า session ดัน เพราะปุ่มอาจโผล่ตอนอยู่ในดันแล้ว)
                if Flags.AutoPressDungeonStart and (Flags.AutoDungeon or Flags.AutoStarDungeon) then
                    local now2 = os.clock()
                    if (now2 - lastStartBtnClickAt) >= 1 then
                        local obj = findDungeonStartButton()
                        if obj then
                            lastStartBtnClickAt = now2
                            clickGuiButton(obj)
                        end
                    end
                end
            end)
        end
        task.wait(0.15)
    end
end)

-- 15. Travelling Snail Worker (กดรับรางวัลหอยทากสัญจร)
task.spawn(function()
    while true do
        if Flags.AutoClickTravellingSnail then
            pcall(function()
                local activityId = Workspace:GetAttribute("ActivityId")
                local countdown = tonumber(Workspace:GetAttribute("CountdownSeconds")) or 0
                if activityId == "TravelSnail" and countdown > 0 then
                    local WuKong = require(ReplicatedStorage.WuKong)
                    WuKong:ExecuteAction("/功能商人/蜗牛活动抽奖?购买")
                end
            end)
        end
        task.wait(0.5)
    end
end)

-- 16. Strawberry Coins Worker (เก็บเหรียญสตอเบอรี่ตาม Delay อย่างรวดเร็ว ไม่กระตุก)
task.spawn(function()
    while true do
        if Flags.AutoPickupStrawberryCoins then
            pcall(function()
                local delayTime = tonumber(Flags.CoinPickupDelay) or 0.10
                local coinFolder = Workspace:FindFirstChild("_StrawberryKingActivityCoins")
                if coinFolder then
                    for _, coinModel in ipairs(coinFolder:GetChildren()) do
                        if not Flags.AutoPickupStrawberryCoins then break end
                        local entityId = coinModel:GetAttribute("StrawberryCoinEntityId")
                        local rootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        local coinPart = coinModel:IsA("BasePart") and coinModel
                            or coinModel:FindFirstChildWhichIsA("BasePart", true)
                        if entityId and rootPart and coinPart then
                            local distance = (rootPart.Position - coinPart.Position).Magnitude
                            if distance > 17 then
                                teleportTo(coinPart.CFrame)
                                task.wait(0.15)
                            end
                            rootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                            if rootPart and (rootPart.Position - coinPart.Position).Magnitude <= 17 then
                                sendEcsCommand("PickupStrawberryCoin", { CoinEntityId = tonumber(entityId) })
                            end
                        end
                        task.wait(delayTime)
                    end
                end
            end)
        end
        task.wait(0.3)
    end
end)

-- 17. Auto Claim Index Worker (รับรางวัลสมุดภาพดัชนีอัตโนมัติ)
task.spawn(function()
    local indexModel
    local indexLoaded = false
    while true do
        if Flags.AutoClaimIndex then
            pcall(function()
                if not indexModel then
                    local ui = ReplicatedStorage:FindFirstChild("UI")
                    local index = ui and (ui:FindFirstChild("Index") or ui:FindFirstChild("IndexPanel"))
                    local modelFolder = index and index:FindFirstChild("Model")
                    local indexModule = modelFolder and modelFolder:FindFirstChild("IndexModel")
                    if indexModule then
                        indexModel = require(indexModule)
                    end
                end
                if indexModel then
                    if not indexModel.Initialized then
                        indexModel:Init()
                    end
                    if not indexLoaded then
                        indexLoaded = indexModel:Load() == true
                    end
                    if indexLoaded then
                        indexModel:ClaimReward("Ants")
                        indexModel:ClaimReward("Mutations")
                    end
                end
            end)
        end
        task.wait(4.0)
    end
end)

-- 17. Auto Claim Playtime Rewards Worker
task.spawn(function()
    local onlineState
    local lastClaimedIndex
    local lastClaimAt = 0
    local lastErrorAt = 0
    while true do
        if Flags.AutoClaimPlaytimeRewards then
            local success, err = pcall(function()
                if not onlineState then
                    onlineState = require(ReplicatedStorage.UI.OnlineReward.Model.OnlineState)
                end
                local rewardIndex = onlineState:GetFirstClaimableRewardIndex()
                local now = os.clock()
                if rewardIndex and (rewardIndex ~= lastClaimedIndex or now - lastClaimAt >= 8) then
                    if onlineState:GetReward(rewardIndex) then
                        lastClaimedIndex = rewardIndex
                        lastClaimAt = now
                    end
                end
            end)
            if not success and os.clock() - lastErrorAt >= 10 then
                lastErrorAt = os.clock()
                warn("[AntEmpireHub] Auto claim playtime reward failed: " .. tostring(err))
            end
        end
        task.wait(2.0)
    end
end)

-- 18. Auto Starfall Event Worker (เข้าร่วมกิจกรรมฝนดาวตกอัตโนมัติ)
task.spawn(function()
    while true do
        if Flags.AutoStarfallEvent then
            pcall(function()
                local StarEventTime = nil
                pcall(function()
                    StarEventTime = require(ReplicatedStorage.Battle.Game.Helper.StarEventTime)
                end)
                local isActive = true
                if StarEventTime and StarEventTime.IsActive then
                    isActive = StarEventTime.IsActive()
                end

                if isActive then
                    local starEvent = Workspace:FindFirstChild("StarEvent")
                    local enterPart = starEvent and starEvent:FindFirstChild("Enterpromt")
                    local enterPrompt = enterPart and (enterPart:IsA("ProximityPrompt") and enterPart or enterPart:FindFirstChildWhichIsA("ProximityPrompt", true))
                    if enterPrompt and enterPrompt.Enabled and fireproximityprompt then
                        local anchor = enterPrompt.Parent
                        if anchor and not anchor:IsA("BasePart") then
                            anchor = anchor:FindFirstAncestorWhichIsA("BasePart")
                        end
                        if anchor then
                            teleportTo(anchor.CFrame)
                            task.wait(0.15)
                        end
                        fireproximityprompt(enterPrompt, 0)
                    end
                end
            end)
        end
        task.wait(2.5)
    end
end)

-- 18. Auto Save Config Worker (บันทึกคอนฟิกอัตโนมัติทุกๆ 30 วินาที)
task.spawn(function()
    while true do
        task.wait(30)
        if Flags.AutoSaveConfig then
            pcall(saveConfig, SelectedConfigName, true)
        end
    end
end)

-- 19. Auto Resource Converter Worker
task.spawn(function()
    while true do
        if Flags.AutoResourceConverter and Flags.ConverterAnts ~= "None" then
            pcall(function()
                local compostModel = require(ReplicatedStorage.UI.Compost.Model.CompostModel)
                local backpackModel = require(ReplicatedStorage.UI.Backpack.Model.BackpackModel)
                if not compostModel.Initialized then
                    compostModel:Init()
                end

                local wuKong = require(ReplicatedStorage.WuKong)
                local context = compostModel:GetContext(nil)
                context.PlayerData = {
                    Gold = getPlayerGold(),
                    CompostCoin = tonumber(wuKong:ExecuteQuery("/货币/堆肥币?属性数量")) or 0,
                    CompostLevel = tonumber(wuKong:ExecuteQuery("/属性/堆肥机等级?属性数量")) or 1
                }
                if compostModel.PendingOperation then return end

                local state = compostModel:GetState(context)
                if not state.Unlocked then return end
                if state.CanPull then
                    compostModel:PullLever(context)
                    return
                end
                if state.Progress >= 1 then return end

                local keepCount = math.max(math.floor(tonumber(Flags.KeepPerStack) or 0), 0)
                local selections = {}
                for packedValue, count in pairs(backpackModel:GetData().Stacks or {}) do
                    local unitIndex = backpackModel:DecodeBackpackValue(packedValue)
                    local unitConfig = unitIndex and battle_tbunit and battle_tbunit["Unit" .. tostring(unitIndex)]
                    if unitConfig and unitConfig.Rarity == Flags.ConverterAnts then
                        local depositCount = math.max(math.floor(tonumber(count) or 0) - keepCount, 0)
                        if depositCount > 0 then
                            selections[packedValue] = depositCount
                        end
                    end
                end

                if next(selections) then
                    compostModel:AddAnts(context, selections)
                end
            end)
        end
        task.wait(3.0)
    end
end)

-- 20. Auto Buy Food Worker
task.spawn(function()
    local lastErrorAt = 0
    while true do
        if Flags.AutoBuyFood and Flags.SelectedShopItem ~= "None" then
            local success, err = pcall(function()
                if not GearShopModel.Initialized then
                    GearShopModel:Init()
                end

                local itemId = Flags.SelectedShopItem
                local config = ShopItemConfigById[itemId]
                if config and GearShopModel:GetStock(itemId) > 0
                    and (tonumber(GearShopModel.Price) or 0) >= (tonumber(config.CoinPrice) or math.huge)
                    and not GearShopModel:IsPending(itemId) then
                    GearShopModel:Purchase(itemId)
                end
            end)
            if not success and os.clock() - lastErrorAt >= 10 then
                lastErrorAt = os.clock()
                warn("[AntEmpireHub] Items Shop auto-buy failed: " .. tostring(err))
            end
        end
        task.wait(1.5)
    end
end)

-- 21. Player Movement & Anti-AFK Worker
task.spawn(function()
    while true do
        pcall(function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                if Flags.WalkSpeed and Flags.WalkSpeed ~= 16 then
                    LocalPlayer.Character.Humanoid.WalkSpeed = Flags.WalkSpeed
                end
                if Flags.JumpPower and Flags.JumpPower ~= 50 then
                    LocalPlayer.Character.Humanoid.JumpPower = Flags.JumpPower
                end
            end
        end)
        task.wait(0.5)
    end
end)

UserInputService.JumpRequest:Connect(function()
    if Flags.InfiniteJump and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

local originalCanCollide = {}
RunService.Stepped:Connect(function()
    local character = LocalPlayer.Character
    if Flags.Noclip and character then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                if originalCanCollide[part] == nil then
                    originalCanCollide[part] = part.CanCollide
                end
                part.CanCollide = false
            end
        end
    else
        for part, canCollide in pairs(originalCanCollide) do
            if part and part.Parent then
                part.CanCollide = canCollide
            end
            originalCanCollide[part] = nil
        end
    end
end)

LocalPlayer.Idled:Connect(function()
    if Flags.AntiAFK then
        pcall(function()
            VirtualUser:Button2Down(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
            task.wait(0.2)
            VirtualUser:Button2Up(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
        end)
    end
end)

-- ========================================================================
-- โหลดคอนฟิกอัตโนมัติ และตรวจเช็คการซ่อนหน้าต่าง UI ตอนเริ่ม (Hide UI On Start)
-- ========================================================================
task.spawn(function()
    applyCloverEffectSetting()
    applySellMoneyEffectSetting()
    applyFpsCap(Flags.LockAFK15FPS and 15 or (Flags.TargetFPS or 60))
    applyLowGraphics(Flags.LowGraphics)
    applyFullbright(Flags.Fullbright)
    if Flags.HideUIOnStart then
        task.wait(0.5)
        pcall(function()
            if Window and Window.Close then
                Window:Close()
            elseif Window and Window.Toggle then
                Window:Toggle()
            end
        end)
    end
end)

WindUI:Notify({
    Title = "Ant Empire Hub",
    Content = "Loaded successfully. Welcome, " .. (LocalPlayer and LocalPlayer.DisplayName or "Player"),
    Duration = 4
})
