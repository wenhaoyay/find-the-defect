local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")

local Release = require(ReplicatedStorage:WaitForChild("FindDefectReleaseConfig"))
local modules = script.Parent:WaitForChild("FindDefectModules")
local Config = require(modules:WaitForChild("ProductConfig"))
local ProductFactory = require(modules:WaitForChild("TeddyFactory"))
local AnomalyService = require(modules:WaitForChild("AnomalyService"))
local Presentation = require(ReplicatedStorage:WaitForChild("FindDefectPresentationConfig"))
local AnomalyConfig = require(ReplicatedStorage:WaitForChild("FindDefectAnomalyConfig"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("FindDefectUpgradeConfig"))
local Infrastructure = require(ReplicatedStorage:WaitForChild("FindDefectInfrastructureConfig"))
local FactoryConfig = require(ReplicatedStorage:WaitForChild("FindDefectFactoryConfig"))
local FirstShiftConfig = require(ReplicatedStorage:WaitForChild("FindDefectFirstShiftConfig"))
local Registry = require(ReplicatedStorage:WaitForChild("FindDefectProductRegistry"))
local Departments = require(ReplicatedStorage:WaitForChild("FindDefectDepartmentConfig"))
local LineProgression = require(modules:WaitForChild("LineProgression"))
local PlayerDataService = require(modules:WaitForChild("PlayerDataService"))
local Analytics = require(modules:WaitForChild("FindDefectAnalytics"))
local RateLimiter = require(modules:WaitForChild("RateLimiter"))

local root = workspace:WaitForChild("FindTheDefectStage0")
local lineProgression = LineProgression.new(root, UpgradeConfig)
local activeProducts = root:WaitForChild("ActiveProducts")
local rejectSystem = root:WaitForChild("RejectSystem")
local pusher = rejectSystem:WaitForChild("PusherBar")
local progressionEffects = root:WaitForChild("ProgressionEffects")
local unlockBurst = progressionEffects:WaitForChild("UnlockBurst"):WaitForChild("Burst")
local impactPart = progressionEffects:WaitForChild("ImpactBurst")
local impactBurst = impactPart:WaitForChild("Burst")
local referenceFolder = ReplicatedStorage:WaitForChild("FindDefectReferences")
local anomalyReferenceFolder = ReplicatedStorage:WaitForChild("FindDefectAnomalyReferences")
local pedestal = root:WaitForChild("RarestFindPedestal")
local pedestalAnchor = pedestal:WaitForChild("DisplayAnchor")
local pedestalDisplayed = pedestal:WaitForChild("DisplayedFind")
local pedestalLabel = pedestal:WaitForChild("TitleAnchor")
    :WaitForChild("RarestLabel")
    :WaitForChild("FindName")
local pedestalBurst = pedestalAnchor:WaitForChild("NewRarestBurst")

local state = ReplicatedStorage:WaitForChild("FindDefectState")
local rejectRequest = state:WaitForChild("RejectRequest")
local purchaseUpgrade = state:WaitForChild("PurchaseUpgrade")
local feedback = state:WaitForChild("Feedback")
local archiveRequest = state:WaitForChild("ArchiveRequest")
local archiveUpdate = state:WaitForChild("ArchiveUpdate")

local streak = state:WaitForChild("QualityStreak")
local caught = state:WaitForChild("Caught")
local missed = state:WaitForChild("Missed")
local falseRejects = state:WaitForChild("FalseRejects")
local credits = state:WaitForChild("Credits")
local lineRevenue = state:WaitForChild("LineRevenue")
local productValueLevel = state:WaitForChild("ProductValueLevel")
local beltSpeedLevel = state:WaitForChild("BeltSpeedLevel")
local unlockedProductCount = state:WaitForChild("UnlockedProductCount")
local duckUnlocked = state:WaitForChild("DuckUnlocked")
local carUnlocked = state:WaitForChild("CarUnlocked")
local rushActiveValue = state:WaitForChild("RushActive")
local rushPhase = state:WaitForChild("RushPhase")
local rushTimeLeft = state:WaitForChild("RushTimeLeft")
local currentBeltSpeed = state:WaitForChild("CurrentBeltSpeed")
local currentSpawnInterval = state:WaitForChild("CurrentSpawnInterval")
local currentValueMultiplier = state:WaitForChild("CurrentValueMultiplier")
local currentOperatingTier = state:WaitForChild("CurrentOperatingTier")
local inspectionRunwayLevel = state:WaitForChild("InspectionRunwayLevel")
local anomalyLuckLevel = state:WaitForChild("AnomalyLuckLevel")
local anomalyQualityLevel = state:WaitForChild("AnomalyQualityLevel")
local streakShieldLevel = state:WaitForChild("StreakShieldLevel")
local streakShieldReady = state:WaitForChild("StreakShieldReady")
local streakShieldProgress = state:WaitForChild("StreakShieldProgress")
local rushDurationLevel = state:WaitForChild("RushDurationLevel")
local rushPayLevel = state:WaitForChild("RushPayLevel")
local currentRunwayLength = state:WaitForChild("CurrentRunwayLength")
local currentAnomalyChance = state:WaitForChild("CurrentAnomalyChance")
local currentGlitchedShare = state:WaitForChild("CurrentGlitchedShare")
local currentRushPayMultiplier = state:WaitForChild("CurrentRushPayMultiplier")
local setOperatingTier = state:WaitForChild("SetOperatingTier")
local firstShiftActive = state:WaitForChild("FirstShiftActive")
local firstShiftRushActive = state:WaitForChild("FirstShiftRushActive")
local firstShiftTimeLeft = state:WaitForChild("FirstShiftTimeLeft")
local firstCatchBonusGranted = state:WaitForChild("FirstCatchBonusGranted")
local firstUpgradePromptShown = state:WaitForChild("FirstUpgradePromptShown")
local firstShiftRushStarted = state:WaitForChild("FirstShiftRushStarted")
local firstShiftRushCompleted = state:WaitForChild("FirstShiftRushCompleted")
local firstShiftCompletionBonusGranted = state:WaitForChild("FirstShiftCompletionBonusGranted")
local earlyGoldenGuaranteeSatisfied = state:WaitForChild("EarlyGoldenGuaranteeSatisfied")
local firstShiftMenuState = state:WaitForChild("FirstShiftMenuState")
local inspectionMode = state:WaitForChild("InspectionMode")
local researchLabPurchased = state:WaitForChild("ResearchLabPurchased")
local rejectGalleryPurchased = state:WaitForChild("RejectGalleryPurchased")
local factoryProjectsPurchased = state:WaitForChild("FactoryProjectsPurchased")
local productionTier = state:WaitForChild("ProductionTier")
local researchTier = state:WaitForChild("ResearchTier")
local householdPurchased = state:WaitForChild("HouseholdProductionPurchased")
local unlockedProducts = state:WaitForChild("UnlockedProducts")
local departmentUnlocked = state:WaitForChild("DepartmentUnlocked")
local departmentRevenue = state:WaitForChild("DepartmentRevenue")
local missingPartIntroduced = state:WaitForChild("MissingPartIntroduced")
local extraPartIntroduced = state:WaitForChild("ExtraPartIntroduced")
local factoryModeRequest = state:WaitForChild("FactoryModeRequest")
local factoryDiscoveries = state:WaitForChild("FactoryArchiveDiscoveries")
local factoryRarestProductKey = state:WaitForChild("FactoryRarestProductKey")
local factoryRarestAnomalyId = state:WaitForChild("FactoryRarestAnomalyId")
local factoryRarestFinder = state:WaitForChild("FactoryRarestFinder")
local dataLoaded = state:WaitForChild("DataLoaded")
local dataLoadFailed = state:WaitForChild("DataLoadFailed")
local activePlayerUserId = state:WaitForChild("ActivePlayerUserId")
local persistentStats = state:WaitForChild("PersistentStatistics")

PlayerDataService.Initialize(state)

local random = Random.new()
local anomalyService = AnomalyService.new(AnomalyConfig)
local productsById = {}
local spawnIndex = 0
local spawnElapsed = FirstShiftConfig.OpeningSpawnInterval
local pusherBusy = false
local nextRushAt
local rushEndsAt
local warningStarted = false
local firstShiftStartedAt
local firstCatchAt
local firstShiftRushDueAt
local firstShiftRushEndsAt
local firstShiftMenuOpen = false
local firstShiftMenuDelayStartedAt
local demonstrateUpgradeOnNextDefect = false
local factoryPausedAt
local priorityProductQueue = {}
local householdStartupQueue = {}
local householdBiasEndsAt = 0
local lastProductKey
local consecutiveProductCount = 0
local activePlayer
local gameplayReady = false

local function isFiniteNumber(value)
    return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function canPlayerAct(player)
    return gameplayReady and PlayerDataService.IsReady(player) and player == activePlayer
end

local firstShiftStats = {
    productsHandled = 0,
    defectsCaught = 0,
    creditsEarned = 0,
}

local rushStats = {
    productsHandled = 0,
    defectsCaught = 0,
    mistakes = 0,
    creditsEarned = 0,
}

local initialLighting = {
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
}

local initialFactoryLights = {}
for _, item in root.Factory:GetChildren() do
    if item.Name == "CeilingLight" and item:IsA("BasePart") then
        local pointLight = item:FindFirstChildOfClass("PointLight")
        initialFactoryLights[item] = {
            Color = item.Color,
            LightColor = pointLight and pointLight.Color,
            Brightness = pointLight and pointLight.Brightness,
        }
    end
end

-- The pusher's WHACK is spatial; semantic feedback audio is client-owned.
local soundAssignments = {
    ImpactSound = Presentation.Audio.SFX.Whack,
}
for soundName, settings in pairs(soundAssignments) do
    local sound = pusher:FindFirstChild(soundName)
    if sound and sound:IsA("Sound") then
        sound.SoundId = settings.Id
        sound.Volume = settings.Volume
    end
end

referenceFolder:ClearAllChildren()
for _, productKey in Config.ProductOrder do
    local reference = ProductFactory.Create("Reference", productKey, "Normal")
    reference.Name = productKey
    local hitbox = reference:FindFirstChild("InteractionHitbox")
    if hitbox then
        hitbox:Destroy()
    end
    reference:PivotTo(CFrame.identity)
    reference.Parent = referenceFolder
end

anomalyReferenceFolder:ClearAllChildren()
for _, anomalyId in AnomalyConfig.ArchiveRows do
    for _, productKey in AnomalyConfig.ProductOrder do
        local reference = ProductFactory.Create("ArchiveReference", productKey, "Normal", anomalyId)
        reference.Name = AnomalyConfig.GetDiscoveryKey(productKey, anomalyId)
        local hitbox = reference:FindFirstChild("InteractionHitbox")
        if hitbox then
            hitbox:Destroy()
        end
        reference:PivotTo(CFrame.identity)
        reference.Parent = anomalyReferenceFolder
    end
end

archiveRequest.OnServerInvoke = function(player)
    if not canPlayerAct(player) then
        return {Discovered = {}, Count = 0, Total = AnomalyConfig.ArchiveSize}
    end
    return anomalyService:GetSnapshot(player)
end

local function resetSessionValues()
    gameplayReady = false
    dataLoaded.Value = false
    dataLoadFailed.Value = ""
    activePlayerUserId.Value = 0
    streak.Value = 0
    caught.Value = 0
    missed.Value = 0
    falseRejects.Value = 0
    credits.Value = 0
    lineRevenue.Value = 0
    productValueLevel.Value = 1
    beltSpeedLevel.Value = 1
    currentOperatingTier.Value = 1
    inspectionRunwayLevel.Value = 1
    anomalyLuckLevel.Value = 1
    anomalyQualityLevel.Value = 1
    streakShieldLevel.Value = 0
    streakShieldReady.Value = false
    streakShieldProgress.Value = 0
    rushDurationLevel.Value = 1
    rushPayLevel.Value = 1
    table.clear(priorityProductQueue)
    table.clear(householdStartupQueue)
    householdBiasEndsAt = 0
    lastProductKey = nil
    consecutiveProductCount = 0
    local debugAllProducts = RunService:IsStudio() and Registry.DebugProductUnlockAll
    local debugAllDepartments = RunService:IsStudio() and Registry.DebugDepartmentUnlock
    for _, productId in ipairs(Registry.ProductOrder) do
        unlockedProducts[productId].Value = debugAllProducts or productId == "TeddyBear"
    end
    for _, departmentId in ipairs(Departments.Order) do
        departmentUnlocked[departmentId].Value = debugAllDepartments or Departments.Definitions[departmentId].DefaultUnlocked
        departmentRevenue[departmentId].Value = 0
    end
    unlockedProductCount.Value = debugAllProducts and #Registry.ProductOrder or 1
    duckUnlocked.Value = false
    carUnlocked.Value = false
    householdPurchased.Value = false
    missingPartIntroduced.Value = false
    extraPartIntroduced.Value = false
    rushActiveValue.Value = false
    rushPhase.Value = "Normal"
    rushTimeLeft.Value = 0
    firstShiftActive.Value = true
    firstShiftRushActive.Value = false
    firstShiftTimeLeft.Value = 0
    firstCatchBonusGranted.Value = false
    firstUpgradePromptShown.Value = false
    firstShiftRushStarted.Value = false
    firstShiftRushCompleted.Value = false
    firstShiftCompletionBonusGranted.Value = false
    earlyGoldenGuaranteeSatisfied.Value = false
    inspectionMode.Value = true
    productionTier.Value = 1
    researchTier.Value = 0
    researchLabPurchased.Value = false
    rejectGalleryPurchased.Value = false
    factoryProjectsPurchased.Value = 0
    factoryRarestProductKey.Value = ""
    factoryRarestAnomalyId.Value = ""
    factoryRarestFinder.Value = ""
    for _, discovery in ipairs(factoryDiscoveries:GetChildren()) do
        if discovery:IsA("BoolValue") then discovery.Value = false end
    end
    for _, statistic in ipairs(persistentStats:GetChildren()) do
        if statistic:IsA("IntValue") then statistic.Value = 0 end
    end
end

local function sendFeedback(title, detail, tone, duration, reward, extras)
    local payload = {
        title = title,
        detail = detail,
        tone = tone,
        duration = duration or 1.6,
        reward = reward,
    }
    if extras then
        for key, value in pairs(extras) do
            payload[key] = value
        end
    end
    feedback:FireAllClients(payload)
end

local function sendFeedbackTo(player, title, detail, tone, duration, reward, extras)
    local payload = {
        title = title,
        detail = detail,
        tone = tone,
        duration = duration or 1.6,
        reward = reward,
    }
    if extras then
        for key, value in pairs(extras) do
            payload[key] = value
        end
    end
    feedback:FireClient(player, payload)
end

local function markFunnel(player, flag, eventName, fields)
    if not player or PlayerDataService.GetFunnelFlag(player, flag) then return end
    PlayerDataService.SetFunnelFlag(player, flag)
    Analytics.Log(player, eventName, 1, fields)
end

local function recordProductHandled(defectCaught)
    local player = activePlayer
    if not player then return end
    markFunnel(player, "FirstProductHandled", "FirstProductHandled")
    PlayerDataService.IncrementStat(player, "TotalProductsHandled", 1)
    if defectCaught then
        markFunnel(player, "FirstDefectCaught", "FirstDefectCaught")
        PlayerDataService.IncrementStat(player, "TotalDefectsCaught", 1)
    end
end

local function safeAwardAmount(amount)
    if not isFiniteNumber(amount) then
        warn("[Economy] Rejected non-finite reward.")
        return 0
    end
    return math.clamp(math.floor(amount + 0.5), 0, 9e15)
end

local function updatePedestal(productKey, anomalyId, playerName, quiet)
    pedestalDisplayed:ClearAllChildren()

    local display = ProductFactory.Create("Pedestal", productKey, "Normal", anomalyId)
    display.Name = "RarestDisplay"
    local hitbox = display:FindFirstChild("InteractionHitbox")
    if hitbox then
        hitbox:Destroy()
    end
    display:ScaleTo(0.52)
    display.Parent = pedestalDisplayed
    display:PivotTo(CFrame.new(pedestalAnchor.Position))

    local boxCFrame, boxSize = display:GetBoundingBox()
    local verticalAdjustment = pedestalAnchor.Position.Y - (boxCFrame.Position.Y - boxSize.Y * 0.5)
    display:PivotTo(display:GetPivot() + Vector3.new(0, verticalAdjustment, 0))

    pedestalLabel.Visible = true
    pedestalLabel.Text = AnomalyConfig.GetDisplayName(productKey, anomalyId)
        .. "\nFOUND BY "
        .. string.upper(playerName)
    local anomaly = AnomalyConfig.Anomalies[anomalyId]
    pedestalLabel.TextColor3 = anomaly.SecondaryColor
    pedestalBurst.Color = ColorSequence.new(anomaly.PrimaryColor, anomaly.SecondaryColor)
    if not quiet then pedestalBurst:Emit(anomalyId == "Glitched" and 80 or 55) end
end

local function flashAndBurst(model, color)
    if not model or not model.Parent then
        return
    end

    local highlight = Instance.new("Highlight")
    highlight.Name = "ResultFlash"
    highlight.FillColor = color
    highlight.FillTransparency = 0.22
    highlight.OutlineColor = Color3.new(1, 1, 1)
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Adornee = model.PrimaryPart or model
    highlight.Parent = model

    impactPart.CFrame = model:GetPivot()
    impactBurst.Color = ColorSequence.new(color)
    impactBurst:Emit(20)

    task.delay(0.28, function()
        if highlight.Parent then
            highlight:Destroy()
        end
    end)
end

local function playPreparedSound(soundName)
    local sound = pusher:FindFirstChild(soundName)
    if sound and sound:IsA("Sound") and sound.SoundId ~= "" then
        sound:Play()
    end
end

local function getValueMultiplier()
    return UpgradeConfig.Upgrades.ProductValue.Levels[productValueLevel.Value].Multiplier
end

local function getBaseBeltSettings()
    return UpgradeConfig.Upgrades.BeltMotor.Levels[currentOperatingTier.Value]
end

local function getRushPayMultiplier()
    return UpgradeConfig.Upgrades.RushPay.Levels[rushPayLevel.Value].Multiplier
end

local function getInspectionBounds()
    return lineProgression:GetInspectionBounds(inspectionRunwayLevel.Value)
end

local function getSpawnX()
    return lineProgression:GetSpawnX(inspectionRunwayLevel.Value)
end

local function getAnomalySettings()
    local luck = UpgradeConfig.Upgrades.AnomalyLuck.Levels[anomalyLuckLevel.Value].Multiplier
    local quality = UpgradeConfig.Upgrades.AnomalyQuality.Levels[anomalyQualityLevel.Value].GlitchedShare
    return luck, quality, AnomalyConfig.GetQualityWeights(quality)
end

local function getActiveSpeed()
    local speed = getBaseBeltSettings().Speed
    if firstShiftRushActive.Value then
        speed *= FirstShiftConfig.Rush.SpeedMultiplier
    elseif rushActiveValue.Value then
        speed *= Config.Rush.SpeedMultiplier
    end
    return speed
end

local function getActiveSpawnInterval()
    local interval = getBaseBeltSettings().SpawnInterval
    if firstShiftRushActive.Value then
        interval *= FirstShiftConfig.Rush.SpawnIntervalMultiplier
    elseif firstShiftActive.Value then
        interval = math.min(interval, FirstShiftConfig.OpeningSpawnInterval)
    elseif rushActiveValue.Value then
        interval *= Config.Rush.SpawnIntervalMultiplier
    end
    return interval
end

local function getActiveEarningsMultiplier()
    if firstShiftRushActive.Value then
        return FirstShiftConfig.Rush.EarningsMultiplier
    elseif rushActiveValue.Value then
        return getRushPayMultiplier()
    end
    return 1
end

local function updateReplicatedMultipliers()
    local luck, quality = getAnomalySettings()
    currentValueMultiplier.Value = getValueMultiplier()
    currentBeltSpeed.Value = getActiveSpeed()
    currentSpawnInterval.Value = getActiveSpawnInterval()
    currentRunwayLength.Value = UpgradeConfig.Upgrades.InspectionRunway.Levels[inspectionRunwayLevel.Value].Length
    currentAnomalyChance.Value = AnomalyConfig.BaseCombinedChance * luck
    currentGlitchedShare.Value = quality
    currentRushPayMultiplier.Value = getRushPayMultiplier()
end

local function setRushVisuals(active)
    if active then
        -- Warm accents add urgency without washing out product colours.
        Lighting.Ambient = Color3.fromRGB(125, 92, 72)
        Lighting.OutdoorAmbient = Color3.fromRGB(105, 80, 70)
        Lighting.Brightness = 3
        Lighting.ClockTime = 17
        for part in pairs(initialFactoryLights) do
            if part.Parent then
                part.Color = Color3.fromRGB(255, 178, 82)
                local light = part:FindFirstChildOfClass("PointLight")
                if light then
                    light.Color = Color3.fromRGB(255, 188, 105)
                    light.Brightness = 2.35
                end
            end
        end
    else
        Lighting.Ambient = initialLighting.Ambient
        Lighting.OutdoorAmbient = initialLighting.OutdoorAmbient
        Lighting.Brightness = initialLighting.Brightness
        Lighting.ClockTime = initialLighting.ClockTime
        for part, values in pairs(initialFactoryLights) do
            if part.Parent then
                part.Color = values.Color
                local light = part:FindFirstChildOfClass("PointLight")
                if light then
                    light.Color = values.LightColor
                    light.Brightness = values.Brightness
                end
            end
        end
    end
end

local function pulseRushWarning(now)
    local pulse = 0.5 + 0.5 * math.sin(now * 8)
    for part, values in pairs(initialFactoryLights) do
        if part.Parent then
            part.Color = Color3.fromRGB(235, math.floor(175 + 35 * pulse), 105)
            local light = part:FindFirstChildOfClass("PointLight")
            if light then
                light.Color = part.Color
                light.Brightness = (values.Brightness or 1.5) + 0.55 * pulse
            end
        end
    end
end

local function celebrateUnlock(productName, productKey)
    unlockBurst:Emit(110)
    playPreparedSound("UnlockSound")
    sendFeedback(
        "NEW PRODUCT UNLOCKED!",
        string.upper(productName),
        "unlock",
        2,
        nil,
        {unlockProductKey = productKey}
    )
end

local function updateUnlockedCount()
    local count = 0
    for _, productId in ipairs(Registry.ProductOrder) do
        local value = unlockedProducts:FindFirstChild(productId)
        if value and value.Value then count += 1 end
    end
    unlockedProductCount.Value = count
    duckUnlocked.Value = unlockedProducts.RubberDuck.Value
    carUnlocked.Value = unlockedProducts.ToyCar.Value
end

local function unlockProduct(productId, queueNormal)
    local value = unlockedProducts:FindFirstChild(productId)
    local product = Registry.Products[productId]
    if not value or not product or value.Value then return false end
    value.Value = true
    updateUnlockedCount()
    if queueNormal then table.insert(priorityProductQueue, {Product = productId, Defect = "Normal", SkipAnomaly = true}) end
    celebrateUnlock(product.DisplayName, productId)
    if activePlayer then
        Analytics.Log(activePlayer, "ProductUnlocked", 1, {ProductId = productId, Department = product.DepartmentId})
        PlayerDataService.MarkDirty("ProductUnlocked:" .. productId, true)
    end
    return true
end

local function checkProductUnlocks()
    for _, productId in ipairs(Registry.ProductOrder) do
        local product = Registry.Products[productId]
        local departmentValue = departmentUnlocked:FindFirstChild(product.DepartmentId)
        local revenueValue = departmentRevenue:FindFirstChild(product.DepartmentId)
        if departmentValue and departmentValue.Value and revenueValue and revenueValue.Value >= product.UnlockRevenue then
            unlockProduct(productId, true)
        end
    end
end

householdPurchased:GetPropertyChangedSignal("Value"):Connect(function()
    if not dataLoaded.Value then return end
    if householdPurchased.Value and departmentUnlocked.Household.Value and unlockedProducts.Mug.Value then return end
    if not householdPurchased.Value then
        departmentUnlocked.Household.Value = false
        return
    end
    householdBiasEndsAt = workspace:GetServerTimeNow() + 60
    task.delay(2.4, function()
        if not householdPurchased.Value then return end
        departmentUnlocked.Household.Value = true
        if activePlayer then
            Analytics.Log(activePlayer, "DepartmentUnlocked", 1, {Department = "Household"})
            PlayerDataService.MarkDirty("DepartmentUnlocked:Household", true)
        end
        unlockProduct("Mug", false)
        householdStartupQueue = {
            {Product = "Mug", Defect = "Normal", SkipAnomaly = true},
            {Product = "Mug", Defect = "Normal", SkipAnomaly = true},
            {Product = "Mug", Defect = "MissingPart", SkipAnomaly = true, Teaching = "MissingPart"},
            {Product = "Mug", Defect = "Normal", SkipAnomaly = true},
            {Product = "Mug", Defect = "ExtraPart", SkipAnomaly = true, Teaching = "ExtraPart"},
        }
        root:SetAttribute("Stage5AHouseholdStartupQueued", true)
    end)
end)

local function announceStreakThreshold(oldStreak, newStreak)
    local oldMultiplier = Config.GetStreakMultiplier(oldStreak)
    local newMultiplier = Config.GetStreakMultiplier(newStreak)
    if newMultiplier > oldMultiplier then
        task.delay(0.35, function()
            sendFeedback(
                tostring(newStreak) .. " STREAK!",
                "x" .. tostring(newMultiplier) .. " PAY",
                "streak",
                1.8,
                nil,
                {milestone = newStreak}
            )
        end)
    end
end

local function increaseStreak()
    local oldStreak = streak.Value
    streak.Value += 1
    announceStreakThreshold(oldStreak, streak.Value)

    if streakShieldLevel.Value > 0 and not streakShieldReady.Value then
        local recharge = UpgradeConfig.Upgrades.StreakShield.Levels[streakShieldLevel.Value + 1].Recharge
        streakShieldProgress.Value = math.min(recharge, streakShieldProgress.Value + 1)
        if streakShieldProgress.Value >= recharge then
            streakShieldReady.Value = true
            sendFeedback("QUALITY SHIELD READY", "Your next mistake will preserve the streak.", "streak", 1.8, nil, {feedbackKind = "ShieldReady"})
        end
    end
end

local function breakStreak()
    if streakShieldLevel.Value > 0 and streakShieldReady.Value then
        streakShieldReady.Value = false
        streakShieldProgress.Value = 0
        sendFeedback("QUALITY SHIELD!", "STREAK SAVED", "streak", 1.8, nil, {feedbackKind = "ShieldConsumed"})
        return false, true
    end
    local wasActive = streak.Value > 0
    streak.Value = 0
    return wasActive, false
end

local function addDepartmentRevenue(record, amount)
    local product = Registry.Products[record.productKey]
    local revenue = product and departmentRevenue:FindFirstChild(product.DepartmentId)
    if revenue then revenue.Value = math.clamp(revenue.Value + math.max(0, amount), 0, 9e15) end
end

local function awardCredits(record, exactAmount)
    local amount
    if exactAmount then
        amount = exactAmount
    else
        local defect = Config.Defects[record.defect]
        local product = Config.Products[record.productKey]
        local rawAmount = defect.BaseReward
            * product.Multiplier
            * getValueMultiplier()
            * Config.GetStreakMultiplier(streak.Value)
            * getActiveEarningsMultiplier()
        amount = math.max(1, safeAwardAmount(rawAmount))
    end
    amount = safeAwardAmount(amount)

    credits.Value = math.clamp(credits.Value + amount, 0, 9e15)
    lineRevenue.Value = math.clamp(lineRevenue.Value + amount, 0, 9e15)
    if activePlayer then PlayerDataService.IncrementStat(activePlayer, "TotalCreditsEarned", amount) end
    addDepartmentRevenue(record, amount)
    if rushActiveValue.Value then
        rushStats.creditsEarned += amount
    elseif firstShiftRushActive.Value then
        firstShiftStats.creditsEarned += amount
    end
    checkProductUnlocks()
    return amount
end

local function awardAnomalyCredits(record)
    local anomaly = AnomalyConfig.Anomalies[record.anomalyId]
    local rawAmount = anomaly.Reward * getValueMultiplier() * getActiveEarningsMultiplier()
    local amount = math.max(1, safeAwardAmount(rawAmount))

    credits.Value = math.clamp(credits.Value + amount, 0, 9e15)
    lineRevenue.Value = math.clamp(lineRevenue.Value + amount, 0, 9e15)
    if activePlayer then PlayerDataService.IncrementStat(activePlayer, "TotalCreditsEarned", amount) end
    addDepartmentRevenue(record, amount)
    if rushActiveValue.Value then
        rushStats.creditsEarned += amount
    elseif firstShiftRushActive.Value then
        firstShiftStats.creditsEarned += amount
    end
    checkProductUnlocks()
    return amount
end

local function handleAnomalyDiscovery(player, record, reward)
    local result = anomalyService:Discover(player, record.productKey, record.anomalyId)
    archiveUpdate:FireClient(player, result.Snapshot)
    local productDefinition = Registry.Products[record.productKey]
    if record.anomalyId == "Golden" then
        PlayerDataService.IncrementStat(player, "TotalGoldenCaught", 1)
        Analytics.Log(player, "GoldenCaught", 1, {ProductId = record.productKey, Department = productDefinition.DepartmentId})
        PlayerDataService.SetOnboardingFlag(player, "EarlyGoldenGuaranteeSatisfied", true, true)
    elseif record.anomalyId == "Glitched" then
        PlayerDataService.IncrementStat(player, "TotalGlitchedCaught", 1)
        Analytics.Log(player, "GlitchedCaught", 1, {ProductId = record.productKey, Department = productDefinition.DepartmentId})
    end
    if result.IsNew then
        Analytics.Log(player, "NewArchiveDiscovery", result.Count, {ProductId = record.productKey, Department = productDefinition.DepartmentId, Anomaly = record.anomalyId})
        PlayerDataService.MarkDirty("ArchiveDiscovery:" .. result.Key, true)
    end

    local discoveryValue = factoryDiscoveries:FindFirstChild(
        AnomalyConfig.GetDiscoveryKey(record.productKey, record.anomalyId)
    )
    if discoveryValue then discoveryValue.Value = true end

    if result.PedestalUpdated then
        factoryRarestProductKey.Value = record.productKey
        factoryRarestAnomalyId.Value = record.anomalyId
        factoryRarestFinder.Value = player.DisplayName
        updatePedestal(record.productKey, record.anomalyId, player.DisplayName)
    end

    local anomaly = AnomalyConfig.Anomalies[record.anomalyId]
    local displayName = AnomalyConfig.GetDisplayName(record.productKey, record.anomalyId)
    sendFeedbackTo(
        player,
        result.IsNew and "NEW DISCOVERY!" or (string.upper(anomaly.DisplayName) .. " DEFECT!"),
        displayName,
        record.anomalyId == "Glitched" and "glitched" or "golden",
        result.IsNew and 2 or 1.65,
        reward,
        {
            feedbackKind = "AnomalyCatch",
            anomalyId = record.anomalyId,
            productKey = record.productKey,
            anomalyDisplay = displayName,
            isNewDiscovery = result.IsNew,
            archiveCount = result.Count,
            archiveTotal = result.Total,
            pedestalUpdated = result.PedestalUpdated,
        }
    )

    if result.IsNew and anomaly.ServerAnnouncement then
        sendFeedback(
            "RARE DISCOVERY",
            string.format(
                "%s found a %s!\nBase rarity: %s",
                player.DisplayName,
                displayName,
                anomaly.BaseOddsLabel
            ),
            "serverRare",
            4,
            nil,
            {
                feedbackKind = "ServerRareAnnouncement",
                anomalyId = record.anomalyId,
                finderUserId = player.UserId,
                finderName = player.DisplayName,
                anomalyDisplay = displayName,
                oddsLabel = anomaly.BaseOddsLabel,
            }
        )
    end
end

local function markOpeningSequenceHandled(record)
    -- The scripted opening flows directly into normal generation.
end

local function animatePusher()
    if pusherBusy then
        return
    end
    pusherBusy = true
    task.spawn(function()
        local restCFrame = pusher:GetAttribute("RestCFrame")
        local strikeCFrame = restCFrame * CFrame.new(0, 0, -4.5)
        local outTween = TweenService:Create(
            pusher,
            TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {CFrame = strikeCFrame}
        )
        outTween:Play()
        outTween.Completed:Wait()
        local backTween = TweenService:Create(
            pusher,
            TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {CFrame = restCFrame}
        )
        backTween:Play()
        backTween.Completed:Wait()
        pusherBusy = false
    end)
end

local function releaseIntoRejectBin(record)
    local model = record.model
    local primary = model.PrimaryPart
    if not primary then
        return
    end

    for _, descendant in model:GetDescendants() do
        if descendant:IsA("BasePart") then
            descendant.Anchored = false
            if descendant.Name == "InteractionHitbox" then
                descendant.CanCollide = false
                descendant.CanQuery = false
            else
                descendant.CanCollide = true
            end
        end
    end

    primary:SetNetworkOwner(nil)
    primary:ApplyImpulse(primary.AssemblyMass * Vector3.new(0, 11, -38))
    primary.AssemblyAngularVelocity = Vector3.new(5, -4, 8)

    task.delay(4.5, function()
        productsById[record.id] = nil
        if model.Parent then
            model:Destroy()
        end
    end)
end

local function rejectProduct(player, record)
    record.processed = true
    record.state = "Rejected"
    record.model:SetAttribute("LifecycleState", "Rejected")

    local defect = Config.Defects[record.defect]
    local product = Config.Products[record.productKey]
    local anomaly = record.anomalyId and AnomalyConfig.Anomalies[record.anomalyId] or nil
    local validReject = defect.Defective or anomaly ~= nil
    recordProductHandled(validReject)

    animatePusher()
    playPreparedSound("ImpactSound")
    flashAndBurst(
        record.model,
        anomaly and anomaly.GlowColor
            or (defect.Defective and Presentation.Highlight.CorrectColor or Presentation.Highlight.IncorrectColor)
    )
    if anomaly then
        impactBurst:Emit(anomaly.BurstCount)
    end

    if validReject then
        caught.Value += 1
        increaseStreak()
        if rushActiveValue.Value then
            rushStats.productsHandled += 1
            rushStats.defectsCaught += 1
        elseif firstShiftRushActive.Value then
            firstShiftStats.productsHandled += 1
            firstShiftStats.defectsCaught += 1
        end

        if anomaly then
            local reward = awardAnomalyCredits(record)
            handleAnomalyDiscovery(player, record, reward)
        else
            local isFirstCatch = not firstCatchBonusGranted.Value
            local reward = awardCredits(record, isFirstCatch and FirstShiftConfig.FirstCatchReward or nil)
            local defectDisplay = Config.GetDefectDisplayName(record.defect, record.productKey)

            if isFirstCatch then
                firstCatchBonusGranted.Value = true
                firstCatchAt = workspace:GetServerTimeNow()
                sendFeedbackTo(
                    player,
                    "FIRST CATCH!",
                    "+" .. Release.FormatCredits(FirstShiftConfig.FirstCatchReward),
                    "good",
                    1.45,
                    reward,
                    {
                        productIdentifier = record.id,
                        feedbackKind = "FirstCatch",
                        productName = product.DisplayName,
                        defectDisplay = defectDisplay,
                        pulseUnlockProgress = true,
                    }
                )
                task.delay(0.75, function()
                    if player.Parent and productValueLevel.Value == 1 and not firstUpgradePromptShown.Value then
                        firstUpgradePromptShown.Value = true
                        sendFeedbackTo(
                            player,
                            "FIRST UPGRADE READY",
                            "PRODUCT VALUE II  •  $75",
                            "upgrade",
                            1.7,
                            nil,
                            {
                                feedbackKind = "FirstUpgradeReady",
                                upgradeName = "ProductValue",
                            }
                        )
                    end
                end)
            else
                local upgradeInAction = demonstrateUpgradeOnNextDefect
                if upgradeInAction then
                    demonstrateUpgradeOnNextDefect = false
                end
                sendFeedbackTo(
                    player,
                    upgradeInAction and "UPGRADE IN ACTION" or "✓ DEFECT CAUGHT",
                    defectDisplay,
                    "good",
                    upgradeInAction and 1.7 or 1.2,
                    reward,
                    {
                        productIdentifier = record.id,
                        feedbackKind = "CorrectReject",
                        productName = product.DisplayName,
                        defectDisplay = defectDisplay,
                        upgradeInAction = upgradeInAction,
                        productValueMultiplier = getValueMultiplier(),
                    }
                )
            end
        end
    else
        falseRejects.Value += 1
        local streakWasBroken = breakStreak()
        if rushActiveValue.Value then
            rushStats.mistakes += 1
        end
        local detail = "That " .. product.DisplayName .. " was perfectly fine 😭"
        if streakWasBroken then
            detail ..= "\nSTREAK BROKEN"
        end
        sendFeedback(
            "FALSE REJECT",
            detail,
            "bad",
            2.2,
            nil,
            {
                productIdentifier = record.id,
                feedbackKind = "FalseReject",
                productName = product.DisplayName,
                streakBroken = streakWasBroken,
            }
        )
    end

    markOpeningSequenceHandled(record)
    releaseIntoRejectBin(record)
end

local function missProduct(record)
    recordProductHandled(false)
    record.processed = true
    record.state = "Missed"
    record.model:SetAttribute("LifecycleState", "Missed")

    missed.Value += 1
    local streakWasBroken = breakStreak()
    if rushActiveValue.Value then
        rushStats.mistakes += 1
    end

    local detail
    local defectDisplay
    if record.anomalyId then
        defectDisplay = AnomalyConfig.GetDisplayName(record.productKey, record.anomalyId)
        detail = defectDisplay .. " escaped inspection."
    else
        defectDisplay = Config.GetDefectDisplayName(record.defect, record.productKey)
        detail = defectDisplay .. " escaped inspection."
    end
    if streakWasBroken then
        detail ..= "\nSTREAK BROKEN"
    end
    sendFeedback(
        "DEFECT MISSED",
        detail,
        "bad",
        2.2,
        nil,
        {
            feedbackKind = "MissedDefect",
            productName = Config.Products[record.productKey].DisplayName,
            defectDisplay = defectDisplay,
            streakBroken = streakWasBroken,
        }
    )
    markOpeningSequenceHandled(record)
end

local function passNormalProduct(record)
    recordProductHandled(false)
    record.processed = true
    record.state = "Passed"
    record.model:SetAttribute("LifecycleState", "Passed")

    increaseStreak()
    if rushActiveValue.Value then
        rushStats.productsHandled += 1
    elseif firstShiftRushActive.Value then
        firstShiftStats.productsHandled += 1
    end
    local reward = awardCredits(record)
    sendFeedback(
        "",
        "",
        "rewardOnly",
        0.9,
        reward,
        {
            feedbackKind = "NormalPass",
            productName = Config.Products[record.productKey].DisplayName,
        }
    )
    markOpeningSequenceHandled(record)
end

local function getEligibleProducts()
    local result = {}
    for _, productId in ipairs(Registry.ProductOrder) do
        local product = Registry.Products[productId]
        if unlockedProducts[productId].Value and departmentUnlocked[product.DepartmentId].Value then
            table.insert(result, productId)
            if product.DepartmentId == "Household" and workspace:GetServerTimeNow() < householdBiasEndsAt then
                table.insert(result, productId)
                table.insert(result, productId)
            end
        end
    end
    return result
end

local function chooseSpawnPlan()
    local onboarding = Config.OnboardingSequence[spawnIndex]
    if onboarding then return {Product = onboarding.Product, Defect = onboarding.Defect, SkipAnomaly = true} end
    if #householdStartupQueue > 0 then return table.remove(householdStartupQueue, 1) end
    if #priorityProductQueue > 0 then return table.remove(priorityProductQueue, 1) end
    local eligible = getEligibleProducts()
    local productId = Config.RollProduct(spawnIndex, eligible, random, lastProductKey, consecutiveProductCount)
    if RunService:IsStudio() then
        local forced = root:GetAttribute("DebugForceProductId")
        if typeof(forced) ~= "string" or forced == "" then forced = Registry.DebugForceProductId end
        if typeof(forced) == "string" and Registry.Products[forced] then productId = forced end
    end
    local accelerated = rushActiveValue.Value or firstShiftRushActive.Value
    local defectName = Config.RollDefect(spawnIndex, productId, random, accelerated, householdPurchased.Value)
    if RunService:IsStudio() then
        local forcedDefect = root:GetAttribute("DebugForceDefectType")
        if typeof(forcedDefect) ~= "string" or forcedDefect == "" then forcedDefect = Registry.DebugForceDefectType end
        if typeof(forcedDefect) == "string" and Config.Defects[forcedDefect] then defectName = forcedDefect end
    end
    return {Product = productId, Defect = defectName}
end

local function spawnProduct()
    spawnIndex += 1
    local plan = chooseSpawnPlan()
    local productKey = plan.Product
    local defectName = plan.Defect
    if productKey == lastProductKey then consecutiveProductCount += 1 else lastProductKey = productKey; consecutiveProductCount = 1 end

    local anomalyId
    local wasGuaranteed = false
    if spawnIndex > #Config.OnboardingSequence and not plan.SkipAnomaly and Registry.Products[productKey].AnomalyCompatible then
        local luck, _, qualityWeights = getAnomalySettings()
        anomalyId, wasGuaranteed = anomalyService:Roll(random, luck, qualityWeights)
        local forcedAnomaly = RunService:IsStudio() and root:GetAttribute("DebugForceNextAnomaly")
        if typeof(forcedAnomaly) == "string" and AnomalyConfig.Anomalies[forcedAnomaly] then
            anomalyId = forcedAnomaly
            root:SetAttribute("DebugForceNextAnomaly", nil)
            wasGuaranteed = true
        elseif RunService:IsStudio() and AnomalyConfig.DebugForceNextAnomaly ~= "" then
            anomalyId = AnomalyConfig.DebugForceNextAnomaly
            AnomalyConfig.DebugForceNextAnomaly = ""
            wasGuaranteed = true
        end
        earlyGoldenGuaranteeSatisfied.Value = anomalyService.GoldenEncountered
        if activePlayer and anomalyService.GoldenEncountered
            and not PlayerDataService.GetOnboardingFlag(activePlayer, "EarlyGoldenGuaranteeSatisfied") then
            PlayerDataService.SetOnboardingFlag(activePlayer, "EarlyGoldenGuaranteeSatisfied", true, true)
        end
    end
    if anomalyId then defectName = "Normal" end

    local id = tostring(spawnIndex)
    local model = ProductFactory.Create(id, productKey, defectName, anomalyId)
    model:SetAttribute("AnomalyGuaranteed", wasGuaranteed)
    model.Parent = activeProducts

    local y = Config.Conveyor.BeltSurfaceY + model:GetAttribute("FootOffset")
    local spawnX = getSpawnX()
    if spawnIndex <= #Config.OnboardingSequence then
        local inspectionMinX = getInspectionBounds()
        spawnX = math.max(spawnX, inspectionMinX - FirstShiftConfig.EntryLeadDistance)
    end
    model:PivotTo(CFrame.new(spawnX, y, 0))

    productsById[id] = {
        id = id,
        model = model,
        productKey = productKey,
        defect = defectName,
        anomalyId = anomalyId,
        anomalyGuaranteed = wasGuaranteed,
        teaching = plan.Teaching,
        spawnIndex = spawnIndex,
        x = spawnX,
        y = y,
        state = "Entering",
        processed = false,
        onboardingPromptShown = false,
    }
end

local function requestFirstShiftRush(now)
    if not firstShiftActive.Value or firstShiftRushStarted.Value or firstShiftRushCompleted.Value then
        return
    end
    local earliest = firstShiftStartedAt + FirstShiftConfig.Rush.EarliestStartDelay
    firstShiftRushDueAt = math.max(now, earliest)
end

local function startFirstShiftRush(now)
    if firstShiftRushStarted.Value or firstShiftRushCompleted.Value then
        return
    end
    firstShiftRushStarted.Value = true
    firstShiftRushActive.Value = true
    firstShiftRushEndsAt = now + FirstShiftConfig.Rush.Duration
    firstShiftTimeLeft.Value = FirstShiftConfig.Rush.Duration
    firstShiftMenuDelayStartedAt = nil
    firstShiftStats = {
        productsHandled = 0,
        defectsCaught = 0,
        creditsEarned = 0,
    }
    updateReplicatedMultipliers()
    playPreparedSound("RushStartSound")
    sendFeedback(
        "FIRST SHIFT RUSH",
        string.format("%d SECONDS  •  x%d CREDITS", FirstShiftConfig.Rush.Duration, FirstShiftConfig.Rush.EarningsMultiplier),
        "rush",
        1.7,
        nil,
        {feedbackKind = "FirstShiftRushStart"}
    )
end

local function endFirstShiftRush(now)
    firstShiftRushActive.Value = false
    firstShiftTimeLeft.Value = 0
    firstShiftRushEndsAt = nil
    firstShiftRushCompleted.Value = true
    firstShiftActive.Value = false
    if activePlayer then PlayerDataService.SetOnboardingFlag(activePlayer, "HasCompletedFirstShift", true, true) end

    local completionBonus = 0
    if not firstShiftCompletionBonusGranted.Value then
        firstShiftCompletionBonusGranted.Value = true
        completionBonus = FirstShiftConfig.CompletionBonus
        credits.Value = math.clamp(credits.Value + completionBonus, 0, 9e15)
        lineRevenue.Value = math.clamp(lineRevenue.Value + completionBonus, 0, 9e15)
        if activePlayer then PlayerDataService.IncrementStat(activePlayer, "TotalCreditsEarned", completionBonus) end
        checkProductUnlocks()
    end

    nextRushAt = now + Config.Rush.FirstDelay
    if activePlayer then
        Analytics.Log(activePlayer, "FirstShiftCompleted", firstShiftStats.productsHandled, {
            DefectsCaught = firstShiftStats.defectsCaught,
            CreditsEarned = firstShiftStats.creditsEarned + completionBonus,
        })
    end
    updateReplicatedMultipliers()
    playPreparedSound("RushEndSound")
    sendFeedback(
        "FIRST SHIFT COMPLETE",
        string.format(
            "Products handled: %d\nDefects caught: %d\nCredits earned: +%s\n+%s SHIFT BONUS",
            firstShiftStats.productsHandled,
            firstShiftStats.defectsCaught,
            Release.FormatCredits(firstShiftStats.creditsEarned),
            Release.FormatCredits(completionBonus)
        ),
        "summary",
        4.5,
        nil,
        {feedbackKind = "FirstShiftComplete", shiftBonus = completionBonus}
    )
end

local function updateFirstShift(now)
    if firstShiftRushActive.Value then
        local remaining = math.max(0, firstShiftRushEndsAt - now)
        firstShiftTimeLeft.Value = math.ceil(remaining)
        if remaining <= 0 then
            endFirstShiftRush(now)
        end
        return
    end

    if not firstShiftActive.Value or firstShiftRushStarted.Value then
        return
    end

    local earliest = firstShiftStartedAt + FirstShiftConfig.Rush.EarliestStartDelay
    local hardFallback = firstShiftStartedAt + FirstShiftConfig.Rush.HardFallbackDelay
    local fallback = hardFallback
    if firstCatchAt then
        fallback = math.min(hardFallback, firstCatchAt + FirstShiftConfig.Rush.FallbackAfterFirstCatch)
    end
    local desiredDueAt = math.max(earliest, fallback)
    if not firstShiftRushDueAt or desiredDueAt < firstShiftRushDueAt then
        firstShiftRushDueAt = desiredDueAt
    end

    if now < firstShiftRushDueAt then
        return
    end

    if firstShiftMenuOpen then
        firstShiftMenuDelayStartedAt = firstShiftMenuDelayStartedAt or now
        if now - firstShiftMenuDelayStartedAt < FirstShiftConfig.Rush.MenuMaxDelay then
            return
        end
    end

    startFirstShiftRush(now)
end

local function startRush(now)
    rushActiveValue.Value = true
    if activePlayer then
        Analytics.Log(activePlayer, "FactoryRushStarted", 1, {OperatingTier = currentOperatingTier.Value})
    end
    rushPhase.Value = "Active"
    rushEndsAt = now + UpgradeConfig.Upgrades.RushDuration.Levels[rushDurationLevel.Value].Duration
    warningStarted = false
    rushStats = {
        productsHandled = 0,
        defectsCaught = 0,
        mistakes = 0,
        creditsEarned = 0,
    }
    setRushVisuals(true)
    updateReplicatedMultipliers()
    playPreparedSound("RushStartSound")
    sendFeedback("FACTORY RUSH!", string.format("x%.2f PAY • FASTER LINE", getRushPayMultiplier()), "rush", 2.2)
end

local function endRush(now)
    rushActiveValue.Value = false
    rushPhase.Value = "Normal"
    rushTimeLeft.Value = 0
    rushEndsAt = nil
    nextRushAt = now + Config.Rush.RepeatDelay
    if activePlayer then
        PlayerDataService.IncrementStat(activePlayer, "TotalFactoryRushesCompleted", 1)
        Analytics.Log(activePlayer, "FactoryRushCompleted", rushStats.productsHandled, {
            DefectsCaught = rushStats.defectsCaught,
            Mistakes = rushStats.mistakes,
            CreditsEarned = rushStats.creditsEarned,
        })
        PlayerDataService.MarkDirty("FactoryRushCompleted", true)
    end
    setRushVisuals(false)
    updateReplicatedMultipliers()
    playPreparedSound("RushEndSound")
    sendFeedback(
        "RUSH COMPLETE",
        string.format(
            "Products handled: %d\nDefects caught: %d\nMistakes: %d\nCredits earned: +%s",
            rushStats.productsHandled,
            rushStats.defectsCaught,
            rushStats.mistakes,
            Release.FormatCredits(rushStats.creditsEarned)
        ),
        "summary",
        5
    )
end

local function updateRush(now)
    if rushActiveValue.Value then
        local remaining = math.max(0, rushEndsAt - now)
        rushTimeLeft.Value = math.ceil(remaining)
        if remaining <= 0 then
            endRush(now)
        end
        return
    end

    if not nextRushAt then
        return
    end

    local remaining = nextRushAt - now
    if remaining <= Config.Rush.WarningDuration and remaining > 0 then
        if not warningStarted then
            warningStarted = true
            rushPhase.Value = "Warning"
        end
        rushTimeLeft.Value = math.ceil(remaining)
        pulseRushWarning(now)
    elseif remaining <= 0 then
        startRush(now)
    end
end

local upgradeState = {
    ProductValue = productValueLevel,
    BeltMotor = beltSpeedLevel,
    InspectionRunway = inspectionRunwayLevel,
    AnomalyLuck = anomalyLuckLevel,
    AnomalyQuality = anomalyQualityLevel,
    StreakShield = streakShieldLevel,
    RushDuration = rushDurationLevel,
    RushPay = rushPayLevel,
}

local function describeUpgrade(upgradeName, levelConfig, nextLevel)
    if upgradeName == "ProductValue" then
        return "PRODUCT PAY x" .. tostring(levelConfig.Multiplier), "PRODUCT VALUE LEVEL " .. nextLevel
    elseif upgradeName == "BeltMotor" then
        return "BELT MOTOR " .. nextLevel, tostring(levelConfig.Speed) .. " STUDS/SEC MAX"
    elseif upgradeName == "InspectionRunway" then
        return "INSPECTION RUNWAY " .. nextLevel, tostring(levelConfig.Length) .. " STUDS"
    elseif upgradeName == "AnomalyLuck" then
        return "ANOMALY LUCK " .. nextLevel, "x" .. tostring(levelConfig.Multiplier)
    elseif upgradeName == "AnomalyQuality" then
        return "ANOMALY QUALITY " .. nextLevel, string.format("%.0f%% Glitched Weight", levelConfig.GlitchedShare * 100)
    elseif upgradeName == "StreakShield" then
        return "QUALITY SHIELD " .. nextLevel, "Recharge: " .. tostring(levelConfig.Recharge)
    elseif upgradeName == "RushDuration" then
        return "RUSH DURATION " .. nextLevel, tostring(levelConfig.Duration) .. " sec"
    elseif upgradeName == "RushPay" then
        return "RUSH PAY " .. nextLevel, string.format("x%.2f", levelConfig.Multiplier)
    end
    return "UPGRADE COMPLETE", ""
end

purchaseUpgrade.OnServerEvent:Connect(function(player, requestedName)
    if not canPlayerAct(player) or not RateLimiter.Allow(player, "PurchaseUpgrade", 0.2, 2) then return end
    if typeof(requestedName) ~= "string" then return end
    local upgradeName = requestedName == "BeltSpeed" and "BeltMotor" or requestedName
    local upgrade = UpgradeConfig.Upgrades[upgradeName]
    local levelValue = upgradeState[upgradeName]
    if not upgrade or not levelValue then return end

    local nextLevel = levelValue.Value + 1
    local nextConfigIndex = upgradeName == "StreakShield" and nextLevel + 1 or nextLevel
    local nextConfig = upgrade.Levels[nextConfigIndex]
    if not nextConfig then
        sendFeedbackTo(player, "MAX LEVEL", upgrade.DisplayName .. " is fully upgraded.", "instruction", 1.5)
        return
    end

    local gate = Infrastructure.GetGate(upgradeName, nextLevel, productionTier.Value, researchTier.Value)
    if gate then
        local branchTitle = gate.Branch == "Production" and "FACTORY CAPACITY REACHED" or "ADVANCED RESEARCH REQUIRED"
        local project = FactoryConfig.Projects[gate.ProjectId]
        sendFeedbackTo(player, branchTitle, "Requires " .. (project and project.DisplayName or "a factory project") .. ".", "instruction", 2, nil, {
            feedbackKind = "FactoryGate",
            projectId = gate.ProjectId,
            upgradeName = upgradeName,
        })
        return
    end
    if credits.Value < nextConfig.Cost then
        sendFeedbackTo(player, "NOT ENOUGH CREDITS", "Need " .. Release.FormatCredits(nextConfig.Cost), "bad", 1.5)
        return
    end

    credits.Value = math.max(0, credits.Value - nextConfig.Cost)
    levelValue.Value = nextLevel
    Analytics.Log(player, "UpgradePurchased", nextLevel, {
        Category = upgrade.Category,
        UpgradeId = upgradeName,
        NewLevel = nextLevel,
    })
    markFunnel(player, "FirstUpgradePurchased", "FirstUpgradePurchased", {
        Category = upgrade.Category,
        UpgradeId = upgradeName,
    })
    PlayerDataService.MarkDirty("UpgradePurchased:" .. upgradeName, true)

    if upgradeName == "InspectionRunway" then
        lineProgression:Apply(nextLevel, true)
    elseif upgradeName == "StreakShield" then
        streakShieldReady.Value = true
        streakShieldProgress.Value = nextConfig.Recharge
    end

    updateReplicatedMultipliers()
    playPreparedSound("UpgradeSound")

    local firstProductValuePurchase = upgradeName == "ProductValue"
        and nextLevel == 2
        and firstShiftActive.Value
    if firstProductValuePurchase then
        demonstrateUpgradeOnNextDefect = true
        requestFirstShiftRush(workspace:GetServerTimeNow())
        sendFeedbackTo(player, "PRODUCT VALUE II", "x1.25 PAY", "upgrade", 1.8, nil, {
            feedbackKind = "FirstUpgradePurchased",
            upgradeName = upgradeName,
            upgradeLevel = nextLevel,
            multiplier = nextConfig.Multiplier,
        })
    else
        local title, detail = describeUpgrade(upgradeName, nextConfig, nextLevel)
        sendFeedbackTo(player, title, detail, "upgrade", 2, nil, {
            upgradeName = upgradeName,
            upgradeLevel = nextLevel,
        })
    end
end)

local function clearProductsForFactoryMode()
    for id, record in pairs(productsById) do
        productsById[id] = nil
        if record.model and record.model.Parent then
            record.model:Destroy()
        end
    end
    activeProducts:ClearAllChildren()
    spawnElapsed = 0
end

local function applyCharacterMode(character, isInspection, reposition)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then return end

    if humanoid:GetAttribute("FactoryDefaultWalkSpeed") == nil then
        humanoid:SetAttribute("FactoryDefaultWalkSpeed", humanoid.WalkSpeed > 0 and humanoid.WalkSpeed or 16)
        humanoid:SetAttribute("FactoryDefaultJumpPower", humanoid.JumpPower > 0 and humanoid.JumpPower or 50)
        humanoid:SetAttribute("FactoryDefaultJumpHeight", humanoid.JumpHeight > 0 and humanoid.JumpHeight or 7.2)
    end

    if isInspection then
        if reposition then rootPart.CFrame = CFrame.new(0, 3.5, 19) end
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0
        humanoid.JumpHeight = 0
        humanoid.AutoRotate = false
    else
        if reposition then rootPart.CFrame = CFrame.new(0, 3.5, 24) end
        humanoid.WalkSpeed = humanoid:GetAttribute("FactoryDefaultWalkSpeed") or 16
        humanoid.JumpPower = humanoid:GetAttribute("FactoryDefaultJumpPower") or 50
        humanoid.JumpHeight = humanoid:GetAttribute("FactoryDefaultJumpHeight") or 7.2
        humanoid.AutoRotate = true
    end
end

local function setInspectionModeForPlayer(player, requestedInspection)
    if requestedInspection == inspectionMode.Value then return end
    local now = workspace:GetServerTimeNow()

    if not requestedInspection then
        if firstShiftActive.Value or firstShiftRushActive.Value then
            sendFeedbackTo(player, "FINISH FIRST SHIFT", "Factory exploration unlocks after onboarding.", "instruction", 1.6)
            return
        end
        if rushActiveValue.Value then
            sendFeedbackTo(player, "FINISH RUSH FIRST", "The line cannot pause during Factory Rush.", "instruction", 1.5)
            return
        end

        clearProductsForFactoryMode()
        factoryPausedAt = now
        inspectionMode.Value = false
        applyCharacterMode(player.Character, false, true)
        sendFeedbackTo(player, "LINE PAUSED", "Explore safely. Your streak and operating tier are preserved.", "instruction", 1.8)
        return
    end

    if factoryPausedAt then
        local pausedDuration = now - factoryPausedAt
        if nextRushAt then nextRushAt += pausedDuration end
        if rushEndsAt then rushEndsAt += pausedDuration end
        factoryPausedAt = nil
    end
    inspectionMode.Value = true
    spawnElapsed = getActiveSpawnInterval()
    applyCharacterMode(player.Character, true, true)
    sendFeedbackTo(player, "LINE STARTED", "Quality Control is back online.", "instruction", 1.4)
end

factoryModeRequest.OnServerEvent:Connect(function(player, action)
    if not canPlayerAct(player) or not RateLimiter.Allow(player, "FactoryMode", 0.3, 2) then return end
    if action == "Leave" then
        setInspectionModeForPlayer(player, false)
    elseif action == "Start" then
        setInspectionModeForPlayer(player, true)
    end
end)

local function bindCharacter(player)
    player.CharacterAdded:Connect(function(character)
        character:WaitForChild("Humanoid")
        character:WaitForChild("HumanoidRootPart")
        task.defer(applyCharacterMode, character, inspectionMode.Value, true)
    end)
    if player.Character then
        task.defer(applyCharacterMode, player.Character, inspectionMode.Value, true)
    end
end
local function loadAndStartPlayer(player)
    if activePlayer and activePlayer ~= player then
        player:Kick("This factory server already has an active inspector. Please rejoin for a fresh factory.")
        return
    end
    activePlayer = player
    bindCharacter(player)

    local loaded, loadInfo = PlayerDataService.Load(player)
    if not loaded then
        gameplayReady = false
        task.delay(0.75, function()
            if player.Parent then
                player:Kick(dataLoadFailed.Value ~= "" and dataLoadFailed.Value or "Your factory data could not be loaded safely. Please rejoin in a moment.")
            end
        end)
        return
    end
    if not player.Parent then return end

    local returning = loadInfo.WasReturning
    local now = workspace:GetServerTimeNow()
    spawnIndex = returning and #Config.OnboardingSequence or 0
    spawnElapsed = getActiveSpawnInterval()
    firstShiftStartedAt = now
    firstCatchAt = nil
    firstShiftRushDueAt = nil
    firstShiftRushEndsAt = nil
    nextRushAt = returning and (now + Config.Rush.FirstDelay) or nil
    rushEndsAt = nil
    warningStarted = false
    firstShiftActive.Value = not returning
    firstShiftRushActive.Value = false
    firstShiftTimeLeft.Value = 0
    firstCatchBonusGranted.Value = returning
    firstUpgradePromptShown.Value = returning
    firstShiftRushStarted.Value = returning
    firstShiftRushCompleted.Value = returning
    firstShiftCompletionBonusGranted.Value = returning
    inspectionMode.Value = true
    streakShieldReady.Value = streakShieldLevel.Value > 0
    if streakShieldLevel.Value > 0 then
        streakShieldProgress.Value = UpgradeConfig.Upgrades.StreakShield.Levels[streakShieldLevel.Value + 1].Recharge
    else
        streakShieldProgress.Value = 0
    end

    local rarest = anomalyService:Restore(
        player,
        loadInfo.Record.Collection.Archive,
        player.DisplayName,
        loadInfo.Record.Onboarding.EarlyGoldenGuaranteeSatisfied
            or loadInfo.Record.Onboarding.HasCompletedFirstShift
            or returning
    )
    earlyGoldenGuaranteeSatisfied.Value = anomalyService.GoldenEncountered
    if anomalyService.GoldenEncountered then
        PlayerDataService.SetOnboardingFlag(player, "EarlyGoldenGuaranteeSatisfied", true, false)
    end
    pedestalDisplayed:ClearAllChildren()
    if rarest.ProductKey and rarest.AnomalyId then
        factoryRarestProductKey.Value = rarest.ProductKey
        factoryRarestAnomalyId.Value = rarest.AnomalyId
        factoryRarestFinder.Value = player.DisplayName
        updatePedestal(rarest.ProductKey, rarest.AnomalyId, player.DisplayName, true)
    else
        factoryRarestProductKey.Value = ""
        factoryRarestAnomalyId.Value = ""
        factoryRarestFinder.Value = ""
        pedestalLabel.Visible = false
    end

    if RunService:IsStudio() and UpgradeConfig.DebugCreditGrant > 0 then
        credits.Value = math.clamp(credits.Value + UpgradeConfig.DebugCreditGrant, 0, 9e15)
    end
    lineProgression:Apply(inspectionRunwayLevel.Value, false)
    setRushVisuals(false)
    updateReplicatedMultipliers()
    Analytics.SessionStarted(player)
    Analytics.Log(player, "SessionStarted", 1, {
        Returning = returning,
        ProductsUnlocked = unlockedProductCount.Value,
        ArchiveDiscovered = loadInfo.Record.Collection and loadInfo.Record.Collection.Archive and (function()
            local count = 0
            for _, discovered in pairs(loadInfo.Record.Collection.Archive) do if discovered then count += 1 end end
            return count
        end)() or 0,
    })
    gameplayReady = true
    PlayerDataService.CompleteLoad(player)
end

setOperatingTier.OnServerEvent:Connect(function(player, requestedTier)
    if not canPlayerAct(player) or not RateLimiter.Allow(player, "OperatingTier", 0.08, 3) then return end
    if not isFiniteNumber(requestedTier) then return end
    local target = math.clamp(math.floor(requestedTier), 1, beltSpeedLevel.Value)
    if target == currentOperatingTier.Value then return end
    currentOperatingTier.Value = target
    updateReplicatedMultipliers()
    spawnElapsed = math.min(spawnElapsed, getActiveSpawnInterval())
end)

rejectRequest.OnServerEvent:Connect(function(player, productIdentifier)
    if not canPlayerAct(player) or not RateLimiter.Allow(player, "RejectProduct", 0.04, 4) then return end
    if not inspectionMode.Value then return end
    if typeof(productIdentifier) ~= "string" then
        return
    end

    local record = productsById[productIdentifier]
    if not record
        or not record.model.Parent
        or record.model.Parent ~= activeProducts
        or record.processed
        or record.state ~= "Inspectable" then
        return
    end

    local x = record.model:GetPivot().Position.X
    local inspectionMinX, inspectionMaxX = getInspectionBounds()
    if x < inspectionMinX or x > inspectionMaxX then
        return
    end

    rejectProduct(player, record)
end)

firstShiftMenuState.OnServerEvent:Connect(function(player, menuOpen)
    if not canPlayerAct(player) or not RateLimiter.Allow(player, "FirstShiftMenu", 0.1, 3) then return end
    if typeof(menuOpen) == "boolean" then
        firstShiftMenuOpen = menuOpen
        if not menuOpen then
            firstShiftMenuDelayStartedAt = nil
        end
    end
end)

resetSessionValues()
lineProgression:Apply(inspectionRunwayLevel.Value, false)
setRushVisuals(false)
updateReplicatedMultipliers()

PlayerDataService.SetSessionEndingCallback(function(player, record)
    local productCount = 0
    local departmentCount = 0
    local archiveCount = 0
    for _, unlocked in pairs(record.Products.Unlocked) do if unlocked then productCount += 1 end end
    for _, unlocked in pairs(record.Products.Departments) do if unlocked then departmentCount += 1 end end
    for _, discovered in pairs(record.Collection.Archive) do if discovered then archiveCount += 1 end end
    local snapshot = {
        SessionDuration = Analytics.GetSessionSeconds(player),
        Credits = record.Economy.Credits,
        LineRevenue = record.Economy.LineRevenue,
        ProductsUnlocked = productCount,
        DepartmentsUnlocked = departmentCount,
        ArchiveDiscovered = archiveCount,
        MotorTier = record.Line.BeltMotorTier,
        RunwayLevel = record.Line.InspectionRunwayLevel,
        LuckLevel = record.Research.AnomalyLuckLevel,
        HouseholdActive = record.Factory.HouseholdProductionPurchased,
    }
    print("[AnalyticsSnapshot] " .. HttpService:JSONEncode(snapshot))
    Analytics.EndSession(player, snapshot)
    if player == activePlayer then
        gameplayReady = false
        activePlayer = nil
    end
end)

Players.PlayerAdded:Connect(loadAndStartPlayer)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(loadAndStartPlayer, player) end

RunService.Heartbeat:Connect(function(deltaTime)
    if not gameplayReady or not dataLoaded.Value or not inspectionMode.Value then return end
    local now = workspace:GetServerTimeNow()
    updateFirstShift(now)
    updateRush(now)

    local activeInterval = getActiveSpawnInterval()
    spawnElapsed += deltaTime
    while spawnElapsed >= activeInterval do
        spawnElapsed -= activeInterval
        spawnProduct()
    end

    local activeSpeed = getActiveSpeed()
    for id, record in pairs(productsById) do
        if record.state ~= "Rejected" then
            record.x += activeSpeed * deltaTime
            record.model:PivotTo(CFrame.new(record.x, record.y, 0))

            local inspectionMinX, inspectionMaxX = getInspectionBounds()
            if record.state == "Entering" and record.x >= inspectionMinX then
                record.state = "Inspectable"
                record.model:SetAttribute("LifecycleState", "Inspectable")

                if record.teaching == "MissingPart" and not missingPartIntroduced.Value then
                    missingPartIntroduced.Value = true
                    sendFeedback("NEW DEFECT TYPE", "MISSING PART\nProducts can now be missing components.", "instruction", 2.2, nil, {feedbackKind = "ComponentDefectIntro", defectType = "MissingPart"})
                elseif record.teaching == "ExtraPart" and not extraPartIntroduced.Value then
                    extraPartIntroduced.Value = true
                    sendFeedback("NEW DEFECT TYPE", "EXTRA PART\nProducts can now have duplicate components.", "instruction", 2.2, nil, {feedbackKind = "ComponentDefectIntro", defectType = "ExtraPart"})
                end

                if record.anomalyId then
                    sendFeedback(
                        "",
                        "",
                        "rareCue",
                        0.2,
                        nil,
                        {
                            feedbackKind = "AnomalyCue",
                            anomalyId = record.anomalyId,
                            productIdentifier = record.id,
                        }
                    )
                end

                if record.spawnIndex == 2 and not record.onboardingPromptShown then
                    record.onboardingPromptShown = true
                    sendFeedback("DEFECT! TAP IT!", "Select the bright blue Teddy.", "instruction", 3)
                end
            end

            if record.state == "Inspectable" and record.x > inspectionMaxX then
                if record.anomalyId or Config.Defects[record.defect].Defective then
                    missProduct(record)
                else
                    passNormalProduct(record)
                end
            end

            if record.x > Config.Conveyor.CleanupX then
                productsById[id] = nil
                record.model:Destroy()
            end
        end
    end
end)
