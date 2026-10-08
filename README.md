# Find the Defect!

**A multiplayer Roblox factory game about catching defective products — built in Luau, tested without Studio.**

Products roll down an inspection line; you reject the defective ones before they escape. Six defect types,
rare Golden and Glitched anomalies to collect, rushes, streaks, and a factory that grows as you earn.

> **Status:** being rebuilt for a multiplayer launch. Phase 1 (foundation) is in progress; the playable
> inspection loop is still the single-player version in [`legacy/`](legacy/). See [the roadmap](docs/roadmap.md).

## What is here

| Path | What |
|---|---|
| [`src/shared/Config`](src/shared/Config) | Every game number: products, defects, upgrades, anomalies, factory projects, line geometry. Frozen at load; one source for each value. |
| [`src/shared/Gameplay`](src/shared/Gameplay) | Pure rules: what comes down the line next, per-player anomaly luck. |
| [`src/server/Data/Schema.luau`](src/server/Data/Schema.luau) | The player record: defaults, versioned migrations, and repair that refuses newer data and keeps unknown keys. |
| [`src/server/Services`](src/server/Services) | `DataService` (ProfileStore sessions), `EconomyService` (the only writer of credits), `Analytics` (Roblox's built-in funnels and economy events). |
| [`src/server/Bootstrap.server.luau`](src/server/Bootstrap.server.luau) | The server's one entry point. |
| [`tests/`](tests) | 61 tests, including cross-server data scenarios. |
| [`tools/harness`](tools/harness) | Runs the tests under Node: real Luau, emulated engine. |
| [`legacy/`](legacy) | The original single-player snapshot, kept for reference until Phase 2 replaces it. |

## Running the tests

```sh
npm ci --ignore-scripts
npm test             # all specs
npm test -- data     # only spec files whose path contains "data"
```

There is no Roblox Studio in the loop. [`tools/harness`](tools/harness) runs the game's Luau on the real
Luau VM (compiled to WebAssembly) against a small engine emulator: a virtual clock and task scheduler,
deferred signals, strict instances, Players, and a DataStore plus MessagingService **shared by several
emulated servers** — with latency, injected failures, shutdowns and crashes. That is what lets the
tests cover the cases that matter for player data:

- a player leaves while an autosave is in flight — the final state is still saved;
- a player rejoins another server immediately — they wait for the old server, not get kicked;
- a server crashes — the next server recovers the last save within a minute and a half;
- the same player opens a second server — the newest wins and the old one lets go;
- a save from a newer game version — refused and left untouched.

The emulator is strict where Roblox is strict (unknown members error, values are type-checked, the
DataStore refuses mixed tables and NaN) and adversarial where Roblox is timing-dependent. It does not
emulate physics, rendering, replication or the client; those need a real Roblox client (see the roadmap).

## Building the place

With [Rokit](https://github.com/rojo-rbx/rokit) installed: `rokit install`, then
`rojo build default.project.json -o find-the-defect.rbxl`. CI builds the place on every push.

## Third-party code

[ProfileStore](https://github.com/MadStudioRoblox/ProfileStore) is vendored at a pinned commit and
reviewed; nothing is fetched by asset id. The list, with licences and review notes, is in
[`THIRD_PARTY.md`](THIRD_PARTY.md).

## Design decisions

Recorded in [`docs/decisions`](docs/decisions). The architecture is in [`docs/architecture.md`](docs/architecture.md).
