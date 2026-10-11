-- Factory projects: one-off purchases that unlock rooms, departments and the
-- higher levels of some upgrades (Production and Research tiers).

local Factory = {}

Factory.ProjectOrder = {
    "ProductionSystemsII",
    "ProductionSystemsIII",
    "ResearchLab",
    "ResearchLabII",
    "ResearchLabIII",
    "RejectGallery",
    "HouseholdProduction",
}

Factory.Projects = {
    ProductionSystemsII = {
        DisplayName = "PRODUCTION SYSTEMS II",
        Description = "Industrial drive cooling and expanded line capacity.",
        Cost = 9000,
        Branch = "Production",
        Tier = 2,
    },
    ProductionSystemsIII = {
        DisplayName = "PRODUCTION SYSTEMS III",
        Description = "High-output power routing and maximum line capacity.",
        Cost = 45000,
        Branch = "Production",
        Tier = 3,
    },
    ResearchLab = {
        DisplayName = "RESEARCH LAB I",
        Description = "Bring basic anomaly analysis and the Research console online.",
        Cost = 2500,
        Branch = "Research",
        Tier = 1,
    },
    ResearchLabII = {
        DisplayName = "RESEARCH LAB II",
        Description = "Install advanced scanners and unlock deeper analysis.",
        Cost = 18000,
        Branch = "Research",
        Tier = 2,
    },
    ResearchLabIII = {
        DisplayName = "RESEARCH LAB III",
        Description = "Energize the experimental containment analyzer.",
        Cost = 75000,
        Branch = "Research",
        Tier = 3,
    },
    RejectGallery = {
        DisplayName = "REJECT GALLERY",
        Description = "Install the Archive exhibits and a Rarest Find display.",
        Cost = 9000,
        Flag = "RejectGalleryPurchased",
    },
    HouseholdProduction = {
        DisplayName = "HOUSEHOLD PRODUCTION",
        Description = "Open a new Department and bring Mug production online.",
        Cost = 3500,
        Flag = "HouseholdProductionPurchased",
        Requirements = { ProductionTier = 2, LineRevenue = 2500 },
    },
}

-- Production starts at tier 1 (built in); Research at tier 0 (no lab).
Factory.BaseTier = { Production = 1, Research = 0 }

function Factory.MaxTier(branch)
    local highest = Factory.BaseTier[branch]
    for _, project in pairs(Factory.Projects) do
        if project.Branch == branch then
            highest = math.max(highest, project.Tier)
        end
    end
    return highest
end

return Factory
