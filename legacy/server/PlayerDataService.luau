local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Config = require(script.Parent:WaitForChild("PersistenceConfig"))
local UpgradeConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("FindDefectUpgradeConfig"))
local FactoryConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("FindDefectFactoryConfig"))
local Registry = require(game:GetService("ReplicatedStorage"):WaitForChild("FindDefectProductRegistry"))
local Departments = require(game:GetService("ReplicatedStorage"):WaitForChild("FindDefectDepartmentConfig"))
local AnomalyConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("FindDefectAnomalyConfig"))

local PlayerDataService = {}
local initialized = false
local state
local dataStore
local activeStoreName
local useMemoryAdapter = false
local memoryRecords = {}
local sessions = {}
local applying = false
local connections = {}
local sessionEndingCallback

local function deepCopy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, child in pairs(value) do copy[deepCopy(key)] = deepCopy(child) end
    return copy
end

local function finiteNumber(value)
    return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function maxFactoryTier(branch)
    local highest = branch == "Production" and 1 or 0
    for _, project in pairs(FactoryConfig.Projects) do
        if project.Branch == branch then highest = math.max(highest, project.Tier or highest) end
    end
    return highest
end

local function buildDefaults()
    local unlocked = {}
    for _, productId in ipairs(Registry.ProductOrder) do unlocked[productId] = productId == "TeddyBear" end
    local departments = {}
    local revenue = {}
    for _, departmentId in ipairs(Departments.Order) do
        departments[departmentId] = Departments.Definitions[departmentId].DefaultUnlocked == true
        revenue[departmentId] = 0
    end
    local archive = {}
    for _, anomalyId in ipairs(AnomalyConfig.ArchiveRows) do
        for _, productId in ipairs(AnomalyConfig.ProductOrder) do
            archive[AnomalyConfig.GetDiscoveryKey(productId, anomalyId)] = false
        end
    end
    return {
        SchemaVersion = Config.SchemaVersion,
        Economy = {Credits = 0, LineRevenue = 0},
        Line = {
            ProductValueLevel = 1,
            BeltMotorTier = 1,
            OperatingTier = 1,
            InspectionRunwayLevel = 1,
        },
        Research = {AnomalyLuckLevel = 1, AnomalyQualityLevel = 1},
        Inspector = {StreakShieldLevel = 0},
        Rush = {DurationLevel = 1, PayLevel = 1},
        Factory = {
            ProductionTier = 1,
            ResearchTier = 0,
            ResearchLabPurchased = false,
            RejectGalleryPurchased = false,
            HouseholdProductionPurchased = false,
        },
        Products = {
            Unlocked = unlocked,
            Departments = departments,
            DepartmentRevenue = revenue,
        },
        Collection = {Archive = archive},
        Onboarding = {
            HasPlayedBefore = false,
            HasCompletedFirstShift = false,
            EarlyGoldenGuaranteeSatisfied = false,
            MissingPartIntroduced = false,
            ExtraPartIntroduced = false,
        },
        Statistics = {
            TotalProductsHandled = 0,
            TotalDefectsCaught = 0,
            TotalCreditsEarned = 0,
            TotalFactoryRushesCompleted = 0,
            TotalGoldenCaught = 0,
            TotalGlitchedCaught = 0,
            PlaySeconds = 0,
        },
        Funnel = {
            FirstProductHandled = false,
            FirstDefectCaught = false,
            FirstUpgradePurchased = false,
        },
        _Meta = {
            SaveRevision = 0,
            LastSavedAt = 0,
            SessionId = "",
            SessionTouchedAt = 0,
        },
    }
end

local DEFAULT_DATA = buildDefaults()

local function childTable(parent, name)
    return type(parent) == "table" and type(parent[name]) == "table" and parent[name] or {}
end

local function choose(container, key, fallbackContainer, fallbackKey, default)
    local value = type(container) == "table" and container[key] or nil
    if value == nil and type(fallbackContainer) == "table" then value = fallbackContainer[fallbackKey or key] end
    if value == nil then return default end
    return value
end

local function repairedNumber(value, default, minimum, maximum, integer, path, repairs)
    if value == nil then return default end
    if not finiteNumber(value) then
        table.insert(repairs, path .. " invalid; defaulted")
        return default
    end
    local fixed = math.clamp(value, minimum, maximum)
    if integer then fixed = math.floor(fixed) end
    if fixed ~= value then table.insert(repairs, path .. " clamped") end
    return fixed
end

local function repairedBoolean(value, default, path, repairs)
    if value == nil then return default end
    if typeof(value) ~= "boolean" then
        table.insert(repairs, path .. " invalid; defaulted")
        return default
    end
    return value
end

local function validateRecord(raw, emitWarnings)
    local hadRecord = raw ~= nil
    if raw ~= nil and type(raw) ~= "table" then
        if emitWarnings then warn("[PlayerData] Record was not a table; protected defaults prepared.") end
        raw = {}
    end
    raw = raw or {}
    local version = raw.SchemaVersion
    if version ~= nil and (not finiteNumber(version) or math.floor(version) ~= version or version < 0) then
        version = 0
    end
    version = version or 0
    if version > Config.SchemaVersion then
        return nil, "Unsupported future schema " .. tostring(version), {}
    end

    local defaults = DEFAULT_DATA
    local result = deepCopy(defaults)
    local repairs = {}
    local economy = childTable(raw, "Economy")
    local line = childTable(raw, "Line")
    local research = childTable(raw, "Research")
    local inspector = childTable(raw, "Inspector")
    local rush = childTable(raw, "Rush")
    local factory = childTable(raw, "Factory")
    local products = childTable(raw, "Products")
    local collection = childTable(raw, "Collection")
    local onboarding = childTable(raw, "Onboarding")
    local statistics = childTable(raw, "Statistics")
    local funnel = childTable(raw, "Funnel")
    local meta = childTable(raw, "_Meta")

    result.Economy.Credits = repairedNumber(choose(economy, "Credits", raw, "Credits", 0), 0, 0, 9e15, true, "Economy.Credits", repairs)
    result.Economy.LineRevenue = repairedNumber(choose(economy, "LineRevenue", raw, "LineRevenue", 0), 0, 0, 9e15, true, "Economy.LineRevenue", repairs)

    result.Line.ProductValueLevel = repairedNumber(choose(line, "ProductValueLevel", raw, "ProductValueLevel", 1), 1, 1, #UpgradeConfig.Upgrades.ProductValue.Levels, true, "Line.ProductValueLevel", repairs)
    local motorSource = choose(line, "BeltMotorTier", raw, "BeltSpeedLevel", nil)
    if motorSource == nil then motorSource = raw.MotorLevel end
    result.Line.BeltMotorTier = repairedNumber(motorSource, 1, 1, #UpgradeConfig.Upgrades.BeltMotor.Levels, true, "Line.BeltMotorTier", repairs)
    result.Line.OperatingTier = repairedNumber(choose(line, "OperatingTier", raw, "CurrentOperatingTier", 1), 1, 1, result.Line.BeltMotorTier, true, "Line.OperatingTier", repairs)
    result.Line.InspectionRunwayLevel = repairedNumber(choose(line, "InspectionRunwayLevel", raw, "InspectionRunwayLevel", 1), 1, 1, #UpgradeConfig.Upgrades.InspectionRunway.Levels, true, "Line.InspectionRunwayLevel", repairs)

    result.Research.AnomalyLuckLevel = repairedNumber(choose(research, "AnomalyLuckLevel", raw, "AnomalyLuckLevel", 1), 1, 1, #UpgradeConfig.Upgrades.AnomalyLuck.Levels, true, "Research.AnomalyLuckLevel", repairs)
    result.Research.AnomalyQualityLevel = repairedNumber(choose(research, "AnomalyQualityLevel", raw, "AnomalyQualityLevel", 1), 1, 1, #UpgradeConfig.Upgrades.AnomalyQuality.Levels, true, "Research.AnomalyQualityLevel", repairs)
    result.Inspector.StreakShieldLevel = repairedNumber(choose(inspector, "StreakShieldLevel", raw, "StreakShieldLevel", 0), 0, 0, #UpgradeConfig.Upgrades.StreakShield.Levels - 1, true, "Inspector.StreakShieldLevel", repairs)
    result.Rush.DurationLevel = repairedNumber(choose(rush, "DurationLevel", raw, "RushDurationLevel", 1), 1, 1, #UpgradeConfig.Upgrades.RushDuration.Levels, true, "Rush.DurationLevel", repairs)
    result.Rush.PayLevel = repairedNumber(choose(rush, "PayLevel", raw, "RushPayLevel", 1), 1, 1, #UpgradeConfig.Upgrades.RushPay.Levels, true, "Rush.PayLevel", repairs)

    result.Factory.ProductionTier = repairedNumber(choose(factory, "ProductionTier", raw, "ProductionTier", 1), 1, 1, maxFactoryTier("Production"), true, "Factory.ProductionTier", repairs)
    result.Factory.ResearchTier = repairedNumber(choose(factory, "ResearchTier", raw, "ResearchTier", 0), 0, 0, maxFactoryTier("Research"), true, "Factory.ResearchTier", repairs)
    result.Factory.ResearchLabPurchased = repairedBoolean(choose(factory, "ResearchLabPurchased", raw, "ResearchLabPurchased", result.Factory.ResearchTier > 0), result.Factory.ResearchTier > 0, "Factory.ResearchLabPurchased", repairs)
    result.Factory.RejectGalleryPurchased = repairedBoolean(choose(factory, "RejectGalleryPurchased", raw, "RejectGalleryPurchased", false), false, "Factory.RejectGalleryPurchased", repairs)
    result.Factory.HouseholdProductionPurchased = repairedBoolean(choose(factory, "HouseholdProductionPurchased", raw, "HouseholdProductionPurchased", false), false, "Factory.HouseholdProductionPurchased", repairs)
    if result.Factory.ResearchLabPurchased and result.Factory.ResearchTier < 1 then result.Factory.ResearchTier = 1 end
    result.Factory.ResearchLabPurchased = result.Factory.ResearchTier >= 1
    if result.Factory.HouseholdProductionPurchased then
        result.Factory.ProductionTier = math.max(result.Factory.ProductionTier, FactoryConfig.Projects.HouseholdProduction.Requirements.ProductionTier or 1)
    end

    local rawUnlocked = childTable(products, "Unlocked")
    local rawDepartments = childTable(products, "Departments")
    local rawRevenue = childTable(products, "DepartmentRevenue")
    if next(rawUnlocked) == nil then rawUnlocked = childTable(raw, "UnlockedProducts") end
    if next(rawDepartments) == nil then rawDepartments = childTable(raw, "DepartmentUnlocked") end
    if next(rawRevenue) == nil then rawRevenue = childTable(raw, "DepartmentRevenue") end
    for _, departmentId in ipairs(Departments.Order) do
        result.Products.Departments[departmentId] = repairedBoolean(rawDepartments[departmentId], defaults.Products.Departments[departmentId], "Products.Departments." .. departmentId, repairs)
        result.Products.DepartmentRevenue[departmentId] = repairedNumber(rawRevenue[departmentId], 0, 0, 9e15, true, "Products.DepartmentRevenue." .. departmentId, repairs)
    end
    result.Products.Departments.Toys = true
    if result.Factory.HouseholdProductionPurchased then result.Products.Departments.Household = true end
    for _, productId in ipairs(Registry.ProductOrder) do
        result.Products.Unlocked[productId] = repairedBoolean(rawUnlocked[productId], defaults.Products.Unlocked[productId], "Products.Unlocked." .. productId, repairs)
    end
    result.Products.Unlocked.TeddyBear = true
    if result.Factory.HouseholdProductionPurchased then result.Products.Unlocked.Mug = true end
    for _, productId in ipairs(Registry.ProductOrder) do
        local definition = Registry.Products[productId]
        if result.Products.Departments[definition.DepartmentId]
            and result.Products.DepartmentRevenue[definition.DepartmentId] >= definition.UnlockRevenue then
            result.Products.Unlocked[productId] = true
        end
    end

    local rawArchive = childTable(collection, "Archive")
    if collection.Archive ~= nil and type(collection.Archive) ~= "table" then
        table.insert(repairs, "Collection.Archive invalid; defaulted")
    end
    if next(rawArchive) == nil then
        if raw.FactoryArchiveDiscoveries ~= nil and type(raw.FactoryArchiveDiscoveries) ~= "table" then
            table.insert(repairs, "FactoryArchiveDiscoveries invalid; defaulted")
        end
        rawArchive = childTable(raw, "FactoryArchiveDiscoveries")
    end
    for key in pairs(defaults.Collection.Archive) do
        result.Collection.Archive[key] = repairedBoolean(rawArchive[key], false, "Collection.Archive." .. key, repairs)
    end

    for key, default in pairs(defaults.Onboarding) do
        result.Onboarding[key] = repairedBoolean(onboarding[key], default, "Onboarding." .. key, repairs)
    end
    for key in pairs(defaults.Statistics) do
        result.Statistics[key] = repairedNumber(statistics[key], 0, 0, 9e15, true, "Statistics." .. key, repairs)
    end
    local hasAnyUpgrade = result.Line.ProductValueLevel > 1
        or result.Line.BeltMotorTier > 1
        or result.Line.InspectionRunwayLevel > 1
        or result.Research.AnomalyLuckLevel > 1
        or result.Research.AnomalyQualityLevel > 1
        or result.Inspector.StreakShieldLevel > 0
        or result.Rush.DurationLevel > 1
        or result.Rush.PayLevel > 1
    result.Funnel.FirstProductHandled = repairedBoolean(funnel.FirstProductHandled, false, "Funnel.FirstProductHandled", repairs)
        or result.Statistics.TotalProductsHandled > 0
    result.Funnel.FirstDefectCaught = repairedBoolean(funnel.FirstDefectCaught, false, "Funnel.FirstDefectCaught", repairs)
        or result.Statistics.TotalDefectsCaught > 0
    result.Funnel.FirstUpgradePurchased = repairedBoolean(funnel.FirstUpgradePurchased, false, "Funnel.FirstUpgradePurchased", repairs)
        or hasAnyUpgrade

    result._Meta.SaveRevision = repairedNumber(meta.SaveRevision, 0, 0, 9e15, true, "_Meta.SaveRevision", repairs)
    result._Meta.LastSavedAt = repairedNumber(meta.LastSavedAt, 0, 0, 9e15, true, "_Meta.LastSavedAt", repairs)
    result._Meta.SessionId = typeof(meta.SessionId) == "string" and meta.SessionId or ""
    result._Meta.SessionTouchedAt = repairedNumber(meta.SessionTouchedAt, 0, 0, 9e15, true, "_Meta.SessionTouchedAt", repairs)
    result.SchemaVersion = Config.SchemaVersion

    if emitWarnings then
        for _, message in ipairs(repairs) do warn("[PlayerData] Repaired " .. message) end
        if hadRecord and version < Config.SchemaVersion then warn("[PlayerData] Migrated schema " .. tostring(version) .. " to " .. tostring(Config.SchemaVersion)) end
    end
    return result, nil, repairs
end

local function value(path)
    local current = state
    for segment in string.gmatch(path, "[^%.]+") do current = current:WaitForChild(segment) end
    return current
end

local function setValue(path, newValue)
    value(path).Value = newValue
end

local function updateDerivedValues()
    local count = 0
    for _, productId in ipairs(Registry.ProductOrder) do
        if value("UnlockedProducts." .. productId).Value then count += 1 end
    end
    state.UnlockedProductCount.Value = count
    state.DuckUnlocked.Value = state.UnlockedProducts.RubberDuck.Value
    state.CarUnlocked.Value = state.UnlockedProducts.ToyCar.Value
    state.ResearchLabPurchased.Value = state.ResearchTier.Value >= 1
    state.FactoryProjectsPurchased.Value = math.max(0, state.ProductionTier.Value - 1)
        + state.ResearchTier.Value
        + (state.RejectGalleryPurchased.Value and 1 or 0)
        + (state.HouseholdProductionPurchased.Value and 1 or 0)
end

local function applyRecord(record)
    applying = true
    setValue("Credits", record.Economy.Credits)
    setValue("LineRevenue", record.Economy.LineRevenue)
    setValue("ProductValueLevel", record.Line.ProductValueLevel)
    setValue("BeltSpeedLevel", record.Line.BeltMotorTier)
    setValue("CurrentOperatingTier", record.Line.OperatingTier)
    setValue("InspectionRunwayLevel", record.Line.InspectionRunwayLevel)
    setValue("AnomalyLuckLevel", record.Research.AnomalyLuckLevel)
    setValue("AnomalyQualityLevel", record.Research.AnomalyQualityLevel)
    setValue("StreakShieldLevel", record.Inspector.StreakShieldLevel)
    setValue("RushDurationLevel", record.Rush.DurationLevel)
    setValue("RushPayLevel", record.Rush.PayLevel)
    setValue("ProductionTier", record.Factory.ProductionTier)
    setValue("ResearchTier", record.Factory.ResearchTier)
    setValue("ResearchLabPurchased", record.Factory.ResearchLabPurchased)
    setValue("RejectGalleryPurchased", record.Factory.RejectGalleryPurchased)
    setValue("HouseholdProductionPurchased", record.Factory.HouseholdProductionPurchased)
    for productId, unlocked in pairs(record.Products.Unlocked) do setValue("UnlockedProducts." .. productId, unlocked) end
    for departmentId, unlocked in pairs(record.Products.Departments) do setValue("DepartmentUnlocked." .. departmentId, unlocked) end
    for departmentId, revenue in pairs(record.Products.DepartmentRevenue) do setValue("DepartmentRevenue." .. departmentId, revenue) end
    for key, discovered in pairs(record.Collection.Archive) do setValue("FactoryArchiveDiscoveries." .. key, discovered) end
    setValue("MissingPartIntroduced", record.Onboarding.MissingPartIntroduced)
    setValue("ExtraPartIntroduced", record.Onboarding.ExtraPartIntroduced)
    for statName, statValue in pairs(record.Statistics) do setValue("PersistentStatistics." .. statName, statValue) end
    updateDerivedValues()
    applying = false
end

local function snapshotSession(session)
    local record = deepCopy(session.Record)
    record.SchemaVersion = Config.SchemaVersion
    record.Economy.Credits = math.max(0, math.floor(state.Credits.Value))
    record.Economy.LineRevenue = math.max(0, math.floor(state.LineRevenue.Value))
    record.Line.ProductValueLevel = state.ProductValueLevel.Value
    record.Line.BeltMotorTier = state.BeltSpeedLevel.Value
    record.Line.OperatingTier = math.clamp(state.CurrentOperatingTier.Value, 1, state.BeltSpeedLevel.Value)
    record.Line.InspectionRunwayLevel = state.InspectionRunwayLevel.Value
    record.Research.AnomalyLuckLevel = state.AnomalyLuckLevel.Value
    record.Research.AnomalyQualityLevel = state.AnomalyQualityLevel.Value
    record.Inspector.StreakShieldLevel = state.StreakShieldLevel.Value
    record.Rush.DurationLevel = state.RushDurationLevel.Value
    record.Rush.PayLevel = state.RushPayLevel.Value
    record.Factory.ProductionTier = state.ProductionTier.Value
    record.Factory.ResearchTier = state.ResearchTier.Value
    record.Factory.ResearchLabPurchased = state.ResearchLabPurchased.Value
    record.Factory.RejectGalleryPurchased = state.RejectGalleryPurchased.Value
    record.Factory.HouseholdProductionPurchased = state.HouseholdProductionPurchased.Value
    for _, productId in ipairs(Registry.ProductOrder) do record.Products.Unlocked[productId] = state.UnlockedProducts[productId].Value end
    for _, departmentId in ipairs(Departments.Order) do
        record.Products.Departments[departmentId] = state.DepartmentUnlocked[departmentId].Value
        record.Products.DepartmentRevenue[departmentId] = math.max(0, math.floor(state.DepartmentRevenue[departmentId].Value))
    end
    for key in pairs(record.Collection.Archive) do record.Collection.Archive[key] = state.FactoryArchiveDiscoveries[key].Value end
    record.Onboarding.MissingPartIntroduced = state.MissingPartIntroduced.Value
    record.Onboarding.ExtraPartIntroduced = state.ExtraPartIntroduced.Value
    local elapsed = math.max(0, math.floor(os.clock() - session.PlayClock))
    record.Statistics.PlaySeconds = session.BasePlaySeconds + elapsed
    state.PersistentStatistics.PlaySeconds.Value = record.Statistics.PlaySeconds
    for statName in pairs(record.Statistics) do
        if statName ~= "PlaySeconds" then record.Statistics[statName] = state.PersistentStatistics[statName].Value end
    end
    return record
end

local function retryDelay(attempt)
    return math.min(Config.RetryMaxDelay, Config.RetryBaseDelay * (2 ^ math.max(0, attempt - 1)))
end

local function storeKey(player)
    return "Player_" .. tostring(player.UserId)
end

local function performLoad(player, sessionId)
    local key = storeKey(player)
    local conflict = false
    local unsupported
    local wasNew = false
    local loaded
    if useMemoryAdapter then
        local current = memoryRecords[key]
        wasNew = current == nil
        local validated, err = validateRecord(current, true)
        if not validated then return nil, err end
        local now = os.time()
        if validated._Meta.SessionId ~= "" and validated._Meta.SessionId ~= sessionId
            and now - validated._Meta.SessionTouchedAt < Config.SessionLockTimeout then
            return nil, "SessionConflict"
        end
        validated._Meta.SessionId = sessionId
        validated._Meta.SessionTouchedAt = now
        memoryRecords[key] = deepCopy(validated)
        loaded = validated
    else
        local ok, result = pcall(function()
            return dataStore:UpdateAsync(key, function(current)
                wasNew = current == nil
                local validated, err = validateRecord(current, true)
                if not validated then unsupported = err; return nil end
                local now = os.time()
                if validated._Meta.SessionId ~= "" and validated._Meta.SessionId ~= sessionId
                    and now - validated._Meta.SessionTouchedAt < Config.SessionLockTimeout then
                    conflict = true
                    return nil
                end
                validated._Meta.SessionId = sessionId
                validated._Meta.SessionTouchedAt = now
                return validated
            end)
        end)
        if not ok then return nil, tostring(result) end
        if unsupported then return nil, unsupported end
        if conflict then return nil, "SessionConflict" end
        loaded = result
    end
    return loaded, nil, wasNew
end

local function performSave(player, session, reason, releaseSession)
    local snapshot = snapshotSession(session)
    local key = storeKey(player)
    local conflict = false
    local newRevision
    local now = os.time()
    if useMemoryAdapter then
        local current = memoryRecords[key]
        if current and current._Meta and current._Meta.SessionId ~= session.SessionId
            and ((current._Meta.SessionId ~= "" and now - (current._Meta.SessionTouchedAt or 0) < Config.SessionLockTimeout)
                or (current._Meta.SaveRevision or 0) > session.LastKnownRevision) then
            return false, "SessionConflict"
        end
        newRevision = math.max(snapshot._Meta.SaveRevision or 0, current and current._Meta and current._Meta.SaveRevision or 0) + 1
        snapshot._Meta.SaveRevision = newRevision
        snapshot._Meta.LastSavedAt = now
        snapshot._Meta.SessionTouchedAt = now
        snapshot._Meta.SessionId = releaseSession and "" or session.SessionId
        memoryRecords[key] = deepCopy(snapshot)
    else
        local ok, result = pcall(function()
            return dataStore:UpdateAsync(key, function(current)
                local currentMeta = type(current) == "table" and type(current._Meta) == "table" and current._Meta or {}
                local currentSession = typeof(currentMeta.SessionId) == "string" and currentMeta.SessionId or ""
                local currentTouched = finiteNumber(currentMeta.SessionTouchedAt) and currentMeta.SessionTouchedAt or 0
                local currentRevision = finiteNumber(currentMeta.SaveRevision) and currentMeta.SaveRevision or 0
                if currentSession ~= session.SessionId
                    and ((currentSession ~= "" and now - currentTouched < Config.SessionLockTimeout)
                        or currentRevision > session.LastKnownRevision) then
                    conflict = true
                    return nil
                end
                newRevision = math.max(snapshot._Meta.SaveRevision or 0, finiteNumber(currentMeta.SaveRevision) and currentMeta.SaveRevision or 0) + 1
                snapshot._Meta.SaveRevision = newRevision
                snapshot._Meta.LastSavedAt = now
                snapshot._Meta.SessionTouchedAt = now
                snapshot._Meta.SessionId = releaseSession and "" or session.SessionId
                return snapshot
            end)
        end)
        if not ok then return false, tostring(result) end
        if conflict then return false, "SessionConflict" end
        if result == nil then return false, "UpdateCancelled" end
    end
    session.Record = deepCopy(snapshot)
    session.Record._Meta.SaveRevision = newRevision or session.Record._Meta.SaveRevision
    session.LastKnownRevision = session.Record._Meta.SaveRevision
    session.BasePlaySeconds = snapshot.Statistics.PlaySeconds
    session.PlayClock = os.clock()
    session.Dirty = false
    session.LastSaveClock = os.clock()
    if RunService:IsStudio() then print(string.format("[PlayerData] Saved %s revision %d (%s)", player.Name, session.Record._Meta.SaveRevision, reason)) end
    return true
end

function PlayerDataService.Initialize(stateFolder)
    if initialized then return end
    initialized = true
    state = stateFolder
    activeStoreName = RunService:IsStudio() and Config.UseTestDataStoreInStudio and Config.StudioDataStoreName or Config.ProductionDataStoreName
    useMemoryAdapter = RunService:IsStudio() and game.PlaceId == 0 and Config.UseMemoryStoreWhenUnpublishedStudio
    if not useMemoryAdapter then dataStore = DataStoreService:GetDataStore(activeStoreName) end

    local persistentPaths = {
        "Credits", "LineRevenue", "ProductValueLevel", "BeltSpeedLevel", "CurrentOperatingTier",
        "InspectionRunwayLevel", "AnomalyLuckLevel", "AnomalyQualityLevel", "StreakShieldLevel",
        "RushDurationLevel", "RushPayLevel", "ProductionTier", "ResearchTier", "ResearchLabPurchased",
        "RejectGalleryPurchased", "HouseholdProductionPurchased", "MissingPartIntroduced", "ExtraPartIntroduced",
    }
    for _, productId in ipairs(Registry.ProductOrder) do table.insert(persistentPaths, "UnlockedProducts." .. productId) end
    for _, departmentId in ipairs(Departments.Order) do
        table.insert(persistentPaths, "DepartmentUnlocked." .. departmentId)
        table.insert(persistentPaths, "DepartmentRevenue." .. departmentId)
    end
    for key in pairs(DEFAULT_DATA.Collection.Archive) do table.insert(persistentPaths, "FactoryArchiveDiscoveries." .. key) end
    for statName in pairs(DEFAULT_DATA.Statistics) do table.insert(persistentPaths, "PersistentStatistics." .. statName) end
    for _, path in ipairs(persistentPaths) do
        table.insert(connections, value(path):GetPropertyChangedSignal("Value"):Connect(function()
            if not applying then PlayerDataService.MarkDirty("StateChanged", false) end
        end))
    end

    Players.PlayerRemoving:Connect(function(player)
        local session = sessions[player]
        if session then
            if sessionEndingCallback then
                local ok, err = pcall(sessionEndingCallback, player, snapshotSession(session))
                if not ok then warn("[PlayerData] Session-ending callback failed: " .. tostring(err)) end
            end
            PlayerDataService.Save(player, "Leave", true)
            sessions[player] = nil
            if state.ActivePlayerUserId.Value == player.UserId then
                state.ActivePlayerUserId.Value = 0
                state.DataLoaded.Value = false
            end
        end
    end)

    game:BindToClose(function()
        local pending = 0
        for player in pairs(sessions) do
            pending += 1
            task.spawn(function()
                PlayerDataService.Save(player, "Shutdown", true)
                pending -= 1
            end)
        end
        local deadline = os.clock() + Config.ShutdownTimeout
        while pending > 0 and os.clock() < deadline do task.wait(0.1) end
        if pending > 0 then warn("[PlayerData] Shutdown timeout with " .. tostring(pending) .. " save(s) pending.") end
    end)

    task.spawn(function()
        while true do
            task.wait(Config.AutosaveInterval)
            for player, session in pairs(sessions) do
                if player.Parent and session.Dirty then PlayerDataService.Save(player, "Autosave", false) end
            end
        end
    end)
end

function PlayerDataService.SetSessionEndingCallback(callback)
    sessionEndingCallback = callback
end

function PlayerDataService.Load(player)
    if not initialized then error("PlayerDataService.Initialize must be called first") end
    if next(sessions) ~= nil then return false, "FactoryOccupied" end
    state.DataLoaded.Value = false
    state.DataLoadFailed.Value = ""
    local sessionId = HttpService:GenerateGUID(false) .. ":" .. tostring(game.JobId)
    if RunService:IsStudio() and Config.DebugResetPlayerData then
        if useMemoryAdapter then
            memoryRecords[storeKey(player)] = nil
        else
            local ok, err = pcall(function() dataStore:RemoveAsync(storeKey(player)) end)
            if not ok then warn("[PlayerData] Explicit Studio reset failed: " .. tostring(err)) end
        end
    end

    local loaded, loadError, wasNew
    for attempt = 1, Config.MaximumLoadRetries do
        loaded, loadError, wasNew = performLoad(player, sessionId)
        if loaded then break end
        if loadError == "SessionConflict" or string.find(tostring(loadError), "Unsupported future schema", 1, true) then break end
        warn(string.format("[PlayerData] Load attempt %d/%d failed for %s: %s", attempt, Config.MaximumLoadRetries, player.Name, tostring(loadError)))
        if attempt < Config.MaximumLoadRetries then task.wait(retryDelay(attempt)) end
    end
    if not loaded then
        state.DataLoadFailed.Value = loadError == "SessionConflict"
            and "Your factory is already active on another server. Please wait a moment and rejoin."
            or "Your factory data could not be loaded safely. Please rejoin in a moment."
        return false, loadError
    end

    if RunService:IsStudio() and Config.DebugSeedPlayerData then
        local root = workspace:FindFirstChild("FindTheDefectStage0")
        local seedJson = root and root:GetAttribute("DebugPlayerDataSeedJson")
        if typeof(seedJson) == "string" and seedJson ~= "" then
            local decodedOk, decoded = pcall(HttpService.JSONDecode, HttpService, seedJson)
            if decodedOk then
                local seeded, seedError = validateRecord(decoded, true)
                if seeded then
                    seeded._Meta.SessionId = sessionId
                    seeded._Meta.SessionTouchedAt = os.time()
                    loaded = seeded
                    wasNew = false
                    print("[PlayerData] Applied explicit Studio seed profile.")
                else
                    warn("[PlayerData] Studio seed rejected: " .. tostring(seedError))
                end
            else
                warn("[PlayerData] Studio seed JSON was invalid: " .. tostring(decoded))
            end
        end
    end

    applyRecord(loaded)
    local returning = loaded.Onboarding.HasPlayedBefore
    loaded.Onboarding.HasPlayedBefore = true
    sessions[player] = {
        SessionId = sessionId,
        Record = loaded,
        WasNew = wasNew,
        WasReturning = returning,
        Dirty = true,
        CheckpointScheduled = false,
        LastSaveClock = os.clock(),
        LastKnownRevision = loaded._Meta.SaveRevision,
        BasePlaySeconds = loaded.Statistics.PlaySeconds,
        PlayClock = os.clock(),
    }
    state.ActivePlayerUserId.Value = player.UserId
    state.DataLoadFailed.Value = ""
    print(string.format("[PlayerData] Loaded %s schema %d from %s%s", player.Name, loaded.SchemaVersion, activeStoreName, useMemoryAdapter and " (unpublished Studio memory adapter)" or ""))
    return true, {WasNew = wasNew, WasReturning = returning, Record = deepCopy(loaded)}
end

function PlayerDataService.CompleteLoad(player)
    if state.ActivePlayerUserId.Value ~= player.UserId or not sessions[player] then return false end
    state.DataLoaded.Value = true
    return true
end

function PlayerDataService.IsReady(player)
    return state and state.DataLoaded.Value and state.ActivePlayerUserId.Value == player.UserId and sessions[player] ~= nil
end

function PlayerDataService.GetActivePlayer()
    for player in pairs(sessions) do return player end
    return nil
end

function PlayerDataService.GetRecord(player)
    local session = sessions[player]
    return session and deepCopy(snapshotSession(session)) or nil
end

function PlayerDataService.GetOnboardingFlag(player, flag)
    local session = sessions[player]
    return session and session.Record.Onboarding[flag] == true or false
end

function PlayerDataService.SetOnboardingFlag(player, flag, enabled, important)
    local session = sessions[player]
    if not session or session.Record.Onboarding[flag] == nil then return false end
    session.Record.Onboarding[flag] = enabled == true
    PlayerDataService.MarkDirty("Onboarding." .. flag, important)
    return true
end

function PlayerDataService.GetFunnelFlag(player, flag)
    local session = sessions[player]
    return session and session.Record.Funnel[flag] == true or false
end

function PlayerDataService.SetFunnelFlag(player, flag)
    local session = sessions[player]
    if not session or session.Record.Funnel[flag] == nil then return false end
    session.Record.Funnel[flag] = true
    PlayerDataService.MarkDirty("Funnel." .. flag, false)
    return true
end

function PlayerDataService.IncrementStat(player, statName, amount)
    local session = sessions[player]
    local stat = state and state:FindFirstChild("PersistentStatistics") and state.PersistentStatistics:FindFirstChild(statName)
    if not session or not stat or not finiteNumber(amount) then return false end
    local nextValue = math.clamp(stat.Value + math.max(0, math.floor(amount)), 0, 9e15)
    stat.Value = nextValue
    return true
end

function PlayerDataService.MarkDirty(reason, important)
    local player = PlayerDataService.GetActivePlayer()
    local session = player and sessions[player]
    if not session then return end
    session.Dirty = true
    session.LastDirtyReason = reason
    if important and not session.CheckpointScheduled then
        session.CheckpointScheduled = true
        task.delay(Config.ImportantSaveDelay, function()
            session.CheckpointScheduled = false
            if not sessions[player] or not session.Dirty or not player.Parent then return end
            local spacing = os.clock() - session.LastSaveClock
            if spacing < Config.MinimumSaveSpacing then
                task.delay(Config.MinimumSaveSpacing - spacing, function()
                    if sessions[player] and session.Dirty and player.Parent then PlayerDataService.Save(player, "Checkpoint:" .. tostring(reason), false) end
                end)
            else
                PlayerDataService.Save(player, "Checkpoint:" .. tostring(reason), false)
            end
        end)
    end
end

function PlayerDataService.Save(player, reason, releaseSession)
    local session = sessions[player]
    if not session then return false, "NoSession" end
    if session.Saving then return false, "SaveAlreadyInProgress" end
    if not session.Dirty and not releaseSession then return true end
    session.Saving = true
    local success, lastError
    for attempt = 1, Config.MaximumSaveRetries do
        success, lastError = performSave(player, session, reason or "Manual", releaseSession == true)
        if success then break end
        warn(string.format("[PlayerData] Save attempt %d/%d failed for %s (%s): %s", attempt, Config.MaximumSaveRetries, player.Name, tostring(reason), tostring(lastError)))
        if lastError == "SessionConflict" then break end
        if attempt < Config.MaximumSaveRetries then task.wait(retryDelay(attempt)) end
    end
    session.Saving = false
    if not success then warn("[PlayerData] FINAL SAVE FAILURE for " .. player.Name .. " (" .. tostring(reason) .. "): " .. tostring(lastError)) end
    return success, lastError
end

function PlayerDataService.GetStoreInfo()
    return {
        ActiveName = activeStoreName,
        ProductionName = Config.ProductionDataStoreName,
        StudioName = Config.StudioDataStoreName,
        SchemaVersion = Config.SchemaVersion,
        AutosaveInterval = Config.AutosaveInterval,
        MaximumLoadRetries = Config.MaximumLoadRetries,
        MaximumSaveRetries = Config.MaximumSaveRetries,
        MemoryAdapter = useMemoryAdapter,
    }
end

function PlayerDataService.GetBudget()
    if useMemoryAdapter then return {Adapter = "Memory", StandardRead = math.huge, StandardWrite = math.huge} end
    local readOk, readBudget = pcall(function()
        return DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.StandardRead)
    end)
    local writeOk, writeBudget = pcall(function()
        return DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.StandardWrite)
    end)
    return {
        Adapter = "DataStore",
        StandardRead = readOk and readBudget or -1,
        StandardWrite = writeOk and writeBudget or -1,
    }
end

function PlayerDataService.GetDefaultData()
    return deepCopy(DEFAULT_DATA)
end

function PlayerDataService.RunSelfTests()
    local results = {}
    local migration, migrationError = validateRecord({Credits = 321, ProductValueLevel = 3, UnlockedProducts = {TeddyBear = true}}, false)
    results.Migration = migration ~= nil and migrationError == nil
        and migration.SchemaVersion == 1 and migration.Economy.Credits == 321
        and migration.Line.ProductValueLevel == 3 and migration.Factory.HouseholdProductionPurchased == false

    local corrupt = deepCopy(DEFAULT_DATA)
    corrupt.Economy.Credits = -500
    corrupt.Line.BeltMotorTier = 999
    corrupt.Line.OperatingTier = 999
    corrupt.Collection.Archive.Golden_TeddyBear = "yes"
    local repaired = validateRecord(corrupt, false)
    results.CorruptRepair = repaired.Economy.Credits == 0
        and repaired.Line.BeltMotorTier == #UpgradeConfig.Upgrades.BeltMotor.Levels
        and repaired.Line.OperatingTier == repaired.Line.BeltMotorTier
        and repaired.Collection.Archive.Golden_TeddyBear == false

    local cycle1 = deepCopy(DEFAULT_DATA)
    cycle1.Economy.Credits = 875
    cycle1.Economy.LineRevenue = 1200
    cycle1.Line.ProductValueLevel = 2
    cycle1.Products.Unlocked.RubberDuck = true
    cycle1.Collection.Archive.Golden_TeddyBear = true
    cycle1.Onboarding.HasPlayedBefore = true
    cycle1.Onboarding.HasCompletedFirstShift = true
    cycle1.Statistics.TotalProductsHandled = 42
    cycle1 = validateRecord(cycle1, false)

    local cycle2 = deepCopy(cycle1)
    cycle2.Economy.Credits = 4200
    cycle2.Factory.ProductionTier = 2
    cycle2.Factory.RejectGalleryPurchased = true
    cycle2.Factory.HouseholdProductionPurchased = true
    cycle2.Products.Departments.Household = true
    cycle2.Products.Unlocked.Mug = true
    cycle2.Collection.Archive.Glitched_Mug = true
    cycle2.Statistics.TotalProductsHandled = 110
    cycle2 = validateRecord(cycle2, false)

    local cycle3 = validateRecord(deepCopy(cycle2), false)
    results.Cycle1 = cycle1.Economy.Credits == 875 and cycle1.Collection.Archive.Golden_TeddyBear
    results.Cycle2 = cycle2.Factory.RejectGalleryPurchased and cycle2.Factory.HouseholdProductionPurchased and cycle2.Collection.Archive.Glitched_Mug
    results.Cycle3 = cycle3.Economy.Credits >= cycle1.Economy.Credits
        and cycle3.Statistics.TotalProductsHandled == 110
        and cycle3.Products.Unlocked.Mug
        and cycle3.Collection.Archive.Golden_TeddyBear
        and cycle3.Collection.Archive.Glitched_Mug

    local matrix = deepCopy(DEFAULT_DATA)
    matrix.Economy.Credits = 765432
    matrix.Economy.LineRevenue = 456789
    matrix.Line.ProductValueLevel = #UpgradeConfig.Upgrades.ProductValue.Levels
    matrix.Line.BeltMotorTier = #UpgradeConfig.Upgrades.BeltMotor.Levels
    matrix.Line.OperatingTier = 7
    matrix.Line.InspectionRunwayLevel = #UpgradeConfig.Upgrades.InspectionRunway.Levels
    matrix.Research.AnomalyLuckLevel = #UpgradeConfig.Upgrades.AnomalyLuck.Levels
    matrix.Research.AnomalyQualityLevel = #UpgradeConfig.Upgrades.AnomalyQuality.Levels
    matrix.Inspector.StreakShieldLevel = #UpgradeConfig.Upgrades.StreakShield.Levels - 1
    matrix.Rush.DurationLevel = #UpgradeConfig.Upgrades.RushDuration.Levels
    matrix.Rush.PayLevel = #UpgradeConfig.Upgrades.RushPay.Levels
    matrix.Factory.ProductionTier = maxFactoryTier("Production")
    matrix.Factory.ResearchTier = maxFactoryTier("Research")
    matrix.Factory.ResearchLabPurchased = true
    matrix.Factory.RejectGalleryPurchased = true
    matrix.Factory.HouseholdProductionPurchased = true
    for productId in pairs(matrix.Products.Unlocked) do matrix.Products.Unlocked[productId] = true end
    for departmentId in pairs(matrix.Products.Departments) do
        matrix.Products.Departments[departmentId] = true
        matrix.Products.DepartmentRevenue[departmentId] = 54321
    end
    for key in pairs(matrix.Collection.Archive) do matrix.Collection.Archive[key] = true end
    matrix.Onboarding.HasPlayedBefore = true
    matrix.Onboarding.HasCompletedFirstShift = true
    matrix.Onboarding.EarlyGoldenGuaranteeSatisfied = true
    matrix.Onboarding.MissingPartIntroduced = true
    matrix.Onboarding.ExtraPartIntroduced = true
    for key in pairs(matrix.Statistics) do matrix.Statistics[key] = 100 end
    matrix = validateRecord(matrix, false)
    local matrixArchiveCount = 0
    for _, discovered in pairs(matrix.Collection.Archive) do if discovered then matrixArchiveCount += 1 end end
    local matrixProducts = 0
    for _, unlocked in pairs(matrix.Products.Unlocked) do if unlocked then matrixProducts += 1 end end
    results.SaveMatrix = matrix.Economy.Credits == 765432
        and matrix.Economy.LineRevenue == 456789
        and matrix.Line.ProductValueLevel == #UpgradeConfig.Upgrades.ProductValue.Levels
        and matrix.Line.BeltMotorTier == #UpgradeConfig.Upgrades.BeltMotor.Levels
        and matrix.Line.OperatingTier == 7
        and matrix.Line.InspectionRunwayLevel == #UpgradeConfig.Upgrades.InspectionRunway.Levels
        and matrix.Research.AnomalyLuckLevel == #UpgradeConfig.Upgrades.AnomalyLuck.Levels
        and matrix.Research.AnomalyQualityLevel == #UpgradeConfig.Upgrades.AnomalyQuality.Levels
        and matrix.Inspector.StreakShieldLevel == #UpgradeConfig.Upgrades.StreakShield.Levels - 1
        and matrix.Rush.DurationLevel == #UpgradeConfig.Upgrades.RushDuration.Levels
        and matrix.Rush.PayLevel == #UpgradeConfig.Upgrades.RushPay.Levels
        and matrix.Factory.ProductionTier == maxFactoryTier("Production")
        and matrix.Factory.ResearchTier == maxFactoryTier("Research")
        and matrix.Factory.ResearchLabPurchased
        and matrix.Factory.RejectGalleryPurchased
        and matrix.Factory.HouseholdProductionPurchased
        and matrixProducts == #Registry.ProductOrder
        and matrixArchiveCount == AnomalyConfig.ArchiveSize
        and matrix.Onboarding.HasCompletedFirstShift
        and matrix.Statistics.TotalProductsHandled == 100

    local d1 = PlayerDataService.GetDefaultData()
    d1.Economy.Credits = 999
    results.DefaultDeepCopy = PlayerDataService.GetDefaultData().Economy.Credits == 0
    results.AllPassed = results.Migration and results.CorruptRepair and results.Cycle1 and results.Cycle2 and results.Cycle3 and results.SaveMatrix and results.DefaultDeepCopy
    return results
end

return PlayerDataService
