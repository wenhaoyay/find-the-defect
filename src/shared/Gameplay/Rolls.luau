-- What comes down the line next. Pure functions: every random number comes from
-- the Random passed in, so a seeded Random replays a line exactly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Products = Config.Products
local Inspection = Config.Inspection

local Rolls = {}

local function weightedPick(random, entries)
    local total = 0
    for _, entry in ipairs(entries) do total += math.max(0, entry.Weight) end
    if total <= 0 then return nil end
    local roll = random:NextNumber() * total
    local cumulative = 0
    for _, entry in ipairs(entries) do
        cumulative += math.max(0, entry.Weight)
        if roll < cumulative then return entry.Id end
    end
    return entries[#entries].Id
end
Rolls.WeightedPick = weightedPick

-- spawnIndex counts from 1. The onboarding sequence overrides the first products.
function Rolls.Product(spawnIndex, eligibleProducts, random, lastProduct, repeatCount)
    local scripted = Inspection.OnboardingSequence[spawnIndex]
    if scripted then return scripted.Product end
    if #eligibleProducts == 0 then return Products.Order[1] end

    local entries = {}
    for _, productId in ipairs(eligibleProducts) do
        local weight = Products.Definitions[productId].SpawnWeight
        if productId == lastProduct and (repeatCount or 0) >= Inspection.MaxConsecutiveSameProduct and #eligibleProducts > 1 then
            weight = 0
        end
        table.insert(entries, { Id = productId, Weight = weight })
    end
    return weightedPick(random, entries) or eligibleProducts[1]
end

function Rolls.Defect(spawnIndex, productId, random, rushActive, componentDefectsEnabled)
    local scripted = Inspection.OnboardingSequence[spawnIndex]
    if scripted then return scripted.Defect end
    local product = Products.Definitions[productId]
    if not product then return "Normal" end

    local entries = {}
    for _, defectName in ipairs(product.ValidDefects) do
        if componentDefectsEnabled or not Products.ComponentDefects[defectName] then
            local defect = Products.Defects[defectName]
            table.insert(entries, { Id = defectName, Weight = rushActive and defect.RushWeight or defect.Weight })
        end
    end
    return weightedPick(random, entries) or "Normal"
end

return Rolls
