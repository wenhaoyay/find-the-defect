-- Rules of the inspection loop that are not upgrades.

local Inspection = {}

-- The first products a new player sees, in order, before random generation.
Inspection.OnboardingSequence = {
    { Product = "TeddyBear", Defect = "Normal" },
    { Product = "TeddyBear", Defect = "WrongColour" },
    { Product = "TeddyBear", Defect = "Normal" },
    { Product = "TeddyBear", Defect = "Giant" },
    { Product = "TeddyBear", Defect = "Normal" },
    { Product = "TeddyBear", Defect = "Tiny" },
}

-- Highest first.
Inspection.StreakTiers = {
    { Minimum = 100, Multiplier = 3 },
    { Minimum = 50, Multiplier = 2 },
    { Minimum = 25, Multiplier = 1.5 },
    { Minimum = 10, Multiplier = 1.25 },
    { Minimum = 0, Multiplier = 1 },
}

-- The same product at most this many times in a row (when another is eligible).
Inspection.MaxConsecutiveSameProduct = 2

-- A reject is judged where the product was when the player clicked:
-- now minus their ping, capped so a high ping cannot reach far into the past.
Inspection.MaxLagCompensation = 0.25

-- Per-player request limits: Interval is seconds per token, Burst the bucket size.
-- Rejects allow a human ceiling (about 8 a second), not a bot's.
Inspection.RateLimits = {
    Reject = { Interval = 0.125, Burst = 4 },
    PurchaseUpgrade = { Interval = 0.2, Burst = 2 },
    FactoryProject = { Interval = 0.25, Burst = 2 },
    OperatingTier = { Interval = 0.08, Burst = 3 },
    LineMode = { Interval = 0.3, Burst = 2 },
}

function Inspection.StreakMultiplier(streak)
    for _, tier in ipairs(Inspection.StreakTiers) do
        if streak >= tier.Minimum then return tier.Multiplier end
    end
    return 1
end

return Inspection
