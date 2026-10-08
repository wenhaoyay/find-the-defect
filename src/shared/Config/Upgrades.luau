-- Purchasable upgrades. Level 1 of each is what a new player has (Cost 0).
-- StreakShield is the exception: level 0 means "not owned", so its Levels table
-- is indexed level + 1.

local Upgrades = {}

Upgrades.CategoryOrder = { "LINE", "RESEARCH", "INSPECTOR", "RUSH" }
Upgrades.Order = {
    LINE = { "ProductValue", "BeltMotor", "InspectionRunway" },
    RESEARCH = { "AnomalyLuck", "AnomalyQuality" },
    INSPECTOR = { "StreakShield" },
    RUSH = { "RushDuration", "RushPay" },
}

Upgrades.Definitions = {
    ProductValue = {
        Category = "LINE",
        DisplayName = "PRODUCT VALUE",
        Levels = {
            { Multiplier = 1.00, Cost = 0 },
            { Multiplier = 1.25, Cost = 75 },
            { Multiplier = 1.60, Cost = 250 },
            { Multiplier = 2.10, Cost = 650 },
            { Multiplier = 2.80, Cost = 1800 },
            { Multiplier = 3.70, Cost = 5000 },
            { Multiplier = 5.00, Cost = 15000 },
            { Multiplier = 6.75, Cost = 45000 },
        },
    },
    BeltMotor = {
        Category = "LINE",
        DisplayName = "BELT MOTOR",
        Levels = {
            { Speed = 7, SpawnInterval = 1.50, Cost = 0 },
            { Speed = 8.5, SpawnInterval = 1.25, Cost = 120 },
            { Speed = 10, SpawnInterval = 1.00, Cost = 350 },
            { Speed = 12, SpawnInterval = 0.80, Cost = 900 },
            { Speed = 14, SpawnInterval = 0.70, Cost = 2000 },
            { Speed = 16, SpawnInterval = 0.62, Cost = 4500 },
            { Speed = 18, SpawnInterval = 0.55, Cost = 10000 },
            { Speed = 20, SpawnInterval = 0.49, Cost = 22000 },
            { Speed = 22, SpawnInterval = 0.44, Cost = 48000 },
            { Speed = 24, SpawnInterval = 0.40, Cost = 100000 },
        },
    },
    InspectionRunway = {
        Category = "LINE",
        DisplayName = "INSPECTION RUNWAY",
        Levels = {
            { Length = 14, Cost = 0 },
            { Length = 18, Cost = 300 },
            { Length = 22, Cost = 1200 },
            { Length = 26, Cost = 4500 },
            { Length = 30, Cost = 15000 },
            { Length = 34, Cost = 50000 },
        },
    },
    AnomalyLuck = {
        Category = "RESEARCH",
        DisplayName = "ANOMALY LUCK",
        Levels = {
            { Multiplier = 1.00, Cost = 0 },
            { Multiplier = 1.10, Cost = 500 },
            { Multiplier = 1.20, Cost = 1200 },
            { Multiplier = 1.35, Cost = 3000 },
            { Multiplier = 1.50, Cost = 7000 },
            { Multiplier = 1.70, Cost = 16000 },
            { Multiplier = 1.95, Cost = 35000 },
            { Multiplier = 2.25, Cost = 75000 },
            { Multiplier = 2.60, Cost = 160000 },
            { Multiplier = 3.00, Cost = 350000 },
        },
    },
    AnomalyQuality = {
        Category = "RESEARCH",
        DisplayName = "ANOMALY QUALITY",
        Levels = {
            { GlitchedShare = 1 / 6, Cost = 0 },
            { GlitchedShare = 0.18, Cost = 3000 },
            { GlitchedShare = 0.20, Cost = 10000 },
            { GlitchedShare = 0.22, Cost = 35000 },
            { GlitchedShare = 0.25, Cost = 120000 },
        },
    },
    StreakShield = {
        Category = "INSPECTOR",
        DisplayName = "STREAK SHIELD",
        ZeroBased = true,
        Levels = {
            { Recharge = 0, Cost = 0 },
            { Recharge = 80, Cost = 2500 },
            { Recharge = 60, Cost = 12000 },
            { Recharge = 40, Cost = 50000 },
        },
    },
    RushDuration = {
        Category = "RUSH",
        DisplayName = "RUSH DURATION",
        Levels = {
            { Duration = 30, Cost = 0 },
            { Duration = 33, Cost = 3000 },
            { Duration = 36, Cost = 10000 },
            { Duration = 40, Cost = 30000 },
            { Duration = 45, Cost = 90000 },
        },
    },
    RushPay = {
        Category = "RUSH",
        DisplayName = "RUSH PAY",
        Levels = {
            { Multiplier = 2.00, Cost = 0 },
            { Multiplier = 2.10, Cost = 5000 },
            { Multiplier = 2.20, Cost = 15000 },
            { Multiplier = 2.35, Cost = 45000 },
            { Multiplier = 2.50, Cost = 135000 },
        },
    },
}

Upgrades.Rush = {
    FirstDelay = 150,
    RepeatDelay = 180,
    WarningDuration = 5,
    SpeedMultiplier = 1.5,
    SpawnIntervalMultiplier = 0.70,
}

-- The level a player can hold: 1..#Levels, or 0..#Levels-1 for zero-based upgrades.
function Upgrades.LevelRange(upgradeId)
    local definition = Upgrades.Definitions[upgradeId]
    if definition.ZeroBased then return 0, #definition.Levels - 1 end
    return 1, #definition.Levels
end

-- The config row for a held level.
function Upgrades.Get(upgradeId, level)
    local definition = Upgrades.Definitions[upgradeId]
    if not definition then return nil end
    return definition.Levels[definition.ZeroBased and level + 1 or level]
end

return Upgrades
