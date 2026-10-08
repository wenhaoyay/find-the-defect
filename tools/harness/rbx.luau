--!nocheck
-- A small Roblox engine emulator, for running server code under plain Luau in tests.
--
-- It is deliberately strict where Roblox is strict (unknown members error, Parent
-- locks after Destroy, values are type-checked, DataStores refuse what they cannot
-- store) and adversarial where Roblox is timing-dependent (signals are deferred,
-- PlayerRemoving handlers see Parent == nil, DataStore calls take time and can fail,
-- a server can be shut down or crash mid-save). Several servers share one "cloud"
-- (DataStores + MessagingService) and one virtual clock, so cross-server session
-- handoff can be tested.
--
-- Not emulated: physics, rendering, replication to clients, the client itself.

local manifest = ...
local realOs = os
local realTypeof = typeof
local realEnv = getfenv(1)

local Rbx = {}

local NIL = setmetatable({}, { __tostring = function() return "nil" end })

local function deepCopy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for k, v in pairs(value) do copy[deepCopy(k)] = deepCopy(v) end
    return copy
end
Rbx.deepCopy = deepCopy

local function deepEqual(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k, v in pairs(a) do if not deepEqual(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
Rbx.deepEqual = deepEqual

----------------------------------------------------------------------------------------
-- Data types (just enough of each)

local function typed(name, fields, meta)
    meta = meta or {}
    meta.__type = name
    return setmetatable(fields, meta)
end

local Vector3 = {}
local Vector3Meta
Vector3Meta = {
    __type = "Vector3",
    __index = function(v, key)
        if key == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
        if key == "Unit" then
            local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
            return Vector3.new(v.X / m, v.Y / m, v.Z / m)
        end
        error(`{key} is not a valid member of Vector3`, 2)
    end,
    __add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end,
    __sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end,
    __mul = function(a, b)
        if type(a) == "number" then a, b = b, a end
        if type(b) == "number" then return Vector3.new(a.X * b, a.Y * b, a.Z * b) end
        return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
    end,
    __div = function(a, b) return Vector3.new(a.X / b, a.Y / b, a.Z / b) end,
    __unm = function(a) return Vector3.new(-a.X, -a.Y, -a.Z) end,
    __eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end,
    __tostring = function(v) return `{v.X}, {v.Y}, {v.Z}` end,
}
function Vector3.new(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3Meta) end
Vector3.zero = Vector3.new(0, 0, 0)
Vector3.one = Vector3.new(1, 1, 1)
Vector3.xAxis = Vector3.new(1, 0, 0)
Vector3.yAxis = Vector3.new(0, 1, 0)
Vector3.zAxis = Vector3.new(0, 0, 1)

local Color3 = {}
local Color3Meta = {
    __type = "Color3",
    __eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end,
    __tostring = function(c) return `{c.R}, {c.G}, {c.B}` end,
}
function Color3.new(r, g, b) return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3Meta) end
function Color3.fromRGB(r, g, b) return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end

local CFrame = {}
local CFrameMeta
CFrameMeta = {
    __type = "CFrame",
    __index = function(cf, key)
        if key == "X" then return cf.Position.X end
        if key == "Y" then return cf.Position.Y end
        if key == "Z" then return cf.Position.Z end
        error(`{key} is not a valid member of CFrame`, 2)
    end,
    -- Rotation is not modelled: composing two CFrames adds their positions.
    __mul = function(a, b)
        if realTypeof(b) == "table" and getmetatable(b) == CFrameMeta then return CFrame.new(a.Position + b.Position) end
        return a.Position + b
    end,
    __add = function(a, v) return CFrame.new(a.Position + v) end,
    __sub = function(a, v) return CFrame.new(a.Position - v) end,
    __eq = function(a, b) return a.Position == b.Position end,
}
function CFrame.new(x, y, z)
    if type(x) == "table" then return setmetatable({ Position = x }, CFrameMeta) end
    return setmetatable({ Position = Vector3.new(x, y, z) }, CFrameMeta)
end
function CFrame.Angles() return CFrame.new(0, 0, 0) end
CFrame.identity = CFrame.new(0, 0, 0)

local function opaque(name)
    return { new = function(...) return typed(name, { args = table.pack(...) }) end }
end

local Random = {}
local RandomMeta = { __type = "Random" }
RandomMeta.__index = Random
local seedCounter = 0
function Random.new(seed)
    if seed == nil then
        seedCounter += 1
        seed = 7919 * seedCounter
    end
    return setmetatable({ state = math.floor(seed) % 4294967296 }, RandomMeta)
end
function Random:NextNumber(min, max)
    -- Linear congruential generator; every product stays below 2^53, so it is exact.
    self.state = (self.state * 1664525 + 1013904223) % 4294967296
    local unit = self.state / 4294967296
    if min == nil then return unit end
    return min + unit * (max - min)
end
function Random:NextInteger(min, max)
    return min + math.floor(self:NextNumber() * (max - min + 1))
end
function Random:Clone() return setmetatable({ state = self.state }, RandomMeta) end

local EnumItemMeta = {
    __type = "EnumItem",
    __tostring = function(item) return `Enum.{item.EnumType}.{item.Name}` end,
}
local Enum = setmetatable({}, {
    __index = function(enums, enumName)
        local enum = setmetatable({}, {
            __index = function(items, itemName)
                local item = setmetatable({ Name = itemName, EnumType = enumName, Value = 0 }, EnumItemMeta)
                rawset(items, itemName, item)
                return item
            end,
        })
        rawset(enums, enumName, enum)
        return enum
    end,
})

local function rbxTypeof(value)
    if type(value) == "table" then
        if rawget(value, "__i") ~= nil then return "Instance" end
        local meta = getmetatable(value)
        if type(meta) == "table" and rawget(meta, "__type") then return rawget(meta, "__type") end
    end
    return realTypeof(value)
end
Rbx.typeof = rbxTypeof

----------------------------------------------------------------------------------------
-- World: virtual clock, scheduler, shared cloud

local World = {}
World.__index = World

function Rbx.newWorld(options)
    options = options or {}
    local world = setmetatable({
        now = 0,
        epoch = options.epoch or 1800000000,
        frame = options.frame or 1 / 20,
        queue = {},
        seq = 0,
        threadServer = setmetatable({}, { __mode = "k" }),
        cancelled = setmetatable({}, { __mode = "k" }),
        -- Threads that outlive their server's crash: a test's own thread, which
        -- may kill the server it runs in and carry on observing.
        survivors = setmetatable({}, { __mode = "k" }),
        activeServer = nil,
        servers = {},
        errors = {},
        logs = {},
        guid = 0,
        cloud = {
            stores = {},
            topics = {},
            latency = options.latency or 0.2,
            fail = nil, -- function(method, key, server) -> error message or nil
            calls = {},
        },
    }, World)
    world.task = world:makeTaskLibrary()
    world.os = {
        clock = function() return world.now end,
        time = function(t)
            if t ~= nil then return realOs.time(t) end
            return math.floor(world.epoch + world.now)
        end,
        date = function(format, t) return realOs.date(format, t or math.floor(world.epoch + world.now)) end,
        difftime = realOs.difftime,
    }
    return world
end

function World:log(kind, server, ...)
    local parts = table.pack(...)
    for i = 1, parts.n do parts[i] = tostring(parts[i]) end
    table.insert(self.logs, {
        kind = kind,
        server = server and server.jobId or "-",
        at = self.now,
        text = table.concat(parts, " ", 1, parts.n),
    })
end

function World:recordError(message, traceback, server)
    table.insert(self.errors, { message = tostring(message), traceback = traceback, server = server and server.jobId })
    self:log("error", server, message)
end

function World:resume(co, ...)
    local previous = self.activeServer
    self.activeServer = self.threadServer[co]
    local ok, err = coroutine.resume(co, ...)
    self.activeServer = previous
    if not ok then self:recordError(err, debug.traceback(co, tostring(err)), self.threadServer[co]) end
end

function World:schedule(co, at, ...)
    self.seq += 1
    table.insert(self.queue, { at = at, seq = self.seq, co = co, args = table.pack(...) })
end

function World:newThread(fnOrThread, server)
    local co = type(fnOrThread) == "thread" and fnOrThread or coroutine.create(fnOrThread)
    if self.threadServer[co] == nil then self.threadServer[co] = server end
    return co
end

function World:spawnIn(server, fn, ...)
    local co = self:newThread(fn, server)
    self:resume(co, ...)
    return co
end

function World:deferIn(server, fn, ...)
    local co = self:newThread(fn, server)
    self:schedule(co, self.now, ...)
    return co
end

function World:makeTaskLibrary()
    local world = self
    local task = {}
    function task.spawn(fn, ...) return world:spawnIn(world.activeServer, fn, ...) end
    function task.defer(fn, ...) return world:deferIn(world.activeServer, fn, ...) end
    function task.delay(seconds, fn, ...)
        local co = world:newThread(fn, world.activeServer)
        world:schedule(co, world.now + math.max(seconds or 0, 1e-9), ...)
        return co
    end
    function task.wait(seconds)
        local co = coroutine.running()
        local started = world.now
        world:schedule(co, world.now + math.max(seconds or 0, 1e-9))
        coroutine.yield()
        return world.now - started
    end
    function task.cancel(co)
        world.cancelled[co] = true
        if coroutine.status(co) == "suspended" then coroutine.close(co) end
    end
    function task.synchronize() end
    function task.desynchronize() end
    return task
end

function World:processDue()
    local guard = 0
    while true do
        local bestIndex, best = nil, nil
        for index, item in ipairs(self.queue) do
            if item.at <= self.now and (best == nil or item.at < best.at or (item.at == best.at and item.seq < best.seq)) then
                bestIndex, best = index, item
            end
        end
        if best == nil then break end
        table.remove(self.queue, bestIndex)
        guard += 1
        if guard > 500000 then error("scheduler runaway: a thread keeps rescheduling itself without time passing") end
        local server = self.threadServer[best.co]
        local dropped = server and server.dead and not self.survivors[best.co]
        if not self.cancelled[best.co] and not dropped and coroutine.status(best.co) == "suspended" then
            self:resume(best.co, table.unpack(best.args, 1, best.args.n))
        end
    end
end

function World:step()
    self.now += self.frame
    for _, server in ipairs(self.servers) do
        if not server.dead then server:heartbeat(self.frame) end
    end
    self:processDue()
end

-- Run fn as a thread (optionally inside a server) and drive the clock until it ends.
function World:run(fn, server, maxSeconds)
    local outcome
    local co = self:newThread(function()
        outcome = table.pack(xpcall(fn, function(err) return debug.traceback(tostring(err), 2) end))
    end, server)
    self.survivors[co] = true
    self:resume(co)
    local limit = self.now + (maxSeconds or 3600)
    while coroutine.status(co) ~= "dead" do
        if self.now > limit then error(`thread did not finish within {maxSeconds or 3600} virtual seconds`, 2) end
        self:step()
    end
    if outcome and not outcome[1] then error(outcome[2], 0) end
    return outcome and table.unpack(outcome, 2, outcome.n)
end

-- From a thread: let virtual time pass.
function World:wait(seconds) return self.task.wait(seconds) end

-- From a thread: wait until predicate() is true (or fail after maxSeconds).
function World:waitUntil(predicate, maxSeconds, what)
    local limit = self.now + (maxSeconds or 120)
    while not predicate() do
        if self.now > limit then error(`timed out waiting for {what or "condition"}`, 2) end
        self.task.wait()
    end
end

function World:nextGuid()
    self.guid += 1
    return string.format("%08X-0000-4000-8000-%012X", self.guid, self.guid * 7919)
end

----------------------------------------------------------------------------------------
-- Signals

local Signal = {}
Signal.__index = Signal
local Connection = {}
Connection.__index = Connection

function Signal.new(world, server, deferred)
    return setmetatable({ world = world, server = server, deferred = deferred ~= false, conns = {}, waiting = {} }, Signal)
end
Rbx.Signal = Signal

function Signal:Connect(fn)
    if type(fn) ~= "function" then error("Attempt to connect failed: Passed value is not a function", 2) end
    local conn = setmetatable({ Connected = true, fn = fn, signal = self }, Connection)
    table.insert(self.conns, conn)
    return conn
end

function Signal:Once(fn)
    local conn
    conn = self:Connect(function(...)
        conn:Disconnect()
        fn(...)
    end)
    return conn
end

function Signal:Wait()
    table.insert(self.waiting, coroutine.running())
    return coroutine.yield()
end

function Signal:Fire(...)
    local world = self.world
    for _, conn in ipairs(table.clone(self.conns)) do
        if conn.Connected then
            if self.deferred then world:deferIn(self.server, conn.fn, ...) else world:spawnIn(self.server, conn.fn, ...) end
        end
    end
    local waiting = self.waiting
    self.waiting = {}
    for _, co in ipairs(waiting) do world:schedule(co, world.now, ...) end
end

function Signal:DisconnectAll()
    for _, conn in ipairs(self.conns) do conn.Connected = false end
    self.conns = {}
end

function Connection:Disconnect()
    if not self.Connected then return end
    self.Connected = false
    local list = self.signal.conns
    local index = table.find(list, self)
    if index then table.remove(list, index) end
end

----------------------------------------------------------------------------------------
-- Instances

local classParent = {
    Folder = "Instance",
    Configuration = "Instance",
    Model = "PVInstance",
    PVInstance = "Instance",
    ValueBase = "Instance",
    IntValue = "ValueBase",
    NumberValue = "ValueBase",
    BoolValue = "ValueBase",
    StringValue = "ValueBase",
    ObjectValue = "ValueBase",
    LuaSourceContainer = "Instance",
    BaseScript = "LuaSourceContainer",
    Script = "BaseScript",
    LocalScript = "BaseScript",
    ModuleScript = "LuaSourceContainer",
    BaseRemoteEvent = "Instance",
    RemoteEvent = "BaseRemoteEvent",
    UnreliableRemoteEvent = "BaseRemoteEvent",
    RemoteFunction = "Instance",
    BindableEvent = "Instance",
    BindableFunction = "Instance",
    Player = "Instance",
    DataModel = "ServiceProvider",
    ServiceProvider = "Instance",
}

local classDefaults = {
    IntValue = { Value = 0 },
    NumberValue = { Value = 0 },
    BoolValue = { Value = false },
    StringValue = { Value = "" },
    ObjectValue = { Value = NIL },
    RemoteFunction = { OnServerInvoke = NIL },
    BindableFunction = { OnInvoke = NIL },
    Player = { UserId = 0, DisplayName = "", Character = NIL, AccountAge = 0 },
    DataModel = { PlaceId = 0, JobId = "", GameId = 0, CreatorId = 0 },
    Model = { PrimaryPart = NIL },
}

local valueTypes = { IntValue = "number", NumberValue = "number", BoolValue = "boolean", StringValue = "string" }

local classSignals = {
    Instance = { "Changed", "ChildAdded", "ChildRemoved", "DescendantAdded", "Destroying", "AncestryChanged", "AttributeChanged" },
    BaseRemoteEvent = { "OnServerEvent", "OnClientEvent" },
    BindableEvent = { "Event" },
    Players = { "PlayerAdded", "PlayerRemoving" },
    Player = { "CharacterAdded", "CharacterRemoving", "Chatted" },
    RunService = { "Heartbeat", "Stepped", "PreSimulation", "PostSimulation" },
}

local classMethods = {}
local InstanceMethods = {}
classMethods.Instance = InstanceMethods

local function lookupClassTable(tables, className, key)
    local class = className
    while class do
        local t = tables[class]
        if t then
            if type(t[1]) == "string" then
                if table.find(t, key) then return true end
            elseif t[key] ~= nil then
                return t[key]
            end
        end
        class = classParent[class] or (class ~= "Instance" and "Instance" or nil)
    end
    return nil
end

local function isA(className, query)
    local class = className
    while class do
        if class == query then return true end
        class = classParent[class] or (class ~= "Instance" and "Instance" or nil)
    end
    return false
end

local InstanceMeta = {}

local function internal(inst) return rawget(inst, "__i") end

local function fullName(inst)
    local parts = {}
    local current = inst
    while current and internal(current).className ~= "DataModel" do
        table.insert(parts, 1, internal(current).props.Name)
        local parent = internal(current).props.Parent
        current = parent ~= NIL and parent or nil
    end
    return table.concat(parts, ".")
end

local function newInstance(server, className, name)
    local inst = setmetatable({}, InstanceMeta)
    local props = { Name = name or className, Parent = NIL, Archivable = true }
    for k, v in pairs(classDefaults[className] or {}) do props[k] = v end
    rawset(inst, "__i", {
        server = server,
        world = server.world,
        className = className,
        props = props,
        children = {},
        attrs = {},
        signals = {},
        propSignals = {},
        attrSignals = {},
        destroyed = false,
    })
    return inst
end
Rbx.newInstance = newInstance

local function getSignal(inst, name)
    local i = internal(inst)
    local signal = i.signals[name]
    if not signal then
        signal = Signal.new(i.world, i.server)
        i.signals[name] = signal
    end
    return signal
end

local function findChild(inst, name)
    for _, child in ipairs(internal(inst).children) do
        if internal(child).props.Name == name then return child end
    end
    return nil
end

InstanceMeta.__index = function(inst, key)
    local i = internal(inst)
    if key == "ClassName" then return i.className end
    local method = lookupClassTable(classMethods, i.className, key)
    if method ~= nil then return method end
    if lookupClassTable(classSignals, i.className, key) then return getSignal(inst, key) end
    local value = i.props[key]
    if value ~= nil then
        if value == NIL then return nil end
        return value
    end
    local child = findChild(inst, key)
    if child then return child end
    error(`{tostring(key)} is not a valid member of {i.className} "{fullName(inst)}"`, 2)
end

local function setParent(inst, parent)
    local i = internal(inst)
    if i.destroyed then error(`The Parent property of {fullName(inst)} is locked, current parent: NULL, new parent {parent and internal(parent).props.Name or "NULL"}`, 3) end
    local old = i.props.Parent
    if old == (parent or NIL) then return end
    if parent ~= nil and rbxTypeof(parent) ~= "Instance" then error("Parent must be an Instance or nil", 3) end
    if old ~= NIL then
        local siblings = internal(old).children
        local index = table.find(siblings, inst)
        if index then table.remove(siblings, index) end
        getSignal(old, "ChildRemoved"):Fire(inst)
    end
    i.props.Parent = parent or NIL
    if parent then
        table.insert(internal(parent).children, inst)
        getSignal(parent, "ChildAdded"):Fire(inst)
    end
    getSignal(inst, "AncestryChanged"):Fire(inst, parent)
    local propSignal = i.propSignals.Parent
    if propSignal then propSignal:Fire() end
end

InstanceMeta.__newindex = function(inst, key, value)
    local i = internal(inst)
    if key == "Parent" then return setParent(inst, value) end
    if key == "ClassName" then error("ClassName is read-only", 2) end
    local current = i.props[key]
    if current == nil then error(`{tostring(key)} is not a valid member of {i.className} "{fullName(inst)}"`, 2) end
    local expected = key == "Value" and valueTypes[i.className]
    if expected and type(value) ~= expected then
        error(`Unable to assign property Value. {expected} expected, got {rbxTypeof(value)}`, 2)
    end
    if i.className == "IntValue" and key == "Value" then
        if value ~= value or value == math.huge or value == -math.huge then error("IntValue cannot hold a non-finite number", 2) end
        value = value >= 0 and math.floor(value) or math.ceil(value)
    end
    local stored = value == nil and NIL or value
    if current == stored then return end
    i.props[key] = stored
    local propSignal = i.propSignals[key]
    if propSignal then propSignal:Fire() end
    if valueTypes[i.className] or i.className == "ObjectValue" then
        if key == "Value" then getSignal(inst, "Changed"):Fire(value) end
    else
        getSignal(inst, "Changed"):Fire(key)
    end
end

InstanceMeta.__tostring = function(inst) return internal(inst).props.Name end

function InstanceMethods.IsA(inst, className) return isA(internal(inst).className, className) end
function InstanceMethods.GetChildren(inst) return table.clone(internal(inst).children) end
function InstanceMethods.GetDescendants(inst)
    local out = {}
    local function walk(node)
        for _, child in ipairs(internal(node).children) do
            table.insert(out, child)
            walk(child)
        end
    end
    walk(inst)
    return out
end
function InstanceMethods.FindFirstChild(inst, name, recursive)
    if not recursive then return findChild(inst, name) end
    for _, d in ipairs(InstanceMethods.GetDescendants(inst)) do
        if internal(d).props.Name == name then return d end
    end
    return nil
end
function InstanceMethods.FindFirstChildOfClass(inst, className)
    for _, child in ipairs(internal(inst).children) do
        if internal(child).className == className then return child end
    end
    return nil
end
function InstanceMethods.FindFirstChildWhichIsA(inst, className)
    for _, child in ipairs(internal(inst).children) do
        if isA(internal(child).className, className) then return child end
    end
    return nil
end
function InstanceMethods.FindFirstAncestor(inst, name)
    local parent = internal(inst).props.Parent
    while parent ~= NIL do
        if internal(parent).props.Name == name then return parent end
        parent = internal(parent).props.Parent
    end
    return nil
end
function InstanceMethods.IsDescendantOf(inst, ancestor)
    local parent = internal(inst).props.Parent
    while parent ~= NIL do
        if parent == ancestor then return true end
        parent = internal(parent).props.Parent
    end
    return false
end
function InstanceMethods.WaitForChild(inst, name, timeout)
    local child = findChild(inst, name)
    if child then return child end
    local world = internal(inst).world
    local started = world.now
    local warned = false
    while true do
        world.task.wait()
        child = findChild(inst, name)
        if child then return child end
        local elapsed = world.now - started
        if timeout and elapsed >= timeout then return nil end
        if not timeout and not warned and elapsed >= 5 then
            warned = true
            world:log("warn", internal(inst).server, `Infinite yield possible on '{fullName(inst)}:WaitForChild("{name}")'`)
        end
    end
end
function InstanceMethods.GetFullName(inst) return fullName(inst) end
function InstanceMethods.ClearAllChildren(inst)
    for _, child in ipairs(table.clone(internal(inst).children)) do InstanceMethods.Destroy(child) end
end
function InstanceMethods.Destroy(inst)
    local i = internal(inst)
    if i.destroyed then return end
    getSignal(inst, "Destroying"):Fire()
    for _, child in ipairs(table.clone(i.children)) do InstanceMethods.Destroy(child) end
    if i.props.Parent ~= NIL then setParent(inst, nil) end
    i.destroyed = true
    for _, signal in pairs(i.signals) do signal:DisconnectAll() end
end
function InstanceMethods.Clone(inst)
    local i = internal(inst)
    local copy = newInstance(i.server, i.className, i.props.Name)
    local ci = internal(copy)
    for k, v in pairs(i.props) do if k ~= "Parent" then ci.props[k] = v end end
    for k, v in pairs(i.attrs) do ci.attrs[k] = v end
    ci.file = i.file
    for _, child in ipairs(i.children) do InstanceMethods.Clone(child).Parent = copy end
    return copy
end
function InstanceMethods.GetPropertyChangedSignal(inst, property)
    local i = internal(inst)
    if i.props[property] == nil and property ~= "Parent" then
        error(`{property} is not a valid property name.`, 2)
    end
    local signal = i.propSignals[property]
    if not signal then
        signal = Signal.new(i.world, i.server)
        i.propSignals[property] = signal
    end
    return signal
end
local attributeTypes = { boolean = true, number = true, string = true, Vector3 = true, Color3 = true, CFrame = true, EnumItem = true }
function InstanceMethods.SetAttribute(inst, name, value)
    if value ~= nil and not attributeTypes[rbxTypeof(value)] then
        error(`{rbxTypeof(value)} is not a supported attribute type`, 2)
    end
    local i = internal(inst)
    if i.attrs[name] == value then return end
    i.attrs[name] = value
    getSignal(inst, "AttributeChanged"):Fire(name)
    local signal = i.attrSignals[name]
    if signal then signal:Fire() end
end
function InstanceMethods.GetAttribute(inst, name) return internal(inst).attrs[name] end
function InstanceMethods.GetAttributes(inst) return table.clone(internal(inst).attrs) end
function InstanceMethods.GetAttributeChangedSignal(inst, name)
    local i = internal(inst)
    local signal = i.attrSignals[name]
    if not signal then
        signal = Signal.new(i.world, i.server)
        i.attrSignals[name] = signal
    end
    return signal
end

-- Remotes: the server side is real; the client side is recorded for assertions.
classMethods.BaseRemoteEvent = {
    FireClient = function(remote, player, ...)
        if rbxTypeof(player) ~= "Instance" or not player:IsA("Player") then error("FireClient: player argument must be a Player", 2) end
        table.insert(internal(remote).server.sent, { remote = remote.Name, player = player, args = table.pack(...) })
    end,
    FireAllClients = function(remote, ...)
        table.insert(internal(remote).server.sent, { remote = remote.Name, player = "all", args = table.pack(...) })
    end,
    FireServer = function() error("FireServer can only be called from the client", 2) end,
}
classMethods.BindableEvent = {
    Fire = function(bindable, ...) getSignal(bindable, "Event"):Fire(...) end,
}
classMethods.DataStoreOptions = {
    SetExperimentalFeatures = function() end,
}

----------------------------------------------------------------------------------------
-- Server (one DataModel)

local Server = {}
Server.__index = Server

local serviceNames = {
    "Workspace", "ReplicatedStorage", "ServerScriptService", "ServerStorage", "StarterPlayer", "Players",
    "RunService", "DataStoreService", "MessagingService", "HttpService", "AnalyticsService", "TweenService",
    "Lighting", "SoundService", "MarketplaceService", "CollectionService", "TextService",
}

function World:newServer(options)
    options = options or {}
    local server = setmetatable({
        world = self,
        studio = options.studio == true,
        placeId = options.placeId or 1001,
        jobId = options.jobId or self:nextGuid(),
        modules = {},
        closeCallbacks = {},
        dead = false,
        closing = false,
        sent = {},
        analytics = {},
    }, Server)
    local game = newInstance(server, "DataModel", "Game")
    internal(game).props.PlaceId = server.placeId
    internal(game).props.JobId = server.jobId
    server.game = game
    server.services = {}
    server.Instance = {
        new = function(className, parent)
            local inst = newInstance(server, className)
            if parent then inst.Parent = parent end
            return inst
        end,
    }
    for _, name in ipairs(serviceNames) do server:service(name) end

    for _, entry in ipairs(manifest) do
        local path = entry.path
        if #path == 1 then
            server:service(path[1])
        else
            local parent = server:service(path[1])
            for depth = 2, #path - 1 do
                parent = findChild(parent, path[depth]) or error(`manifest parent missing: {table.concat(path, ".")}`)
            end
            local inst = newInstance(server, entry.className, path[#path])
            internal(inst).file = entry.file
            inst.Parent = parent
        end
    end

    table.insert(self.servers, server)
    return server
end

function Server:service(name)
    local existing = self.services[name]
    if existing then return existing end
    local inst = newInstance(self, name, name)
    internal(inst).props.Parent = self.game
    table.insert(internal(self.game).children, inst)
    self.services[name] = inst
    return inst
end

classMethods.DataModel = {
    GetService = function(game, name)
        local server = internal(game).server
        if not server.services[name] and not table.find(serviceNames, name) then
            error(`'{name}' is not a valid Service name`, 2)
        end
        return server:service(name)
    end,
    BindToClose = function(game, fn)
        table.insert(internal(game).server.closeCallbacks, fn)
    end,
}
classMethods.DataModel.FindService = classMethods.DataModel.GetService

function Server:heartbeat(dt)
    local runService = self.services.RunService
    local signal = internal(runService).signals.Heartbeat
    if signal then signal:Fire(dt) end
end

function Server:resolve(path)
    local parts = string.split(path, ".")
    local node = self:service(parts[1])
    for index = 2, #parts do
        node = findChild(node, parts[index]) or error(`no instance at {path} (missing {parts[index]})`, 2)
    end
    return node
end

function Server:envFor(scriptInstance)
    local server = self
    local world = self.world
    local game = self.game
    return setmetatable({
        script = scriptInstance,
        game = game,
        workspace = self.services.Workspace,
        require = function(target) return server:require(target) end,
        task = world.task,
        os = world.os,
        tick = function() return world.epoch + world.now end,
        time = function() return world.now end,
        typeof = rbxTypeof,
        Instance = server.Instance,
        Enum = Enum,
        Vector3 = Vector3,
        Color3 = Color3,
        CFrame = CFrame,
        Random = Random,
        ColorSequence = opaque("ColorSequence"),
        NumberSequence = opaque("NumberSequence"),
        NumberRange = opaque("NumberRange"),
        TweenInfo = opaque("TweenInfo"),
        UDim2 = opaque("UDim2"),
        DateTime = {
            now = function()
                local seconds = world.epoch + world.now
                return { UnixTimestamp = math.floor(seconds), UnixTimestampMillis = math.floor(seconds * 1000) }
            end,
        },
        print = function(...) world:log("print", server, ...) end,
        warn = function(...) world:log("warn", server, ...) end,
        wait = function() error("wait() is deprecated; use task.wait()", 2) end,
        spawn = function() error("spawn() is deprecated; use task.spawn()", 2) end,
        delay = function() error("delay() is deprecated; use task.delay()", 2) end,
        shared = server.shared or {},
    }, { __index = realEnv })
end

function Server:load(scriptInstance)
    local file = internal(scriptInstance).file or error(`{fullName(scriptInstance)} has no source`)
    local fn = host_compile(host_readFile(file), fullName(scriptInstance))
    setfenv(fn, self:envFor(scriptInstance))
    return fn
end

function Server:require(target)
    if type(target) == "string" then target = self:resolve(target) end
    if type(target) == "number" then error("require(assetId) is not allowed: third-party code is vendored, never fetched", 2) end
    if rbxTypeof(target) ~= "Instance" or internal(target).className ~= "ModuleScript" then
        error("Attempted to call require with invalid argument(s).", 2)
    end
    local cached = self.modules[target]
    if cached then
        if cached.loading then error(`Recursive require of {fullName(target)}`, 2) end
        return cached.value
    end
    cached = { loading = true }
    self.modules[target] = cached
    local ok, result = pcall(function()
        local results = table.pack(self:load(target)())
        if results.n ~= 1 then error(`Module code did not return exactly one value: {fullName(target)}`) end
        return results[1]
    end)
    if not ok then
        self.modules[target] = nil
        error(`Requested module experienced an error while loading: {fullName(target)}\n{result}`, 2)
    end
    cached.value = result
    cached.loading = false
    return result
end

-- Start every server Script, as Roblox does when a server boots.
function Server:start()
    for _, inst in ipairs(InstanceMethods.GetDescendants(self.services.ServerScriptService)) do
        if internal(inst).className == "Script" then
            local fn = self:load(inst)
            self.world:spawnIn(self, fn)
        end
    end
end

function Server:addPlayer(options)
    options = options or {}
    local player = newInstance(self, "Player", options.name or `Player{options.userId or 1}`)
    local i = internal(player)
    i.props.UserId = options.userId or 1
    i.props.DisplayName = options.displayName or i.props.Name
    i.ping = options.ping or 0.08
    player.Parent = self.services.Players
    getSignal(self.services.Players, "PlayerAdded"):Fire(player)
    return player
end

function Server:removePlayer(player)
    if internal(player).props.Parent == NIL then return end
    getSignal(self.services.Players, "PlayerRemoving"):Fire(player)
    -- Adversarial on purpose: deferred PlayerRemoving handlers run after the player is gone.
    setParent(player, nil)
end

-- From a thread: Roblox's shutdown sequence. Players leave, BindToClose callbacks
-- run in parallel and the server waits for them (at most 30 s), then it is gone.
function Server:shutdown()
    self.closing = true
    for _, player in ipairs(InstanceMethods.GetChildren(self.services.Players)) do self:removePlayer(player) end
    local pending = 0
    for _, callback in ipairs(self.closeCallbacks) do
        pending += 1
        self.world:spawnIn(self, function()
            callback()
            pending -= 1
        end)
    end
    local deadline = self.world.now + 30
    while pending > 0 and self.world.now < deadline do self.world.task.wait() end
    self:kill()
    return pending == 0
end

-- The server disappears without warning; its threads never run again.
function Server:kill()
    self.dead = true
    local index = table.find(self.world.servers, self)
    if index then table.remove(self.world.servers, index) end
end

-- Simulate a client firing a RemoteEvent at this server.
function Server:fireServer(remote, player, ...)
    getSignal(remote, "OnServerEvent"):Fire(player, ...)
end

function Server:sentTo(player, remoteName)
    local out = {}
    for _, message in ipairs(self.sent) do
        if (message.player == player or message.player == "all") and (remoteName == nil or message.remote == remoteName) then
            table.insert(out, message)
        end
    end
    return out
end

classMethods.Players = {
    GetPlayers = function(players)
        return table.clone(internal(players).children)
    end,
    GetPlayerByUserId = function(players, userId)
        for _, player in ipairs(internal(players).children) do
            if internal(player).props.UserId == userId then return player end
        end
        return nil
    end,
}

classMethods.Player = {
    Kick = function(player, message)
        local i = internal(player)
        i.kickMessage = message or ""
        local server = i.server
        server.world:deferIn(server, function() server:removePlayer(player) end)
    end,
    GetNetworkPing = function(player) return internal(player).ping end,
}
Rbx.kickMessage = function(player) return internal(player).kickMessage end

classMethods.RunService = {
    IsStudio = function(rs) return internal(rs).server.studio end,
    IsServer = function() return true end,
    IsClient = function() return false end,
    IsRunning = function() return true end,
    IsRunMode = function() return false end,
}

classMethods.HttpService = {
    GenerateGUID = function(http, wrap)
        local guid = internal(http).world:nextGuid()
        return wrap == false and guid or `\{{guid}\}`
    end,
    JSONEncode = function(_, value)
        local function encode(v)
            local t = type(v)
            if t == "nil" then return "null" end
            if t == "boolean" then return tostring(v) end
            if t == "number" then
                if v ~= v or v == math.huge or v == -math.huge then return "null" end
                return tostring(v)
            end
            if t == "string" then return string.format("%q", v) end
            if t == "table" then
                if #v > 0 then
                    local items = {}
                    for _, item in ipairs(v) do table.insert(items, encode(item)) end
                    return "[" .. table.concat(items, ",") .. "]"
                end
                local keys = {}
                for k in pairs(v) do table.insert(keys, tostring(k)) end
                table.sort(keys)
                local items = {}
                for _, k in ipairs(keys) do table.insert(items, string.format("%q", k) .. ":" .. encode(v[k])) end
                return "{" .. table.concat(items, ",") .. "}"
            end
            error(`Can't convert {t} to JSON`)
        end
        return encode(value)
    end,
}

-- AnalyticsService: validated the way the engine validates, then recorded.
local customFieldKeys = { CustomField01 = true, CustomField02 = true, CustomField03 = true }
local function checkAnalytics(method, player, customFields)
    if rbxTypeof(player) ~= "Instance" or not player:IsA("Player") then error(`{method}: player must be a Player`, 3) end
    if customFields ~= nil then
        for key, value in pairs(customFields) do
            if not customFieldKeys[key] then error(`{method}: invalid custom field key {tostring(key)}`, 3) end
            if type(value) ~= "string" then error(`{method}: custom field values must be strings`, 3) end
        end
    end
end
local function finite(n) return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge end
classMethods.AnalyticsService = {
    LogCustomEvent = function(service, player, eventName, value, customFields)
        checkAnalytics("LogCustomEvent", player, customFields)
        if type(eventName) ~= "string" or eventName == "" then error("LogCustomEvent: eventName must be a non-empty string", 2) end
        if value ~= nil and not finite(value) then error("LogCustomEvent: value must be finite", 2) end
        table.insert(internal(service).server.analytics, { kind = "Custom", player = player, name = eventName, value = value or 1, fields = customFields })
    end,
    LogEconomyEvent = function(service, player, flowType, currencyType, amount, endingBalance, transactionType, itemSku, customFields)
        checkAnalytics("LogEconomyEvent", player, customFields)
        if rbxTypeof(flowType) ~= "EnumItem" or flowType.EnumType ~= "AnalyticsEconomyFlowType" then error("LogEconomyEvent: bad flowType", 2) end
        if type(currencyType) ~= "string" or not finite(amount) or amount <= 0 or not finite(endingBalance) then error("LogEconomyEvent: bad amount", 2) end
        if type(transactionType) ~= "string" then error("LogEconomyEvent: transactionType must be a string", 2) end
        table.insert(internal(service).server.analytics, {
            kind = "Economy", player = player, flow = flowType.Name, currency = currencyType, amount = amount,
            balance = endingBalance, transaction = transactionType, sku = itemSku, fields = customFields,
        })
    end,
    LogOnboardingFunnelStepEvent = function(service, player, step, stepName, customFields)
        checkAnalytics("LogOnboardingFunnelStepEvent", player, customFields)
        if not finite(step) or step < 1 then error("LogOnboardingFunnelStepEvent: step must be >= 1", 2) end
        table.insert(internal(service).server.analytics, { kind = "Onboarding", player = player, step = step, name = stepName, fields = customFields })
    end,
    LogProgressionEvent = function(service, player, pathName, status, level, levelName, customFields)
        checkAnalytics("LogProgressionEvent", player, customFields)
        if rbxTypeof(status) ~= "EnumItem" or status.EnumType ~= "AnalyticsProgressionType" then error("LogProgressionEvent: bad status", 2) end
        if not finite(level) then error("LogProgressionEvent: level must be a number", 2) end
        table.insert(internal(service).server.analytics, {
            kind = "Progression", player = player, path = pathName, status = status.Name, level = level, name = levelName, fields = customFields,
        })
    end,
    LogFunnelStepEvent = function(service, player, funnelName, funnelSessionId, step, stepName, customFields)
        checkAnalytics("LogFunnelStepEvent", player, customFields)
        table.insert(internal(service).server.analytics, { kind = "Funnel", player = player, funnel = funnelName, step = step, name = stepName, fields = customFields })
    end,
}

----------------------------------------------------------------------------------------
-- Cloud: DataStores and MessagingService, shared by every server in the world

local function assertStorable(value, path)
    local t = type(value)
    if t == "nil" or t == "boolean" or t == "string" then return end
    if t == "number" then
        if value ~= value or value == math.huge or value == -math.huge then error(`DataStore: non-finite number at {path}`, 0) end
        return
    end
    if t ~= "table" or rbxTypeof(value) ~= "table" then error(`DataStore: cannot store {rbxTypeof(value)} at {path}`, 0) end
    local hasArray, hasHash = #value > 0, false
    for k, v in pairs(value) do
        if type(k) == "string" then
            hasHash = true
        elseif type(k) ~= "number" then
            error(`DataStore: invalid key type {type(k)} at {path}`, 0)
        end
        assertStorable(v, `{path}.{tostring(k)}`)
    end
    if hasArray and hasHash then error(`DataStore: mixed array/dictionary at {path}`, 0) end
end

local function keyInfoOf(entry)
    return {
        Version = tostring(entry.version),
        CreatedTime = entry.created,
        UpdatedTime = entry.updated,
        GetUserIds = function() return deepCopy(entry.userIds) end,
        GetMetadata = function() return deepCopy(entry.metadata) end,
    }
end

local function cloudCall(world, method, key)
    local server = world.activeServer
    if server == nil then error("DataStore calls must come from a server thread", 3) end
    if server.dead then error("server is gone", 3) end
    table.insert(world.cloud.calls, { server = server.jobId, method = method, key = key, at = world.now })
    world.task.wait(world.cloud.latency / 2)
    local failure = world.cloud.fail and world.cloud.fail(method, key, server)
    if failure then error(failure, 0) end
end

local function writeEntry(world, data, key, value, userIds, metadata)
    local entry = data.entries[key]
    local stamp = math.floor((world.epoch + world.now) * 1000)
    if not entry then
        entry = { version = 0, created = stamp, history = {} }
        data.entries[key] = entry
    end
    entry.version += 1
    entry.value = deepCopy(value)
    entry.userIds = deepCopy(userIds or {})
    entry.metadata = deepCopy(metadata or {})
    entry.updated = stamp
    table.insert(entry.history, { version = tostring(entry.version), value = deepCopy(value), updated = stamp })
    return entry
end

local DataStore = {}
DataStore.__index = DataStore

function DataStore:GetAsync(key)
    cloudCall(self.world, "GetAsync", key)
    local entry = self.data.entries[key]
    self.world.task.wait(self.world.cloud.latency / 2)
    if not entry or entry.value == nil then return nil, nil end
    return deepCopy(entry.value), keyInfoOf(entry)
end

function DataStore:SetAsync(key, value, userIds, options)
    cloudCall(self.world, "SetAsync", key)
    assertStorable(value, key)
    local metadata = options and options.metadata or nil
    local entry = writeEntry(self.world, self.data, key, value, userIds, metadata)
    self.world.task.wait(self.world.cloud.latency / 2)
    return tostring(entry.version)
end

function DataStore:UpdateAsync(key, transform)
    cloudCall(self.world, "UpdateAsync", key)
    local entry = self.data.entries[key]
    local current = entry and entry.value ~= nil and deepCopy(entry.value) or nil
    local info = entry and entry.value ~= nil and keyInfoOf(entry) or nil
    -- The read-transform-write is atomic: nothing else runs in between.
    local transformThread = coroutine.running()
    local newValue, userIds, metadata = transform(current, info)
    if coroutine.running() ~= transformThread then error("UpdateAsync transform must not yield", 0) end
    if newValue == nil then
        self.world.task.wait(self.world.cloud.latency / 2)
        return nil, nil
    end
    assertStorable(newValue, key)
    entry = writeEntry(self.world, self.data, key, newValue, userIds, metadata)
    self.world.task.wait(self.world.cloud.latency / 2)
    return deepCopy(newValue), keyInfoOf(entry)
end

function DataStore:RemoveAsync(key)
    cloudCall(self.world, "RemoveAsync", key)
    local entry = self.data.entries[key]
    local old = entry and deepCopy(entry.value)
    if entry then entry.value = nil end
    self.world.task.wait(self.world.cloud.latency / 2)
    return old
end

function DataStore:GetVersionAsync(key, version)
    cloudCall(self.world, "GetVersionAsync", key)
    local entry = self.data.entries[key]
    if entry then
        for _, item in ipairs(entry.history) do
            if item.version == version then return deepCopy(item.value), keyInfoOf(entry) end
        end
    end
    error("Version is not valid", 0)
end

function DataStore:ListVersionsAsync(key, sortDirection)
    cloudCall(self.world, "ListVersionsAsync", key)
    local entry = self.data.entries[key]
    local items = {}
    for _, item in ipairs(entry and entry.history or {}) do
        table.insert(items, { Version = item.version, CreatedTime = item.updated, IsDeleted = false })
    end
    if sortDirection and sortDirection.Name == "Descending" then
        local reversed = {}
        for index = #items, 1, -1 do table.insert(reversed, items[index]) end
        items = reversed
    end
    return {
        IsFinished = true,
        GetCurrentPage = function() return items end,
        AdvanceToNextPageAsync = function() end,
    }
end

classMethods.DataStoreService = {
    GetDataStore = function(service, name, scope)
        local world = internal(service).world
        local id = name .. "/" .. (scope or "global")
        local data = world.cloud.stores[id]
        if not data then
            data = { entries = {} }
            world.cloud.stores[id] = data
        end
        return setmetatable({ world = world, data = data, Name = name }, DataStore)
    end,
    GetRequestBudgetForRequestType = function() return 1000 end,
}

-- Direct access for tests: the stored value of a key, as the cloud has it.
function World:peek(storeName, key)
    local data = self.cloud.stores[storeName .. "/global"]
    local entry = data and data.entries[key]
    return entry and deepCopy(entry.value)
end

classMethods.MessagingService = {
    SubscribeAsync = function(service, topic, callback)
        local world = internal(service).world
        local server = internal(service).server
        local subscribers = world.cloud.topics[topic] or {}
        world.cloud.topics[topic] = subscribers
        local subscription = { server = server, callback = callback, active = true }
        table.insert(subscribers, subscription)
        return {
            Disconnect = function() subscription.active = false end,
        }
    end,
    PublishAsync = function(service, topic, message)
        local world = internal(service).world
        cloudCall(world, "PublishAsync", topic)
        assertStorable(message, topic)
        for _, subscription in ipairs(world.cloud.topics[topic] or {}) do
            if subscription.active and not subscription.server.dead then
                world:deferIn(subscription.server, subscription.callback, {
                    Data = deepCopy(message),
                    Sent = world.epoch + world.now,
                })
            end
        end
        world.task.wait(world.cloud.latency / 2)
    end,
}

Rbx.NIL = NIL
Rbx.Enum = Enum
Rbx.Vector3 = Vector3
Rbx.Color3 = Color3
Rbx.CFrame = CFrame
Rbx.Random = Random
return Rbx
