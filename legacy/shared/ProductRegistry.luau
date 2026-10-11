local Registry = {}

Registry.DebugDepartmentUnlock = false
Registry.DebugProductUnlockAll = false
Registry.DebugForceDefectType = ""
Registry.DebugForceProductId = ""

Registry.ProductOrder = {
    "TeddyBear", "RubberDuck", "ToyCar", "ToyRobot", "DinosaurFigure", "ToyAeroplane",
    "Mug", "TableLamp", "Toaster", "Kettle", "DeskFan", "AlarmClock",
}

Registry.DefectOrder = {"Normal", "WrongColour", "Tiny", "Giant", "MissingPart", "ExtraPart"}
Registry.Defects = {
    Normal = {Weight = 0.68, RushWeight = 0.45, Scale = 1, DisplayPrefix = "Normal", Defective = false, BaseReward = 2, Difficulty = "Approved"},
    WrongColour = {Weight = 0.10, RushWeight = 0.18, Scale = 1, DisplayPrefix = "Wrong Colour", Defective = true, BaseReward = 10, Difficulty = "Obvious"},
    Tiny = {Weight = 0.05, RushWeight = 0.08, Scale = 0.65, DisplayPrefix = "Tiny", Defective = true, BaseReward = 15, Difficulty = "Moderate"},
    Giant = {Weight = 0.05, RushWeight = 0.09, Scale = 1.4, DisplayPrefix = "Giant", Defective = true, BaseReward = 18, Difficulty = "Obvious"},
    MissingPart = {Weight = 0.07, RushWeight = 0.10, Scale = 1, DisplayPrefix = "Missing Part", Defective = true, BaseReward = 20, Difficulty = "Moderate"},
    ExtraPart = {Weight = 0.05, RushWeight = 0.10, Scale = 1, DisplayPrefix = "Extra Part", Defective = true, BaseReward = 24, Difficulty = "Subtle"},
}

local globalDefects = {"Normal", "WrongColour", "Tiny", "Giant", "MissingPart", "ExtraPart"}

local function component(parts, missingTarget, extraSource, extraOffset, extraRotation, missingAll, extraAll)
    return {
        Parts = parts,
        MissingTarget = missingTarget,
        ExtraSource = extraSource,
        ExtraOffset = extraOffset or Vector3.zero,
        ExtraRotation = extraRotation or Vector3.zero,
        MissingAll = missingAll == true,
        ExtraAll = extraAll == true,
    }
end

local function product(data)
    data.ValidDefects = data.ValidDefects or globalDefects
    data.AnomalyCompatible = data.AnomalyCompatible ~= false
    data.SpawnWeight = data.SpawnWeight or 1
    data.ReferenceEnabled = data.ReferenceEnabled ~= false
    return data
end

Registry.Products = {
    TeddyBear = product({
        ProductId = "TeddyBear", DisplayName = "Teddy Bear", ShortName = "Teddy", ReferenceLabel = "TEDDY",
        DepartmentId = "Toys", BuilderId = "TeddyBear", Multiplier = 1.00, UnlockRevenue = 0,
        BodyColor = Color3.fromRGB(132, 82, 48), AccentColor = Color3.fromRGB(232, 199, 151), WrongColor = Color3.fromRGB(35, 218, 235),
        HitboxSize = Vector3.new(5.2, 8.8, 3.6), HitboxOffset = Vector3.new(0, 0.55, 0),
        Components = {Ear = component({"LeftEar", "RightEar"}, "RightEar", "LeftEar", Vector3.new(-2.3, 0.6, 0))},
        ComponentDefects = {MissingPart = "Ear", ExtraPart = "Ear"},
    }),
    RubberDuck = product({
        ProductId = "RubberDuck", DisplayName = "Rubber Duck", ShortName = "Duck", ReferenceLabel = "DUCK",
        DepartmentId = "Toys", BuilderId = "RubberDuck", Multiplier = 1.25, UnlockRevenue = 150,
        BodyColor = Color3.fromRGB(255, 218, 45), AccentColor = Color3.fromRGB(245, 126, 35), WrongColor = Color3.fromRGB(195, 70, 255),
        HitboxSize = Vector3.new(5.5, 5.6, 3.8), HitboxOffset = Vector3.new(0, 0.95, 0),
        Components = {
            Beak = component({"Beak"}, "Beak", "Beak", Vector3.new(0, 0.9, 0.2)),
            Wing = component({"LeftWing", "RightWing"}, "RightWing", "LeftWing", Vector3.new(-0.2, 1.3, 0.7), Vector3.new(0, 0, 25)),
        },
        ComponentDefects = {MissingPart = "Beak", ExtraPart = "Wing"},
    }),
    ToyCar = product({
        ProductId = "ToyCar", DisplayName = "Toy Car", ShortName = "Car", ReferenceLabel = "TOY CAR",
        DepartmentId = "Toys", BuilderId = "ToyCar", Multiplier = 1.50, UnlockRevenue = 700,
        BodyColor = Color3.fromRGB(220, 55, 55), AccentColor = Color3.fromRGB(30, 32, 38), WrongColor = Color3.fromRGB(35, 218, 235),
        HitboxSize = Vector3.new(6.2, 4.0, 4.0), HitboxOffset = Vector3.new(0, 0.25, 0),
        Components = {Wheel = component({"WheelLF", "WheelRF", "WheelLB", "WheelRB"}, "WheelRF", "WheelLF", Vector3.new(0, 2.2, 0.4), Vector3.new(0, 0, 25))},
        ComponentDefects = {MissingPart = "Wheel", ExtraPart = "Wheel"},
    }),
    ToyRobot = product({
        ProductId = "ToyRobot", DisplayName = "Toy Robot", ShortName = "Robot", ReferenceLabel = "ROBOT",
        DepartmentId = "Toys", BuilderId = "ToyRobot", Multiplier = 1.55, UnlockRevenue = 2000,
        BodyColor = Color3.fromRGB(80, 145, 205), AccentColor = Color3.fromRGB(225, 178, 55), WrongColor = Color3.fromRGB(235, 80, 165),
        HitboxSize = Vector3.new(6.2, 8.2, 3.8), HitboxOffset = Vector3.new(0, 0.6, 0),
        Components = {Arm = component({"LeftArm", "RightArm"}, "RightArm", "LeftArm", Vector3.new(-0.4, 2.5, 0.5), Vector3.new(0, 0, 30))},
        ComponentDefects = {MissingPart = "Arm", ExtraPart = "Arm"},
    }),
    DinosaurFigure = product({
        ProductId = "DinosaurFigure", DisplayName = "Dinosaur Figure", ShortName = "Dinosaur", ReferenceLabel = "DINOSAUR",
        DepartmentId = "Toys", BuilderId = "DinosaurFigure", Multiplier = 1.65, UnlockRevenue = 6000,
        BodyColor = Color3.fromRGB(78, 164, 88), AccentColor = Color3.fromRGB(218, 188, 72), WrongColor = Color3.fromRGB(105, 80, 235),
        HitboxSize = Vector3.new(8.5, 6.0, 3.8), HitboxOffset = Vector3.new(0, 0.5, 0),
        Components = {
            Tail = component({"Tail"}, "Tail", "Tail", Vector3.new(-0.8, 1.0, 0.8), Vector3.new(0, 0, -30)),
            Horn = component({"Horn"}, "Horn", "Horn", Vector3.new(0.8, 0.8, 0.5), Vector3.new(0, 0, 25)),
        },
        ComponentDefects = {MissingPart = "Tail", ExtraPart = "Horn"},
    }),
    ToyAeroplane = product({
        ProductId = "ToyAeroplane", DisplayName = "Toy Aeroplane", ShortName = "Aeroplane", ReferenceLabel = "AEROPLANE",
        DepartmentId = "Toys", BuilderId = "ToyAeroplane", Multiplier = 1.75, UnlockRevenue = 14000,
        BodyColor = Color3.fromRGB(225, 78, 62), AccentColor = Color3.fromRGB(235, 235, 225), WrongColor = Color3.fromRGB(65, 205, 215),
        HitboxSize = Vector3.new(9.0, 4.2, 7.0), HitboxOffset = Vector3.new(0, 0.35, 0),
        Components = {Wing = component({"LeftWing", "RightWing"}, "RightWing", "LeftWing", Vector3.new(0, 1.0, 1.5), Vector3.new(10, 0, 12))},
        ComponentDefects = {MissingPart = "Wing", ExtraPart = "Wing"},
    }),
    Mug = product({
        ProductId = "Mug", DisplayName = "Mug", ShortName = "Mug", ReferenceLabel = "MUG",
        DepartmentId = "Household", BuilderId = "Mug", Multiplier = 1.80, UnlockRevenue = 0,
        BodyColor = Color3.fromRGB(225, 230, 235), AccentColor = Color3.fromRGB(72, 145, 190), WrongColor = Color3.fromRGB(245, 95, 55),
        HitboxSize = Vector3.new(5.8, 5.5, 4.5), HitboxOffset = Vector3.new(0.5, 0.5, 0),
        Components = {Handle = component({"HandleTop", "HandleSide", "HandleBottom"}, nil, nil, Vector3.new(-4.0, 0, 0), Vector3.zero, true, true)},
        ComponentDefects = {MissingPart = "Handle", ExtraPart = "Handle"},
    }),
    TableLamp = product({
        ProductId = "TableLamp", DisplayName = "Table Lamp", ShortName = "Lamp", ReferenceLabel = "TABLE LAMP",
        DepartmentId = "Household", BuilderId = "TableLamp", Multiplier = 1.95, UnlockRevenue = 1200,
        BodyColor = Color3.fromRGB(214, 205, 170), AccentColor = Color3.fromRGB(70, 92, 115), WrongColor = Color3.fromRGB(70, 230, 135),
        HitboxSize = Vector3.new(6.0, 8.0, 5.0), HitboxOffset = Vector3.new(0, 1.0, 0),
        Components = {Shade = component({"ShadeTop", "ShadeBody"}, nil, nil, Vector3.new(2.8, -0.6, 0.8), Vector3.new(0, 0, 18), true, true)},
        ComponentDefects = {MissingPart = "Shade", ExtraPart = "Shade"},
    }),
    Toaster = product({
        ProductId = "Toaster", DisplayName = "Toaster", ShortName = "Toaster", ReferenceLabel = "TOASTER",
        DepartmentId = "Household", BuilderId = "Toaster", Multiplier = 2.10, UnlockRevenue = 4000,
        BodyColor = Color3.fromRGB(165, 170, 178), AccentColor = Color3.fromRGB(45, 48, 54), WrongColor = Color3.fromRGB(240, 135, 45),
        HitboxSize = Vector3.new(6.6, 5.2, 4.8), HitboxOffset = Vector3.new(0, 0.4, 0),
        Components = {Lever = component({"LeverStem", "LeverKnob"}, nil, nil, Vector3.new(0, 1.6, 0.7), Vector3.new(0, 0, -20), true, true)},
        ComponentDefects = {MissingPart = "Lever", ExtraPart = "Lever"},
    }),
    Kettle = product({
        ProductId = "Kettle", DisplayName = "Kettle", ShortName = "Kettle", ReferenceLabel = "KETTLE",
        DepartmentId = "Household", BuilderId = "Kettle", Multiplier = 2.25, UnlockRevenue = 9000,
        BodyColor = Color3.fromRGB(180, 190, 198), AccentColor = Color3.fromRGB(42, 48, 58), WrongColor = Color3.fromRGB(210, 72, 190),
        HitboxSize = Vector3.new(7.0, 6.5, 5.0), HitboxOffset = Vector3.new(0.4, 0.6, 0),
        Components = {
            Lid = component({"Lid", "LidKnob"}, nil, nil, Vector3.new(1.4, 0.8, 0.4), Vector3.new(0, 0, 18), true, true),
            Handle = component({"HandleTop", "HandleBack"}, nil, nil, Vector3.new(-4.0, 0.2, 0), Vector3.zero, true, true),
        },
        ComponentDefects = {MissingPart = "Lid", ExtraPart = "Handle"},
    }),
    DeskFan = product({
        ProductId = "DeskFan", DisplayName = "Desk Fan", ShortName = "Fan", ReferenceLabel = "DESK FAN",
        DepartmentId = "Household", BuilderId = "DeskFan", Multiplier = 2.40, UnlockRevenue = 18000, GiantScale = 1.25,
        BodyColor = Color3.fromRGB(92, 145, 165), AccentColor = Color3.fromRGB(35, 42, 48), WrongColor = Color3.fromRGB(235, 95, 65),
        HitboxSize = Vector3.new(7.0, 8.0, 4.5), HitboxOffset = Vector3.new(0, 1.0, 0),
        Components = {Blade = component({"Blade1", "Blade2", "Blade3", "Blade4"}, "Blade1", "Blade2", Vector3.new(0.6, 0.5, 0.5), Vector3.new(0, 0, 45))},
        ComponentDefects = {MissingPart = "Blade", ExtraPart = "Blade"},
    }),
    AlarmClock = product({
        ProductId = "AlarmClock", DisplayName = "Alarm Clock", ShortName = "Clock", ReferenceLabel = "ALARM CLOCK",
        DepartmentId = "Household", BuilderId = "AlarmClock", Multiplier = 2.60, UnlockRevenue = 32000,
        BodyColor = Color3.fromRGB(230, 85, 75), AccentColor = Color3.fromRGB(238, 226, 190), WrongColor = Color3.fromRGB(70, 205, 225),
        HitboxSize = Vector3.new(6.5, 6.6, 4.2), HitboxOffset = Vector3.new(0, 0.7, 0),
        Components = {Bell = component({"LeftBell", "RightBell"}, "RightBell", "LeftBell", Vector3.new(0.4, 1.6, 0.5), Vector3.new(0, 0, 25))},
        ComponentDefects = {MissingPart = "Bell", ExtraPart = "Bell"},
    }),
}

function Registry.Get(productId)
    return Registry.Products[productId]
end

function Registry.GetDepartmentProducts(departmentId)
    local result = {}
    for _, productId in ipairs(Registry.ProductOrder) do
        local product = Registry.Products[productId]
        if product.DepartmentId == departmentId then table.insert(result, productId) end
    end
    return result
end

return Registry