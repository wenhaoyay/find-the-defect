-- The emulator itself: if these fail, no other result means anything.

describe("harness", function()
    it("runs threads on a virtual clock", function(t)
        local started = t.world.now
        local order = {}
        task.delay(2, function() table.insert(order, "delay2") end)
        task.spawn(function()
            t.wait(1)
            table.insert(order, "wait1")
        end)
        task.defer(function() table.insert(order, "defer") end)
        t.wait(3)
        expect(order).toEqual({ "defer", "wait1", "delay2" })
        expect(t.world.now - started).toBeCloseTo(3, 0.06)
    end)

    it("defers signal handlers until the firing thread yields", function(t)
        local value = Instance.new("IntValue")
        local seen = {}
        value.Changed:Connect(function(v) table.insert(seen, v) end)
        value.Value = 3
        expect(#seen).toBe(0)
        t.wait()
        expect(seen).toEqual({ 3 })
    end)

    it("is strict about members, types and destroyed parents", function()
        local folder = Instance.new("Folder")
        expect(function() return folder.NoSuchThing end).toThrow("not a valid member")
        local value = Instance.new("IntValue")
        expect(function() value.Value = "x" end).toThrow("number expected")
        value.Value = 2.7
        expect(value.Value).toBe(2)
        folder:Destroy()
        expect(function() folder.Parent = workspace end).toThrow("locked")
    end)

    it("maps the Rojo project into the tree", function(t)
        expect(t.server:resolve("ServerScriptService.Vendor.ProfileStore").ClassName).toBe("ModuleScript")
        expect(game:GetService("ReplicatedStorage"):FindFirstChild("Shared")).never.toBeNil()
    end)

    it("shares one DataStore between servers, with latency", function(t)
        local storeA = game:GetService("DataStoreService"):GetDataStore("S")
        local before = t.world.now
        storeA:SetAsync("k", { n = 1 })
        expect(t.world.now - before).toBeGreaterThan(0.1)
        local serverB = t.world:newServer({ jobId = "server-B" })
        local value = t.within(serverB, function()
            local storeB = serverB.game:GetService("DataStoreService"):GetDataStore("S")
            return storeB:UpdateAsync("k", function(old) return { n = old.n + 1 } end)
        end)
        expect(value.n).toBe(2)
        expect(t.world:peek("S", "k")).toEqual({ n = 2 })
    end)

    it("refuses what a DataStore cannot store", function()
        local store = game:GetService("DataStoreService"):GetDataStore("S")
        expect(function() store:SetAsync("k", { 1, 2, x = 3 }) end).toThrow("mixed")
        expect(function() store:SetAsync("k", { f = function() end }) end).toThrow("cannot store")
        expect(function() store:SetAsync("k", { n = 0 / 0 }) end).toThrow("non-finite")
    end)

    it("drops a dead server's threads", function(t)
        local serverB = t.world:newServer({ jobId = "server-B" })
        local finished = false
        t.world:spawnIn(serverB, function()
            t.world.task.wait(5)
            finished = true
        end)
        serverB:kill()
        t.wait(6)
        expect(finished).toBe(false)
    end)

    it("never fetches code by asset id", function()
        expect(function() require(12345) end).toThrow("not allowed")
    end)
end)
