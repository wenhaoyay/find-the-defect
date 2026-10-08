-- Credits, revenue and the economy dashboard: one writer, one set of rules.

local function boot(t)
    t.server:start()
    local DataService = t.server:require("ServerScriptService.Server.Services.DataService")
    local Economy = t.server:require("ServerScriptService.Server.Services.EconomyService")
    local player = t.server:addPlayer({ userId = 1 })
    t.world:waitUntil(function() return DataService.IsLoaded(player) end, 60, "load")
    return Economy, DataService.Get(player), player
end

local function economyEvents(t, flow)
    local out = {}
    for _, event in ipairs(t.server.analytics) do
        if event.kind == "Economy" and (flow == nil or event.flow == flow) then table.insert(out, event) end
    end
    return out
end

describe("economy", function()
    it("grants credits, revenue and statistics together", function(t)
        local Economy, data, player = boot(t)
        expect(Economy.Grant(player, 12.4, { Sku = "DefectCaught", Department = "Toys" })).toBe(12)
        expect(data.Economy.Credits).toBe(12)
        expect(data.Economy.LineRevenue).toBe(12)
        expect(data.Products.DepartmentRevenue.Toys).toBe(12)
        expect(data.Statistics.TotalCreditsEarned).toBe(12)
        expect(Economy.Balance(player)).toBe(12)
    end)

    it("refuses non-finite, zero and negative grants", function(t)
        local Economy, data, player = boot(t)
        t.allow("non-finite")
        expect(Economy.Grant(player, 0 / 0)).toBe(0)
        expect(Economy.Grant(player, math.huge)).toBe(0)
        expect(Economy.Grant(player, -5)).toBe(0)
        expect(Economy.Grant(player, 0.2)).toBe(0)
        expect(data.Economy.Credits).toBe(0)
    end)

    it("caps credits instead of overflowing", function(t)
        local Economy, data, player = boot(t)
        data.Economy.Credits = 9e15 - 5
        expect(Economy.Grant(player, 100)).toBe(5)
        expect(data.Economy.Credits).toBe(9e15)
        expect(Economy.Grant(player, 100)).toBe(0)
    end)

    it("can grant without counting it as revenue", function(t)
        local Economy, data, player = boot(t)
        Economy.Grant(player, 50, { Transaction = "Onboarding", Sku = "Refund", Revenue = false })
        expect(data.Economy.Credits).toBe(50)
        expect(data.Economy.LineRevenue).toBe(0)
    end)

    it("spends only what the player has, and saves soon after", function(t)
        local Economy, data, player = boot(t)
        data.Economy.Credits = 100
        local ok, reason = Economy.Spend(player, 150, { Sku = "Upgrade:BeltMotor:2" })
        expect(ok).toBe(false)
        expect(reason).toBe("InsufficientCredits")
        expect(Economy.Spend(player, 1.5)).toBe(false)
        expect(Economy.Spend(player, -1)).toBe(false)
        expect(Economy.Spend(player, 75, { Sku = "Upgrade:ProductValue:2" })).toBe(true)
        expect(data.Economy.Credits).toBe(25)
        t.wait(20)
        local stored = t.world:peek("FindTheDefect_Profiles_v2", "Player_1")
        expect(stored.Data.Economy.Credits).toBe(25)
    end)

    it("reports spends at once and gameplay income in batches", function(t)
        local Economy, _, player = boot(t)
        for _ = 1, 30 do Economy.Grant(player, 2, { Sku = "NormalPass", Department = "Toys" }) end
        Economy.Grant(player, 25, { Transaction = "Onboarding", Sku = "FirstCatch" })
        Economy.Spend(player, 50, { Sku = "Upgrade:ProductValue:2" })
        expect(#economyEvents(t, "Sink")).toBe(1)
        expect(economyEvents(t, "Sink")[1].sku).toBe("Upgrade:ProductValue:2")
        local sources = economyEvents(t, "Source")
        expect(#sources).toBe(1) -- the onboarding grant; gameplay is still batched
        expect(sources[1].transaction).toBe("Onboarding")
        t.wait(61)
        sources = economyEvents(t, "Source")
        expect(#sources).toBe(2)
        expect(sources[2].sku).toBe("NormalPass")
        expect(sources[2].amount).toBe(60)
    end)

    it("reports unflushed income when the player leaves", function(t)
        local Economy, _, player = boot(t)
        Economy.Grant(player, 40, { Sku = "DefectCaught" })
        t.server:removePlayer(player)
        t.wait(1)
        local sources = economyEvents(t, "Source")
        expect(#sources).toBe(1)
        expect(sources[1].amount).toBe(40)
    end)

    it("does nothing for a player whose data is not loaded", function(t)
        local Economy = boot(t)
        local stranger = t.server:addPlayer({ userId = 2 })
        t.server:removePlayer(stranger)
        expect(Economy.Grant(stranger, 10)).toBe(0)
        expect(Economy.Spend(stranger, 0)).toBe(false)
    end)
end)
