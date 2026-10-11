# Roadmap

From a single-player snapshot to a multiplayer launch. Each phase ends with something checkable.

## Phase 0 — Decide ✅
Multiplayer model and defaults: [ADR 0001](decisions/0001-multiplayer-model.md).

## Phase 1 — Foundation (in progress)
- [x] Rojo project; legacy snapshot moved to `legacy/`
- [x] Studio-free test harness ([ADR 0003](decisions/0003-studio-free-testing.md))
- [x] ProfileStore, vendored and reviewed; `DataService` on it ([ADR 0002](decisions/0002-profilestore.md))
- [x] Fixed: final save skipped during an autosave; quick rejoin kicked; analytics fields silently
      dropped; debug values writable at runtime
- [x] Tutorial progress saved as a step, so an early leave can resume (the Phase 2 loop reads it)
- [x] Configs consolidated and frozen; one source for line geometry; anomaly odds computed, not typed
- [x] `EconomyService` as the only writer of credits, reporting to Roblox's economy dashboard
- [x] CI green: Rojo builds the place, tests pass on Linux, StyLua and Selene clean (`npm run format`)
- [ ] One pass on a real Roblox staging place to confirm the data scenarios

**Done when:** CI is green and the data scenarios behave the same on a staging place.

## Phase 2 — Multiplayer core
Plots and per-player lines; products rendered on the client from a server timeline (no per-frame server
moves); rejects judged where the product was when clicked (ping-compensated, capped at 0.25 s); the
legacy inspection loop rebuilt on the new services; server-wide Factory Rush.

**Done when:** six players for thirty minutes on a staging place with no cross-talk, and server bandwidth measured.

## Phase 3 — Stakes and balance
Quality meter (misses and false rejects drain it; Certified pays more; zero triggers a Product Recall);
AFK pause; Leave line refused while a defect is in the window; growth from product value and new defect
types rather than raw speed (at most about two products in the window); Inspection Tools upgrades; an
economy simulator to tune curves.

**Done when:** the simulator shows no dominant idle or spam strategy and playtesters read the meter unprompted.

## Phase 4 — Social and retention
Plant-wide rushes, leaderboards (bot-flagged accounts excluded), daily contracts, the onboarding funnel
dashboard.

## Phase 5 — Launch readiness
Monetisation (passes, private servers, cosmetics; no paid luck), Roblox's maturity questionnaire,
performance budget, soft launch.

**Done when:** day-one retention of at least 30% in the soft-launch cohort.
