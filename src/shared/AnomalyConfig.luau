local AnomalyConfig = {}
local Registry = require(game:GetService("ReplicatedStorage"):WaitForChild("FindDefectProductRegistry"))

AnomalyConfig.DebugAnomalyMultiplier = 1
AnomalyConfig.DebugForceNextAnomaly = "" -- Studio-only one-shot helper; empty in production.
AnomalyConfig.FirstGoldenGuaranteeAfter = 35
AnomalyConfig.ArchiveSize = #Registry.ProductOrder * 2
AnomalyConfig.BaseCombinedChance = 0.006

AnomalyConfig.ProductOrder = Registry.ProductOrder
AnomalyConfig.ProductNames = {}
for _, productId in ipairs(Registry.ProductOrder) do
    AnomalyConfig.ProductNames[productId] = Registry.Products[productId].DisplayName
end

-- QualityOrder and weights are intentionally generic so future anomaly tiers can be inserted.
AnomalyConfig.QualityOrder = {"Glitched", "Golden"}
AnomalyConfig.ArchiveRows = {"Golden", "Glitched"}

AnomalyConfig.Anomalies = {
    Golden = {
        Id = "Golden",
        DisplayName = "Golden",
        Probability = 0.005,
        BaseQualityWeight = 5 / 6,
        BaseOddsLabel = "1 / 200",
        Reward = 400,
        Priority = 1,
        ServerAnnouncement = false,
        PrimaryColor = Color3.fromRGB(255, 198, 45),
        SecondaryColor = Color3.fromRGB(255, 232, 125),
        DarkColor = Color3.fromRGB(105, 70, 20),
        GlowColor = Color3.fromRGB(255, 205, 70),
        ParticleTexture = "rbxasset://textures/particles/sparkles_main.dds",
        ParticleRate = 3,
        BurstCount = 48,
        Audio = {
            CueId = "rbxasset://sounds/electronicpingshort.wav",
            CueVolume = 0.24,
            CuePlaybackSpeed = 1.35,
            CatchId = "rbxasset://sounds/electronicpingshort.wav",
            CatchVolume = 0.72,
            CatchPlaybackSpeed = 0.82,
        },
    },
    Glitched = {
        Id = "Glitched",
        DisplayName = "Glitched",
        Probability = 0.001,
        BaseQualityWeight = 1 / 6,
        BaseOddsLabel = "1 / 1,000",
        Reward = 1500,
        Priority = 2,
        ServerAnnouncement = true,
        PrimaryColor = Color3.fromRGB(235, 45, 255),
        SecondaryColor = Color3.fromRGB(35, 235, 255),
        DarkColor = Color3.fromRGB(18, 14, 24),
        GlowColor = Color3.fromRGB(115, 80, 255),
        ParticleTexture = "rbxasset://textures/particles/sparkles_main.dds",
        ParticleRate = 5,
        BurstCount = 72,
        Audio = {
            CueId = "rbxasset://sounds/electronicpingshort.wav",
            CueVolume = 0.32,
            CuePlaybackSpeed = 0.55,
            CatchId = "rbxasset://sounds/electronicpingshort.wav",
            CatchVolume = 0.78,
            CatchPlaybackSpeed = 0.48,
            DistortionLevel = 0.62,
        },
    },
}

function AnomalyConfig.GetQualityWeights(glitchedShare)
    local share = math.clamp(glitchedShare or AnomalyConfig.Anomalies.Glitched.BaseQualityWeight, 0, 1)
    return {
        Glitched = share,
        Golden = 1 - share,
    }
end

function AnomalyConfig.GetDiscoveryKey(productKey, anomalyId)
    return anomalyId .. "_" .. productKey
end

function AnomalyConfig.GetDisplayName(productKey, anomalyId)
    local anomaly = assert(AnomalyConfig.Anomalies[anomalyId], "Unknown anomaly: " .. tostring(anomalyId))
    local productName = assert(AnomalyConfig.ProductNames[productKey], "Unknown product: " .. tostring(productKey))
    return string.upper(anomaly.DisplayName .. " " .. productName)
end

return AnomalyConfig