# 0003 — Testing without Roblox Studio

**Status:** accepted.

## Context

Development happens on a machine without Roblox Studio. Code that only runs inside Studio cannot be
tested there, and "it worked when I played it" does not cover server crashes or cross-server races.

## Decision

`tools/harness` runs the tests with Node and [luau-web](https://github.com/xNasuni/luau-web), the real
Luau VM compiled to WebAssembly. Around it, `rbx.luau` emulates the parts of the engine server code
touches:

- a virtual clock and task scheduler (`task.*`, `os.clock`, `os.time`), so minutes of play run in
  milliseconds and the result is deterministic;
- instances built from `default.project.json` exactly as Rojo maps them, strict about unknown
  members, value types and destroyed parents;
- deferred signals, with `PlayerRemoving` handlers running after the player is gone (the adversarial
  reading of Roblox's timing);
- one DataStore and MessagingService shared by several emulated servers, with latency, injected
  failures, `BindToClose` shutdowns and crashes that drop a server's threads mid-save.

Specs are Luau (`tests/*.spec.luau`) with `describe` / `it` / `expect`. A test also fails if a background
thread errored or an infinite-yield warning was logged.

## Limits

The emulator is a model of Roblox, not Roblox. It does not cover physics, rendering, replication, the
client, or engine behaviour it does not model. The data scenarios run the real ProfileStore, but against
an emulated DataStore. So:

- every behaviour the tests pin must also be checked once on a real Roblox server (a staging place),
  and a difference found there becomes a fix to the emulator plus a test;
- CI additionally builds the place with Rojo, so a broken project mapping fails on GitHub.
