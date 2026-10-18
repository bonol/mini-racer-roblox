# v2 implementation index

v2.0 → v2.4 are **implemented** (including multi-racer). `LapCount` is **3**. Next version is [v3 racer experience](../v3/00-index.md). Open leftover: Creator Hub listing.

Product rules and tunables: [../ROADMAP.md](../ROADMAP.md). Phase catalogs below are historical.

```text
v2.0 Shared race  →  v2.1 Credits  →  v2.2 Marketplace  →  v2.3 Pickups  →  v2.4 Plaza/track
```

## Current code

Shared match on `MatchService`. `RaceService.luau` is leftover v1 and is not the session owner.

| Module | Role now |
| --- | --- |
| `ServerScriptService/MatchService.luau` | Shared `Lobby → Selecting → Countdown → Racing → Podium` |
| `ServerScriptService/PlayerService.luau` | Join/leave the match |
| `ServerScriptService/VehicleService.luau` | Plaza walk, paddock, grid sit |
| `ServerScriptService/TrackService.luau` | Circuit, plaza, grid, climbs, recover CFrames |
| `ServerScriptService/CreditService.luau` | Wallet, stipend, payout |
| `ServerScriptService/InventoryService.luau` | Booster + Bomb counts |
| `ServerScriptService/MarketService.luau` | Stalls in Lobby/Selecting |
| `ServerScriptService/ItemService.luau` | E boost, Q bomb, slow |
| `ServerScriptService/PickupService.luau` | One pad per checkpoint |
| `ReplicatedStorage/DriveSim.luau` | Client drive, `SpeedMul`, grade |
| `StarterPlayerScripts/KartSelect.luau` | Shared 20s; wait for the field |
| `StarterPlayerScripts/RaceHud.luau` | Lap, place, credits, bag, SPD |
| `StarterPlayerScripts/MusicController.luau` | Toolbox stings |

`Constants.Race.LapCount` is **3** (testing). North star is 20. `RequestRestart` only from Podium.

## Ground rules

1. **Server owns the match.** Clients render HUD and predict driving.
2. **Do not rewrite `KartPrototype`.** Attachments are modifiers on the existing kart.
3. **Keep CollectionService tags** (`Checkpoint`, `RaceSpawn`).
4. **Script Sync names stay** `Bootstrap.server.luau` / `Bootstrap.client.luau`.
5. After a product call, update [DECISIONS.md](../DECISIONS.md) and ROADMAP Rules — not these historical catalogs.

## Status

- [x] [v2.0 Shared race](01-shared-race.md) — solo Playtesters
- [x] [v2.1 Credits](02-credits.md) — solo (stipend 20, start 10, 1st 150)
- [x] [v2.2 Marketplace](03-marketplace.md) — solo (Bomb 10 / Booster 20, shop closed after green)
- [x] [v2.3 Pickups](04-pickups.md) — solo (pad collect, E boost 1.5×, Q bomb, no owner immunity)
- [x] [v2.4 Track plaza](05-track-plaza.md) — solo (walk plaza, grid sit, climbs, off-map recover)

Open leftover (v2 packaging, not v3):

- [ ] Upload `assets/storefront/` to Creator Hub (listing still blank)

Deferred: 20 laps. Next: [v3/00-index.md](../v3/00-index.md).
