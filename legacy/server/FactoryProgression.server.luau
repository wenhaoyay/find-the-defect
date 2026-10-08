local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Release = require(ReplicatedStorage:WaitForChild("FindDefectReleaseConfig"))
local Config = require(ReplicatedStorage:WaitForChild("FindDefectFactoryConfig"))
local Registry = require(ReplicatedStorage:WaitForChild("FindDefectProductRegistry"))
local modules = script.Parent:WaitForChild("FindDefectModules")
local PlayerDataService = require(modules:WaitForChild("PlayerDataService"))
local Analytics = require(modules:WaitForChild("FindDefectAnalytics"))
local RateLimiter = require(modules:WaitForChild("RateLimiter"))
local state = ReplicatedStorage:WaitForChild("FindDefectState")
local credits = state:WaitForChild("Credits")
local lineRevenue = state:WaitForChild("LineRevenue")
local inspectionMode = state:WaitForChild("InspectionMode")
local researchPurchased = state:WaitForChild("ResearchLabPurchased")
local galleryPurchased = state:WaitForChild("RejectGalleryPurchased")
local productionTier = state:WaitForChild("ProductionTier")
local researchTier = state:WaitForChild("ResearchTier")
local householdPurchased = state:WaitForChild("HouseholdProductionPurchased")
local projectsPurchased = state:WaitForChild("FactoryProjectsPurchased")
local purchaseProject = state:WaitForChild("PurchaseFactoryProject")
local clientAction = state:WaitForChild("FactoryClientAction")
local feedback = state:WaitForChild("Feedback")
local discoveries = state:WaitForChild("FactoryArchiveDiscoveries")
local rareProductKey = state:WaitForChild("FactoryRarestProductKey")
local rareAnomalyId = state:WaitForChild("FactoryRarestAnomalyId")
local rareFinder = state:WaitForChild("FactoryRarestFinder")
local dataLoaded = state:WaitForChild("DataLoaded")

local function canPlayerAct(player)
    return dataLoaded.Value and PlayerDataService.IsReady(player)
end

local root = workspace:WaitForChild("FindTheDefectStage0")
local world = root:WaitForChild("FactoryWorld")
local references = ReplicatedStorage:WaitForChild("FindDefectAnomalyReferences")
local originalPedestal = root:WaitForChild("RarestFindPedestal")
local function isProjectOwned(projectId)
    local project = Config.Projects[projectId]
    if not project then return false end
    if project.Branch == "Production" then return productionTier.Value >= project.Tier end
    if project.Branch == "Research" then return researchTier.Value >= project.Tier end
    if projectId == "RejectGallery" then return galleryPurchased.Value end
    if projectId == "HouseholdProduction" then return householdPurchased.Value end
    return false
end

local function send(player, title, detail, tone, duration, extras)
    local payload = {
        title = title,
        detail = detail,
        tone = tone,
        duration = duration or 1.8,
        feedbackKind = "FactoryProject",
    }
    if extras then for key, value in pairs(extras) do payload[key] = value end end
    feedback:FireClient(player, payload)
end

local function setLabel(anchor, status, color)
    local gui = anchor and anchor:FindFirstChild("WorldLabel")
    local frame = gui and gui:FindFirstChild("Frame")
    local statusLabel = frame and frame:FindFirstChild("Status")
    local stroke = frame and frame:FindFirstChild("Stroke")
    if statusLabel then
        statusLabel.Text = status
        statusLabel.TextColor3 = color
    end
    if stroke then
        stroke.Color = color
    end
end

local function setRoomState(projectId, purchased, animate)
    local project = Config.Projects[projectId]
    local room = world:FindFirstChild(project.RoomReference)
    if not room then return end

    local door = room:FindFirstChild("ProjectShutter")
    local indicator = room:FindFirstChild("StatusIndicator")
    local sign = room:FindFirstChild("ProjectSign")
    local activeColor = Config.Unlock.ActiveColor
    local lockedColor = Config.Unlock.LockedColor

    if indicator then indicator.Color = purchased and activeColor or lockedColor end
    if sign then
        setLabel(sign, purchased and "ACTIVE" or ("OFFLINE • PROJECT " .. Release.FormatCredits(project.Cost)), purchased and activeColor or lockedColor)
    end

    for _, item in ipairs(room:GetChildren()) do
        if item.Name == "InteriorLight" and item:IsA("BasePart") then
            local light = item:FindFirstChildOfClass("PointLight")
            if purchased and animate then
                item.Transparency = 0.75
                if light then light.Enabled = false end
            else
                item.Transparency = purchased and (item:GetAttribute("ActiveTransparency") or 0.1) or 0.72
                if light then light.Enabled = purchased end
            end
        end
    end

    local consolePrompt = room:FindFirstChild(projectId == "ResearchLab" and "ResearchConsole" or "ArchiveTerminal")
    consolePrompt = consolePrompt and consolePrompt:FindFirstChildOfClass("ProximityPrompt")
    if consolePrompt then consolePrompt.Enabled = purchased end

    if door then
        local closedY = door:GetAttribute("ClosedY") or 4.5
        local targetY = purchased and (door:GetAttribute("OpenY") or closedY + 9) or closedY
        local target = CFrame.new(door.Position.X, targetY, door.Position.Z) * (door.CFrame - door.Position)
        if purchased and animate then
            TweenService:Create(
                door,
                TweenInfo.new(Config.Unlock.ShutterTween, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                {CFrame = target}
            ):Play()
        else
            door.CFrame = target
        end
        door.CanCollide = not purchased
    end

    if purchased and animate then
        setLabel(sign, "PROJECT APPROVED", activeColor)
        task.spawn(function()
            local lights = {}
            for _, item in ipairs(room:GetChildren()) do
                if item.Name == "InteriorLight" and item:IsA("BasePart") then
                    table.insert(lights, item)
                end
            end
            table.sort(lights, function(a, b) return a.Position.Z < b.Position.Z end)
            task.wait(0.55)
            for _, lightPart in ipairs(lights) do
                lightPart.Transparency = lightPart:GetAttribute("ActiveTransparency") or 0.1
                local light = lightPart:FindFirstChildOfClass("PointLight")
                if light then light.Enabled = true end
                task.wait(Config.Unlock.LightStep)
            end
            task.wait(0.65)
            setLabel(sign, "ACTIVE", activeColor)
        end)
    end
end

local function updateProjectCount()
    projectsPurchased.Value = math.max(0, productionTier.Value - 1)
        + researchTier.Value
        + (galleryPurchased.Value and 1 or 0)
        + (householdPurchased.Value and 1 or 0)
end

local function prepareDisplay(model, scale)
    local hitbox = model:FindFirstChild("InteractionHitbox", true)
    if hitbox then hitbox:Destroy() end
    for _, item in ipairs(model:GetDescendants()) do
        if item:IsA("BasePart") then
            item.Anchored = true
            item.CanCollide = false
            item.CanTouch = false
            item.CanQuery = false
        elseif item:IsA("ProximityPrompt") or item:IsA("ClickDetector") then
            item:Destroy()
        end
    end
    if scale then model:ScaleTo(scale) end
end

local function placeOnAnchor(model, anchor)
    model:PivotTo(CFrame.new(anchor.Position))
    local boxCFrame, boxSize = model:GetBoundingBox()
    local lift = anchor.Position.Y - (boxCFrame.Position.Y - boxSize.Y * 0.5)
    model:PivotTo(model:GetPivot() + Vector3.new(0, lift, 0))
end

local function updateCase(productId)
    if not galleryPurchased.Value then return end
    local product = Registry.Products[productId]
    local case = world.RejectGallery.DisplayCases:FindFirstChild(productId)
    if not product or not case then return end
    local departmentActive = product.DepartmentId ~= "Household" or householdPurchased.Value
    local bestAnomaly
    local glitched = discoveries:FindFirstChild("Glitched_" .. productId)
    local golden = discoveries:FindFirstChild("Golden_" .. productId)
    if glitched and glitched.Value then bestAnomaly = "Glitched"
    elseif golden and golden.Value then bestAnomaly = "Golden" end
    local shown = case.DisplayedProduct
    shown:ClearAllChildren()
    local anchor = case.DisplayAnchor
    local status = anchor.CaseLabel.Frame.Status
    local light = case.Glass:FindFirstChild("CaseLight")
    status.Text = not departmentActive and "DEPARTMENT LOCKED" or bestAnomaly and string.upper(bestAnomaly) or "???"
    status.TextColor3 = not departmentActive and Color3.fromRGB(85, 90, 98)
        or bestAnomaly == "Glitched" and Color3.fromRGB(220, 82, 235)
        or bestAnomaly == "Golden" and Color3.fromRGB(225, 180, 58)
        or Color3.fromRGB(120, 125, 130)
    if light then
        light.Enabled = departmentActive and bestAnomaly ~= nil
        light.Color = bestAnomaly == "Glitched" and Color3.fromRGB(200, 65, 225) or Color3.fromRGB(235, 190, 70)
    end
    case.UndiscoveredSilhouette.Transparency = departmentActive and (bestAnomaly and 1 or 0.25) or 0.78
    if departmentActive and bestAnomaly then
        local source = references:FindFirstChild(bestAnomaly .. "_" .. productId)
        if source then
            local model = source:Clone()
            model.Name = "Exhibit"
            prepareDisplay(model, 0.38)
            model.Parent = shown
            placeOnAnchor(model, anchor)
        end
    end
end

local function updateAllCases()
    for _, productId in ipairs(Registry.ProductOrder) do updateCase(productId) end
end

local function updateRarest()
    if not galleryPurchased.Value then return end
    local rare = world.RejectGallery.RarestFindDisplay
    rare.DisplayedProduct:ClearAllChildren()
    local label = rare.RarestLabel.WorldLabel.Frame.Status
    if rareProductKey.Value == "" or rareAnomalyId.Value == "" then
        label.Text = "NO DISCOVERY YET"
        return
    end
    local key = rareAnomalyId.Value .. "_" .. rareProductKey.Value
    local source = references:FindFirstChild(key)
    if source then
        local model = source:Clone()
        model.Name = "RarestExhibit"
        prepareDisplay(model, 0.52)
        model.Parent = rare.DisplayedProduct
        placeOnAnchor(model, rare.DisplayAnchor)
    end
    label.Text = string.upper(rareAnomalyId.Value .. " " .. rareProductKey.Value)
        .. (rareFinder.Value ~= "" and (" • FOUND BY " .. string.upper(rareFinder.Value)) or "")
end

local function setOriginalPedestalReceded(receded)
    for _, item in ipairs(originalPedestal:GetDescendants()) do
        if item:IsA("BasePart") then
            if item:GetAttribute("Stage4OriginalTransparency") == nil then
                item:SetAttribute("Stage4OriginalTransparency", item.Transparency)
            end
            item.Transparency = receded and 1 or item:GetAttribute("Stage4OriginalTransparency")
            item.CanCollide = not receded
            item.CanQuery = not receded
        elseif item:IsA("BillboardGui") or item:IsA("ParticleEmitter") then
            item.Enabled = not receded
        end
    end
end

purchaseProject.OnServerEvent:Connect(function(player, projectId)
    if not canPlayerAct(player) or not RateLimiter.Allow(player, "FactoryProject", 0.25, 2) then return end
    if typeof(projectId) ~= "string" then return end
    local project = Config.Projects[projectId]
    if not project or not project.Available or project.ComingSoon then
        send(player, "PROJECT UNAVAILABLE", "This expansion is coming soon.", "instruction", 1.5)
        return
    end
    if isProjectOwned(projectId) then
        send(player, "ALREADY ACTIVE", project.DisplayName .. " is already online.", "instruction", 1.5)
        return
    end

    if project.Requirements then
        if productionTier.Value < (project.Requirements.ProductionTier or 0) or lineRevenue.Value < (project.Requirements.LineRevenue or 0) then
            send(player, "PROJECT LOCKED", string.format("Requires Production Systems II and $%d Line Revenue.", project.Requirements.LineRevenue or 0), "instruction", 1.8)
            return
        end
    end
    if project.Branch then
        local currentTier = project.Branch == "Production" and productionTier.Value or researchTier.Value
        if currentTier < project.PrerequisiteTier then
            local previousName = project.Branch == "Production"
                and ("PRODUCTION SYSTEMS " .. string.rep("I", project.PrerequisiteTier))
                or ("RESEARCH LAB " .. string.rep("I", project.PrerequisiteTier))
            send(player, "PROJECT LOCKED", "Requires " .. previousName .. ".", "instruction", 1.7)
            return
        end
    end
    if credits.Value < project.Cost then
        send(player, "NOT ENOUGH CREDITS", "Need " .. Release.FormatCredits(project.Cost), "bad", 1.6)
        return
    end

    credits.Value -= project.Cost
    if project.Branch == "Production" then
        productionTier.Value = project.Tier
    elseif project.Branch == "Research" then
        researchTier.Value = project.Tier
        researchPurchased.Value = researchTier.Value >= 1
    elseif projectId == "RejectGallery" then
        galleryPurchased.Value = true
    elseif projectId == "HouseholdProduction" then
        householdPurchased.Value = true
    end
    updateProjectCount()
    Analytics.Log(player, "FactoryProjectPurchased", project.Cost, {ProjectId = projectId})
    PlayerDataService.MarkDirty("FactoryProjectPurchased:" .. projectId, true)
    if project.RoomReference then setRoomState(projectId, true, true) end
    send(player, "PROJECT APPROVED", project.DisplayName .. " is coming online.", "upgrade", Config.Unlock.Duration, {
        projectId = projectId,
        factoryTierBranch = project.Branch,
        factoryTier = project.Tier,
    })
end)

world.CentralHub.ProjectsTerminal.FactoryProjectsPrompt.Triggered:Connect(function(player)
    if canPlayerAct(player) then clientAction:FireClient(player, "OpenProjects") end
end)
world.ResearchLab.ResearchConsole.ResearchPrompt.Triggered:Connect(function(player)
    if canPlayerAct(player) and researchPurchased.Value then clientAction:FireClient(player, "OpenResearch") end
end)
world.RejectGallery.ArchiveTerminal.ArchivePrompt.Triggered:Connect(function(player)
    if canPlayerAct(player) and galleryPurchased.Value then clientAction:FireClient(player, "OpenArchive") end
end)
root.Factory.WorkConsole.StartLinePrompt.Triggered:Connect(function(player)
    if canPlayerAct(player) and not inspectionMode.Value then clientAction:FireClient(player, "StartLine") end
end)

inspectionMode:GetPropertyChangedSignal("Value"):Connect(function()
    root.Factory.WorkConsole.StartLinePrompt.Enabled = not inspectionMode.Value
end)

researchPurchased:GetPropertyChangedSignal("Value"):Connect(function()
    if researchPurchased.Value and researchTier.Value < 1 then researchTier.Value = 1 end
    if not researchPurchased.Value and researchTier.Value > 0 then researchPurchased.Value = true end
    updateProjectCount()
end)
productionTier:GetPropertyChangedSignal("Value"):Connect(updateProjectCount)
researchTier:GetPropertyChangedSignal("Value"):Connect(function()
    researchPurchased.Value = researchTier.Value >= 1
    updateProjectCount()
end)

householdPurchased:GetPropertyChangedSignal("Value"):Connect(function()
    updateProjectCount()
    updateAllCases()
end)

galleryPurchased:GetPropertyChangedSignal("Value"):Connect(function()
    updateProjectCount()
    setOriginalPedestalReceded(galleryPurchased.Value)
    if galleryPurchased.Value then
        task.defer(function()
            updateAllCases()
            updateRarest()
        end)
    end
end)

for _, value in ipairs(discoveries:GetChildren()) do
    value:GetPropertyChangedSignal("Value"):Connect(function()
        local productId = string.match(value.Name, "^[^_]+_(.+)$")
        if productId then updateCase(productId) end
        if galleryPurchased.Value and value.Value then
            for _, player in ipairs(Players:GetPlayers()) do
                send(player, "NEW EXHIBIT INSTALLED", value.Name:gsub("_", " "), "upgrade", 1.5)
            end
        end
    end)
end
for _, value in ipairs({rareProductKey, rareAnomalyId, rareFinder}) do
    value:GetPropertyChangedSignal("Value"):Connect(updateRarest)
end

local function restoreFactoryWorld()
    if not dataLoaded.Value then return end
    if researchPurchased.Value and researchTier.Value < 1 then researchTier.Value = 1 end
    researchPurchased.Value = researchTier.Value >= 1
    if RunService:IsStudio() and Config.DebugUnlockFactoryProjects then
        productionTier.Value = 3
        researchTier.Value = 3
        researchPurchased.Value = true
        galleryPurchased.Value = true
    end
    setRoomState("ResearchLab", researchTier.Value >= 1, false)
    setRoomState("RejectGallery", galleryPurchased.Value, false)
    setRoomState("HouseholdProduction", householdPurchased.Value, false)
    setOriginalPedestalReceded(galleryPurchased.Value)
    root.Factory.WorkConsole.StartLinePrompt.Enabled = not inspectionMode.Value
    updateProjectCount()
    updateAllCases()
    updateRarest()
end

root.Factory.WorkConsole.StartLinePrompt.Enabled = false
dataLoaded:GetPropertyChangedSignal("Value"):Connect(function()
    if dataLoaded.Value then task.defer(restoreFactoryWorld) end
end)
if dataLoaded.Value then task.defer(restoreFactoryWorld) end
