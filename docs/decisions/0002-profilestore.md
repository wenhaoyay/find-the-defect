# 0002 — Player data on ProfileStore, in a new store

**Status:** accepted.

## Context

The legacy `PlayerDataService` implemented its own session lock and had three failures that lose data
or players: a leave during an autosave skipped the final save and kept the lock for five minutes; a
quick rejoin to another server was kicked instead of waiting; and the lock was refreshed only on save.

## Decision

- Use [ProfileStore](https://github.com/MadStudioRoblox/ProfileStore), vendored at a pinned commit
  (see `THIRD_PARTY.md`). It hands sessions between servers (MessagingService plus a timed steal),
  queues saves for the same key instead of skipping them, and flushes on shutdown.
- Keep the game's own rules in `Schema` and `DataService`: repair before use, refuse newer schemas,
  keep unknown keys, kick on session takeover.
- **No ProfileStore template.** Its `Reconcile` would fill defaults before our migrations run, hiding
  what an old record contained (a v1 record would gain `TutorialStep = 0` and lose its real progress).
  `Schema.Repair` fills defaults itself.
- **A new store, `FindTheDefect_Profiles_v2`.** The legacy store's records have a different envelope,
  and the game never shipped publicly, so nothing is imported. `Schema` still migrates the v1 record
  shape, so an import could be added if test players' progress ever needs keeping.
- Autosave every 120 seconds; checkpoints after purchases and discoveries, at most one per 15 seconds
  per player.
