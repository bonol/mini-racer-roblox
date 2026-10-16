# v2 implementation index

Build **in order**. Do not start a later phase until the earlier one is playable with two Studio clients (Start / Start Server + Player for 2.0+).

```text
v2.0 Shared race  →  v2.1 Credits  →  v2.2 Marketplace  →  v2.3 Pickups  →  v2.4 Plaza/track
```

Product rules and tunables: [../ROADMAP.md](../ROADMAP.md).

## Current code (v1)

Solo time trial. Each player gets their own `RaceService` session.

| Module | Role now | v2 pressure |
| --- | --- | --- |
| `ServerScriptService/RaceService.luau` | Per-player `Idle → Selecting → Countdown → Racing → Finished`; finish on checkpoint 4 | Must become a **shared match** + 20 laps |
| `ServerScriptService/PlayerService.luau` | `CharacterAdded` / **R** calls `RaceService.start(player)` | Join match instead of starting a private race |
| `ServerScriptService/VehicleService.luau` | One kart at `getSpawnCFrame()`; freeze walk during select | Grid slots; later plaza walking |
| `ServerScriptService/TrackService.luau` | One spawn stripe, 4 checkpoints | Grid, plaza, pickup pads |
| `ReplicatedStorage/DriveSim.luau` | Client drive, `MaxSpeed` cap | Speed multiplier (2.2+) |
| `StarterPlayerScripts/KartSelect.luau` | 20s pick, then **that player** counts down | Shared 20s; wait for the field |
| `StarterPlayerScripts/RaceHud.luau` | Timer + “time trial” | Lap, place, credits, items |

`Constants.Race.LapCount` is `1`. `RequestRestart` restarts **that player** immediately.

## Ground rules for every phase

1. **Server owns the match.** Clients render HUD and predict driving. Credits, laps, items, and wins are server decisions.
2. **Do not rewrite `KartPrototype`.** Attachments are modifiers on the existing kart.
3. **Keep CollectionService tags** (`Checkpoint`, `RaceSpawn`). Add new tags; do not break the old ones.
4. **Script Sync names stay** `Bootstrap.server.luau` / `Bootstrap.client.luau` (no `init.server.luau`).
5. **One phase = one playable loop.** Leave later features as stubs (`inventory = {}`) only when the phase plan says so.
6. After each phase, update this index checkbox and the phase doc’s status line.

## Status

- [x] [v2.0 Shared race](01-shared-race.md) — solo Play verified; two-client Start Server still a manual check
- [ ] [v2.1 Credits](02-credits.md)
- [ ] [v2.2 Marketplace](03-marketplace.md)
- [ ] [v2.3 Pickups](04-pickups.md)
- [ ] [v2.4 Track plaza](05-track-plaza.md)

## Suggested Studio flow

1. Implement the phase on disk (and Script Sync / Studio MCP).
2. Play Solo: still works with 1 racer (min players = 1 in Studio).
3. Play Start Server + 2 Players: shared countdown, both see the same lap/place.
4. Only then open the next phase doc.
