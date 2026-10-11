-- What comes down the line: scripted start, weights, repeat limit, anomaly guarantee.

local function Shared()
    return game:GetService("ReplicatedStorage").Shared
end

describe("rolls", function()
    it("plays the onboarding sequence first, exactly", function()
        local Rolls = require(Shared().Gameplay.Rolls)
        local config = require(Shared().Config)
        local random = Random.new(1)
        for index, scripted in ipairs(config.Inspection.OnboardingSequence) do
            expect(Rolls.Product(index, { "TeddyBear", "RubberDuck" }, random)).toBe(scripted.Product)
            expect(Rolls.Defect(index, scripted.Product, random, false, true)).toBe(scripted.Defect)
        end
    end)

    it("never sends the same product three times running when another is eligible", function()
        local Rolls = require(Shared().Gameplay.Rolls)
        local random = Random.new(7)
        local last, run, longest = nil, 0, 0
        for index = 7, 3000 do
            local productId = Rolls.Product(index, { "TeddyBear", "RubberDuck" }, random, last, run)
            if productId == last then
                run += 1
            else
                last, run = productId, 1
            end
            longest = math.max(longest, run)
        end
        expect(longest).toBe(2)
        -- With only one product eligible, repeats are unavoidable and allowed.
        expect(Rolls.Product(10, { "TeddyBear" }, random, "TeddyBear", 5)).toBe("TeddyBear")
    end)

    it("rolls defects at their configured weights", function()
        local Rolls = require(Shared().Gameplay.Rolls)
        local config = require(Shared().Config)
        local random = Random.new(42)
        local counts = {}
        local n = 40000
        for _ = 1, n do
            local defect = Rolls.Defect(100, "TeddyBear", random, false, true)
            counts[defect] = (counts[defect] or 0) + 1
        end
        for name, defect in pairs(config.Products.Defects) do
            expect((counts[name] or 0) / n).toBeCloseTo(defect.Weight, 0.012)
        end
    end)

    it("holds component defects back until they are introduced", function()
        local Rolls = require(Shared().Gameplay.Rolls)
        local random = Random.new(3)
        for _ = 1, 5000 do
            local defect = Rolls.Defect(100, "Mug", random, true, false)
            expect(defect ~= "MissingPart" and defect ~= "ExtraPart").toBe(true)
        end
    end)

    it("guarantees a first Golden, once, after the configured count", function()
        local AnomalyRoller = require(Shared().Gameplay.AnomalyRoller)
        local config = require(Shared().Config)
        local never = {
            NextNumber = function()
                return 0.999
            end,
        }
        local roller = AnomalyRoller.new(false)
        for _ = 1, config.Anomalies.FirstGoldenGuaranteeAfter do
            expect(roller:Roll(never, 1)).toBeNil()
        end
        local id, guaranteed = roller:Roll(never, 1)
        expect(id).toBe("Golden")
        expect(guaranteed).toBe(true)
        for _ = 1, 200 do
            expect(roller:Roll(never, 1)).toBeNil()
        end
        -- A player who has met a Golden before gets no guarantee.
        local veteran = AnomalyRoller.new(true)
        for _ = 1, 200 do
            expect(veteran:Roll(never, 1)).toBeNil()
        end
    end)

    it("keeps luck per player: one player's rolls do not use up another's guarantee", function()
        local AnomalyRoller = require(Shared().Gameplay.AnomalyRoller)
        local never = {
            NextNumber = function()
                return 0.999
            end,
        }
        local a, b = AnomalyRoller.new(false), AnomalyRoller.new(false)
        for _ = 1, 30 do
            a:Roll(never, 1)
        end
        expect(b.EligibleProducts).toBe(0)
    end)

    it("hits the configured anomaly rate and tier split", function()
        local AnomalyRoller = require(Shared().Gameplay.AnomalyRoller)
        local roller = AnomalyRoller.new(true)
        local random = Random.new(99)
        local golden, glitched, n = 0, 0, 400000
        for _ = 1, n do
            local id = roller:Roll(random, 3, 0.25)
            if id == "Golden" then
                golden += 1
            elseif id == "Glitched" then
                glitched += 1
            end
        end
        expect((golden + glitched) / n).toBeCloseTo(0.018, 0.0015)
        expect(glitched / (golden + glitched)).toBeCloseTo(0.25, 0.03)
    end)
end)
