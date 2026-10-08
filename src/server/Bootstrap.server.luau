-- The server's one entry point: start the services in order, then admit players.
-- Gameplay (plots, lines, inspection) joins here in Phase 2.

local Players = game:GetService("Players")

local Services = script.Parent.Services
local DataService = require(Services.DataService)
local EconomyService = require(Services.EconomyService)

DataService.Init()
EconomyService.Init()

local function admit(player)
    local data, reason = DataService.LoadAsync(player)
    if not data then
        if reason ~= "Left" and player.Parent == Players then
            player:Kick(DataService.FailureMessage(reason))
        end
        return
    end
end

Players.PlayerAdded:Connect(admit)
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(admit, player)
end
