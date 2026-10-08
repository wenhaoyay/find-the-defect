-- Analytics through Roblox's built-in events, so the Creator Hub dashboards fill
-- themselves: onboarding funnel, economy sources/sinks, progression. Custom
-- events carry at most three fields; asking for more is an error, not a silent
-- drop (the legacy module sent the first three alphabetically and lost the rest).

local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")

local Analytics = {}

local FIELD_KEYS = { "CustomField01", "CustomField02", "CustomField03" }

local function customFields(fields)
    if fields == nil then
        return nil
    end
    if #fields > #FIELD_KEYS then
        error(`Analytics: at most {#FIELD_KEYS} custom fields, got {#fields}`, 3)
    end
    local result = {}
    for index, field in ipairs(fields) do
        result[FIELD_KEYS[index]] = string.sub(`{field[1]}={tostring(field[2])}`, 1, 100)
    end
    return result
end

local function safely(method, ...)
    local ok, err = pcall(method, AnalyticsService, ...)
    if not ok then
        if RunService:IsStudio() then
            error(err, 3)
        end
        warn("[Analytics] " .. tostring(err))
    end
    return ok
end

local function finite(n)
    return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

-- fields: an ordered list of at most three {name, value} pairs.
function Analytics.Custom(player, eventName, value, fields)
    local cf = customFields(fields)
    return safely(AnalyticsService.LogCustomEvent, player, eventName, finite(value) and value or 1, cf)
end

function Analytics.OnboardingStep(player, step, stepName)
    return safely(AnalyticsService.LogOnboardingFunnelStepEvent, player, step, stepName)
end

-- flow: "Source" or "Sink"; transaction: an Enum.AnalyticsEconomyTransactionType name
-- such as "Gameplay", "Shop" or "Onboarding"; sku: what it was for.
function Analytics.Economy(player, flow, amount, endingBalance, transaction, sku)
    if not finite(amount) or amount <= 0 then
        return false
    end
    return safely(
        AnalyticsService.LogEconomyEvent,
        player,
        Enum.AnalyticsEconomyFlowType[flow],
        "Credits",
        amount,
        endingBalance,
        transaction,
        sku
    )
end

-- status: "Start", "Complete" or "Fail".
function Analytics.Progression(player, path, status, level, levelName)
    return safely(
        AnalyticsService.LogProgressionEvent,
        player,
        path,
        Enum.AnalyticsProgressionType[status],
        level,
        levelName
    )
end

return Analytics
