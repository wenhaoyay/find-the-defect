local UpgradeConfig = {}

UpgradeConfig.CategoryOrder = {"LINE", "RESEARCH", "INSPECTOR", "RUSH"}
UpgradeConfig.UpgradeOrder = {
    LINE = {"ProductValue", "BeltMotor", "InspectionRunway"},
    RESEARCH = {"AnomalyLuck", "AnomalyQuality"},
    INSPECTOR = {"StreakShield"},
    RUSH = {"RushDuration", "RushPay"},
}

UpgradeConfig.Upgrades = {
    ProductValue = {
        Category = "LINE",
        DisplayName = "PRODUCT VALUE",
        StateName = "ProductValueLevel",
        Levels = {
            {Multiplier = 1.00, Cost = 0},
            {Multiplier = 1.25, Cost = 75},
            {Multiplier = 1.60, Cost = 250},
            {Multiplier = 2.10, Cost = 650},
            {Multiplier = 2.80, Cost = 1800},
            {Multiplier = 3.70, Cost = 5000},
            {Multiplier = 5.00, Cost = 15000},
            {Multiplier = 6.75, Cost = 45000},
        },
    },
    BeltMotor = {
        Category = "LINE",
        DisplayName = "BELT MOTOR",
        StateName = "BeltSpeedLevel",
        Levels = {
            {Speed = 7, SpawnInterval = 1.50, Cost = 0},
            {Speed = 8.5, SpawnInterval = 1.25, Cost = 120},
            {Speed = 10, SpawnInterval = 1.00, Cost = 350},
            {Speed = 12, SpawnInterval = 0.80, Cost = 900},
            {Speed = 14, SpawnInterval = 0.70, Cost = 2000},
            {Speed = 16, SpawnInterval = 0.62, Cost = 4500},
            {Speed = 18, SpawnInterval = 0.55, Cost = 10000},
            {Speed = 20, SpawnInterval = 0.49, Cost = 22000},
            {Speed = 22, SpawnInterval = 0.44, Cost = 48000},
            {Speed = 24, SpawnInterval = 0.40, Cost = 100000},
        },
    },
    InspectionRunway = {
        Category = "LINE",
        DisplayName = "INSPECTION RUNWAY",
        StateName = "InspectionRunwayLevel",
        Levels = {
            {Length = 14, Cost = 0},
            {Length = 18, Cost = 300},
            {Length = 22, Cost = 1200},
            {Length = 26, Cost = 4500},
            {Length = 30, Cost = 15000},
            {Length = 34, Cost = 50000},
        },
    },
    AnomalyLuck = {
        Category = "RESEARCH",
        DisplayName = "ANOMALY LUCK",
        StateName = "AnomalyLuckLevel",
        Levels = {
            {Multiplier = 1.00, Cost = 0},
            {Multiplier = 1.10, Cost = 500},
            {Multiplier = 1.20, Cost = 1200},
            {Multiplier = 1.35, Cost = 3000},
            {Multiplier = 1.50, Cost = 7000},
            {Multiplier = 1.70, Cost = 16000},
            {Multiplier = 1.95, Cost = 35000},
            {Multiplier = 2.25, Cost = 75000},
            {Multiplier = 2.60, Cost = 160000},
            {Multiplier = 3.00, Cost = 350000},
        },
    },
    AnomalyQuality = {
        Category = "RESEARCH",
        DisplayName = "ANOMALY QUALITY",
        StateName = "AnomalyQualityLevel",
        Levels = {
            {GlitchedShare = 1 / 6, Cost = 0},
            {GlitchedShare = 0.18, Cost = 3000},
            {GlitchedShare = 0.20, Cost = 10000},
            {GlitchedShare = 0.22, Cost = 35000},
            {GlitchedShare = 0.25, Cost = 120000},
        },
    },
    StreakShield = {
        Category = "INSPECTOR",
        DisplayName = "STREAK SHIELD",
        StateName = "StreakShieldLevel",
        Levels = {
            {Recharge = nil, Cost = 0},
            {Recharge = 80, Cost = 2500},
            {Recharge = 60, Cost = 12000},
            {Recharge = 40, Cost = 50000},
        },
    },
    RushDuration = {
        Category = "RUSH",
        DisplayName = "RUSH DURATION",
        StateName = "RushDurationLevel",
        Levels = {
            {Duration = 30, Cost = 0},
            {Duration = 33, Cost = 3000},
            {Duration = 36, Cost = 10000},
            {Duration = 40, Cost = 30000},
            {Duration = 45, Cost = 90000},
        },
    },
    RushPay = {
        Category = "RUSH",
        DisplayName = "RUSH PAY",
        StateName = "RushPayLevel",
        Levels = {
            {Multiplier = 2.00, Cost = 0},
            {Multiplier = 2.10, Cost = 5000},
            {Multiplier = 2.20, Cost = 15000},
            {Multiplier = 2.35, Cost = 45000},
            {Multiplier = 2.50, Cost = 135000},
        },
    },
}

UpgradeConfig.BaseAnomalyChance = 0.006
UpgradeConfig.DebugCreditGrant = 0 -- Studio-only helper; disabled in production.
UpgradeConfig.Rush = {
    FirstDelay = 150,
    RepeatDelay = 180,
    WarningDuration = 5,
    SpeedMultiplier = 1.5,
    SpawnIntervalMultiplier = 0.70,
}

function UpgradeConfig.Get(upgradeName, level)
    local upgrade = UpgradeConfig.Upgrades[upgradeName]
    return upgrade and upgrade.Levels[level]
end

return UpgradeConfig