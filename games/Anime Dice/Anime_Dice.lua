local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Framework = ReplicatedStorage:WaitForChild("Framework")
local Features = Framework:WaitForChild("Features")

local DataController = require(Features.Data.DataController)
local UpgradeData = require(Features.Upgrades.Upgrades)
local UpgradeTree = require(Features.Upgrades.TreeStructure)
local DiceData = require(Features.Rolling.Dice)
local SettingsConfig = require(Features.Settings.SettingsConfig)
local UnitUtil = require(Features.Inventory.Kinds.Unit.UnitUtil)
local EntryRegistry = require(Features.Inventory.EntryRegistry)
local GearConfig = require(Features.Inventory.Kinds.Gear.GearConfig)
local TowerData = require(Features.Towers.Towers)
local TowerController = require(Features.Towers.TowerController)
local RebirthData = require(Features.Rebirth.Rebirths)
local RebirthStatsConfig = require(Features.Rebirth.RebirthStatsConfig)
local DailyRewardConfig = require(Features.Rewards.DailyRewardConfig)
local QuestConfig = require(Features.Quests.QuestConfig)
local NumberFormatter = require(ReplicatedStorage.Packages.NumberFormatter)

local Network = ReplicatedStorage:WaitForChild("Network")

local function getRemote(path, className)
    local current = Network
    for _, name in ipairs(path) do
        current = current:WaitForChild(name, 10)
        if not current then
            error("[JOJOHUB Anime Dice] Missing remote: " .. table.concat(path, "."), 0)
        end
    end
    if not current:IsA(className) then
        error(("[JOJOHUB Anime Dice] %s must be a %s"):format(table.concat(path, "."), className), 0)
    end
    return current
end

local AutoRollRemote = getRemote({"RollService", "RE", "SetAutoRoll"}, "RemoteEvent")
local RollRemote = getRemote({"RollService", "RF", "RollDice"}, "RemoteFunction")
local AutoSellRemote = getRemote({"SellService", "RE", "UpdateAutoSell"}, "RemoteEvent")
local SellInventoryRemote = getRemote({"SellService", "RF", "SellInventory"}, "RemoteFunction")
local BuyUpgradeRemote = getRemote({"RE", "BuyUpgrade"}, "RemoteEvent")
local CollectBalanceRemote = getRemote({"PlotService", "RE", "CollectBalance"}, "RemoteEvent")
local LevelUpSlotRemote = getRemote({"PlotService", "RE", "LevelUpSlot"}, "RemoteEvent")
local EquipBestRemote = getRemote({"PlotService", "RE", "EquipBest"}, "RemoteEvent")
local BuyDiceRemote = getRemote({"DiceShopService", "RE", "BuyDice"}, "RemoteEvent")
local EquipDiceRemote = getRemote({"DiceShopService", "RE", "EquipDice"}, "RemoteEvent")
local EquipGearRemote = getRemote({"GearService", "RE", "Equip"}, "RemoteEvent")
local AutoTowerRemote = getRemote({"Towers", "RE", "SetAutoTower"}, "RemoteEvent")
local EquipBestTowerRemote = getRemote({"Towers", "RE", "EquipBestTowerTeam"}, "RemoteEvent")
local AddRebirthStatRemote = getRemote({"RebirthService", "RE", "AddStat"}, "RemoteEvent")
local DailyRewardClaimSignal = (require(ReplicatedStorage.Packages.Network)
    .ClientComm.new(Network, false, "DailyRewardService")):GetSignal("Claim")
local QuestClaimSignal = (require(ReplicatedStorage.Packages.Network)
    .ClientComm.new(Network, false, "QuestService")):GetSignal("Claim")

local hideRollResults = false
local hiddenRollButton
local gameRollIsHidden = false
local selectedTowers = {}
local autoTowerEnabled = false
local autoRollEnabled = false
local towerFarmRunning = false
local towerFarmGeneration = 0
local pendingDicePurchase
local pendingDicePurchaseAt = 0
local lastDiceEquipRequest
local lastDiceEquipRequestAt = 0
local pendingRollSpeedUpgrade
local pendingRollSpeedUpgradeAt = 0
local skipRareRollCutscene = false
local rareCutscenePatch
local autoRebirthStatSelection = {}
local pendingRebirthStat
local pendingRebirthStatLevel
local pendingRebirthStatAt = 0
local lastDailyRewardClaimRequest = 0
local questClaimRequests = {}

AutoRollRemote:FireServer(false)

local hideSettingKey
local lastHideClick = 0
local rollingUi
local rollingOptionsUi

local function collectSettingKeys()
    local found = {}
    local function scan(tbl, depth)
        if type(tbl) ~= "table" or depth > 2 then
            return
        end
        for key, value in pairs(tbl) do
            if type(key) == "string" then
                local lower = string.lower(key)
                if string.find(lower, "hide", 1, true) or string.find(lower, "hidden", 1, true)
                    or string.find(lower, "skip", 1, true) or string.find(lower, "cutscene", 1, true)
                    or string.find(lower, "animation", 1, true) then
                    table.insert(found, key)
                end
            end
            if type(value) == "table" then
                scan(value, depth + 1)
            end
        end
    end
    pcall(scan, SettingsConfig, 0)
    return found
end

local function readSetting(key)
    local ok, value = pcall(function()
        return DataController[key]()
    end)
    if ok and type(value) == "boolean" then
        return value
    end
    return nil
end

local function detectHideSettingKey()
    local candidates = {"HiddenRoll", "HideRoll", "HideRolls", "HideRollResults", "HiddenRolls"}
    for _, key in ipairs(collectSettingKeys()) do
        table.insert(candidates, key)
    end
    for _, key in ipairs(candidates) do
        if readSetting(key) ~= nil then
            return key
        end
    end
    return nil
end

local function isShown(gui)
    local current = gui
    while current and not current:IsA("ScreenGui") do
        if current:IsA("GuiObject") and not current.Visible then
            return false
        end
        current = current.Parent
    end
    return current ~= nil and current.Enabled
end

-- Presses a GuiButton the way executors can actually trigger it:
-- fires whichever click signal the game really listens to (only one, so toggles don't double-fire).
local function pressButton(button)
    if not button then
        return false
    end
    if type(getconnections) == "function" and type(firesignal) == "function" then
        for _, signalName in ipairs({"Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up"}) do
            local signal = button[signalName]
            local ok, connections = pcall(getconnections, signal)
            if ok and type(connections) == "table" and #connections > 0 then
                if pcall(firesignal, signal) then
                    return true
                end
            end
        end
    end
    if type(firesignal) == "function" and pcall(firesignal, button.Activated) then
        return true
    end
    return (pcall(function()
        button:Activate()
    end))
end

local function findHideButton(playerGui)
    local root = playerGui:FindFirstChild("Root")
    local rolling = root and root:FindFirstChild("Rolling")
    local options = rolling and rolling:FindFirstChild("Options")
    local direct = options and options:FindFirstChild("HiddenRoll")
    if direct and direct:IsA("GuiButton") then
        return direct, rolling, options
    end

    -- Fallback: look for the on-screen HIDE button anywhere (but not the tower's own one)
    local towerUi = root and root:FindFirstChild("Tower")
    for _, gui in ipairs(playerGui:GetDescendants()) do
        if gui:IsA("GuiButton") and not (towerUi and gui:IsDescendantOf(towerUi)) then
            local lower = string.lower(gui.Name)
            local match = string.find(lower, "hiddenroll", 1, true) or string.find(lower, "hideroll", 1, true)
            if not match then
                for _, child in ipairs(gui:GetDescendants()) do
                    if child:IsA("TextLabel") and string.lower(child.Text) == "hide" then
                        match = true
                        break
                    end
                end
            end
            if match then
                return gui, rolling, options
            end
        end
    end
    return nil, rolling, options
end

task.spawn(function()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local rolling, options
    local deadline = os.clock() + 60
    repeat
        hiddenRollButton, rolling, options = findHideButton(playerGui)
        if hiddenRollButton then
            break
        end
        task.wait(2)
    until os.clock() > deadline
    rollingUi = rolling
    rollingOptionsUi = options

    if hiddenRollButton then
        print("[JOJOHUB Anime Dice] Hide button found: " .. hiddenRollButton:GetFullName())
    else
        warn("[JOJOHUB Anime Dice] Could not find the Hide button. Press Debug Info in the Roll tab.")
    end

    hideSettingKey = detectHideSettingKey()
    if hideSettingKey then
        print("[JOJOHUB Anime Dice] Hide setting detected: " .. hideSettingKey)
    else
        warn("[JOJOHUB Anime Dice] Hide setting not detected; using click-state fallback. Candidates: "
            .. table.concat(collectSettingKeys(), ", "))
    end

    local clickedAt = setmetatable({}, {__mode = "k"})
    local lastRefind = 0
    while true do
        local ok, err = pcall(function()
            -- Re-find the button if the game rebuilt its UI
            if (not hiddenRollButton or not hiddenRollButton.Parent) and os.clock() - lastRefind > 2 then
                lastRefind = os.clock()
                hiddenRollButton, rolling, options = findHideButton(playerGui)
                rollingUi = rolling
                rollingOptionsUi = options
                gameRollIsHidden = false
            end

            -- 1) Keep the game's "Hidden Roll" setting in sync with our toggle
            if hiddenRollButton and hiddenRollButton.Parent then
                local actual = hideSettingKey and readSetting(hideSettingKey) or nil
                if actual ~= nil then
                    gameRollIsHidden = actual
                    if actual ~= hideRollResults and os.clock() - lastHideClick > 1 then
                        lastHideClick = os.clock()
                        pressButton(hiddenRollButton)
                    end
                elseif gameRollIsHidden ~= hideRollResults then
                    pressButton(hiddenRollButton)
                    gameRollIsHidden = hideRollResults
                end
            end

            -- 2) Auto-click any visible "Hide" button on the roll cutscene / result
            if hideRollResults and rolling and rolling.Parent then
                for _, gui in ipairs(rolling:GetDescendants()) do
                    if gui:IsA("GuiButton") and gui ~= hiddenRollButton
                        and not (options and gui:IsDescendantOf(options)) then
                        local label = string.lower(gui.Name)
                        if gui:IsA("TextButton") then
                            label = label .. " " .. string.lower(gui.Text)
                        end
                        if (string.find(label, "hide", 1, true) or string.find(label, "hidden", 1, true))
                            and isShown(gui) and os.clock() - (clickedAt[gui] or 0) > 0.5 then
                            clickedAt[gui] = os.clock()
                            pressButton(gui)
                        end
                    end
                end
            end
        end)
        if not ok then
            warn("[JOJOHUB Anime Dice] Hide loop error: " .. tostring(err))
            task.wait(2)
        end
        task.wait(0.25)
    end
end)

if type(loadstring) ~= "function" then
    error("[JOJOHUB Anime Dice] loadstring is unavailable in this environment.", 0)
end

local loaded, WindUI = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
end)
if not loaded or not WindUI then
    error("[JOJOHUB Anime Dice] Failed to load WindUI: " .. tostring(WindUI), 0)
end

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
    Title = "JOJOHUB | Anime Dice",
    Author = "Anime Dice",
    Folder = "JOJOHUBAnimeDice",
    Size = initialWindowSize,
    MinSize = initialMinSize,
    MaxSize = initialMaxSize,
    Resizable = not mobileUi,
    Transparent = not mobileUi,
    AutoScale = true,
    Theme = "Dark",
    SideBarWidth = initialSidebarWidth,
    HasOutline = true,
    ToggleKey = Enum.KeyCode.RightControl,
    User = {
        Enabled = true,
        Anonymous = false,
        Title = LocalPlayer.DisplayName,
        Desc = "@" .. LocalPlayer.Name,
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

local playerGui = LocalPlayer:WaitForChild("PlayerGui")
local previousWatermark = playerGui:FindFirstChild("AnimeDiceHubWatermark")
if previousWatermark then
    previousWatermark:Destroy()
end

local watermarkGui = Instance.new("ScreenGui")
watermarkGui.Name = "AnimeDiceHubWatermark"
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
local watermarkDragInput
local watermarkDragStart
local watermarkStart
local watermarkDragMoved = false

watermark.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        watermarkDragInput = input
        watermarkDragStart = input.Position
        watermarkStart = watermark.AbsolutePosition
        watermarkDragMoved = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not watermarkDragInput then
        return
    end
    local isDragging = input.UserInputType == Enum.UserInputType.MouseMovement
        or (watermarkDragInput.UserInputType == Enum.UserInputType.Touch and input == watermarkDragInput)
    if not isDragging then
        return
    end

    local delta = input.Position - watermarkDragStart
    if math.abs(delta.X) > 4 or math.abs(delta.Y) > 4 then
        watermarkDragMoved = true
    end
    local camera = Workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize
    if viewport then
        local x = math.clamp(watermarkStart.X + delta.X, 0, math.max(0, viewport.X - watermark.AbsoluteSize.X))
        local y = math.clamp(watermarkStart.Y + delta.Y, 0, math.max(0, viewport.Y - watermark.AbsoluteSize.Y))
        watermark.Position = UDim2.fromOffset(x, y)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if not watermarkDragInput then
        return
    end
    local matchingInput = input == watermarkDragInput
        or (watermarkDragInput.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseButton1)
    if not matchingInput then
        return
    end

    local shouldToggle = not watermarkDragMoved
    watermarkDragInput = nil
    watermarkDragStart = nil
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

local function makeGroup(title)
    local ok, section = pcall(function()
        return Window:Section({Title = title, Opened = true})
    end)
    if ok and section and section.Tab then
        return section
    end
    return Window
end

local FarmGroup = makeGroup("Auto Farm")
local GameGroup = makeGroup("Game")
local TowerGroup = makeGroup("Tower")
local Tabs = {
    Roll = FarmGroup:Tab({Title = "Roll", Icon = "sparkles"}),
    Farm = FarmGroup:Tab({Title = "Farm & Sell", Icon = "coins"}),
    Upgrades = FarmGroup:Tab({Title = "Upgrades", Icon = "trending-up"}),
    Rebirth = FarmGroup:Tab({Title = "Rebirth", Icon = "refresh-cw"}),
    Towers = TowerGroup:Tab({Title = "Towers", Icon = "swords"}),
    DiceGear = GameGroup:Tab({Title = "Dice & Gear", Icon = "box"}),
    Configs = GameGroup:Tab({Title = "Configs", Icon = "folder"}),
    Rewards = GameGroup:Tab({Title = "Rewards", Icon = "gift"}),
}

local Flags = {
    AutoCollect = false,
    AutoUpgrade = false,
    AutoLevelUnits = false,
    AutoEquipBest = false,
    AutoDice = false,
    AutoGear = false,
    AutoDailyReward = false,
    AutoQuestClaim = false,
    AutoRebirth = false,
    AutoRollSpeed = false,
    AutoRebirthStats = false,
}

local function notify(title, content)
    WindUI:Notify({
        Title = title,
        Content = content,
        Duration = 4
    })
end

local function isDailyRewardReady()
    local lastClaim = tonumber(DataController.LastDailyRewardClaim()) or 0
    return lastClaim == 0 or os.time() - lastClaim >= DailyRewardConfig.Cooldown
end

local function claimDailyReward()
    if not isDailyRewardReady() then
        return false, "Daily reward is not ready yet."
    end
    if os.clock() - lastDailyRewardClaimRequest < 10 then
        return false, "Daily reward claim is already pending."
    end
    lastDailyRewardClaimRequest = os.clock()
    DailyRewardClaimSignal:Fire()
    return true
end

local function claimCompletedQuests()
    local claimedCount = 0
    local now = os.clock()
    for periodName, periodConfig in pairs(QuestConfig.Periods) do
        local questState = DataController.Quests[periodName]()
        if questState and type(questState.progress) == "table" and type(questState.claimed) == "table" then
            local expiresAt = tonumber(questState.expiresAt) or 0
            if expiresAt > 0 and expiresAt > workspace:GetServerTimeNow() then
                for _, quest in ipairs(periodConfig.quests) do
                    local requestKey = periodName .. ":" .. quest.id .. ":" .. tostring(expiresAt)
                    local progress = tonumber(questState.progress[quest.id]) or 0
                    local isClaimed = questState.claimed[quest.id] == true
                    local lastRequestAt = questClaimRequests[requestKey]

                    if isClaimed then
                        questClaimRequests[requestKey] = nil
                    elseif progress >= quest.target
                        and (not lastRequestAt or now - lastRequestAt >= 5) then
                        QuestClaimSignal:Fire(periodName, quest.id, expiresAt)
                        questClaimRequests[requestKey] = now
                        claimedCount = claimedCount + 1
                        task.wait(0.3)
                    end
                end
            end
        end
    end
    return claimedCount
end

local function setRareRollCutsceneSkip(enabled)
    if rareCutscenePatch then
        if enabled then
            skipRareRollCutscene = true
            return true
        end

        local setupvalue = debug and debug.setupvalue
        if type(setupvalue) ~= "function" then
            return false, "Debug upvalue support is unavailable."
        end
        for _, patch in ipairs(rareCutscenePatch) do
            local ok, err = pcall(setupvalue, patch.callback, patch.index, patch.original)
            if not ok then
                return false, "Could not restore the original rare cutscene handler: " .. tostring(err)
            end
            local verifyOk, nameOrValue, value = pcall(debug.getupvalue, patch.callback, patch.index)
            if not verifyOk or (value or nameOrValue) ~= patch.original then
                return false, "Could not verify restoration of the rare cutscene handler."
            end
        end
        rareCutscenePatch = nil
        skipRareRollCutscene = false
        return true
    end

    if not enabled then
        skipRareRollCutscene = false
        return true
    end

    local debugLibrary = debug
    if type(debugLibrary) ~= "table"
        or type(debugLibrary.getupvalue) ~= "function"
        or type(debugLibrary.setupvalue) ~= "function" then
        return false, "This executor does not support patching the rare cutscene handler."
    end
    if type(getgc) ~= "function" then
        return false, "This executor does not support locating the game's roll cutscene calls."
    end

    local loaded, controller = pcall(require, Features.Rolling.RollController)
    if not loaded or type(controller) ~= "table" or type(controller.PlayCutscene) ~= "function" then
        return false, "Could not access the game's roll controller."
    end
    local cutsceneLoaded, cutscene = pcall(require, Features.Rolling.RollCutscene)
    if not cutsceneLoaded or type(cutscene) ~= "function" then
        return false, "Could not access the game's rare cutscene."
    end

    local gcOk, objects = pcall(getgc, true)
    if not gcOk or type(objects) ~= "table" then
        return false, "Could not inspect the game's roll functions."
    end

    local replacement = function(...)
        if skipRareRollCutscene then
            return
        end
        return cutscene(...)
    end

    local patches = {}
    local seen = {}
    for _, object in ipairs(objects) do
        if type(object) == "function" then
            for index = 1, 80 do
                local readOk, nameOrValue, value = pcall(debugLibrary.getupvalue, object, index)
                if not readOk or nameOrValue == nil then
                    break
                end
                if (value or nameOrValue) == cutscene then
                    local key = tostring(object) .. ":" .. tostring(index)
                    if not seen[key] then
                        table.insert(patches, {
                            callback = object,
                            index = index,
                            original = cutscene,
                        })
                        seen[key] = true
                    end
                    break
                end
            end
        end
    end

    local hasRollControllerHook = false
    for _, patch in ipairs(patches) do
        if patch.callback == controller.PlayCutscene then
            hasRollControllerHook = true
            break
        end
    end
    if #patches == 0 or not hasRollControllerHook then
        return false, "Could not locate the game's actual roll cutscene calls."
    end

    local applied = {}
    for _, patch in ipairs(patches) do
        local patched, patchError = pcall(debugLibrary.setupvalue,
            patch.callback, patch.index, replacement)
        local verifyOk, nameOrValue, value = pcall(debugLibrary.getupvalue, patch.callback, patch.index)
        if not patched or not verifyOk or (value or nameOrValue) ~= replacement then
            pcall(debugLibrary.setupvalue, patch.callback, patch.index, patch.original)
            for _, previous in ipairs(applied) do
                pcall(debugLibrary.setupvalue, previous.callback, previous.index, previous.original)
            end
            return false, "Could not install the rare cutscene option: " .. tostring(patchError)
        end
        table.insert(applied, patch)
    end

    rareCutscenePatch = applied
    skipRareRollCutscene = true
    return true
end

local function getAffordableUpgrade()
    local available = {}
    local money = DataController.Money()
    local priority = {
        "Money", "Luck", "Roll Speed", "Unit Storage", "Sell",
        "Grade Luck", "Trait Luck", "Damage", "Health", "Walkspeed", "Fortune"
    }

    local function categoryRank(name)
        for index, category in ipairs(priority) do
            if string.find(name, category, 1, true) then
                return index
            end
        end
        return #priority + 1
    end

    local function visit(parent)
        for _, name in ipairs(UpgradeTree.GetChildren(parent)) do
            local config = UpgradeData[name]
            local state = DataController.Upgrades[name]
            if state and state() then
                visit(name)
            elseif config and type(config.price) == "number" and config.price <= money then
                table.insert(available, {
                    name = name,
                    price = config.price,
                    rank = categoryRank(name)
                })
            end
        end
    end

    visit("Start")
    table.sort(available, function(left, right)
        if left.rank == right.rank then
            return left.price < right.price
        end
        return left.rank < right.rank
    end)
    return available[1] and available[1].name
end

local function buyNextUpgrade()
    local name = getAffordableUpgrade()
    if not name then
        return false
    end
    BuyUpgradeRemote:FireServer(name)
    return true
end

local function buyNextRollSpeedUpgrade()
    local now = os.clock()
    if pendingRollSpeedUpgrade then
        local state = DataController.Upgrades[pendingRollSpeedUpgrade]
        if state and state() then
            pendingRollSpeedUpgrade = nil
        elseif now - pendingRollSpeedUpgradeAt < 5 then
            return false
        else
            pendingRollSpeedUpgrade = nil
        end
    end

    local money = DataController.Money()
    local affordable = {}
    local function visit(parent)
        for _, name in ipairs(UpgradeTree.GetChildren(parent)) do
            local state = DataController.Upgrades[name]
            local config = UpgradeData[name]
            if state and state() then
                visit(name)
            elseif config and string.find(name, "Roll Speed", 1, true) == 1
                and type(config.price) == "number" and config.price <= money then
                table.insert(affordable, {name = name, price = config.price})
            end
        end
    end

    visit("Start")
    table.sort(affordable, function(left, right)
        return left.price < right.price
    end)
    local nextUpgrade = affordable[1]
    if not nextUpgrade then
        return false
    end

    BuyUpgradeRemote:FireServer(nextUpgrade.name)
    pendingRollSpeedUpgrade = nextUpgrade.name
    pendingRollSpeedUpgradeAt = now
    return true
end

local function collectBalances()
    local slots = DataController.Slots()
    for slotId, slot in pairs(slots) do
        if type(slotId) == "string" or type(slotId) == "number" then
            if type(slot) == "table" and (tonumber(slot.balance) or 0) > 0 then
                local numericId = tonumber(slotId)
                if numericId then
                    CollectBalanceRemote:FireServer(numericId)
                end
            end
        end
    end
end

local function levelAffordableUnits()
    local money = DataController.Money()
    local slots = DataController.Slots()
    for slotId, slot in pairs(slots) do
        local numericId = tonumber(slotId)
        if numericId and type(slot) == "table" and type(slot.unitId) == "string" then
            local inventoryEntry = DataController.Inventory[slot.unitId]()
            if inventoryEntry then
                local config = EntryRegistry.getEntryConfig(inventoryEntry.name)
                if config and config.kind == "Unit" then
                    local price = UnitUtil.GetLevelPrice(inventoryEntry.name, inventoryEntry.attributes)
                    if price <= money then
                        LevelUpSlotRemote:FireServer(numericId)
                        money = money - price
                    end
                end
            end
        end
    end
end

local gearBuffWeights = {
    Luck = 5,
    ["Grade Luck"] = 4,
    ["Trait Luck"] = 3,
    ["Money Multiplier"] = 3,
    ["Damage Multiplier"] = 2,
    Walkspeed = 0.5,
}

local function getGearScore(name)
    local config = GearConfig.entries[name]
    if not config then
        return 0
    end

    local score = 0
    for buffName, buff in pairs(config.buffs or {}) do
        score = score + (gearBuffWeights[buffName] or 1) * (tonumber(buff.amount) or 0)
    end
    return score
end

local function equipBestGear()
    local bestBySlot = {}
    for key, entry in pairs(DataController.Inventory()) do
        if (tonumber(entry.amount) or 0) > 0 then
            local config = GearConfig.entries[entry.name]
            if config then
                local score = getGearScore(entry.name)
                local currentBest = bestBySlot[config.slot]
                if not currentBest or score > currentBest.score
                    or (score == currentBest.score and entry.name < currentBest.name) then
                    bestBySlot[config.slot] = {
                        key = key,
                        name = entry.name,
                        score = score,
                    }
                end
            end
        end
    end

    local equippedGear = DataController.EquippedGear
    for slot, best in pairs(bestBySlot) do
        local equippedState = equippedGear[slot]
        local equippedName = equippedState and equippedState()
        if equippedName ~= best.name then
            EquipGearRemote:FireServer(slot, best.name)
        end
    end
end

local function equipBestOrBuyNextDice()
    local money = DataController.Money()
    local currentDice = DiceData.Get(DataController.Dice())
    local currentLuck = currentDice and currentDice.luck or 0
    local now = os.clock()

    if pendingDicePurchase then
        local pendingState = DataController.OwnedDice[pendingDicePurchase]
        if pendingState and pendingState() then
            pendingDicePurchase = nil
        elseif now - pendingDicePurchaseAt < 10 then
            return false
        else
            pendingDicePurchase = nil
        end
    end

    local bestOwnedName
    local bestOwnedLuck = currentLuck

    for name, dice in pairs(DiceData.GetAll()) do
        local ownedState = DataController.OwnedDice[name]
        if ownedState and ownedState() and dice.luck > bestOwnedLuck then
            bestOwnedName = name
            bestOwnedLuck = dice.luck
        end
    end

    if bestOwnedName then
        if lastDiceEquipRequest == bestOwnedName and now - lastDiceEquipRequestAt < 10 then
            return false
        end
        EquipDiceRemote:FireServer(bestOwnedName)
        lastDiceEquipRequest = bestOwnedName
        lastDiceEquipRequestAt = now
        return true
    end

    local nextDiceName
    local nextDiceLuck = currentLuck
    for name, dice in pairs(DiceData.GetAll()) do
        local ownedState = DataController.OwnedDice[name]
        local isOwned = ownedState and ownedState() == true
        if not isOwned and dice.price and dice.price <= money and dice.luck > nextDiceLuck then
            nextDiceName = name
            nextDiceLuck = dice.luck
        end
    end

    if nextDiceName then
        BuyDiceRemote:FireServer(nextDiceName)
        pendingDicePurchase = nextDiceName
        pendingDicePurchaseAt = now
        return true
    end
    return false
end

local function getTowerNames()
    local names = {}
    for name, _ in pairs(TowerData.GetAll()) do
        table.insert(names, name)
    end
    table.sort(names, function(left, right)
        local leftOrder = TowerData.GetAll()[left].order or math.huge
        local rightOrder = TowerData.GetAll()[right].order or math.huge
        if leftOrder == rightOrder then
            return left < right
        end
        return leftOrder < rightOrder
    end)
    return names
end

local function getTowerUi()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local root = playerGui:WaitForChild("Root", 30)
    local tower = root and root:WaitForChild("Tower", 10)
    local screen = tower and tower:WaitForChild("Screen", 10)
    local hidden = tower and tower:WaitForChild("Hidden", 10)
    if not screen or not hidden then
        return nil, nil
    end
    return screen, hidden
end

local function waitForTowerToEnd(generation)
    local screen, hidden = getTowerUi()
    if not screen then
        warn("[JOJOHUB Anime Dice] Could not find the tower UI.")
        return false
    end

    local startedDeadline = os.clock() + 30
    while generation == towerFarmGeneration
        and not screen.Visible and not hidden.Visible
        and os.clock() < startedDeadline do
        task.wait(0.2)
    end
    if not screen.Visible and not hidden.Visible then
        warn("[JOJOHUB Anime Dice] Tower UI did not appear after starting a run.")
        return false
    end

    local hideRequested = false
    while screen.Visible or hidden.Visible do
        if not hideRequested and screen.Visible and hidden.Visible then
            pressButton(hidden)
            hideRequested = true
        end
        task.wait(0.5)
    end
    task.wait(1)
    return true
end

local function getSelectedTowerNames()
    local list = {}
    for _, name in ipairs(getTowerNames()) do
        if selectedTowers[name] then
            table.insert(list, name)
        end
    end
    return list
end

local function runTowerSequential(name, generation)
    local screen, hidden = getTowerUi()
    if not screen then
        notify("Towers", "Could not find the tower UI.")
        return false
    end
    if screen.Visible or hidden.Visible then
        if not waitForTowerToEnd(generation) then
            return false
        end
    end

    EquipBestTowerRemote:FireServer()
    local teamReady = false
    local teamDeadline = os.clock() + 5
    repeat
        if generation ~= towerFarmGeneration then
            return false
        end
        task.wait(0.2)
        local ok, team = pcall(DataController.TowerTeam)
        teamReady = ok and type(team) == "table" and next(team) ~= nil
    until teamReady or os.clock() >= teamDeadline

    if not teamReady then
        notify("Towers", "No units are assigned to Tower Team. Equip at least one unit, then try again.")
        return false
    end

    local called, started = pcall(TowerController.startTower, name)
    if not called then
        error("Failed to start " .. name .. ": " .. tostring(started))
    end
    if not started then
        warn("[JOJOHUB Anime Dice] Could not start " .. name .. "; the current tower may still be active.")
        notify("Towers", "Could not start " .. name .. ". Make sure another tower is not already running.")
        return false
    end
    if not waitForTowerToEnd(generation) then
        return false
    end
    task.wait(1)
    return true
end

local function runTowerQueue()
    if towerFarmRunning then
        return
    end
    towerFarmRunning = true
    local generation = towerFarmGeneration

    local ok, err = pcall(function()
        if #getSelectedTowerNames() == 0 then
            notify("Towers", "Select at least one tower to farm.")
            return
        end

        AutoTowerRemote:FireServer(false)

        repeat
            local list = getSelectedTowerNames()
            if #list == 0 or generation ~= towerFarmGeneration then
                break
            end

            for _, name in ipairs(list) do
                if generation ~= towerFarmGeneration or not selectedTowers[name] then
                    break
                end
                if not runTowerSequential(name, generation) then
                    return
                end
            end

            if not autoTowerEnabled or generation ~= towerFarmGeneration then
                break
            end
        until false
    end)

    towerFarmRunning = false
    if not ok then
        warn("[JOJOHUB Anime Dice] Tower farm stopped: " .. tostring(err))
    end
end

local rebirthRemote
local rebirthMinMoney = 0
local rebirthWarned = false

local function findRebirthRemote()
    if rebirthRemote and rebirthRemote.Parent then
        return rebirthRemote
    end
    local fallback
    for _, remote in ipairs(Network:GetDescendants()) do
        if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
            local lower = string.lower(remote.Name)
            if string.find(lower, "rebirth", 1, true) then
                local skip = false
                for _, word in ipairs({"get", "info", "data", "update", "changed", "sync", "notify", "preview"}) do
                    if string.find(lower, word, 1, true) then
                        skip = true
                        break
                    end
                end
                if not skip then
                    if lower == "rebirth" or lower == "dorebirth" then
                        rebirthRemote = remote
                        return remote
                    end
                    fallback = fallback or remote
                end
            end
        end
    end
    rebirthRemote = fallback
    return fallback
end

local function doRebirth()
    local currentRebirth = DataController.Rebirth()
    local nextRebirth = RebirthData.GetNext(currentRebirth)
    if not nextRebirth or DataController.Money() < math.max(nextRebirth.cost, rebirthMinMoney) then
        return false
    end

    local remote = findRebirthRemote()
    if not remote then
        return false
    end
    if remote:IsA("RemoteFunction") then
        pcall(remote.InvokeServer, remote)
    else
        remote:FireServer()
    end
    return true
end

local function autoAllocateRebirthStat()
    local stats = DataController.RebirthStats() or {}
    local now = os.clock()
    if pendingRebirthStat then
        local currentLevel = tonumber(stats[pendingRebirthStat]) or 0
        if currentLevel > pendingRebirthStatLevel then
            pendingRebirthStat = nil
        elseif now - pendingRebirthStatAt < 3 then
            return false
        else
            pendingRebirthStat = nil
        end
    end

    local remaining = RebirthStatsConfig.GetRemaining(DataController.Rebirth(), stats)
    if remaining < 1 then
        return false
    end

    local selectedStat
    local lowestBuff = math.huge
    for _, stat in ipairs(RebirthStatsConfig.Stats) do
        if autoRebirthStatSelection[stat.name] then
            local level = tonumber(stats[stat.name]) or 0
            local currentBuff = level * stat.perPoint
            if currentBuff < lowestBuff then
                lowestBuff = currentBuff
                selectedStat = stat.name
            end
        end
    end
    if not selectedStat then
        return false
    end

    AddRebirthStatRemote:FireServer(selectedStat)
    pendingRebirthStat = selectedStat
    pendingRebirthStatLevel = tonumber(stats[selectedStat]) or 0
    pendingRebirthStatAt = now
    return true
end

local configControls = {}

Tabs.Rewards:Paragraph({
    Title = "Daily Rewards",
    Desc = "Claim the next daily reward when it becomes available. The game enforces its daily cooldown."
})

configControls.AutoDailyReward = Tabs.Rewards:Toggle({
    Title = "Auto Claim Daily Reward",
    Value = Flags.AutoDailyReward,
    Callback = function(enabled)
        Flags.AutoDailyReward = enabled
        if enabled and isDailyRewardReady() then
            local claimed, err = claimDailyReward()
            if not claimed then
                notify("Daily Rewards", err)
            end
        end
    end
})

configControls.AutoQuestClaim = Tabs.Rewards:Toggle({
    Title = "Auto Claim Quests",
    Value = Flags.AutoQuestClaim,
    Callback = function(enabled)
        Flags.AutoQuestClaim = enabled
        if enabled then
            local count = claimCompletedQuests()
            if count == 0 then
                notify("Quests", "No completed, unclaimed quests are ready.")
            end
        end
    end
})

Tabs.Rewards:Button({
    Title = "Claim Completed Quests Now",
    Callback = function()
        local count = claimCompletedQuests()
        notify("Quests", count > 0
            and ("Sent claim requests for " .. tostring(count) .. " completed quest(s).")
            or "No completed, unclaimed quests are ready.")
    end
})

Tabs.Rewards:Button({
    Title = "Claim Daily Reward Now",
    Callback = function()
        local claimed, err = claimDailyReward()
        if claimed then
            notify("Daily Rewards", "Claim request sent.")
        else
            notify("Daily Rewards", err)
        end
    end
})

Tabs.Rebirth:Paragraph({
    Title = "Auto Rebirth",
    Desc = "Rebirths only after you have enough money for the next rebirth."
})

configControls.AutoRebirth = Tabs.Rebirth:Toggle({
    Title = "Auto Rebirth",
    Value = false,
    Callback = function(enabled)
        Flags.AutoRebirth = enabled
        rebirthWarned = false
    end
})

configControls.RebirthMinMoney = Tabs.Rebirth:Input({
    Title = "Minimum Money Before Rebirth",
    Placeholder = "Optional extra threshold, e.g. 1m",
    Value = "0",
    Callback = function(value)
        local normalized = tostring(value):gsub(",", "")
        local amount = tonumber(normalized) or NumberFormatter.ParseCompact(normalized)
        if type(amount) ~= "number" or amount < 0 then
            notify("Auto Rebirth", "Enter a valid non-negative amount.")
            return
        end
        rebirthMinMoney = amount
        notify("Auto Rebirth", amount > 0 and ("Minimum money set to " .. NumberFormatter.FormatCompact(amount)) or "Using the game's next rebirth cost")
    end
})

Tabs.Rebirth:Button({
    Title = "Rebirth Now",
    Callback = function()
        local currentRebirth = DataController.Rebirth()
        local nextRebirth = RebirthData.GetNext(currentRebirth)
        if nextRebirth and DataController.Money() >= math.max(nextRebirth.cost, rebirthMinMoney) then
            if not doRebirth() then
                notify("Auto Rebirth", "Could not find a rebirth remote. Use Debug Info in the Roll tab.")
            end
        elseif not nextRebirth then
            notify("Auto Rebirth", "You already have the maximum rebirth.")
        end
    end
})

Tabs.Rebirth:Paragraph({
    Title = "Auto Rebirth Stats",
    Desc = "Choose stats below. Selected stats are upgraded using available rebirth points, balanced by their current bonus."
})

local rebirthStatNames = {}
for _, stat in ipairs(RebirthStatsConfig.Stats) do
    table.insert(rebirthStatNames, stat.name)
end

configControls.RebirthStats = Tabs.Rebirth:Dropdown({
    Title = "Select Stats to Auto Upgrade",
    Values = rebirthStatNames,
    Value = {},
    Multi = true,
    AllowNone = true,
    Callback = function(selection)
        local picked = {}
        if type(selection) == "table" then
            for key, value in pairs(selection) do
                if type(value) == "string" then
                    picked[value] = true
                elseif value == true and type(key) == "string" then
                    picked[key] = true
                end
            end
        elseif type(selection) == "string" then
            picked[selection] = true
        end
        autoRebirthStatSelection = picked
    end
})

configControls.AutoRebirthStats = Tabs.Rebirth:Toggle({
    Title = "Auto Spend Rebirth Points",
    Value = Flags.AutoRebirthStats,
    Callback = function(enabled)
        Flags.AutoRebirthStats = enabled
    end
})

Tabs.Roll:Paragraph({
    Title = "Dice Rolls",
    Desc = "Uses the game's Auto Roll and roll cooldown. Increase speed with Roll Speed upgrades."
})

configControls.AutoRoll = Tabs.Roll:Toggle({
    Title = "Auto Roll",
    Value = false,
    Callback = function(enabled)
        autoRollEnabled = enabled
        AutoRollRemote:FireServer(enabled)
    end
})

configControls.HideRollResults = Tabs.Roll:Toggle({
    Title = "Auto Hide Roll Results",
    Value = hideRollResults,
    Callback = function(enabled)
        hideRollResults = enabled
    end
})

configControls.SkipRareRollCutscene = Tabs.Roll:Toggle({
    Title = "Skip Rare Roll Cutscenes",
    Value = false,
    Callback = function(enabled)
        local ok, err = setRareRollCutsceneSkip(enabled)
        if not ok then
            warn("[JOJOHUB Anime Dice] " .. tostring(err))
            notify("Roll", tostring(err))
            if configControls.SkipRareRollCutscene
                and type(configControls.SkipRareRollCutscene.Set) == "function" then
                pcall(configControls.SkipRareRollCutscene.Set,
                    configControls.SkipRareRollCutscene, false)
            end
        end
    end
})

Tabs.Roll:Button({
    Title = "Roll Once",
    Callback = function()
        RollRemote:InvokeServer()
    end
})

Tabs.Roll:Button({
    Title = "Debug Info (print to F9 console)",
    Callback = function()
        print("[JOJOHUB Debug] Hide setting key:", tostring(hideSettingKey))
        print("[JOJOHUB Debug] Settings candidates:", table.concat(collectSettingKeys(), ", "))
        if rollingUi then
            for _, gui in ipairs(rollingUi:GetDescendants()) do
                if gui:IsA("GuiButton") then
                    print("[JOJOHUB Debug] Rolling button:", gui:GetFullName(), "shown=", tostring(isShown(gui)))
                end
            end
        end
        print("[JOJOHUB Debug] Hide button:", hiddenRollButton and hiddenRollButton:GetFullName() or "nil")
        print("[JOJOHUB Debug] getconnections/firesignal:", tostring(type(getconnections)), tostring(type(firesignal)))
        pcall(function()
            for _, gui in ipairs(LocalPlayer.PlayerGui:GetDescendants()) do
                if gui:IsA("GuiButton") then
                    local lower = string.lower(gui.Name)
                    if string.find(lower, "hid", 1, true) or string.find(lower, "auto", 1, true) then
                        print("[JOJOHUB Debug] HUD button:", gui:GetFullName(), "shown=", tostring(isShown(gui)))
                    end
                end
            end
        end)
        pcall(function()
            local rollingFolder = Features:FindFirstChild("Rolling")
            for _, module in ipairs(rollingFolder and rollingFolder:GetChildren() or {}) do
                print("[JOJOHUB Debug] Rolling module:", module:GetFullName(), module.ClassName)
                if module:IsA("ModuleScript") then
                    local ok, result = pcall(require, module)
                    if ok and type(result) == "table" then
                        local keys = {}
                        for key in pairs(result) do
                            table.insert(keys, tostring(key))
                        end
                        print("[JOJOHUB Debug]   keys:", table.concat(keys, ", "))
                    end
                end
            end
        end)
        for _, remote in ipairs(Network:GetDescendants()) do
            if string.find(string.lower(remote.Name), "rebirth", 1, true) then
                print("[JOJOHUB Debug] Rebirth remote:", remote:GetFullName(), remote.ClassName)
            end
        end
        notify("Debug", "Printed to the console (F9).")
    end
})

Tabs.Roll:Paragraph({
    Title = "Safety",
    Desc = "Automation starts disabled. Enable only the features you want to use."
})

Tabs.Farm:Paragraph({
    Title = "Collect Plot Income",
    Desc = "Collects available balance from every unlocked plot slot."
})

configControls.AutoCollect = Tabs.Farm:Toggle({
    Title = "Auto Collect Money",
    Value = Flags.AutoCollect,
    Callback = function(enabled)
        Flags.AutoCollect = enabled
        if enabled then
            collectBalances()
        end
    end
})

Tabs.Farm:Button({
    Title = "Collect Money Now",
    Callback = collectBalances
})

Tabs.Farm:Divider()

Tabs.Farm:Paragraph({
    Title = "Auto Sell Units",
    Desc = "The game automatically sells rolled units with a chance below the threshold."
})

Tabs.Farm:Button({
    Title = "Sell All Sellable Units",
    Callback = function()
        local keys = {}
        for key, entry in pairs(DataController.Inventory()) do
            local config = type(entry) == "table" and EntryRegistry.getEntryConfig(entry.name)
            if config and config.kind == "Unit" and (tonumber(entry.amount) or 0) > 0 then
                table.insert(keys, key)
            end
        end

        if #keys == 0 then
            notify("Sell Units", "No sellable units found in your inventory.")
            return
        end

        local ok, earnings, soldCount = pcall(SellInventoryRemote.InvokeServer, SellInventoryRemote, keys)
        if not ok then
            warn("[JOJOHUB Anime Dice] Sell inventory request failed: " .. tostring(earnings))
            notify("Sell Units", "Could not sell units. Please try again.")
            return
        end

        if (tonumber(soldCount) or 0) > 0 then
            notify("Sell Units", ("Sold %s units for $%s. Locked or placed units were skipped."):format(
                NumberFormatter.FormatCompact(soldCount),
                NumberFormatter.FormatCompact(earnings or 0)
            ))
        else
            notify("Sell Units", "No unlocked, unplaced units could be sold.")
        end
    end
})

configControls.AutoSellThreshold = Tabs.Farm:Input({
    Title = "Sell Chance Threshold",
    Placeholder = "Example: 1000 or 1k",
    Value = tostring(DataController.AutoSell()),
    Callback = function(value)
        local normalized = tostring(value):gsub(",", "")
        local threshold = tonumber(normalized) or NumberFormatter.ParseCompact(normalized)
        if type(threshold) ~= "number" or threshold < 0
            or not SettingsConfig.IsValid("AutoSell", threshold) then
            notify("Auto Sell", "Enter a valid non-negative threshold.")
            return
        end
        AutoSellRemote:FireServer(threshold)
        notify("Auto Sell", threshold > 0 and ("Enabled below 1 in " .. NumberFormatter.FormatCompact(threshold)) or "Disabled")
    end
})

Tabs.Farm:Button({
    Title = "Disable Auto Sell",
    Callback = function()
        AutoSellRemote:FireServer(0)
        notify("Auto Sell", "Disabled")
    end
})

Tabs.Upgrades:Paragraph({
    Title = "Upgrade Tree",
    Desc = "Prioritizes Money and Luck, then roll speed and other affordable upgrades."
})

configControls.AutoUpgrade = Tabs.Upgrades:Toggle({
    Title = "Auto Buy Upgrades",
    Value = Flags.AutoUpgrade,
    Callback = function(enabled)
        Flags.AutoUpgrade = enabled
    end
})

configControls.AutoRollSpeed = Tabs.Upgrades:Toggle({
    Title = "Auto Buy Roll Speed",
    Value = Flags.AutoRollSpeed,
    Callback = function(enabled)
        Flags.AutoRollSpeed = enabled
    end
})

Tabs.Upgrades:Button({
    Title = "Buy Next Affordable Upgrade",
    Callback = function()
        if not buyNextUpgrade() then
            notify("Upgrades", "No unlocked upgrade is affordable right now.")
        end
    end
})

Tabs.Upgrades:Divider()

configControls.AutoLevelUnits = Tabs.Upgrades:Toggle({
    Title = "Auto Level Plot Units",
    Value = Flags.AutoLevelUnits,
    Callback = function(enabled)
        Flags.AutoLevelUnits = enabled
    end
})

configControls.AutoEquipBest = Tabs.Upgrades:Toggle({
    Title = "Auto Equip Best Units to Plot",
    Value = Flags.AutoEquipBest,
    Callback = function(enabled)
        Flags.AutoEquipBest = enabled
    end
})

Tabs.Upgrades:Button({
    Title = "Equip Best Units to Plot",
    Callback = function()
        EquipBestRemote:FireServer()
    end
})

Tabs.DiceGear:Paragraph({
    Title = "Dice Shop",
    Desc = "Automatically equips better owned dice and buys the next affordable dice."
})

configControls.AutoDice = Tabs.DiceGear:Toggle({
    Title = "Auto Equip / Buy Better Dice",
    Value = Flags.AutoDice,
    Callback = function(enabled)
        Flags.AutoDice = enabled
    end
})

Tabs.DiceGear:Divider()

Tabs.DiceGear:Paragraph({
    Title = "Best Gear",
    Desc = "Auto equips the owned gear with the strongest weighted buffs in each slot."
})

configControls.AutoGear = Tabs.DiceGear:Toggle({
    Title = "Auto Equip Best Gear",
    Value = Flags.AutoGear,
    Callback = function(enabled)
        Flags.AutoGear = enabled
    end
})

local towerNames = getTowerNames()
if #towerNames > 0 then
    Tabs.Towers:Paragraph({
        Title = "Tower Rotation",
        Desc = "Select towers, then enable Auto Tower. It equips your best team, fights selected towers one at a time, and repeats until disabled."
    })

    local towerDropdown
    towerDropdown = Tabs.Towers:Dropdown({
        Title = "Select Towers",
        Desc = "Pick one or more towers. They are played in order, one at a time.",
        Values = towerNames,
        Value = {},
        Multi = true,
        AllowNone = true,
        Callback = function(selection)
            local picked = {}
            if type(selection) == "table" then
                for key, value in pairs(selection) do
                    if type(value) == "string" then
                        picked[value] = true
                    elseif value == true and type(key) == "string" then
                        picked[key] = true
                    end
                end
            elseif type(selection) == "string" then
                picked[selection] = true
            end
            selectedTowers = picked
        end
    })
    configControls.SelectedTowers = towerDropdown

    Tabs.Towers:Button({
        Title = "Select All Towers",
        Callback = function()
            pcall(function()
                towerDropdown:Select(towerNames)
            end)
            local picked = {}
            for _, name in ipairs(towerNames) do
                picked[name] = true
            end
            selectedTowers = picked
        end
    })

    configControls.AutoTower = Tabs.Towers:Toggle({
        Title = "Auto Tower",
        Value = false,
        Callback = function(enabled)
            autoTowerEnabled = enabled
            if enabled then
                if not towerFarmRunning then
                    towerFarmGeneration = towerFarmGeneration + 1
                    task.spawn(runTowerQueue)
                end
            else
                towerFarmGeneration = towerFarmGeneration + 1
                AutoTowerRemote:FireServer(false)
            end
        end
    })
else
    Tabs.Towers:Paragraph({
        Title = "No Towers Found",
        Desc = "The current game version did not provide a tower list."
    })
end

local configRoot = "JOJOHUB/AnimeDice/Configs"
local configFolder = configRoot
local configAutoloadPath = configRoot .. "/autoload.txt"
local selectedConfigName = ""
local renameSourceName = ""
local renameTargetName = ""
local importJson = ""

local function validateConfigName(name)
    name = tostring(name or ""):match("^%s*(.-)%s*$")
    if name == "" or #name > 40 or not name:match("^[%w _%-]+$") then
        return nil, "Use 1-40 letters, numbers, spaces, underscores, or hyphens for the config name."
    end
    return name
end

local function ensureConfigStorage()
    if type(isfolder) ~= "function" or type(makefolder) ~= "function"
        or type(isfile) ~= "function" or type(readfile) ~= "function"
        or type(writefile) ~= "function" or type(delfile) ~= "function" then
        return false, "This executor does not support the required file APIs."
    end

    local current = ""
    for part in string.gmatch(configFolder, "[^/]+") do
        current = current == "" and part or (current .. "/" .. part)
        if not isfolder(current) then
            makefolder(current)
        end
    end
    return true
end

local function getSavedConfigNames()
    local storageReady, storageError = ensureConfigStorage()
    if not storageReady then
        return nil, storageError
    end
    if type(listfiles) ~= "function" then
        return nil, "This executor does not support listing saved config files."
    end
    local ok, paths = pcall(listfiles, configFolder)
    if not ok or type(paths) ~= "table" then
        return nil, "Could not list saved configs: " .. tostring(paths)
    end

    local names = {}
    for _, path in ipairs(paths) do
        local normalized = tostring(path):gsub("\\", "/")
        local filename = normalized:match("([^/]+)%.json$")
        if filename and not filename:match("%.export$") and validateConfigName(filename) then
            table.insert(names, filename)
        end
    end
    table.sort(names, function(left, right)
        return string.lower(left) < string.lower(right)
    end)
    return names
end

local function selectedNames(selection)
    local names = {}
    for name, selected in pairs(selection) do
        if selected then
            table.insert(names, name)
        end
    end
    table.sort(names)
    return names
end

local function makeConfigSnapshot()
    return {
        version = 1,
        flags = table.clone(Flags),
        autoRoll = autoRollEnabled,
        autoTower = autoTowerEnabled,
        selectedTowers = selectedNames(selectedTowers),
        selectedRebirthStats = selectedNames(autoRebirthStatSelection),
        rebirthMinMoney = rebirthMinMoney,
        autoSellThreshold = tonumber(DataController.AutoSell()) or 0,
        hideRollResults = hideRollResults,
        skipRareRollCutscene = skipRareRollCutscene,
    }
end

local function validateConfig(data)
    if type(data) ~= "table" or data.version ~= 1 or type(data.flags) ~= "table" then
        return false, "Unsupported or invalid config format."
    end

    for key in pairs(Flags) do
        if data.flags[key] ~= nil and type(data.flags[key]) ~= "boolean" then
            return false, "Config is missing a valid " .. key .. " setting."
        end
    end
    for key, value in pairs(data.flags) do
        if key == "AutoGrade" and type(value) == "boolean" then
            continue
        end
        if Flags[key] == nil or type(value) ~= "boolean" then
            return false, "Config contains an unknown or invalid setting: " .. tostring(key)
        end
    end
    for _, key in ipairs({"autoRoll", "autoTower", "hideRollResults", "skipRareRollCutscene"}) do
        if type(data[key]) ~= "boolean" then
            return false, "Config is missing a valid " .. key .. " value."
        end
    end
    if type(data.rebirthMinMoney) ~= "number" or data.rebirthMinMoney < 0
        or data.rebirthMinMoney ~= data.rebirthMinMoney or data.rebirthMinMoney == math.huge then
        return false, "Config has an invalid rebirth money threshold."
    end
    if type(data.autoSellThreshold) ~= "number" or data.autoSellThreshold < 0
        or data.autoSellThreshold ~= data.autoSellThreshold
        or not SettingsConfig.IsValid("AutoSell", data.autoSellThreshold) then
        return false, "Config has an invalid Auto Sell threshold."
    end
    if type(data.selectedTowers) ~= "table" or type(data.selectedRebirthStats) ~= "table" then
        return false, "Config has invalid tower or rebirth stat selections."
    end

    local function isArray(value)
        local count = 0
        for key in pairs(value) do
            if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
                return false
            end
            count = count + 1
        end
        if count ~= #value then
            return false
        end
        for index = 1, count do
            if value[index] == nil then
                return false
            end
        end
        return true
    end
    if not isArray(data.selectedTowers) or not isArray(data.selectedRebirthStats) then
        return false, "Config has invalid tower or rebirth stat selections."
    end

    local validTowers = {}
    for _, name in ipairs(getTowerNames()) do
        validTowers[name] = true
    end
    for _, name in ipairs(data.selectedTowers) do
        if type(name) ~= "string" or not validTowers[name] then
            return false, "Config contains an unknown tower selection."
        end
    end
    local validStats = {}
    for _, stat in ipairs(RebirthStatsConfig.Stats) do
        validStats[stat.name] = true
    end
    for _, name in ipairs(data.selectedRebirthStats) do
        if type(name) ~= "string" or not validStats[name] then
            return false, "Config contains an unknown Rebirth Stat selection."
        end
    end
    return true
end

local function applyConfig(data)
    for key in pairs(Flags) do
        Flags[key] = data.flags[key] == true
    end
    autoRollEnabled = data.autoRoll
    autoTowerEnabled = false
    rebirthMinMoney = data.rebirthMinMoney
    hideRollResults = data.hideRollResults
    selectedTowers = {}
    for _, name in ipairs(data.selectedTowers) do
        selectedTowers[name] = true
    end
    autoRebirthStatSelection = {}
    for _, name in ipairs(data.selectedRebirthStats) do
        autoRebirthStatSelection[name] = true
    end

    local flagControlNames = {
        AutoCollect = "AutoCollect",
        AutoUpgrade = "AutoUpgrade",
        AutoLevelUnits = "AutoLevelUnits",
        AutoEquipBest = "AutoEquipBest",
        AutoDice = "AutoDice",
        AutoGear = "AutoGear",
        AutoDailyReward = "AutoDailyReward",
        AutoQuestClaim = "AutoQuestClaim",
        AutoRebirth = "AutoRebirth",
        AutoRollSpeed = "AutoRollSpeed",
        AutoRebirthStats = "AutoRebirthStats",
    }
    for flagName, controlName in pairs(flagControlNames) do
        local control = configControls[controlName]
        if control and type(control.Set) == "function" then
            local ok, err = pcall(control.Set, control, data.flags[flagName])
            if not ok then
                warn("[JOJOHUB Anime Dice] Could not update config control " .. controlName .. ": " .. tostring(err))
            end
        end
    end
    local function setControlValue(controlName, value, methodName)
        local control = configControls[controlName]
        local setter = control and control[methodName or "Set"]
        if type(setter) == "function" then
            local ok, err = pcall(setter, control, value)
            if not ok then
                warn("[JOJOHUB Anime Dice] Could not update config control " .. controlName .. ": " .. tostring(err))
            end
        end
    end
    setControlValue("AutoRoll", autoRollEnabled)
    setControlValue("HideRollResults", hideRollResults)
    setControlValue("SkipRareRollCutscene", data.skipRareRollCutscene)
    setControlValue("RebirthMinMoney", tostring(rebirthMinMoney))
    setControlValue("AutoSellThreshold", tostring(data.autoSellThreshold))
    setControlValue("RebirthStats", selectedNames(autoRebirthStatSelection), "Select")
    setControlValue("SelectedTowers", selectedNames(selectedTowers), "Select")

    AutoRollRemote:FireServer(autoRollEnabled)
    AutoSellRemote:FireServer(data.autoSellThreshold)
    local skipOk, skipError = setRareRollCutsceneSkip(data.skipRareRollCutscene)
    if not skipOk then
        notify("Configs", "Settings loaded, but rare cutscene skipping failed: " .. tostring(skipError))
    end

    towerFarmGeneration = towerFarmGeneration + 1
    AutoTowerRemote:FireServer(false)
    if data.autoTower then
        if next(selectedTowers) then
            autoTowerEnabled = true
            task.spawn(runTowerQueue)
        else
            notify("Configs", "Auto Tower was not started because this config has no selected towers.")
        end
    end
    setControlValue("AutoTower", autoTowerEnabled)
end

local function readConfig(name)
    local ok, err = ensureConfigStorage()
    if not ok then
        return nil, err
    end
    local path = configFolder .. "/" .. name .. ".json"
    if not isfile(path) then
        return nil, "Config not found: " .. name
    end
    local decoded, data = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)
    if not decoded then
        return nil, "Could not parse config JSON: " .. tostring(data)
    end
    local valid, validationError = validateConfig(data)
    if not valid then
        return nil, validationError
    end
    return data
end

Tabs.Configs:Paragraph({
    Title = "Config Manager",
    Desc = "Save and load named settings, export JSON to the clipboard/file, or import pasted JSON. Loading applies automation switches."
})

local configNameControl = Tabs.Configs:Input({
    Title = "Config Name",
    Placeholder = "Enter a config name",
    Value = "",
    Callback = function(value)
        selectedConfigName = value
    end
})

local configDropdown = Tabs.Configs:Dropdown({
    Title = "Saved Configs",
    Values = {},
    Value = "",
    AllowNone = true,
    Callback = function(value)
        if type(value) == "string" and value ~= "" then
            selectedConfigName = value
            if configNameControl and type(configNameControl.Set) == "function" then
                pcall(configNameControl.Set, configNameControl, value)
            end
        end
    end
})

local function refreshConfigDropdown()
    local names, err = getSavedConfigNames()
    if not names then
        notify("Configs", err)
        return false
    end
    local refreshed, refreshError = pcall(configDropdown.Refresh, configDropdown, names)
    if not refreshed then
        warn("[JOJOHUB Anime Dice] Could not refresh config list: " .. tostring(refreshError))
        notify("Configs", "Could not refresh config list: " .. tostring(refreshError))
        return false
    end
    return true
end

Tabs.Configs:Button({
    Title = "Refresh Config List",
    Callback = refreshConfigDropdown
})

Tabs.Configs:Input({
    Title = "Rename From",
    Placeholder = "Existing config name",
    Value = "",
    Callback = function(value)
        renameSourceName = value
    end
})

Tabs.Configs:Input({
    Title = "Rename To",
    Placeholder = "New config name",
    Value = "",
    Callback = function(value)
        renameTargetName = value
    end
})

Tabs.Configs:Button({
    Title = "Create / Save Config",
    Callback = function()
        local name, nameError = validateConfigName(selectedConfigName)
        if not name then
            notify("Configs", nameError)
            return
        end
        local ok, err = ensureConfigStorage()
        if not ok then
            notify("Configs", err)
            return
        end
        local saved, saveError = pcall(function()
            writefile(configFolder .. "/" .. name .. ".json", HttpService:JSONEncode(makeConfigSnapshot()))
        end)
        if not saved then
            warn("[JOJOHUB Anime Dice] Config save failed: " .. tostring(saveError))
            notify("Configs", "Could not save config: " .. tostring(saveError))
            return
        end
        notify("Configs", "Saved config: " .. name)
        refreshConfigDropdown()
    end
})

Tabs.Configs:Button({
    Title = "Load Config",
    Callback = function()
        local name, nameError = validateConfigName(selectedConfigName)
        if not name then
            notify("Configs", nameError)
            return
        end
        local data, err = readConfig(name)
        if not data then
            notify("Configs", err)
            return
        end
        applyConfig(data)
        notify("Configs", "Loaded config: " .. name)
    end
})

Tabs.Configs:Button({
    Title = "Delete Config",
    Callback = function()
        local name, nameError = validateConfigName(selectedConfigName)
        if not name then
            notify("Configs", nameError)
            return
        end
        local ok, err = ensureConfigStorage()
        if not ok then
            notify("Configs", err)
            return
        end
        local path = configFolder .. "/" .. name .. ".json"
        if not isfile(path) then
            notify("Configs", "Config not found: " .. name)
            return
        end
        local deleted, deleteError = pcall(delfile, path)
        if not deleted then
            notify("Configs", "Could not delete config: " .. tostring(deleteError))
            return
        end
        if isfile(configAutoloadPath) and readfile(configAutoloadPath) == name then
            local cleared, clearError = pcall(delfile, configAutoloadPath)
            if not cleared then
                notify("Configs", "Config deleted, but autoload could not be cleared: " .. tostring(clearError))
                return
            end
        end
        notify("Configs", "Deleted config: " .. name)
        refreshConfigDropdown()
    end
})

Tabs.Configs:Button({
    Title = "Rename Config",
    Callback = function()
        local oldName, nameError = validateConfigName(renameSourceName)
        local newName, renameError = validateConfigName(renameTargetName)
        if not oldName or not newName then
            notify("Configs", nameError or renameError)
            return
        end
        local ok, storageError = ensureConfigStorage()
        if not ok then
            notify("Configs", storageError)
            return
        end
        local oldPath = configFolder .. "/" .. oldName .. ".json"
        local newPath = configFolder .. "/" .. newName .. ".json"
        if not isfile(oldPath) or isfile(newPath) then
            notify("Configs", "The source must exist and the new name must be unused.")
            return
        end
        local data, readError = readConfig(oldName)
        if not data then
            notify("Configs", readError)
            return
        end
        local renamed, renameFileError = pcall(function()
            writefile(newPath, HttpService:JSONEncode(data))
            delfile(oldPath)
        end)
        if not renamed then
            notify("Configs", "Could not rename config: " .. tostring(renameFileError))
            return
        end
        if isfile(configAutoloadPath) and readfile(configAutoloadPath) == oldName then
            local autoloadUpdated, autoloadError = pcall(writefile, configAutoloadPath, newName)
            if not autoloadUpdated then
                warn("[JOJOHUB Anime Dice] Renamed config but could not update autoload: " .. tostring(autoloadError))
            end
        end
        selectedConfigName = newName
        renameSourceName = newName
        notify("Configs", "Renamed config to: " .. newName)
        refreshConfigDropdown()
    end
})

Tabs.Configs:Button({
    Title = "Set Autoload",
    Callback = function()
        local name, nameError = validateConfigName(selectedConfigName)
        if not name then
            notify("Configs", nameError)
            return
        end
        local data, err = readConfig(name)
        if not data then
            notify("Configs", err)
            return
        end
        local ok, saveError = pcall(writefile, configAutoloadPath, name)
        if not ok then
            notify("Configs", "Could not set autoload: " .. tostring(saveError))
            return
        end
        notify("Configs", "Autoload set to: " .. name)
    end
})

Tabs.Configs:Button({
    Title = "Clear Autoload",
    Callback = function()
        local ok, err = ensureConfigStorage()
        if not ok then
            notify("Configs", err)
            return
        end
        if isfile(configAutoloadPath) then
            local deleted, deleteError = pcall(delfile, configAutoloadPath)
            if not deleted then
                notify("Configs", "Could not clear autoload: " .. tostring(deleteError))
                return
            end
        end
        notify("Configs", "Autoload cleared.")
    end
})

Tabs.Configs:Input({
    Title = "Import JSON",
    Placeholder = "Paste exported config JSON here",
    Value = "",
    Callback = function(value)
        importJson = tostring(value or "")
    end
})

Tabs.Configs:Button({
    Title = "Import Config",
    Callback = function()
        local name, nameError = validateConfigName(selectedConfigName)
        if not name then
            notify("Configs", nameError)
            return
        end
        local parsed, data = pcall(function()
            return HttpService:JSONDecode(importJson)
        end)
        if not parsed then
            notify("Configs", "Invalid JSON: " .. tostring(data))
            return
        end
        local valid, validationError = validateConfig(data)
        if not valid then
            notify("Configs", validationError)
            return
        end
        local ok, err = ensureConfigStorage()
        if not ok then
            notify("Configs", err)
            return
        end
        local saved, saveError = pcall(function()
            writefile(configFolder .. "/" .. name .. ".json", HttpService:JSONEncode(data))
        end)
        if not saved then
            notify("Configs", "Could not import config: " .. tostring(saveError))
            return
        end
        notify("Configs", "Imported config: " .. name)
        refreshConfigDropdown()
    end
})

Tabs.Configs:Button({
    Title = "Export Config",
    Callback = function()
        local name, nameError = validateConfigName(selectedConfigName)
        if not name then
            notify("Configs", nameError)
            return
        end
        local data, err = readConfig(name)
        if not data then
            data = makeConfigSnapshot()
        end
        local encoded = HttpService:JSONEncode(data)
        local ok, storageError = ensureConfigStorage()
        if not ok then
            notify("Configs", storageError)
            return
        end
        local exported, exportError = pcall(writefile, configFolder .. "/" .. name .. ".export.json", encoded)
        if not exported then
            notify("Configs", "Could not export config file: " .. tostring(exportError))
            return
        end
        if type(setclipboard) == "function" then
            local copied, clipboardError = pcall(setclipboard, encoded)
            if copied then
                notify("Configs", "Exported JSON file and copied it to the clipboard.")
            else
                notify("Configs", "JSON saved to the export file; clipboard failed: " .. tostring(clipboardError))
            end
        else
            notify("Configs", "Exported JSON file: " .. name .. ".export.json")
        end
    end
})

Tabs.Configs:Button({
    Title = "Reset Config",
    Callback = function()
        local name, nameError = validateConfigName(selectedConfigName)
        if not name then
            notify("Configs", nameError)
            return
        end
        local ok, err = ensureConfigStorage()
        if not ok then
            notify("Configs", err)
            return
        end
        local path = configFolder .. "/" .. name .. ".json"
        if isfile(path) then
            local deleted, deleteError = pcall(delfile, path)
            if not deleted then
                notify("Configs", "Could not reset config: " .. tostring(deleteError))
                return
            end
        end
        if isfile(configAutoloadPath) and readfile(configAutoloadPath) == name then
            local cleared, clearError = pcall(delfile, configAutoloadPath)
            if not cleared then
                notify("Configs", "Config removed, but autoload could not be cleared: " .. tostring(clearError))
                return
            end
        end
        notify("Configs", "Removed saved config: " .. name)
        refreshConfigDropdown()
    end
})

task.spawn(function()
    local ok, err = ensureConfigStorage()
    if not ok then
        warn("[JOJOHUB Anime Dice] Config autoload unavailable: " .. tostring(err))
        return
    end
    if isfile(configAutoloadPath) then
        local name = readfile(configAutoloadPath)
        local validName = validateConfigName(name)
        if validName then
            local data, readError = readConfig(validName)
            if data then
                applyConfig(data)
                notify("Configs", "Autoloaded config: " .. validName)
            else
                warn("[JOJOHUB Anime Dice] Config autoload failed: " .. tostring(readError))
            end
        end
    end
end)

task.defer(refreshConfigDropdown)

task.spawn(function()
    while true do
        if Flags.AutoCollect then
            collectBalances()
            task.wait(4)
        else
            task.wait(0.5)
        end
    end
end)

task.spawn(function()
    while true do
        if Flags.AutoUpgrade then
            buyNextUpgrade()
            task.wait(2)
        else
            task.wait(0.5)
        end
    end
end)

task.spawn(function()
    while true do
        if Flags.AutoRollSpeed then
            buyNextRollSpeedUpgrade()
            task.wait(2)
        else
            task.wait(0.5)
        end
    end
end)

task.spawn(function()
    while true do
        if Flags.AutoRebirthStats then
            autoAllocateRebirthStat()
            task.wait(0.5)
        else
            task.wait(0.5)
        end
    end
end)

task.spawn(function()
    while true do
        if Flags.AutoLevelUnits then
            levelAffordableUnits()
            task.wait(2)
        else
            task.wait(0.5)
        end
    end
end)

task.spawn(function()
    while true do
        if Flags.AutoEquipBest then
            EquipBestRemote:FireServer()
            task.wait(15)
        else
            task.wait(0.5)
        end
    end
end)

task.spawn(function()
    while true do
        if Flags.AutoDice then
            equipBestOrBuyNextDice()
            task.wait(2)
        else
            task.wait(0.5)
        end
    end
end)

task.spawn(function()
    while true do
        if Flags.AutoDailyReward and isDailyRewardReady() then
            local claimed, err = claimDailyReward()
            if not claimed and err ~= "Daily reward claim is already pending." then
                warn("[JOJOHUB Anime Dice] Daily reward claim failed: " .. tostring(err))
            end
            task.wait(10)
        else
            task.wait(5)
        end
    end
end)

task.spawn(function()
    while true do
        if Flags.AutoQuestClaim then
            local ok, err = pcall(claimCompletedQuests)
            if not ok then
                warn("[JOJOHUB Anime Dice] Auto quest claim failed: " .. tostring(err))
            end
            task.wait(2)
        else
            task.wait(0.5)
        end
    end
end)

task.spawn(function()
    while true do
        if Flags.AutoGear then
            equipBestGear()
            task.wait(5)
        else
            task.wait(0.5)
        end
    end
end)

task.spawn(function()
    while true do
        if Flags.AutoRebirth then
            local nextRebirth = RebirthData.GetNext(DataController.Rebirth())
            local canAfford = nextRebirth
                and DataController.Money() >= math.max(nextRebirth.cost, rebirthMinMoney)
            if canAfford and not doRebirth() and not rebirthWarned then
                rebirthWarned = true
                notify("Auto Rebirth", "Could not find a rebirth remote. Use Debug Info in the Roll tab.")
            end
            task.wait(5)
        else
            task.wait(0.5)
        end
    end
end)
