# v3 — Racer experience

**Status:** discussion (not implementing yet)  
**Depends on:** v2 loop (shared 3-lap race) is playable  
**Not this version:** 20 laps, DataStore, ranked, extra courses, ghosts, in-game character editor

v3 is how the weekend *looks and what you drive*. Same racing line, same `DriveSim`, same 3 laps. Avatar stays whatever Roblox spawned.

Current law: [ROADMAP.md](../ROADMAP.md). Theme hook: [TRACK_THEMES.md](../TRACK_THEMES.md).

## Pillars

### 1. Track looks good

Today the circuit is generated parts: asphalt, grass tiles, metal rails, plaza pads. `ThemeService` can recolor those parts. It cannot look like a race meeting until we dress it (banners, kerb art, start gantry, plaza furniture, lighting) **on the existing centerline**.

Out: a new fantasy track. That is “extra courses”, after v3.

### 2. New kart bodies (character stays Roblox)

**Locked:** no in-experience character editor. The racer is the avatar Roblox already spawned.

**Car today:** six palettes during `Selecting` only. One procedural body (`KartPrototype`). Lock lasts until the next round.

**v3 car:** extra **bodies / models**, still `DriveSim`. Palettes remain paint. Pick in **plaza / Lobby+Selecting**, not after green.

Open: how many bodies, who models them, whether paddock shows one of each body or body×palette.

### 3. Theme per round

Already wired: `ThemeService.nextRound()` on each new lobby; `themeId` on `RaceStateChanged`; tagged decals + `ThemeColorRole`.

Classic IDs are filled (large repeating banners). `TrackThemes.Order` is still `{ Classic }`, so rounds look the same until a second theme exists.

v3 needs **at least two** filled themes so a second lobby is obviously a different meeting.

## Suggested slice order (draft)

1. **Dress Classic** so one round already looks like a race (gantry, banners, plaza, lighting) even before a second theme.
2. **Second theme** using the existing color + image slots.
3. **Kart bodies** in the paddock / select UI (same physics).

Art assets can land in `assets/` first, then `rbxassetid://` in `TrackThemes.luau`, same as storefront.

## Open questions

Record answers in [DECISIONS.md](../DECISIONS.md) when we pick them.

1. Themes: how many for v3 — two (Classic + one contrast) or a full weekend rotation?
2. Who paints the track: you supply images (like storefront), then we slot them into `TrackThemes` and tagged parts?
3. Kart bodies: how many for v3, and do you supply models / meshes, or do we stay procedural-but-distinct (wheelbase, wing, cabin) inside `KartPrototype`?
4. Pick flow: still one lock during Selecting, or can you walk the paddock and change body until countdown?
