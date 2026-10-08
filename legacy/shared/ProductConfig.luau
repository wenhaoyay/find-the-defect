local Config = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("FindDefectUpgradeConfig"))
local Registry = require(ReplicatedStorage:WaitForChild("FindDefectProductRegistry"))

Config.Conveyor = {
    SpawnX = -29,
    CleanupX = 31,
    InspectionMinX = -7,
    InspectionMaxX = 7,
    BeltSurfaceY = 2.7,
}

Config.ProductOrder = Registry.ProductOrder
Config.Products = Registry.Products
Config.Defects = Registry.Defects
Config.DefectOrder = Registry.DefectOrder
Config.OnboardingSequence = {
    {Product = "TeddyBear", Defect = "Normal"},
    {Product = "TeddyBear", Defect = "WrongColour"},
    {Product = "TeddyBear", Defect = "Normal"},
    {Product = "TeddyBear", Defect = "Giant"},
    {Product = "TeddyBear", Defect = "Normal"},
    {Product = "TeddyBear", Defect = "Tiny"},
}

Config.Upgrades = {
    ProductValue = UpgradeConfig.Upgrades.ProductValue,
    BeltSpeed = UpgradeConfig.Upgrades.BeltMotor,
}

Config.StreakTiers = {
    {Minimum = 100, Multiplier = 3},
    {Minimum = 50, Multiplier = 2},
    {Minimum = 25, Multiplier = 1.5},
    {Minimum = 10, Multiplier = 1.25},
    {Minimum = 0, Multiplier = 1},
}

Config.Rush = UpgradeConfig.Rush

function Config.RollDefect(spawnIndex, productKey, random, rushActive, componentDefectsEnabled)
    local onboarding = Config.OnboardingSequence[spawnIndex]
    if onboarding then return onboarding.Defect end
    local product = Config.Products[productKey]
    if not product then return "Normal" end

    local candidates = {}
    local totalWeight = 0
    for _, defectName in ipairs(product.ValidDefects) do
        local componentDefect = defectName == "MissingPart" or defectName == "ExtraPart"
        if not componentDefect or componentDefectsEnabled then
            local defect = Config.Defects[defectName]
            local weight = rushActive and defect.RushWeight or defect.Weight
            totalWeight += weight
            table.insert(candidates, {Name = defectName, Weight = weight})
        end
    end
    local roll = random:NextNumber() * math.max(totalWeight, 0.000001)
    local cumulative = 0
    for _, candidate in ipairs(candidates) do
        cumulative += candidate.Weight
        if roll <= cumulative then return candidate.Name end
    end
    return "Normal"
end

function Config.RollProduct(spawnIndex, eligibleProducts, random, lastProduct, repeatCount)
    local onboarding = Config.OnboardingSequence[spawnIndex]
    if onboarding then return onboarding.Product end
    if #eligibleProducts == 0 then return "TeddyBear" end

    local weighted = {}
    local total = 0
    for _, productId in ipairs(eligibleProducts) do
        local product = Config.Products[productId]
        local weight = product and product.SpawnWeight or 1
        if productId == lastProduct and (repeatCount or 0) >= 2 and #eligibleProducts > 1 then
            weight = 0
        end
        total += weight
        table.insert(weighted, {Id = productId, Weight = weight})
    end
    local roll = random:NextNumber() * total
    local cumulative = 0
    for _, entry in ipairs(weighted) do
        cumulative += entry.Weight
        if roll <= cumulative then return entry.Id end
    end
    return weighted[#weighted].Id
end

function Config.GetStreakMultiplier(currentStreak)
    for _, tier in ipairs(Config.StreakTiers) do
        if currentStreak >= tier.Minimum then return tier.Multiplier end
    end
    return 1
end

function Config.GetDefectDisplayName(defectName, productKey)
    local defect = Config.Defects[defectName]
    local product = Config.Products[productKey]
    if defectName == "MissingPart" or defectName == "ExtraPart" then
        local componentId = product.ComponentDefects[defectName]
        local prefix = defectName == "MissingPart" and "Missing " or "Extra "
        return prefix .. componentId .. " " .. product.DisplayName
    end
    return defect.DisplayPrefix .. " " .. product.DisplayName
end

return Config