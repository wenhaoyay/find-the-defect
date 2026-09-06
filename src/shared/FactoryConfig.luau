local FactoryConfig = {}

FactoryConfig.DebugUnlockFactoryProjects = false
FactoryConfig.ProjectOrder = {
    "ProductionSystemsII",
    "ProductionSystemsIII",
    "ResearchLab",
    "ResearchLabII",
    "ResearchLabIII",
    "RejectGallery",
    "HouseholdProduction",
}
FactoryConfig.Projects = {
    ProductionSystemsII = {
        ProjectId = "ProductionSystemsII",
        DisplayName = "PRODUCTION SYSTEMS II",
        Description = "Industrial drive cooling and expanded line capacity.",
        Cost = 9000,
        DisplayOrder = 1,
        Branch = "Production",
        Tier = 2,
        PrerequisiteTier = 1,
        Available = true,
        ComingSoon = false,
    },
    ProductionSystemsIII = {
        ProjectId = "ProductionSystemsIII",
        DisplayName = "PRODUCTION SYSTEMS III",
        Description = "High-output power routing and maximum line capacity.",
        Cost = 45000,
        DisplayOrder = 2,
        Branch = "Production",
        Tier = 3,
        PrerequisiteTier = 2,
        Available = true,
        ComingSoon = false,
    },
    ResearchLab = {
        ProjectId = "ResearchLab",
        DisplayName = "RESEARCH LAB I",
        Description = "Bring basic anomaly analysis and the Research console online.",
        Cost = 2500,
        RoomReference = "ResearchLab",
        DisplayOrder = 3,
        Branch = "Research",
        Tier = 1,
        PrerequisiteTier = 0,
        StateName = "ResearchLabPurchased",
        Available = true,
        ComingSoon = false,
    },
    ResearchLabII = {
        ProjectId = "ResearchLabII",
        DisplayName = "RESEARCH LAB II",
        Description = "Install advanced scanners and unlock deeper analysis.",
        Cost = 18000,
        DisplayOrder = 4,
        Branch = "Research",
        Tier = 2,
        PrerequisiteTier = 1,
        Available = true,
        ComingSoon = false,
    },
    ResearchLabIII = {
        ProjectId = "ResearchLabIII",
        DisplayName = "RESEARCH LAB III",
        Description = "Energize the experimental containment analyzer.",
        Cost = 75000,
        DisplayOrder = 5,
        Branch = "Research",
        Tier = 3,
        PrerequisiteTier = 2,
        Available = true,
        ComingSoon = false,
    },
    RejectGallery = {
        ProjectId = "RejectGallery",
        DisplayName = "REJECT GALLERY",
        Description = "Install six Archive exhibits and a Rarest Find display.",
        Cost = 9000,
        RoomReference = "RejectGallery",
        DisplayOrder = 6,
        StateName = "RejectGalleryPurchased",
        Available = true,
        ComingSoon = false,
    },
    HouseholdProduction = {
        ProjectId = "HouseholdProduction",
        DisplayName = "HOUSEHOLD PRODUCTION",
        Description = "Open a new Department and bring Mug production online.",
        Cost = 3500,
        RoomReference = "HouseholdProduction",
        DisplayOrder = 7,
        StateName = "HouseholdProductionPurchased",
        Requirements = {
            ProductionTier = 2,
            LineRevenue = 2500,
        },
        Available = true,
        ComingSoon = false,
    },
}

FactoryConfig.Unlock = {
    Duration = 2.8,
    ShutterTween = 1.25,
    LightStep = 0.28,
    ActiveColor = Color3.fromRGB(60, 168, 104),
    LockedColor = Color3.fromRGB(139, 48, 55),
}

FactoryConfig.Layout = {
    Bounds = Vector3.new(240, 24, 160),
    OperatorPosition = CFrame.new(0, 3.5, 19),
    FactorySpawnPosition = CFrame.new(0, 3.5, 24),
}

return FactoryConfig