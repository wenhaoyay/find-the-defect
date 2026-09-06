local Players = game:GetService("Players")

local AnomalyService = {}
AnomalyService.__index = AnomalyService

function AnomalyService.new(config)
    local self = setmetatable({}, AnomalyService)
    self.Config = config
    self.EligibleProducts = 0
    self.GoldenEncountered = false
    self.PlayerData = {}
    self.CurrentRarest = {
        Priority = 0,
        ProductKey = nil,
        AnomalyId = nil,
        PlayerName = nil,
    }

    Players.PlayerRemoving:Connect(function(player)
        self.PlayerData[player] = nil
    end)

    return self
end

function AnomalyService:GetPlayerData(player)
    local data = self.PlayerData[player]
    if not data then
        data = {Discovered = {}, Count = 0}
        self.PlayerData[player] = data
    end
    return data
end

function AnomalyService:GetSnapshot(player)
    local data = self:GetPlayerData(player)
    local discovered = {}
    for key, value in pairs(data.Discovered) do
        discovered[key] = value
    end
    return {Discovered = discovered, Count = data.Count, Total = self.Config.ArchiveSize}
end

-- Roll 1: whether an anomaly occurs. Roll 2: weighted anomaly quality.
function AnomalyService:Roll(random, luckMultiplier, qualityWeights)
    self.EligibleProducts += 1

    local debugMultiplier = math.max(0, self.Config.DebugAnomalyMultiplier)
    local totalChance = math.clamp(
        self.Config.BaseCombinedChance * math.max(0, luckMultiplier or 1) * debugMultiplier,
        0,
        1
    )

    if random:NextNumber() <= totalChance then
        local weights = qualityWeights or self.Config.GetQualityWeights()
        local totalWeight = 0
        for _, anomalyId in self.Config.QualityOrder do
            totalWeight += math.max(0, weights[anomalyId] or 0)
        end

        local qualityRoll = random:NextNumber() * math.max(totalWeight, 0.000001)
        local cumulative = 0
        for _, anomalyId in self.Config.QualityOrder do
            cumulative += math.max(0, weights[anomalyId] or 0)
            if qualityRoll <= cumulative then
                if anomalyId == "Golden" then
                    self.GoldenEncountered = true
                end
                return anomalyId, false
            end
        end
    end

    if not self.GoldenEncountered
        and self.EligibleProducts > self.Config.FirstGoldenGuaranteeAfter then
        self.GoldenEncountered = true
        return "Golden", true
    end

    return nil, false
end

function AnomalyService:Restore(player, discovered, playerName, goldenSatisfied)
    local data = {Discovered = {}, Count = 0}
    self.PlayerData[player] = data
    self.EligibleProducts = 0
    self.GoldenEncountered = goldenSatisfied == true
    self.CurrentRarest = {
        Priority = 0,
        ProductKey = nil,
        AnomalyId = nil,
        PlayerName = nil,
    }

    for _, anomalyId in ipairs(self.Config.ArchiveRows) do
        for _, productKey in ipairs(self.Config.ProductOrder) do
            local key = self.Config.GetDiscoveryKey(productKey, anomalyId)
            if discovered[key] == true then
                data.Discovered[key] = true
                data.Count += 1
                if anomalyId == "Golden" then self.GoldenEncountered = true end
                local anomaly = self.Config.Anomalies[anomalyId]
                if anomaly and anomaly.Priority > self.CurrentRarest.Priority then
                    self.CurrentRarest = {
                        Priority = anomaly.Priority,
                        ProductKey = productKey,
                        AnomalyId = anomalyId,
                        PlayerName = playerName,
                    }
                end
            end
        end
    end
    return self.CurrentRarest
end

function AnomalyService:Discover(player, productKey, anomalyId)
    local data = self:GetPlayerData(player)
    local key = self.Config.GetDiscoveryKey(productKey, anomalyId)
    local isNew = not data.Discovered[key]

    if isNew then
        data.Discovered[key] = true
        data.Count += 1
    end

    local anomaly = self.Config.Anomalies[anomalyId]
    local pedestalUpdated = false
    if isNew and anomaly.Priority >= self.CurrentRarest.Priority then
        self.CurrentRarest = {
            Priority = anomaly.Priority,
            ProductKey = productKey,
            AnomalyId = anomalyId,
            PlayerName = player.DisplayName,
        }
        pedestalUpdated = true
    end

    return {
        IsNew = isNew,
        Key = key,
        Count = data.Count,
        Total = self.Config.ArchiveSize,
        PedestalUpdated = pedestalUpdated,
        Snapshot = self:GetSnapshot(player),
    }
end

return AnomalyService