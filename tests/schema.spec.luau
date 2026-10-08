-- The record's shape and repair rules. Ports the legacy in-game self-tests and
-- adds the cases that used to lose data.

local function Schema()
    return require(game:GetService("ServerScriptService").Server.Data.Schema)
end

local function hasRepair(repairs, text)
    for _, message in ipairs(repairs) do
        if string.find(message, text, 1, true) then return true end
    end
    return false
end

describe("schema", function()
    it("repairs an empty record into the template, with nothing to report", function()
        local schema = Schema()
        local record, repairs = schema.Repair(nil)
        expect(record).toEqual(schema.Template())
        expect(#repairs).toBe(0)
        local again = schema.Repair({})
        expect(again).toEqual(schema.Template())
    end)

    it("starts a new player with the starter product and nothing else", function()
        local record = Schema().Template()
        expect(record.Products.Unlocked.TeddyBear).toBe(true)
        expect(record.Products.Unlocked.RubberDuck).toBe(false)
        expect(record.Products.Departments.Toys).toBe(true)
        expect(record.Products.Departments.Household).toBe(false)
        expect(record.Onboarding.TutorialStep).toBe(0)
        expect(record.Inspector.StreakShieldLevel).toBe(0)
    end)

    it("hands out independent copies", function()
        local schema = Schema()
        local a = schema.Template()
        a.Economy.Credits = 999
        expect(schema.Template().Economy.Credits).toBe(0)
        local raw = { SchemaVersion = 2, Economy = { Credits = 5 } }
        local repaired = schema.Repair(raw)
        repaired.Economy.Credits = 77
        expect(raw.Economy.Credits).toBe(5)
    end)

    it("clamps and defaults corrupt values, and says so", function()
        local schema = Schema()
        local corrupt = schema.Template()
        corrupt.Economy.Credits = -500
        corrupt.Economy.LineRevenue = 0 / 0
        corrupt.Line.BeltMotorTier = 999
        corrupt.Line.OperatingTier = 999
        corrupt.Inspector.StreakShieldLevel = 99
        corrupt.Collection.Archive.Golden_TeddyBear = "yes"
        corrupt.Statistics.TotalProductsHandled = 2.5
        local record, repairs = schema.Repair(corrupt)
        expect(record.Economy.Credits).toBe(0)
        expect(record.Economy.LineRevenue).toBe(0)
        expect(record.Line.BeltMotorTier).toBe(10)
        expect(record.Line.OperatingTier).toBe(10)
        expect(record.Inspector.StreakShieldLevel).toBe(3)
        expect(record.Collection.Archive.Golden_TeddyBear).toBe(false)
        expect(record.Statistics.TotalProductsHandled).toBe(2)
        expect(hasRepair(repairs, "Economy.Credits clamped")).toBe(true)
        expect(hasRepair(repairs, "Economy.LineRevenue invalid")).toBe(true)
        expect(hasRepair(repairs, "Collection.Archive.Golden_TeddyBear invalid")).toBe(true)
    end)

    it("replaces a section of the wrong type instead of failing", function()
        local record, repairs = Schema().Repair({ SchemaVersion = 2, Economy = "lots", Collection = { Archive = 5 } })
        expect(record.Economy.Credits).toBe(0)
        expect(hasRepair(repairs, "Economy invalid")).toBe(true)
        expect(hasRepair(repairs, "Collection.Archive invalid")).toBe(true)
    end)

    it("refuses a record from a newer schema instead of overwriting it", function()
        local record, err = Schema().Repair({ SchemaVersion = 3, Economy = { Credits = 5 } })
        expect(record).toBeNil()
        expect(err).toContain("future schema 3")
        local bad, badErr = Schema().Repair({ SchemaVersion = "two" })
        expect(bad).toBeNil()
        expect(badErr).toContain("Invalid schema version")
    end)

    it("keeps keys it does not know, so retired content is not erased", function()
        local schema = Schema()
        local raw = schema.Template()
        raw.Collection.Archive.Golden_RetiredProduct = true
        raw.Products.Unlocked.RetiredProduct = true
        raw.FutureSection = { Value = 1 }
        local record, repairs = schema.Repair(raw)
        expect(record.Collection.Archive.Golden_RetiredProduct).toBe(true)
        expect(record.Products.Unlocked.RetiredProduct).toBe(true)
        expect(record.FutureSection).toEqual({ Value = 1 })
        expect(hasRepair(repairs, "Collection.Archive.Golden_RetiredProduct unknown; kept")).toBe(true)
    end)

    it("migrates a legacy v1 record, finished tutorial included", function()
        local record, repairs = Schema().Repair({
            SchemaVersion = 1,
            Economy = { Credits = 321, LineRevenue = 4000 },
            Line = { ProductValueLevel = 3, BeltMotorTier = 2, OperatingTier = 2, InspectionRunwayLevel = 1 },
            Factory = { ProductionTier = 2, ResearchTier = 1, ResearchLabPurchased = true, RejectGalleryPurchased = false, HouseholdProductionPurchased = true },
            Onboarding = { HasPlayedBefore = true, HasCompletedFirstShift = true, EarlyGoldenGuaranteeSatisfied = true },
            _Meta = { SaveRevision = 9, SessionId = "abc", SessionTouchedAt = 1, LastSavedAt = 1 },
        })
        expect(record.SchemaVersion).toBe(2)
        expect(record.Economy.Credits).toBe(321)
        expect(record.Line.ProductValueLevel).toBe(3)
        expect(record.Onboarding.TutorialStep).toBe(5)
        expect(record.Onboarding.HasPlayedBefore).toBeNil()
        expect(record._Meta).toBeNil()
        expect(record.Factory.ResearchLabPurchased).toBeNil()
        expect(record.Products.Departments.Household).toBe(true)
        expect(record.Products.Unlocked.Mug).toBe(true)
        expect(hasRepair(repairs, "migrated schema 1 to 2")).toBe(true)
    end)

    it("migrates a v1 player who left mid-tutorial to step 0, not 'returning'", function()
        local record = Schema().Repair({ SchemaVersion = 1, Onboarding = { HasPlayedBefore = true, HasCompletedFirstShift = false } })
        expect(record.Onboarding.TutorialStep).toBe(0)
    end)

    it("unlocks what department revenue has earned, whatever the record says", function()
        local raw = Schema().Template()
        raw.Products.DepartmentRevenue.Toys = 2000
        raw.Products.Unlocked.RubberDuck = false
        local record = Schema().Repair(raw)
        expect(record.Products.Unlocked.RubberDuck).toBe(true)
        expect(record.Products.Unlocked.ToyCar).toBe(true)
        expect(record.Products.Unlocked.ToyRobot).toBe(true)
        expect(record.Products.Unlocked.DinosaurFigure).toBe(false)
        -- Household revenue counts only once the department is open.
        raw.Products.DepartmentRevenue.Household = 50000
        expect(Schema().Repair(raw).Products.Unlocked.TableLamp).toBe(false)
    end)

    it("survives repeated save cycles unchanged (fixed point)", function()
        local schema = Schema()
        local raw = schema.Template()
        raw.Economy.Credits = 765432
        raw.Factory.HouseholdProductionPurchased = true
        raw.Collection.Archive.Glitched_Mug = true
        raw.Onboarding.TutorialStep = 3
        local once = schema.Repair(raw)
        local twice, repairs = schema.Repair(once)
        expect(twice).toEqual(once)
        expect(#repairs).toBe(0)
    end)

    it("holds the full progression matrix", function()
        local schema = Schema()
        local config = require(game:GetService("ReplicatedStorage").Shared.Config)
        local raw = schema.Template()
        for upgradeId, field in pairs(schema.UpgradeFields) do
            local _, maximum = config.Upgrades.LevelRange(upgradeId)
            raw[field[1]][field[2]] = maximum
        end
        raw.Line.OperatingTier = 7
        raw.Factory.ProductionTier = config.Factory.MaxTier("Production")
        raw.Factory.ResearchTier = config.Factory.MaxTier("Research")
        raw.Factory.RejectGalleryPurchased = true
        raw.Factory.HouseholdProductionPurchased = true
        for key in pairs(raw.Collection.Archive) do raw.Collection.Archive[key] = true end
        for productId in pairs(raw.Products.Unlocked) do raw.Products.Unlocked[productId] = true end
        raw.Products.Departments.Household = true
        raw.Funnel.FirstUpgradePurchased = true
        raw.Onboarding.TutorialStep = 5
        local record, repairs = schema.Repair(raw)
        expect(record).toEqual(raw)
        expect(#repairs).toBe(0)
    end)
end)
