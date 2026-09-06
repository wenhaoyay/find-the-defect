local Departments = {}

Departments.DebugUnlockAll = false
Departments.Order = {"Toys", "Household"}
Departments.Definitions = {
    Toys = {
        DepartmentId = "Toys",
        DisplayName = "TOYS",
        DisplayOrder = 1,
        DefaultUnlocked = true,
        ProductIds = {"TeddyBear", "RubberDuck", "ToyCar", "ToyRobot", "DinosaurFigure", "ToyAeroplane"},
        ProjectId = nil,
        ArchiveCategory = "Toys",
        ReferenceGroup = "Toys",
        AccentColor = Color3.fromRGB(238, 170, 72),
    },
    Household = {
        DepartmentId = "Household",
        DisplayName = "HOUSEHOLD",
        DisplayOrder = 2,
        DefaultUnlocked = false,
        ProductIds = {"Mug", "TableLamp", "Toaster", "Kettle", "DeskFan", "AlarmClock"},
        ProjectId = "HouseholdProduction",
        ArchiveCategory = "Household",
        ReferenceGroup = "Household",
        AccentColor = Color3.fromRGB(80, 190, 215),
        Eligibility = {
            ProductionTier = 2,
            LineRevenue = 2500,
        },
    },
}

function Departments.Get(id)
    return Departments.Definitions[id]
end

function Departments.GetProductIds(id)
    local department = Departments.Definitions[id]
    return department and department.ProductIds or {}
end

return Departments