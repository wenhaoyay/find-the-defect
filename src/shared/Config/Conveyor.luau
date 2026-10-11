-- The ONE place the line's geometry lives (it used to be in three files that
-- disagreed). Coordinates are along the belt, in studs, relative to a line's
-- origin; products travel toward +X and the inspection window ends at
-- InspectionEndX whatever the runway length, growing backwards as it upgrades.

local Conveyor = {}

Conveyor.InspectionEndX = 7
Conveyor.BaseRunwayLength = 14
Conveyor.BeltLeftEdgeX = -31 -- at the base runway; moves left as the runway grows
Conveyor.BeltRightEdgeX = 31
Conveyor.CleanupX = 31 -- a product past this is removed
Conveyor.SpawnLead = 22 -- studs of belt before the inspection window starts
Conveyor.BeltSurfaceY = 2.7

function Conveyor.InspectionBounds(runwayLength)
    return Conveyor.InspectionEndX - runwayLength, Conveyor.InspectionEndX
end

function Conveyor.SpawnX(runwayLength)
    local startX = Conveyor.InspectionBounds(runwayLength)
    return startX - Conveyor.SpawnLead
end

function Conveyor.BeltLeftEdge(runwayLength)
    return Conveyor.BeltLeftEdgeX - (runwayLength - Conveyor.BaseRunwayLength)
end

return Conveyor
