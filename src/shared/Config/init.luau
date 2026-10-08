-- All game configuration, frozen. Nothing at runtime may change a config value
-- (the legacy code wrote to its anomaly config to force a debug anomaly).
-- Studio-only debug switches live in Debug, and read as off outside Studio.

local function deepFreeze(value)
    if type(value) ~= "table" or table.isfrozen(value) then
        return value
    end
    for _, child in pairs(value) do
        deepFreeze(child)
    end
    return table.freeze(value)
end

local Config = {
    Products = require(script.Products),
    Departments = require(script.Departments),
    Upgrades = require(script.Upgrades),
    Anomalies = require(script.Anomalies),
    Factory = require(script.Factory),
    Conveyor = require(script.Conveyor),
    Inspection = require(script.Inspection),
    Tutorial = require(script.Tutorial),
    Persistence = require(script.Persistence),
    Debug = require(script.Debug),
}

return deepFreeze(Config)
