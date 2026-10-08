-- The client's one entry point. Controllers (line rendering, input, UI) start
-- here in Phase 2; until then it only confirms the client tree loads.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
