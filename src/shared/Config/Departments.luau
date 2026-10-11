-- Departments group products; a department's products unlock from its own revenue.

local Departments = {}

Departments.Order = { "Toys", "Household" }

Departments.Definitions = {
    Toys = {
        DepartmentId = "Toys",
        DisplayName = "TOYS",
        DefaultUnlocked = true,
        StarterProduct = "TeddyBear",
        AccentColor = Color3.fromRGB(238, 170, 72),
    },
    Household = {
        DepartmentId = "Household",
        DisplayName = "HOUSEHOLD",
        DefaultUnlocked = false,
        StarterProduct = "Mug",
        UnlockedByProject = "HouseholdProduction",
        AccentColor = Color3.fromRGB(80, 190, 215),
    },
}

function Departments.Get(departmentId)
    return Departments.Definitions[departmentId]
end

return Departments
