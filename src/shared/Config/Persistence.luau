-- How player data is stored. ProfileStore owns session locking, retries,
-- autosave and shutdown saves; these are the knobs we set.

local Persistence = {}

-- A new store name: the legacy store held a different record format and the
-- game never shipped publicly, so nothing is migrated from it (ADR 0002).
Persistence.StoreName = "FindTheDefect_Profiles_v2"
Persistence.StudioStoreName = "FindTheDefect_Profiles_v2_STUDIO"
Persistence.KeyPrefix = "Player_"

-- Seconds between autosaves of one profile (ProfileStore staggers them).
Persistence.AutosavePeriod = 120
-- After an important change, save soon, but never more often than this per player.
Persistence.CheckpointSpacing = 15

return Persistence
