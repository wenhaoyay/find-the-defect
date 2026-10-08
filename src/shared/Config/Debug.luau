-- Studio-only switches. Outside Studio every one of them reads as off, whatever
-- is written here, so a forgotten `true` cannot reach players.

local RunService = game:GetService("RunService")

local switches = {
    UnlockAllProducts = false,
    UnlockAllDepartments = false,
    UnlockAllProjects = false,
    ForceProductId = "",
    ForceDefect = "",
    ForceAnomaly = "",
    CreditGrant = 0,
}

if not RunService:IsStudio() then
    for name, value in pairs(switches) do
        if type(value) == "boolean" then
            switches[name] = false
        elseif type(value) == "string" then
            switches[name] = ""
        else
            switches[name] = 0
        end
    end
end

return switches
