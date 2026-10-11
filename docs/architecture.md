# Architecture

## Shape of the game

A server hosts several players in one shared factory hall. Each player runs **their own inspection
line** (a plot); rushes, the rarest-find pedestal and announcements are shared by the server. See
[ADR 0001](decisions/0001-multiplayer-model.md).

```text
Bootstrap.server.luau          starts services in order, admits players
  Services/
    DataService                ProfileStore session per player; Schema.Repair on load
    EconomyService             the only code that changes credits; economy analytics
    Analytics                  Roblox built-in onboarding / economy / progression events
    (Phase 2) PlotService      assigns a line to a player, releases it on leave
    (Phase 2) LineService      the spawn timeline per line
    (Phase 2) InspectionService  validates rejects (with lag tolerance), resolves outcomes
    (Phase 3) QualityService   the quality meter and product recalls
  Data/Schema                  the player record: template, migrations, repair
  Util/RateLimiter             per-player token buckets for remotes
ReplicatedStorage/Shared
  Config                       every game number, frozen
  Gameplay                     pure rules (rolls, anomaly luck) shared by server and client
  Util/Signal                  module-to-module events
```

## Rules the code keeps

- **One source of truth for player state.** `DataService.Get(player)` is the live record; nothing else
  stores player state. Replicated values (Phase 2) are derived from it, never read back.
- **One writer per kind of state.** Credits change only in `EconomyService`; the record's shape only in
  `Schema`.
- **Configs are frozen.** Studio-only debug switches live in `Config.Debug` and read as off outside Studio.
- **Repair never destroys.** A record from a newer schema is refused; keys this version does not know
  are kept.
- **Per player, not per server.** Anomaly luck, onboarding and rate limits belong to a player. The
  legacy server kept them globally because it allowed one player per server.

## Player data

ProfileStore handles session locks, autosave, retries and the shutdown flush. `DataService` adds:
repair before use, kick if another server takes the session, synchronous release handlers (so play
time and analytics totals are in the final save), and throttled checkpoints after important changes.
See [ADR 0002](decisions/0002-profilestore.md).

## Testing

[ADR 0003](decisions/0003-studio-free-testing.md) explains the harness and what it can and cannot prove.
