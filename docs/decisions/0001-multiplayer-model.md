# 0001 — Multiplayer: a shared hall, one line per player

**Status:** accepted. The numbers marked *provisional* are defaults to revisit with real playtests.

## Context

The legacy server allowed one player per server and kicked anyone else. The game is to launch as
multiplayer. Three shapes were considered:

| Model | For | Against |
|---|---|---|
| A. Shared hall, one line per player | Keeps the solo skill loop; other players are visible social proof; the Reject Gallery becomes something to visit | Per-player state everywhere; more server load |
| B. Co-op on one line | Strong as an event | Griefing and blame for shared mistakes are hard to balance |
| C. Personal servers plus a hub | Least work | Gives up the multiplayer pitch |

## Decision

**A.** Every runtime state the legacy server held globally becomes per player (anomaly luck, onboarding,
the line itself). Server-wide: Factory Rush becomes a plant-wide target with a shared bonus; the rarest-find
pedestal shows the server's rarest find. Co-op on one line may return later as an event mode.

## Provisional defaults

- **6 lines per server.** Lower is safer on mobile and server load; raise after measuring in Phase 2.
- **Missed defects never cost banked credits.** Stakes come from a Quality meter and Product Recall
  (Phase 3).
- **Shift Pay** (an unbanked pot a failed recall can dent): built behind a flag, off by default.
- **AFK:** the line pauses after about 45 seconds without input; no income while idle.
