-- The player record: its shape, its defaults, and how a stored record is made safe.
--
-- ProfileStore stores and locks the record; this module decides what a valid one
-- looks like. Repair never trusts what it loads: numbers are clamped to what the
-- configs allow, wrong types fall back to defaults, and every change is reported.
-- Two rules keep a bad deploy from destroying data:
--   * a record from a NEWER schema is refused, never "repaired" down;
--   * keys this version does not know are KEPT, not dropped, so a removed or
--     renamed product does not erase its discoveries on the next save.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Products = Config.Products
local Departments = Config.Departments
local Upgrades = Config.Upgrades
local Anomalies = Config.Anomalies
local Factory = Config.Factory
local Tutorial = Config.Tutorial

local Schema = {}

Schema.Version = 2
local MAX_AMOUNT = 9e15

local function deepCopy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, child in pairs(value) do copy[key] = deepCopy(child) end
    return copy
end
Schema.DeepCopy = deepCopy

-- Upgrade levels live in these sections of the record.
Schema.UpgradeFields = {
    ProductValue = { "Line", "ProductValueLevel" },
    BeltMotor = { "Line", "BeltMotorTier" },
    InspectionRunway = { "Line", "InspectionRunwayLevel" },
    AnomalyLuck = { "Research", "AnomalyLuckLevel" },
    AnomalyQuality = { "Research", "AnomalyQualityLevel" },
    StreakShield = { "Inspector", "StreakShieldLevel" },
    RushDuration = { "Rush", "DurationLevel" },
    RushPay = { "Rush", "PayLevel" },
}

function Schema.Template()
    local unlocked, departments, revenue, archive = {}, {}, {}, {}
    for _, productId in ipairs(Products.Order) do unlocked[productId] = false end
    for _, departmentId in ipairs(Departments.Order) do
        local definition = Departments.Definitions[departmentId]
        departments[departmentId] = definition.DefaultUnlocked
        revenue[departmentId] = 0
        if definition.DefaultUnlocked then unlocked[definition.StarterProduct] = true end
    end
    for _, anomalyId in ipairs(Anomalies.ArchiveRows) do
        for _, productId in ipairs(Products.Order) do
            archive[Anomalies.DiscoveryKey(productId, anomalyId)] = false
        end
    end

    local record = {
        SchemaVersion = Schema.Version,
        Economy = { Credits = 0, LineRevenue = 0 },
        Line = { ProductValueLevel = 1, BeltMotorTier = 1, OperatingTier = 1, InspectionRunwayLevel = 1 },
        Research = { AnomalyLuckLevel = 1, AnomalyQualityLevel = 1 },
        Inspector = { StreakShieldLevel = 0 },
        Rush = { DurationLevel = 1, PayLevel = 1 },
        Factory = {
            ProductionTier = Factory.BaseTier.Production,
            ResearchTier = Factory.BaseTier.Research,
            RejectGalleryPurchased = false,
            HouseholdProductionPurchased = false,
        },
        Products = { Unlocked = unlocked, Departments = departments, DepartmentRevenue = revenue },
        Collection = { Archive = archive },
        Onboarding = {
            TutorialStep = 0,
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
            BestStreak = 0,
            PlaySeconds = 0,
        },
        Funnel = { FirstProductHandled = false, FirstDefectCaught = false, FirstUpgradePurchased = false },
    }
    return record
end

----------------------------------------------------------------------------------------
-- Migrations: Migrations[n] turns a version-n record into version n+1.

local Migrations = {}

-- v1: the legacy PlayerDataService record. Same sections, plus _Meta (session
-- locking, now ProfileStore's job), a duplicated ResearchLabPurchased, and
-- onboarding as two booleans instead of a step.
Migrations[1] = function(record)
    record._Meta = nil
    if type(record.Factory) == "table" then record.Factory.ResearchLabPurchased = nil end
    local onboarding = type(record.Onboarding) == "table" and record.Onboarding or {}
    if onboarding.TutorialStep == nil then
        onboarding.TutorialStep = onboarding.HasCompletedFirstShift == true and #Tutorial.Steps or 0
    end
    onboarding.HasCompletedFirstShift = nil
    onboarding.HasPlayedBefore = nil
    record.Onboarding = onboarding
    return record
end

Schema.Migrations = Migrations

----------------------------------------------------------------------------------------
-- Repair

local function finiteNumber(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local Repairer = {}
Repairer.__index = Repairer

function Repairer:note(message) table.insert(self.repairs, message) end

function Repairer:number(source, key, path, default, minimum, maximum)
    local value = type(source) == "table" and source[key] or nil
    if value == nil then return default end
    if not finiteNumber(value) then
        self:note(path .. " invalid; defaulted")
        return default
    end
    local fixed = math.floor(math.clamp(value, minimum, maximum))
    if fixed ~= value then self:note(path .. " clamped") end
    return fixed
end

function Repairer:boolean(source, key, path, default)
    local value = type(source) == "table" and source[key] or nil
    if value == nil then return default end
    if type(value) ~= "boolean" then
        self:note(path .. " invalid; defaulted")
        return default
    end
    return value
end

-- Copy keys the template does not know, untouched, so newer or retired data survives.
function Repairer:keepUnknown(source, target, path)
    if type(source) ~= "table" then return end
    for key, value in pairs(source) do
        if target[key] == nil then
            target[key] = deepCopy(value)
            self:note(path .. tostring(key) .. " unknown; kept")
        end
    end
end

local function section(raw, name, repairer)
    local value = raw[name]
    if value == nil then return {} end
    if type(value) ~= "table" then
        repairer:note(name .. " invalid; defaulted")
        return {}
    end
    return value
end

-- Returns (record, repairs) or (nil, errorMessage). Never mutates `raw`.
function Schema.Repair(raw)
    local repairer = setmetatable({ repairs = {} }, Repairer)
    if raw ~= nil and type(raw) ~= "table" then
        repairer:note("record invalid; defaulted")
        raw = nil
    end
    raw = deepCopy(raw or {})

    local version = raw.SchemaVersion
    if version == nil then
        version = next(raw) == nil and Schema.Version or 1
    elseif not finiteNumber(version) or version ~= math.floor(version) or version < 1 then
        return nil, "Invalid schema version " .. tostring(version)
    end
    if version > Schema.Version then
        return nil, "Unsupported future schema " .. tostring(version)
    end
    while version < Schema.Version do
        raw = Migrations[version](raw)
        repairer:note(`migrated schema {version} to {version + 1}`)
        version += 1
    end

    local template = Schema.Template()
    local result = deepCopy(template)

    local economy = section(raw, "Economy", repairer)
    result.Economy.Credits = repairer:number(economy, "Credits", "Economy.Credits", 0, 0, MAX_AMOUNT)
    result.Economy.LineRevenue = repairer:number(economy, "LineRevenue", "Economy.LineRevenue", 0, 0, MAX_AMOUNT)
    repairer:keepUnknown(economy, result.Economy, "Economy.")

    local sections = {}
    for upgradeId, field in pairs(Schema.UpgradeFields) do
        local sectionName, key = field[1], field[2]
        sections[sectionName] = sections[sectionName] or section(raw, sectionName, repairer)
        local minimum, maximum = Upgrades.LevelRange(upgradeId)
        result[sectionName][key] = repairer:number(sections[sectionName], key, `{sectionName}.{key}`, template[sectionName][key], minimum, maximum)
    end
    -- The tier the belt is run at can never exceed the motor owned.
    sections.Line = sections.Line or section(raw, "Line", repairer)
    result.Line.OperatingTier = repairer:number(sections.Line, "OperatingTier", "Line.OperatingTier", 1, 1, result.Line.BeltMotorTier)
    for sectionName, source in pairs(sections) do repairer:keepUnknown(source, result[sectionName], sectionName .. ".") end

    local factory = section(raw, "Factory", repairer)
    result.Factory.ProductionTier = repairer:number(factory, "ProductionTier", "Factory.ProductionTier", Factory.BaseTier.Production, Factory.BaseTier.Production, Factory.MaxTier("Production"))
    result.Factory.ResearchTier = repairer:number(factory, "ResearchTier", "Factory.ResearchTier", Factory.BaseTier.Research, Factory.BaseTier.Research, Factory.MaxTier("Research"))
    result.Factory.RejectGalleryPurchased = repairer:boolean(factory, "RejectGalleryPurchased", "Factory.RejectGalleryPurchased", false)
    result.Factory.HouseholdProductionPurchased = repairer:boolean(factory, "HouseholdProductionPurchased", "Factory.HouseholdProductionPurchased", false)
    if result.Factory.HouseholdProductionPurchased then
        local required = Factory.Projects.HouseholdProduction.Requirements.ProductionTier
        result.Factory.ProductionTier = math.max(result.Factory.ProductionTier, required)
    end
    repairer:keepUnknown(factory, result.Factory, "Factory.")

    local products = section(raw, "Products", repairer)
    local rawUnlocked = type(products.Unlocked) == "table" and products.Unlocked or {}
    local rawDepartments = type(products.Departments) == "table" and products.Departments or {}
    local rawRevenue = type(products.DepartmentRevenue) == "table" and products.DepartmentRevenue or {}
    for _, departmentId in ipairs(Departments.Order) do
        local path = "Products.Departments." .. departmentId
        result.Products.Departments[departmentId] = repairer:boolean(rawDepartments, departmentId, path, template.Products.Departments[departmentId])
        result.Products.DepartmentRevenue[departmentId] = repairer:number(rawRevenue, departmentId, "Products.DepartmentRevenue." .. departmentId, 0, 0, MAX_AMOUNT)
    end
    if result.Factory.HouseholdProductionPurchased then result.Products.Departments.Household = true end
    for _, departmentId in ipairs(Departments.Order) do
        if Departments.Definitions[departmentId].DefaultUnlocked then result.Products.Departments[departmentId] = true end
    end
    for _, productId in ipairs(Products.Order) do
        result.Products.Unlocked[productId] = repairer:boolean(rawUnlocked, productId, "Products.Unlocked." .. productId, template.Products.Unlocked[productId])
    end
    -- What revenue has earned is unlocked, whatever the record says.
    for _, departmentId in ipairs(Departments.Order) do
        if result.Products.Departments[departmentId] then
            result.Products.Unlocked[Departments.Definitions[departmentId].StarterProduct] = true
            for _, productId in ipairs(Products.InDepartment(departmentId)) do
                if result.Products.DepartmentRevenue[departmentId] >= Products.Definitions[productId].UnlockRevenue then
                    result.Products.Unlocked[productId] = true
                end
            end
        end
    end
    repairer:keepUnknown(rawUnlocked, result.Products.Unlocked, "Products.Unlocked.")
    repairer:keepUnknown(rawDepartments, result.Products.Departments, "Products.Departments.")
    repairer:keepUnknown(rawRevenue, result.Products.DepartmentRevenue, "Products.DepartmentRevenue.")

    local collection = section(raw, "Collection", repairer)
    local rawArchive = collection.Archive
    if rawArchive ~= nil and type(rawArchive) ~= "table" then
        repairer:note("Collection.Archive invalid; defaulted")
        rawArchive = {}
    end
    rawArchive = rawArchive or {}
    for key in pairs(template.Collection.Archive) do
        result.Collection.Archive[key] = repairer:boolean(rawArchive, key, "Collection.Archive." .. key, false)
    end
    repairer:keepUnknown(rawArchive, result.Collection.Archive, "Collection.Archive.")

    local onboarding = section(raw, "Onboarding", repairer)
    result.Onboarding.TutorialStep = repairer:number(onboarding, "TutorialStep", "Onboarding.TutorialStep", 0, 0, #Tutorial.Steps)
    for _, key in ipairs({ "EarlyGoldenGuaranteeSatisfied", "MissingPartIntroduced", "ExtraPartIntroduced" }) do
        result.Onboarding[key] = repairer:boolean(onboarding, key, "Onboarding." .. key, false)
    end
    repairer:keepUnknown(onboarding, result.Onboarding, "Onboarding.")

    local statistics = section(raw, "Statistics", repairer)
    for key in pairs(template.Statistics) do
        result.Statistics[key] = repairer:number(statistics, key, "Statistics." .. key, 0, 0, MAX_AMOUNT)
    end
    repairer:keepUnknown(statistics, result.Statistics, "Statistics.")

    local funnel = section(raw, "Funnel", repairer)
    result.Funnel.FirstProductHandled = repairer:boolean(funnel, "FirstProductHandled", "Funnel.FirstProductHandled", false)
        or result.Statistics.TotalProductsHandled > 0
    result.Funnel.FirstDefectCaught = repairer:boolean(funnel, "FirstDefectCaught", "Funnel.FirstDefectCaught", false)
        or result.Statistics.TotalDefectsCaught > 0
    local anyUpgrade = false
    for upgradeId, field in pairs(Schema.UpgradeFields) do
        if result[field[1]][field[2]] > (Upgrades.LevelRange(upgradeId)) then anyUpgrade = true end
    end
    result.Funnel.FirstUpgradePurchased = repairer:boolean(funnel, "FirstUpgradePurchased", "Funnel.FirstUpgradePurchased", false) or anyUpgrade
    repairer:keepUnknown(funnel, result.Funnel, "Funnel.")

    repairer:keepUnknown(raw, result, "")
    result.SchemaVersion = Schema.Version
    return result, repairer.repairs
end

return Schema
