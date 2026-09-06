# Find the Defect!

**Server-authoritative Roblox factory inspection and progression systems built in Luau.**

Find the Defect! is a factory quality-control game where products move through an inspection line and the player decides whether to reject defective units. The project combines weighted defect generation, persistent factory progression, anomaly collection, streak/rush systems and an explorable factory layer.

> **Status:** active development. This repository is a curated portfolio snapshot recovered from the original Roblox place; it is not the complete game or a public release build.

## What this repository demonstrates

### Server-authoritative inspection

The server owns active products, defect state, rewards and progression. Client requests are accepted only for the loaded active inspector and remote actions are rate-limited server-side.

The inspection loop handles correct rejects, false rejects and missed defects separately, with those outcomes feeding credits, line revenue, quality streaks, onboarding state, analytics and persistent statistics.

### Product/defect generation

The public registry contains **12 products** across Toys and Household departments and six base inspection states:

- Normal
- Wrong Colour
- Tiny
- Giant
- Missing Part
- Extra Part

Product-specific components define what can be removed or duplicated for the component-defect families. Spawn logic also includes deterministic onboarding examples and repeat-product suppression.

### Persistent progression

`PlayerDataService` is the strongest systems module in this project. It contains:

- schema versioning and legacy-field migration;
- defensive repair/clamping of corrupt data;
- `DataStoreService:UpdateAsync` persistence;
- session locks and save revisions for conflicting-session protection;
- bounded load/save retries with exponential backoff;
- autosave and delayed checkpoints;
- Studio memory/test-store paths;
- persistence self-tests covering migration, corruption repair, repeated save cycles, the full progression matrix and deep-copy defaults.

### Anomalies and collection

Products can also roll rare anomaly states. The current public configuration contains Golden and Glitched variants, with a two-stage occurrence/quality roll and a guaranteed early Golden safeguard.

With 12 products × 2 anomaly types, the persistent archive contains **24 discovery entries**.

### Factory progression

Progression is not only numeric. Upgrades can change the physical production line itself: `LineProgression` expands the inspection runway and moves the product spawn point as the runway level increases.

The wider factory progression includes production/research tiers, a research lab, reject gallery and a second Household production department.

## Start here

For a technical review:

- [`src/server/PlayerDataService.luau`](src/server/PlayerDataService.luau) — schema repair, session locking, revision-safe persistence and self-tests.
- [`src/server/FindDefectServer.server.luau`](src/server/FindDefectServer.server.luau) — authoritative inspection loop, streak/rush handling, upgrades and mode transitions.
- [`src/shared/ProductRegistry.luau`](src/shared/ProductRegistry.luau) — data-driven product/component/defect definitions.
- [`src/server/AnomalyService.luau`](src/server/AnomalyService.luau) — anomaly rolls, archive restoration and rarest-discovery tracking.
- [`src/server/LineProgression.luau`](src/server/LineProgression.luau) — physical conveyor/runway progression.

## Architecture

```text
Roblox client
    │ inspection / upgrade / mode requests
    ▼
Authoritative server
    ├── FindDefectServer       inspection loop, streaks, rushes, rewards
    ├── PlayerDataService      persistence, schema repair, session locking
    ├── RateLimiter            per-player remote throttling
    ├── AnomalyService         rare variant rolls + collection
    ├── LineProgression        physical inspection-line upgrades
    ├── FactoryProgression     project/gallery/factory progression
    └── Analytics              session and funnel events
            │
            ▼
Shared configuration
    ├── ProductRegistry        products, components and defect definitions
    ├── ProductConfig          weighted rolls and streak rules
    ├── UpgradeConfig          line/research/inspector/rush progression
    ├── FactoryConfig          factory project tree
    ├── DepartmentConfig       department unlocks
    └── AnomalyConfig          archive and anomaly probabilities
```

More detail is in [`docs/architecture.md`](docs/architecture.md).

## Repository layout

```text
src/
  shared/    product, defect, anomaly, upgrade and persistence configuration
  server/    persistence, inspection, anomaly and factory progression systems
docs/
  architecture.md
```

## Why this is a curated snapshot

The original `.rbxl` contains the complete factory world, client UI, environment logic, presentation/audio configuration, product model builders and other content that is not necessary for technical review. Those remain private.

The Luau files here were extracted from the embedded Roblox place source. The public snapshot intentionally keeps the engineering-heavy systems and omits most presentation code. Some server modules therefore reference private visual/world modules that are not included here.

This repository is for **technical review**, not a one-command reproduction of the full game.

## Validation boundary

The persistence module contains its own in-project self-test matrix, but I am **not claiming a fresh automated test run from this extracted repository** because Roblox Studio/Luau runtime services are not available in the publication environment.

The extracted source was checked against the original `.rbxl` payload and scanned for credentials and unintended development artefacts before publication.

## Current limitations

- Active work in progress; gameplay balance and presentation are still changing.
- No public experience link yet.
- The public repo excludes the `.rbxl`, full client/UI, product model builders and world/presentation layer.
- Some server imports intentionally point to those private modules.
- The original place metadata contains an internal `5C-LaunchReady` milestone label; that is an internal development checkpoint, not a claim that the game is publicly shipped.
