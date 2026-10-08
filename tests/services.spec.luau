-- Analytics and the rate limiter.

local function server(name)
    return "ServerScriptService.Server." .. name
end

describe("analytics", function()
    it("sends custom fields in the order given", function(t)
        local Analytics = t.server:require(server("Services.Analytics"))
        local player = t.server:addPlayer({ userId = 1 })
        Analytics.Custom(player, "RushCompleted", 14, { { "Caught", 9 }, { "Mistakes", 2 }, { "Credits", 340 } })
        local event = t.server.analytics[1]
        expect(event.name).toBe("RushCompleted")
        expect(event.fields).toEqual({
            CustomField01 = "Caught=9",
            CustomField02 = "Mistakes=2",
            CustomField03 = "Credits=340",
        })
    end)

    it("refuses a fourth field instead of dropping it", function(t)
        local Analytics = t.server:require(server("Services.Analytics"))
        local player = t.server:addPlayer({ userId = 1 })
        expect(function()
            Analytics.Custom(player, "TooMuch", 1, { { "a", 1 }, { "b", 2 }, { "c", 3 }, { "d", 4 } })
        end).toThrow("at most 3")
    end)

    it("uses the built-in onboarding, progression and economy events", function(t)
        local Analytics = t.server:require(server("Services.Analytics"))
        local player = t.server:addPlayer({ userId = 1 })
        Analytics.OnboardingStep(player, 2, "FirstCatch")
        Analytics.Progression(player, "Factory", "Complete", 2, "ProductionSystemsII")
        Analytics.Economy(player, "Sink", 75, 25, "Shop", "Upgrade:ProductValue:2")
        local kinds = {}
        for _, event in ipairs(t.server.analytics) do
            table.insert(kinds, event.kind)
        end
        expect(kinds).toEqual({ "Onboarding", "Progression", "Economy" })
    end)
end)

describe("rate limiter", function()
    it("allows a burst, then one request per interval", function(t)
        local RateLimiter = t.server:require(server("Util.RateLimiter"))
        local player = t.server:addPlayer({ userId = 1 })
        local allowed = 0
        for _ = 1, 10 do
            if RateLimiter.Allow(player, "Reject", 0.125, 4) then
                allowed += 1
            end
        end
        expect(allowed).toBe(4)
        t.wait(1)
        allowed = 0
        for _ = 1, 20 do
            if RateLimiter.Allow(player, "Reject", 0.125, 4) then
                allowed += 1
            end
        end
        expect(allowed).toBe(4) -- refilled to the burst, not beyond
    end)

    it("caps rejects at a human rate over time", function(t)
        local RateLimiter = t.server:require(server("Util.RateLimiter"))
        local config = require(game:GetService("ReplicatedStorage").Shared.Config)
        local player = t.server:addPlayer({ userId = 1 })
        local allowed, attempts = 0, 0
        local started = t.world.now
        while t.world.now - started < 10 do -- a bot clicking 3 times every frame
            for _ = 1, 3 do
                attempts += 1
                if RateLimiter.AllowAction(player, config.Inspection.RateLimits, "Reject") then
                    allowed += 1
                end
            end
            t.wait()
        end
        local elapsed = t.world.now - started
        expect(attempts).toBeGreaterThan(500)
        expect(allowed).toBeLessThanOrEqual(4 + math.ceil(elapsed * 8))
    end)

    it("refuses anything that is not a player", function(t)
        local RateLimiter = t.server:require(server("Util.RateLimiter"))
        expect(RateLimiter.Allow({}, "Reject", 1, 1)).toBe(false)
        expect(RateLimiter.Allow(Instance.new("Folder"), "Reject", 1, 1)).toBe(false)
    end)
end)
