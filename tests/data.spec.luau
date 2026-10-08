-- Player data end to end: Bootstrap + DataService + the real ProfileStore, on
-- emulated servers sharing one DataStore. These are the scenarios that lost
-- data or kicked players in the legacy PlayerDataService.

local STORE = "FindTheDefect_Profiles_v2"

local function boot(server)
    server:start()
    return server:require("ServerScriptService.Server.Services.DataService")
end

local function join(t, server, DataService, userId)
    local player = server:addPlayer({ userId = userId or 1 })
    t.world:waitUntil(function()
        return DataService.IsLoaded(player) or player.Parent == nil
    end, 180, "player load")
    return player
end

local function stored(t, userId)
    local entry = t.world:peek(STORE, "Player_" .. tostring(userId or 1))
    return entry and entry.Data, entry and entry.MetaData
end

local function waitReleased(t, userId)
    t.world:waitUntil(function()
        local _, meta = stored(t, userId)
        return meta ~= nil and meta.ActiveSession == nil
    end, 60, "session release")
end

describe("player data", function()
    it("gives a new player the template and saves it when they leave", function(t)
        local DataService = boot(t.server)
        local player = join(t, t.server, DataService)
        local data = DataService.Get(player)
        expect(data.Economy.Credits).toBe(0)
        expect(data.Products.Unlocked.TeddyBear).toBe(true)
        data.Economy.Credits = 40
        t.server:removePlayer(player)
        waitReleased(t)
        expect(stored(t).Economy.Credits).toBe(40)
        expect(stored(t).SchemaVersion).toBe(2)
    end)

    it("keeps progress across sessions", function(t)
        local DataService = boot(t.server)
        local player = join(t, t.server, DataService)
        DataService.Get(player).Economy.Credits = 500
        DataService.Get(player).Onboarding.TutorialStep = 2
        t.server:removePlayer(player)
        waitReleased(t)
        local again = join(t, t.server, DataService)
        expect(DataService.Get(again).Economy.Credits).toBe(500)
        -- Mid-tutorial players resume where they were (legacy: tutorial skipped).
        expect(DataService.Get(again).Onboarding.TutorialStep).toBe(2)
    end)

    it("lets a player rejoin another server at once, with their latest progress", function(t)
        local DataA = boot(t.server)
        local serverB = t.world:newServer({ jobId = "server-B" })
        local DataB = boot(serverB)
        local player = join(t, t.server, DataA)
        DataA.Get(player).Economy.Credits = 777 -- not saved yet
        t.server:removePlayer(player)
        local started = t.world.now
        local onB = t.within(serverB, function()
            return join(t, serverB, DataB)
        end)
        expect(DataB.IsLoaded(onB)).toBe(true)
        expect(Rbx.kickMessage(onB)).toBeNil()
        expect(DataB.Get(onB).Economy.Credits).toBe(777)
        expect(t.world.now - started).toBeLessThan(30)
    end)

    it("saves the final state when a player leaves during an autosave", function(t)
        local DataService = boot(t.server)
        local player = join(t, t.server, DataService)
        local data = DataService.Get(player)
        t.wait(20) -- past the checkpoint spacing, so the next checkpoint saves at once
        local function updates()
            local count = 0
            for _, call in ipairs(t.world.cloud.calls) do
                if call.method == "UpdateAsync" then
                    count += 1
                end
            end
            return count
        end
        local before = updates()
        data.Economy.Credits = 10
        DataService.Checkpoint(player)
        t.wait(0.05)
        expect(updates()).toBe(before + 1) -- that save is in flight now
        data.Economy.Credits = 999 -- changed while it is in flight
        t.server:removePlayer(player)
        waitReleased(t)
        expect(stored(t).Economy.Credits).toBe(999)
    end)

    it("saves everyone when the server shuts down", function(t)
        local DataService = boot(t.server)
        local first = join(t, t.server, DataService, 1)
        local second = join(t, t.server, DataService, 2)
        DataService.Get(first).Economy.Credits = 111
        DataService.Get(second).Economy.Credits = 222
        local clean = t.server:shutdown()
        expect(clean).toBe(true)
        expect(stored(t, 1).Economy.Credits).toBe(111)
        expect(stored(t, 2).Economy.Credits).toBe(222)
        local _, meta1 = stored(t, 1)
        local _, meta2 = stored(t, 2)
        expect(meta1.ActiveSession).toBeNil()
        expect(meta2.ActiveSession).toBeNil()
    end)

    it("recovers a player's last save after their server crashes", function(t)
        t.allow("DataStore API error")
        local DataA = boot(t.server)
        local serverB = t.world:newServer({ jobId = "server-B" })
        local DataB = boot(serverB)
        local player = join(t, t.server, DataA)
        DataA.Get(player).Economy.Credits = 100
        DataA.Checkpoint(player)
        t.world:waitUntil(function()
            local data = stored(t)
            return data ~= nil and data.Economy ~= nil and data.Economy.Credits == 100
        end, 30, "checkpoint")
        DataA.Get(player).Economy.Credits = 150 -- never saved
        t.server:kill()
        local started = t.world.now
        local onB = t.within(serverB, function()
            return join(t, serverB, DataB)
        end)
        expect(DataB.IsLoaded(onB)).toBe(true)
        expect(DataB.Get(onB).Economy.Credits).toBe(100)
        expect(t.world.now - started).toBeLessThan(90)
    end)

    it("lets the newest server win when a player is in two places, and kicks the old one", function(t)
        local DataA = boot(t.server)
        local serverB = t.world:newServer({ jobId = "server-B" })
        local DataB = boot(serverB)
        local onA = join(t, t.server, DataA)
        DataA.Get(onA).Economy.Credits = 55
        local onB = t.within(serverB, function()
            return join(t, serverB, DataB)
        end)
        expect(DataB.IsLoaded(onB)).toBe(true)
        expect(DataB.Get(onB).Economy.Credits).toBe(55)
        t.world:waitUntil(function()
            return onA.Parent == nil
        end, 30, "old server to let go")
        expect(Rbx.kickMessage(onA)).toContain("another server")
        expect(DataA.IsLoaded(onA)).toBe(false)
    end)

    it("refuses a record from a newer version and leaves it untouched", function(t)
        local store = game:GetService("DataStoreService"):GetDataStore(STORE)
        store:SetAsync("Player_1", {
            Data = { SchemaVersion = 3, Economy = { Credits = 4242 } },
            MetaData = { ProfileCreateTime = 0, SessionLoadCount = 1, MetaTags = {} },
            GlobalUpdates = { 0, {} },
        })
        local DataService = boot(t.server)
        local player = join(t, t.server, DataService)
        t.world:waitUntil(function()
            return player.Parent == nil
        end, 30, "kick")
        expect(Rbx.kickMessage(player)).toContain("newer version")
        waitReleased(t)
        expect(stored(t)).toEqual({ SchemaVersion = 3, Economy = { Credits = 4242 } })
    end)

    it("rides out transient DataStore errors", function(t)
        t.allow("DataStore API error")
        local failures = 3
        t.world.cloud.fail = function(method)
            if method == "UpdateAsync" and failures > 0 then
                failures -= 1
                return "502: API Services rejected request"
            end
            return nil
        end
        local DataService = boot(t.server)
        local player = join(t, t.server, DataService)
        expect(DataService.IsLoaded(player)).toBe(true)
        expect(failures).toBe(0)
    end)

    it("drops a load cleanly when the player leaves before it finishes", function(t)
        local DataService = boot(t.server)
        local player = t.server:addPlayer({ userId = 1 })
        t.wait(0.05)
        t.server:removePlayer(player)
        t.wait(10)
        expect(DataService.IsLoaded(player)).toBe(false)
        local _, meta = stored(t)
        expect(meta == nil or meta.ActiveSession == nil).toBe(true)
    end)

    it("saves a checkpoint at most once per spacing, with the latest values", function(t)
        local DataService = boot(t.server)
        local player = join(t, t.server, DataService)
        local data = DataService.Get(player)
        t.wait(20)
        local function writes()
            local count = 0
            for _, call in ipairs(t.world.cloud.calls) do
                if call.method == "UpdateAsync" then
                    count += 1
                end
            end
            return count
        end
        local before = writes()
        for credits = 1, 10 do
            data.Economy.Credits = credits
            DataService.Checkpoint(player)
            t.wait(1)
        end
        t.wait(20)
        expect(writes() - before).toBeLessThanOrEqual(2)
        expect(stored(t).Economy.Credits).toBe(10)
    end)

    it("adds play time on release", function(t)
        local DataService = boot(t.server)
        local player = join(t, t.server, DataService)
        t.wait(90)
        t.server:removePlayer(player)
        waitReleased(t)
        expect(stored(t).Statistics.PlaySeconds).toBeGreaterThanOrEqual(89)
    end)
end)
