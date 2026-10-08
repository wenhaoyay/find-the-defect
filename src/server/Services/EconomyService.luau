-- The only code that changes a player's credits.
--
-- Every grant and spend goes through here, so the rules live in one place
-- (finite, rounded, capped, never negative), revenue and statistics stay in step
-- with credits, and every change is reported to the economy dashboard.
-- Gameplay income arrives several times a second, so it is summed per
-- (transaction, sku) and reported once a minute, and when the player leaves.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local DataService = require(script.Parent.DataService)
local Analytics = require(script.Parent.Analytics)

local EconomyService = {}

EconomyService.Changed = Signal.new() -- (player, balance, delta, sku)

local MAX_CREDITS = 9e15
local FLUSH_INTERVAL = 60

local batched = {} -- [player] = { [key] = { Transaction, Sku, Amount } }

local function finite(n)
    return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function flush(player, data)
    local pending = batched[player]
    batched[player] = nil
    if not pending or not data then return end
    for _, entry in pairs(pending) do
        Analytics.Economy(player, "Source", entry.Amount, data.Economy.Credits, entry.Transaction, entry.Sku)
    end
end

function EconomyService.Init()
    DataService.OnRelease(flush)
    task.spawn(function()
        while true do
            task.wait(FLUSH_INTERVAL)
            for player in pairs(batched) do flush(player, DataService.Get(player)) end
        end
    end)
end

function EconomyService.Balance(player)
    local data = DataService.Get(player)
    return data and data.Economy.Credits or 0
end

-- options: Transaction (default "Gameplay"), Sku (what it was for),
-- Department (credits this department's revenue), Revenue (default true:
-- counts toward LineRevenue, which unlocks projects), Batch (default true
-- for "Gameplay" transactions).
-- Returns the amount actually granted.
function EconomyService.Grant(player, amount, options)
    options = options or {}
    local data = DataService.Get(player)
    if not data then return 0 end
    if not finite(amount) then
        warn("[Economy] refused a non-finite grant: " .. tostring(options.Sku))
        return 0
    end
    amount = math.floor(amount + 0.5)
    if amount <= 0 then return 0 end

    local before = data.Economy.Credits
    data.Economy.Credits = math.min(MAX_CREDITS, before + amount)
    local granted = data.Economy.Credits - before
    if granted <= 0 then return 0 end

    if options.Revenue ~= false then
        data.Economy.LineRevenue = math.min(MAX_CREDITS, data.Economy.LineRevenue + granted)
        local department = options.Department
        if department and data.Products.DepartmentRevenue[department] ~= nil then
            data.Products.DepartmentRevenue[department] = math.min(MAX_CREDITS, data.Products.DepartmentRevenue[department] + granted)
        end
    end
    data.Statistics.TotalCreditsEarned = math.min(MAX_CREDITS, data.Statistics.TotalCreditsEarned + granted)

    local transaction = options.Transaction or "Gameplay"
    local sku = options.Sku or "Unspecified"
    local batch = options.Batch
    if batch == nil then batch = transaction == "Gameplay" end
    if batch then
        local pending = batched[player] or {}
        batched[player] = pending
        local key = transaction .. "/" .. sku
        local entry = pending[key] or { Transaction = transaction, Sku = sku, Amount = 0 }
        entry.Amount += granted
        pending[key] = entry
    else
        Analytics.Economy(player, "Source", granted, data.Economy.Credits, transaction, sku)
    end

    EconomyService.Changed:Fire(player, data.Economy.Credits, granted, sku)
    return granted
end

-- Returns true, or false and "NoData" / "InvalidCost" / "InsufficientCredits".
-- A successful spend is saved soon (DataService.Checkpoint).
function EconomyService.Spend(player, cost, options)
    options = options or {}
    local data = DataService.Get(player)
    if not data then return false, "NoData" end
    if not finite(cost) or cost < 0 or cost ~= math.floor(cost) then return false, "InvalidCost" end
    if data.Economy.Credits < cost then return false, "InsufficientCredits" end

    data.Economy.Credits -= cost
    if cost > 0 then
        Analytics.Economy(player, "Sink", cost, data.Economy.Credits, options.Transaction or "Shop", options.Sku or "Unspecified")
    end
    EconomyService.Changed:Fire(player, data.Economy.Credits, -cost, options.Sku)
    DataService.Checkpoint(player)
    return true
end

return EconomyService
