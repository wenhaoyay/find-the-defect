-- Per-player token buckets for remote requests. A refused request is dropped
-- silently: legitimate clients stay under the limits (Config.Inspection.RateLimits).

local Players = game:GetService("Players")

local RateLimiter = {}
local buckets = {}

function RateLimiter.Allow(player, key, interval, burst)
    if typeof(player) ~= "Instance" or not player:IsA("Player") or type(key) ~= "string" then
        return false
    end
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
        bucket = { Tokens = burst, UpdatedAt = now }
        playerBuckets[key] = bucket
    end

    bucket.Tokens = math.min(burst, bucket.Tokens + (now - bucket.UpdatedAt) / interval)
    bucket.UpdatedAt = now
    if bucket.Tokens < 1 then
        return false
    end
    bucket.Tokens -= 1
    return true
end

-- Allow with a named limit from config.
function RateLimiter.AllowAction(player, limits, action)
    local limit = limits[action]
    return RateLimiter.Allow(player, action, limit.Interval, limit.Burst)
end

Players.PlayerRemoving:Connect(function(player)
    buckets[player] = nil
end)

return RateLimiter
