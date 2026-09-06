local Players = game:GetService("Players")

local RateLimiter = {}
local buckets = {}

function RateLimiter.Allow(player, key, interval, burst)
    if typeof(player) ~= "Instance" or not player:IsA("Player") then return false end
    if typeof(key) ~= "string" then return false end
    interval = math.max(0.01, tonumber(interval) or 0.1)
    burst = math.max(1, math.floor(tonumber(burst) or 1))

    local now = os.clock()
    local playerBuckets = buckets[player]
    if not playerBuckets then
        playerBuckets = {}
        buckets[player] = playerBuckets
    end
    local bucket = playerBuckets[key]
    if not bucket then
        bucket = {Tokens = burst, UpdatedAt = now}
        playerBuckets[key] = bucket
    end

    local refill = (now - bucket.UpdatedAt) / interval
    bucket.Tokens = math.min(burst, bucket.Tokens + refill)
    bucket.UpdatedAt = now
    if bucket.Tokens < 1 then return false end
    bucket.Tokens -= 1
    return true
end

Players.PlayerRemoving:Connect(function(player)
    buckets[player] = nil
end)

return RateLimiter
