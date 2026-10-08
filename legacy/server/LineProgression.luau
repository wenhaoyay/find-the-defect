local TweenService = game:GetService("TweenService")

local LineProgression = {}
LineProgression.__index = LineProgression

function LineProgression.new(root, upgradeConfig)
    local self = setmetatable({}, LineProgression)
    self.Root = root
    self.Config = upgradeConfig
    self.Conveyor = root:WaitForChild("Conveyor")
    self.RightInspectionX = 7
    self.BaseLength = 14
    self.BaseLeftEdge = -31
    self.RightEdge = 31
    self:_ensureExtensionParts()
    return self
end

local function createPart(parent, name, size, cframe, color, material)
    local part = Instance.new("Part")
    part.Name = name
    part.Anchored = true
    part.CanCollide = true
    part.Size = size
    part.CFrame = cframe
    part.Color = color
    part.Material = material or Enum.Material.Metal
    part.Parent = parent
    return part
end

function LineProgression:_ensureExtensionParts()
    local folder = self.Conveyor:FindFirstChild("Stage3Extension")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "Stage3Extension"
        folder.Parent = self.Conveyor
    end
    self.Extension = folder

    if #folder:GetChildren() == 0 then
        for x = -48, -32, 4 do
            local roller = createPart(
                folder,
                "ExtensionRoller",
                Vector3.new(1, 6.2, 1),
                CFrame.new(x, 2.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
                Color3.fromRGB(105, 115, 125),
                Enum.Material.Metal
            )
            roller.Shape = Enum.PartType.Cylinder
        end
        for _, x in ipairs({-42, -35}) do
            createPart(
                folder,
                "ExtensionSupport",
                Vector3.new(1.2, 3, 5),
                CFrame.new(x, 0.5, 0),
                Color3.fromRGB(65, 72, 82),
                Enum.Material.Metal
            )
        end
        createPart(
            folder,
            "ExtensionFloor",
            Vector3.new(20, 0.35, 12),
            CFrame.new(-40, 0.15, 0),
            Color3.fromRGB(38, 42, 49),
            Enum.Material.Concrete
        )
    end
end

function LineProgression:GetLevel(level)
    return self.Config.Upgrades.InspectionRunway.Levels[level]
end

function LineProgression:GetInspectionBounds(level)
    local length = self:GetLevel(level).Length
    return self.RightInspectionX - length, self.RightInspectionX
end

function LineProgression:GetSpawnX(level)
    local minX = self:GetInspectionBounds(level)
    return minX - 22
end

function LineProgression:Apply(level, animate)
    local runway = self:GetLevel(level)
    local length = runway.Length
    local extension = length - self.BaseLength
    local inspectionMin = self.RightInspectionX - length
    local leftEdge = self.BaseLeftEdge - extension
    local totalLength = self.RightEdge - leftEdge
    local centerX = (self.RightEdge + leftEdge) * 0.5

    local belt = self.Conveyor:WaitForChild("Belt")
    local base = self.Conveyor:WaitForChild("ConveyorBase")
    local inspectionSurface = self.Conveyor:WaitForChild("InspectionSurface")
    local front = self.Conveyor:WaitForChild("ZoneFrontStripe")
    local back = self.Conveyor:WaitForChild("ZoneBackStripe")
    local leftMarker = self.Conveyor:WaitForChild("ZoneLeftMarker")
    local rightMarker = self.Conveyor:WaitForChild("ZoneRightMarker")

    local duration = animate and 0.7 or 0
    local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local goals = {
        {base, {Size = Vector3.new(totalLength, base.Size.Y, base.Size.Z), CFrame = CFrame.new(centerX, 1.5, 0)}},
        {belt, {Size = Vector3.new(totalLength, belt.Size.Y, belt.Size.Z), CFrame = CFrame.new(centerX, 2.45, 0)}},
        {inspectionSurface, {Size = Vector3.new(length, inspectionSurface.Size.Y, inspectionSurface.Size.Z), CFrame = CFrame.new((inspectionMin + self.RightInspectionX) * 0.5, 2.655, 0)}},
        {front, {Size = Vector3.new(length, front.Size.Y, front.Size.Z), CFrame = CFrame.new((inspectionMin + self.RightInspectionX) * 0.5, 2.665, 3)}},
        {back, {Size = Vector3.new(length, back.Size.Y, back.Size.Z), CFrame = CFrame.new((inspectionMin + self.RightInspectionX) * 0.5, 2.665, -3)}},
        {leftMarker, {CFrame = CFrame.new(inspectionMin, 2.665, 0)}},
        {rightMarker, {CFrame = CFrame.new(self.RightInspectionX, 2.665, 0)}},
    }

    for _, item in ipairs(goals) do
        if duration > 0 then
            TweenService:Create(item[1], info, item[2]):Play()
        else
            for property, value in pairs(item[2]) do
                item[1][property] = value
            end
        end
    end

    for _, part in ipairs(self.Extension:GetChildren()) do
        if part:IsA("BasePart") then
            if part.Name == "ExtensionFloor" then
                part.Transparency = extension > 0 and 0.18 or 1
                part.CanCollide = false
                part.Size = Vector3.new(math.max(extension, 0.1), 0.35, 12)
                part.CFrame = CFrame.new(self.BaseLeftEdge - extension * 0.5, 0.15, 0)
            else
                local active = part.Position.X >= leftEdge + 1 and part.Position.X < self.BaseLeftEdge
                part.Transparency = active and 0.4 or 1
                part.CanCollide = false
            end
        end
    end

    self.Root:SetAttribute("InspectionRunwayLevel", level)
    self.Root:SetAttribute("InspectionRunwayLength", length)
    self.Root:SetAttribute("InspectionMinX", inspectionMin)
    self.Root:SetAttribute("InspectionMaxX", self.RightInspectionX)
    self.Root:SetAttribute("ProductSpawnX", inspectionMin - 22)

    return inspectionMin, self.RightInspectionX
end

return LineProgression