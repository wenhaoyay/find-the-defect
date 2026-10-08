-- One player's anomaly luck. Each line (player) owns one roller; the legacy
-- service kept these counters for the whole server.
--
-- Roll 1 decides whether an anomaly occurs, roll 2 which tier. If a player has
-- never met a Golden, one is guaranteed after FirstGoldenGuaranteeAfter eligible
-- products, so every new player sees one early.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Anomalies = Config.Anomalies

local AnomalyRoller = {}
AnomalyRoller.__index = AnomalyRoller

function AnomalyRoller.new(goldenAlreadyMet)
    return setmetatable({
        EligibleProducts = 0,
        GoldenEncountered = goldenAlreadyMet == true,
    }, AnomalyRoller)
end

-- Returns anomalyId or nil, and whether it came from the guarantee.
function AnomalyRoller:Roll(random, luckMultiplier, glitchedShare)
    self.EligibleProducts += 1
    local chance = math.clamp(Anomalies.BaseChance * math.max(0, luckMultiplier or 1), 0, 1)

    if random:NextNumber() < chance then
        local weights = Anomalies.QualityWeights(glitchedShare)
        local total = 0
        for _, anomalyId in ipairs(Anomalies.QualityOrder) do
            total += weights[anomalyId]
        end
        local roll = random:NextNumber() * total
        local cumulative = 0
        for _, anomalyId in ipairs(Anomalies.QualityOrder) do
            cumulative += weights[anomalyId]
            if roll < cumulative then
                if anomalyId == "Golden" then
                    self.GoldenEncountered = true
                end
                return anomalyId, false
            end
        end
    end

    if not self.GoldenEncountered and self.EligibleProducts > Anomalies.FirstGoldenGuaranteeAfter then
        self.GoldenEncountered = true
        return "Golden", true
    end
    return nil, false
end

return AnomalyRoller
