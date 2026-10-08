-- Invariants the configs must keep. A rebalance that breaks one fails here, not in play.

local function Config()
    return require(game:GetService("ReplicatedStorage").Shared.Config)
end

describe("config", function()
    it("is frozen all the way down", function()
        local config = Config()
        expect(function() config.Anomalies.BaseChance = 1 end).toThrow()
        expect(function() config.Products.Definitions.TeddyBear.Multiplier = 99 end).toThrow()
        expect(function() config.Upgrades.Definitions.BeltMotor.Levels[1].Speed = 99 end).toThrow()
    end)

    it("gives every product a department, a valid unlock, and real component defects", function()
        local config = Config()
        local products = config.Products
        expect(#products.Order).toBe(12)
        for _, productId in ipairs(products.Order) do
            local product = products.Definitions[productId]
            expect(product.ProductId).toBe(productId)
            expect(config.Departments.Definitions[product.DepartmentId]).never.toBeNil()
            for defectName in pairs(products.ComponentDefects) do
                local componentName = product.ComponentDefects[defectName]
                local componentDef = product.Components[componentName]
                expect(componentDef).never.toBeNil()
                if defectName == "MissingPart" and not componentDef.MissingAll then
                    expect(componentDef.Parts).toContain(componentDef.MissingTarget)
                end
                if defectName == "ExtraPart" and not componentDef.ExtraAll then
                    expect(componentDef.Parts).toContain(componentDef.ExtraSource)
                end
            end
        end
        for _, departmentId in ipairs(config.Departments.Order) do
            local starter = config.Departments.Definitions[departmentId].StarterProduct
            expect(products.Definitions[starter].DepartmentId).toBe(departmentId)
            expect(products.Definitions[starter].UnlockRevenue).toBe(0)
        end
    end)

    it("keeps defect weights summing to 1, in and out of a rush", function()
        local defects = Config().Products.Defects
        local normal, rush = 0, 0
        for _, defect in pairs(defects) do
            normal += defect.Weight
            rush += defect.RushWeight
        end
        expect(normal).toBeCloseTo(1, 1e-9)
        expect(rush).toBeCloseTo(1, 1e-9)
    end)

    it("makes every upgrade level cost more and do more than the last", function()
        local upgrades = Config().Upgrades
        local effect = {
            ProductValue = "Multiplier", BeltMotor = "Speed", InspectionRunway = "Length", AnomalyLuck = "Multiplier",
            AnomalyQuality = "GlitchedShare", RushDuration = "Duration", RushPay = "Multiplier",
        }
        for upgradeId, definition in pairs(upgrades.Definitions) do
            expect(definition.Levels[1].Cost).toBe(0)
            for level = 2, #definition.Levels do
                local previous, current = definition.Levels[level - 1], definition.Levels[level]
                expect(current.Cost).toBeGreaterThan(previous.Cost)
                local key = effect[upgradeId]
                if key then expect(current[key]).toBeGreaterThan(previous[key]) end
                if upgradeId == "StreakShield" and level > 2 then expect(current.Recharge).toBeLessThan(previous.Recharge) end
            end
        end
        expect(upgrades.Get("StreakShield", 0).Recharge).toBe(0)
        expect(upgrades.Get("StreakShield", 1).Recharge).toBe(80)
        expect(upgrades.Get("ProductValue", 2).Multiplier).toBe(1.25)
    end)

    it("lays the line out consistently at every runway length", function()
        local config = Config()
        local conveyor = config.Conveyor
        for _, level in ipairs(config.Upgrades.Definitions.InspectionRunway.Levels) do
            local startX, endX = conveyor.InspectionBounds(level.Length)
            expect(endX - startX).toBe(level.Length)
            expect(conveyor.SpawnX(level.Length)).toBeLessThan(startX)
            expect(conveyor.BeltLeftEdge(level.Length)).toBeLessThanOrEqual(conveyor.SpawnX(level.Length))
            expect(endX).toBeLessThan(conveyor.CleanupX)
        end
        -- The legacy layout at the base runway, unchanged.
        expect(conveyor.SpawnX(14)).toBe(-29)
        expect(conveyor.BeltLeftEdge(14)).toBe(-31)
    end)

    it("computes anomaly odds instead of labelling them by hand", function()
        local anomalies = Config().Anomalies
        expect(anomalies.ArchiveSize).toBe(24)
        expect(anomalies.OddsLabel("Golden")).toBe("1 / 200")
        expect(anomalies.OddsLabel("Glitched")).toBe("1 / 1000")
        expect(anomalies.OddsLabel("Glitched", 3, 0.25)).toBe("1 / 222")
    end)

    it("ranks finds strictly, so ties keep the first", function()
        local anomalies = Config().Anomalies
        expect(anomalies.IsRarer("Golden", nil)).toBe(true)
        expect(anomalies.IsRarer("Glitched", "Golden")).toBe(true)
        expect(anomalies.IsRarer("Golden", "Golden")).toBe(false)
        expect(anomalies.IsRarer("Golden", "Glitched")).toBe(false)
    end)

    it("turns every debug switch off outside Studio", function(t)
        local debug = Config().Debug
        expect(debug.UnlockAllProducts).toBe(false)
        expect(debug.ForceAnomaly).toBe("")
        expect(debug.CreditGrant).toBe(0)
        expect(t.server.studio).toBe(false)
    end)
end)
