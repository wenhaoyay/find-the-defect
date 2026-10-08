-- Rare anomaly states: an occurrence roll, then a quality roll between tiers.

local Products = require(script.Parent.Products)

local Anomalies = {}

Anomalies.BaseChance = 0.006
Anomalies.FirstGoldenGuaranteeAfter = 35

-- QualityOrder drives the quality roll; ArchiveRows is the archive's display order.
Anomalies.QualityOrder = { "Glitched", "Golden" }
Anomalies.ArchiveRows = { "Golden", "Glitched" }

Anomalies.Definitions = {
    Golden = {
        Id = "Golden",
        DisplayName = "Golden",
        BaseQualityWeight = 5 / 6,
        Reward = 400,
        Priority = 1,
        ServerAnnouncement = false,
        PrimaryColor = Color3.fromRGB(255, 198, 45),
        SecondaryColor = Color3.fromRGB(255, 232, 125),
        GlowColor = Color3.fromRGB(255, 205, 70),
    },
    Glitched = {
        Id = "Glitched",
        DisplayName = "Glitched",
        BaseQualityWeight = 1 / 6,
        Reward = 1500,
        Priority = 2,
        ServerAnnouncement = true,
        PrimaryColor = Color3.fromRGB(235, 45, 255),
        SecondaryColor = Color3.fromRGB(35, 235, 255),
        GlowColor = Color3.fromRGB(115, 80, 255),
    },
}

Anomalies.ArchiveSize = #Products.Order * #Anomalies.ArchiveRows

function Anomalies.QualityWeights(glitchedShare)
    local share = math.clamp(glitchedShare or Anomalies.Definitions.Glitched.BaseQualityWeight, 0, 1)
    return { Glitched = share, Golden = 1 - share }
end

-- Odds of one tier per eligible product, for labels: computed, never hard-coded,
-- so upgrades and rebalancing cannot leave a stale "1 / 1,000" behind.
function Anomalies.Chance(anomalyId, luckMultiplier, glitchedShare)
    local total = math.clamp(Anomalies.BaseChance * (luckMultiplier or 1), 0, 1)
    return total * Anomalies.QualityWeights(glitchedShare)[anomalyId]
end

function Anomalies.OddsLabel(anomalyId, luckMultiplier, glitchedShare)
    local chance = Anomalies.Chance(anomalyId, luckMultiplier, glitchedShare)
    if chance <= 0 then return "never" end
    return "1 / " .. tostring(math.floor(1 / chance + 0.5))
end

function Anomalies.DiscoveryKey(productId, anomalyId)
    return anomalyId .. "_" .. productId
end

function Anomalies.DisplayName(productId, anomalyId)
    local anomaly = assert(Anomalies.Definitions[anomalyId], "Unknown anomaly: " .. tostring(anomalyId))
    local product = assert(Products.Definitions[productId], "Unknown product: " .. tostring(productId))
    return string.upper(anomaly.DisplayName .. " " .. product.DisplayName)
end

-- The one rule for "rarest find", used live and when restoring a save: a find
-- replaces the current one only if its tier is strictly rarer. Ties keep the first.
function Anomalies.IsRarer(candidateId, currentId)
    if currentId == nil then return candidateId ~= nil end
    if candidateId == nil then return false end
    return Anomalies.Definitions[candidateId].Priority > Anomalies.Definitions[currentId].Priority
end

return Anomalies
