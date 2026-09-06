# Architecture notes

## Inspection loop

The server owns the production-line state. It selects an eligible product, rolls a defect, applies optional anomaly state, spawns the product, and tracks the active inspection record until the player rejects it or it exits the inspection window.

The client sends requests; the server decides whether those requests are valid. `canPlayerAct` requires a loaded active session, while `RateLimiter` applies per-player token buckets to remote actions such as upgrades and factory-mode changes.

The server distinguishes three outcomes:

- a valid reject for a defect/anomaly;
- a false reject of a normal product;
- a missed defect that passes the inspection window.

Those outcomes feed credits, line revenue, quality streaks, onboarding, analytics and persistent statistics.

## Product and defect model

`ProductRegistry` defines 12 products across Toys and Household departments. Each product maps visual components to the `MissingPart` and `ExtraPart` defect families. `ProductConfig` adds weighted defect selection, onboarding fixtures, repeat-product suppression and streak multipliers.

The six base inspection states are Normal, WrongColour, Tiny, Giant, MissingPart and ExtraPart. Component defects are enabled only after the relevant progression point.

## Anomalies and collection

`AnomalyService` uses a two-stage roll:

1. whether an anomaly occurs;
2. the quality/tier of the anomaly.

The current configuration exposes Golden and Glitched anomalies. Discoveries are stored per product/anomaly pair, creating a 24-entry archive across 12 products. A guaranteed first Golden is available after a configured number of eligible products if one has not appeared naturally.

## Persistence

`PlayerDataService` owns the save boundary. Important properties include:

- schema versioning and rejection of unsupported future schemas;
- migration from older flat fields into the current nested record;
- defensive repair/clamping for corrupt numeric and boolean fields;
- DataStore `UpdateAsync` writes;
- session IDs with a five-minute lock timeout;
- monotonic save revisions to detect conflicting writers;
- bounded load/save retries with exponential backoff;
- autosave and delayed checkpoints for important changes;
- a memory adapter for unpublished Studio testing;
- a self-test matrix covering migration, corrupt-record repair, repeated save cycles, full progression state and deep-copy defaults.

A failed or conflicting load does not silently create a fresh production profile; the server treats safe loading as a prerequisite for gameplay.

## Progression

Progression is split between line upgrades and factory projects.

Line/research/inspector/rush upgrades control product value, belt motor tier, inspection runway length, anomaly luck/quality, streak protection and rush duration/pay.

Factory projects unlock production and research tiers, the reject gallery and the Household department. `LineProgression` changes the physical inspection runway and product spawn location as the runway upgrade advances.

## Public snapshot boundary

The original Roblox place also contains a large client UI, environment scripts, product model builders, presentation/audio configuration and the complete world model. Those remain private. The public source focuses on state, persistence, progression, inspection and factory systems.
