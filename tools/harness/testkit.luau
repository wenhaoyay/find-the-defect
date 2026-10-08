--!nocheck
-- describe / it / expect, driven by the emulator's virtual clock.
--
-- Every `it` gets a fresh world and one server (t.server, not started). The test
-- body runs as a thread bound to that server, so it can yield (t.wait, DataStore
-- calls, WaitForChild). A test also fails if any background thread errored or an
-- infinite-yield warning was logged, unless it declared it with t.allow(pattern).

local function format(value, depth)
	depth = depth or 0
	if type(value) == "string" then return string.format("%q", value) end
	if type(value) ~= "table" or depth > 2 then return tostring(value) end
	local parts = {}
	local count = 0
	for k, v in pairs(value) do
		count += 1
		if count > 8 then
			table.insert(parts, "…")
			break
		end
		table.insert(parts, `{tostring(k)}={format(v, depth + 1)}`)
	end
	return "{" .. table.concat(parts, ", ") .. "}"
end

return function(Rbx, specFiles)
	local deepEqual = Rbx.deepEqual

	local function expect(actual)
		local negate = false
		local e = {}
		local function check(ok, message)
			if negate then ok = not ok end
			if not ok then error((negate and "expected NOT " or "expected ") .. message, 3) end
		end
		e.never = setmetatable({}, {
			__index = function(_, key)
				negate = true
				return e[key]
			end,
		})
		function e.toBe(expected) check(actual == expected, `{format(actual)} to be {format(expected)}`) end
		function e.toEqual(expected) check(deepEqual(actual, expected), `{format(actual)} to equal {format(expected)}`) end
		function e.toBeTruthy() check(not not actual, `{format(actual)} to be truthy`) end
		function e.toBeNil() check(actual == nil, `{format(actual)} to be nil`) end
		function e.toBeCloseTo(expected, tolerance)
			check(math.abs(actual - expected) <= (tolerance or 1e-6), `{actual} to be within {tolerance or 1e-6} of {expected}`)
		end
		function e.toBeGreaterThan(n) check(actual > n, `{actual} > {n}`) end
		function e.toBeGreaterThanOrEqual(n) check(actual >= n, `{actual} >= {n}`) end
		function e.toBeLessThan(n) check(actual < n, `{actual} < {n}`) end
		function e.toBeLessThanOrEqual(n) check(actual <= n, `{actual} <= {n}`) end
		function e.toContain(item)
			local found = false
			if type(actual) == "string" then
				found = string.find(actual, item, 1, true) ~= nil
			else
				for _, v in pairs(actual) do
					if deepEqual(v, item) then
						found = true
						break
					end
				end
			end
			check(found, `{format(actual)} to contain {format(item)}`)
		end
		function e.toThrow(pattern)
			local ok, err = pcall(actual)
			local matches = not ok and (pattern == nil or string.find(tostring(err), pattern, 1, true) ~= nil)
			check(matches, `function to throw{pattern and (" " .. format(pattern)) or ""}, got {ok and "no error" or tostring(err)}`)
		end
		return e
	end

	local passed, failed = 0, 0
	local failures = {}

	-- Spec files see the current test's server globals (game, task, Instance, require...).
	local currentServerEnv = nil
	local baseEnv = getfenv(1)
	local function lookup(_, key)
		if currentServerEnv then return currentServerEnv[key] end
		return baseEnv[key]
	end

	for _, specFile in ipairs(specFiles) do
		local tests = {}
		local prefix = {}
		local env = setmetatable({
			Rbx = Rbx,
			expect = expect,
			describe = function(name, body)
				table.insert(prefix, name)
				body()
				table.remove(prefix)
			end,
			it = function(name, body)
				table.insert(tests, { name = table.concat(prefix, " › ") .. (#prefix > 0 and " › " or "") .. name, body = body })
			end,
		}, { __index = lookup })
		local chunk = host_compile(host_readFile(specFile), specFile)
		setfenv(chunk, env)
		chunk()

		host_write(`\n{specFile}\n`)
		for _, test in ipairs(tests) do
			local world = Rbx.newWorld()
			local allowed = {}
			local t = { world = world }
			t.server = world:newServer({ jobId = "server-A" })
			currentServerEnv = t.server:envFor(nil)
			function t.wait(seconds) return world:wait(seconds) end
			function t.allow(pattern) table.insert(allowed, pattern) end
			function t.within(server, fn, ...)
				local args = table.pack(...)
				local result
				world:spawnIn(server, function()
					result = table.pack(xpcall(fn, function(err) return debug.traceback(tostring(err), 2) end, table.unpack(args, 1, args.n)))
				end)
				while result == nil do world.task.wait() end
				if not result[1] then error(result[2], 0) end
				return table.unpack(result, 2, result.n)
			end

			local ok, err = pcall(function() world:run(function() test.body(t) end, t.server, 7200) end)
			if ok then
				local problems = {}
				local function isAllowed(text)
					for _, pattern in ipairs(allowed) do
						if string.find(text, pattern, 1, true) then return true end
					end
					return false
				end
				for _, e in ipairs(world.errors) do
					if not isAllowed(e.message) then table.insert(problems, "background error: " .. e.traceback) end
				end
				for _, line in ipairs(world.logs) do
					if line.kind == "warn" and string.find(line.text, "Infinite yield", 1, true) and not isAllowed(line.text) then
						table.insert(problems, line.text)
					end
				end
				if #problems > 0 then
					ok = false
					err = table.concat(problems, "\n")
				end
			end

			if ok then
				passed += 1
				host_write(`  ✓ {test.name}\n`)
			else
				failed += 1
				host_write(`  ✗ {test.name}\n`)
				local tail = {}
				for index = math.max(1, #world.logs - 12), #world.logs do
					local line = world.logs[index]
					table.insert(tail, `      [{string.format("%7.2f", line.at)} {line.server} {line.kind}] {line.text}`)
				end
				table.insert(failures, `{test.name}\n    {tostring(err)}\n    last log lines:\n{table.concat(tail, "\n")}`)
			end
		end
	end

	if #failures > 0 then
		host_write("\nFailures:\n")
		for _, failure in ipairs(failures) do host_write(`\n✗ {failure}\n`) end
	end
	host_write(`\n{passed} passed, {failed} failed\n`)
	return failed
end
