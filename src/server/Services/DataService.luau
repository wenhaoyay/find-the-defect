-- Player data on ProfileStore.
--
-- ProfileStore owns what used to break: session locks handed between servers
-- (a quick rejoin waits for the old server instead of being kicked), saves
-- queued rather than skipped (a leave during an autosave still saves), and the
-- shutdown flush. This module adds the game's rules on top:
--   * every loaded record goes through Schema.Repair BEFORE anything else, and a
--     record from a newer schema is refused rather than overwritten;
--   * the record is the single source of truth while the player is here
--     (DataService.Get returns the live table; nothing else stores player state);
--   * if another server takes the session, this server lets the player go.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Schema = require(script.Parent.Parent.Data.Schema)
local ProfileStore = require(ServerScriptService.Vendor.ProfileStore)

local Persistence = Config.Persistence

local DataService = {}

DataService.Loaded = Signal.new() -- (player, data)

local store
local sessions = {} -- [player] = { Profile, JoinedAt, LastCheckpoint, CheckpointQueued, Releasing }
local releaseHandlers = {}

local MESSAGES = {
    Busy = "Your factory is still being saved by another server. Please rejoin in a moment.",
    Newer = "Your factory was saved by a newer version of the game. Please rejoin in a minute.",
    Taken = "Your factory was opened on another server.",
}

function DataService.FailureMessage(reason)
    if reason == "Newer" then return MESSAGES.Newer end
    return MESSAGES.Busy
end

local function profileKey(player)
    return Persistence.KeyPrefix .. tostring(player.UserId)
end

local function isHere(player)
    return player.Parent == Players
end

-- options.StoreName lets tests use their own store.
function DataService.Init(options)
    if store then return end
    options = options or {}
    local name = options.StoreName or (RunService:IsStudio() and Persistence.StudioStoreName or Persistence.StoreName)
    ProfileStore.SetConstant("AUTO_SAVE_PERIOD", Persistence.AutosavePeriod)
    -- No template: Schema.Repair fills defaults. ProfileStore's Reconcile would run
    -- before our migrations and hide what an old record actually contained.
    store = ProfileStore.New(name)

    Players.PlayerRemoving:Connect(function(player)
        DataService.Release(player)
    end)
end

-- Yields. Returns the player's live record, or nil and a reason:
-- "Left" (gone while loading), "Busy" (could not get the session), "Newer".
function DataService.LoadAsync(player)
    assert(store, "DataService.Init must be called first")
    if sessions[player] then return sessions[player].Profile.Data end

    local profile = store:StartSessionAsync(profileKey(player), {
        Cancel = function()
            return not isHere(player)
        end,
    })
    if profile == nil then
        return nil, isHere(player) and "Busy" or "Left"
    end

    local record, repairs = Schema.Repair(profile.Data)
    if record == nil then
        -- Leave the stored record exactly as it is; a newer server will read it.
        warn(`[DataService] Refused {profileKey(player)}: {repairs}`)
        profile:EndSession()
        return nil, "Newer"
    end
    for _, message in ipairs(repairs) do
        warn(`[DataService] {profileKey(player)}: {message}`)
    end
    profile.Data = record
    profile:AddUserId(player.UserId) -- data-deletion requests find the key by user id

    if not isHere(player) then
        profile:EndSession()
        return nil, "Left"
    end

    local session = {
        Profile = profile,
        JoinedAt = os.clock(),
        LastCheckpoint = os.clock(),
        CheckpointQueued = false,
        Releasing = false,
    }
    sessions[player] = session

    profile.OnSessionEnd:Connect(function()
        if sessions[player] == session then sessions[player] = nil end
        if not session.Releasing and isHere(player) then
            player:Kick(MESSAGES.Taken)
        end
    end)

    DataService.Loaded:Fire(player, record)
    return record
end

function DataService.IsLoaded(player)
    return sessions[player] ~= nil
end

-- The live record. Mutate it directly; it is saved by autosave, checkpoints
-- and on release.
function DataService.Get(player)
    local session = sessions[player]
    return session and session.Profile.Data or nil
end

-- Run fn(player, data) synchronously just before a player's record is released,
-- so the last changes (play time, analytics totals) are in the final save.
function DataService.OnRelease(fn)
    table.insert(releaseHandlers, fn)
end

function DataService.Release(player)
    local session = sessions[player]
    if not session or session.Releasing then return end
    session.Releasing = true
    local data = session.Profile.Data
    data.Statistics.PlaySeconds += math.floor(os.clock() - session.JoinedAt)
    for _, handler in ipairs(releaseHandlers) do
        local ok, err = pcall(handler, player, data)
        if not ok then warn("[DataService] release handler failed: " .. tostring(err)) end
    end
    sessions[player] = nil
    session.Profile:EndSession()
end

-- Save soon after an important change (a purchase, a discovery), at most once
-- per CheckpointSpacing per player; changes in between ride along.
function DataService.Checkpoint(player)
    local session = sessions[player]
    if not session or session.CheckpointQueued then return end
    local wait = Persistence.CheckpointSpacing - (os.clock() - session.LastCheckpoint)
    if wait <= 0 then
        session.LastCheckpoint = os.clock()
        session.Profile:Save()
        return
    end
    session.CheckpointQueued = true
    task.delay(wait, function()
        session.CheckpointQueued = false
        if sessions[player] ~= session then return end
        session.LastCheckpoint = os.clock()
        session.Profile:Save()
    end)
end

return DataService
