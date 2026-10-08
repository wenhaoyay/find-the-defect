local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")

local Config = require(script.Parent:WaitForChild("PersistenceConfig"))

local Analytics = {}
local sessionStartedAt = {}
local oncePerSession = {}

local function cleanValue(value)
    local kind = typeof(value)
    if kind == "string" then return string.sub(value, 1, 64) end
    if kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge then return 0 end
        return value
    end
    if kind == "boolean" then return value and "true" or "false" end
    return tostring(value)
end

local function analyticsFields(fields)
    if type(fields) ~= "table" then return nil, "" end
    local keys = {}
    for key in pairs(fields) do table.insert(keys, tostring(key)) end
    table.sort(keys)
    local custom = {}
    local logParts = {}
    for index, key in ipairs(keys) do
        local value = cleanValue(fields[key])
        table.insert(logParts, key .. "=" .. tostring(value))
        if index <= 3 then
            custom["CustomField0" .. tostring(index)] = string.sub(key .. "=" .. tostring(value), 1, 100)
        end
    end
    return next(custom) and custom or nil, table.concat(logParts, " ")
end

function Analytics.SessionStarted(player)
    sessionStartedAt[player] = os.clock()
    oncePerSession[player] = {}
end

function Analytics.GetSessionSeconds(player)
    local started = sessionStartedAt[player]
    return started and math.max(0, math.floor(os.clock() - started)) or 0
end

function Analytics.Log(player, eventName, value, fields)
    if typeof(player) ~= "Instance" or not player:IsA("Player") then return false end
    if typeof(eventName) ~= "string" or eventName == "" then return false end
    local numericValue = tonumber(value) or 1
    if numericValue ~= numericValue or numericValue == math.huge or numericValue == -math.huge then numericValue = 1 end
    local custom, logText = analyticsFields(fields)
    local ok, err = pcall(function()
        AnalyticsService:LogCustomEvent(player, eventName, numericValue, custom)
    end)
    if RunService:IsStudio() and Config.StudioAnalyticsLogging then
        print(string.format("[Analytics] %s at %ds%s", eventName, Analytics.GetSessionSeconds(player), logText ~= "" and (" " .. logText) or ""))
    elseif not ok then
        warn("[Analytics] " .. eventName .. " failed: " .. tostring(err))
    end
    return ok
end

function Analytics.LogOnce(player, eventName, value, fields)
    local seen = oncePerSession[player]
    if not seen then
        Analytics.SessionStarted(player)
        seen = oncePerSession[player]
    end
    if seen[eventName] then return false end
    seen[eventName] = true
    return Analytics.Log(player, eventName, value, fields)
end

function Analytics.EndSession(player, snapshot)
    local fields = snapshot or {}
    fields.SessionSeconds = Analytics.GetSessionSeconds(player)
    Analytics.Log(player, "SessionEnded", fields.SessionSeconds, fields)
    sessionStartedAt[player] = nil
    oncePerSession[player] = nil
end

return Analytics
