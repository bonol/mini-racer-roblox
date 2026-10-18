# v2.4 — Track made for racing

**Status:** implemented (solo Studio Play verified; two-client Start Server still a manual check)  
**Depends on:** [v2.0 shared race](01-shared-race.md) (required). Better **after 2.2–2.3** so the plaza has a shop and the grid is not rebuilt twice.  
**Unlocks:** v2 north-star loop complete

## Playable outcome

Before green, racers **walk** a start plaza: paddock karts, market stalls, then run to the grid and sit. The racing line stays the current circuit (hairpins + whoops). The **start/finish is a proper grid in front of the pit whoops** (whoops stay *after* the line). Karts that leave the world **respawn on track**, not into a new time trial.

## Why last

2.0–2.3 can ship on the existing freeze-at-spawn + grass stall. This phase is layout and feel: walk to race, race 20 laps without a stuck pile-up.

## Layout

Keep the current centerline. Do not design a new fantasy circuit.

```text
  [infield plaza]
    paddock (display karts)     market stalls
              \                /
               run-up / fence
  =================================================  pit straight
  GRID  |  S/F stripe  |  (flat)  |  pit whoops  |  T1 ...
  =================================================
```

- **Grid** on the flat pit, **before** the yellow stripe and **before** the whoops zone (`PIT_WHOOP_NEAR` in `TrackService`).
- **Plaza** infield of the pit (`spawn.RightVector` toward infield — verify sign in Studio; paddock today uses `CFrame.new(48, 0, 8)` from spawn).
- Characters spawn in the plaza with **normal walk speed** during `Lobby` / `Selecting`.
- Sitting: proximity on the **grid kart** (already have `EnterCar`) or auto-sit at Countdown like today.

`VehicleService.freezeForSelect` currently zeros walk and teleports to the stripe. **Stop doing that** in this phase:

- Lobby/Selecting: walk the plaza
- Countdown: teleport/sit onto assigned grid slot (so AFK walkers still start)

## Implementation steps

### 1. TrackService plaza + grid

- `buildPlaza()`: a few anchored floor parts (asphalt pads) beside the pit, not overlapping the road.
- `getGridCFrame(i, n)`: finalize 2 rows if `n > 4`. Paint stall decals (colored parts).
- Move whoops if they overlap the grid: keep `zoneNear` so the first ~32 studs after S/F stay flat; grid sits **upstream** of S/F (before the line along the lap).
- Re-place `KartPaddock` and `KartMarket` on plaza pads (replace magic `CFrame.new(48,0,8)` with `TrackService.getPaddockCFrame(i)` / `getStallCFrame(i)`).

### 2. Character flow

| Match state | Character | Kart |
| --- | --- | --- |
| Lobby | Walk plaza | Display paddock only |
| Selecting | Walk plaza, click paddock to lock color | Still display |
| Countdown | Sit grid kart | Real racers spawned on slots |
| Racing | Seated | Drive |
| Podium | Seated or stand in plaza | Frozen |

### 3. Racing safety

- If a kart `Position.Y < -20` or far from centerline, `PivotTo` last checkpoint CFrame + hover (server).
- Optional: slightly taller barriers only in T1 / south hairpin if 4 karts wedge. Do not remove whoops.
- Ghost collisions (karts pass through each other) **only if** 4-player tests brick; default **solid** for 2.4.

### 4. HUD / camera

- Selecting: camera can stay paddock overview **or** follow the walking character — follow-on-foot is better for “run to race”.
- Hint: “Walk the shop · click a kart · sit before green”

### 5. 20-lap feel

Drive 5+ laps in a 2-player test on whoops and T1. If the post-T1 whoops launch people off the map, clamp hop `MAX_LAUNCH` or flatten that zone slightly — that is in scope for 2.4, not a new item.

## Files to touch

| File | Change |
| --- | --- |
| `TrackService.luau` | Plaza parts, grid, named CFrame helpers; whoops vs grid |
| `VehicleService.luau` | No freeze-walk; paddock/market from TrackService |
| `MatchService.luau` | Spawn characters in plaza; sit at countdown |
| `CameraController.luau` | Follow on foot in Lobby/Selecting |
| `KartSelect.luau` | Copy: “run to the shop / paddock” |
| `DriveSim.luau` | Only if whoops eject karts (launch clamp) |

## Do not in 2.4

- New track silhouette (no extra hairpins unless a 4-wide pile-up proves T1 is broken)
- Catch-up rubber band (revisit only if place-1 is always alone by lap 8)
- Extra shop items
- DataStore

## Test plan

1. Lobby: walk from paddock to market without hitting the racing line (or only a curb).
2. Selecting: click a display kart, still walk, then countdown snaps you to a unique grid slot. No two karts overlap.
3. Whoops start **after** the pack has crossed S/F, not under the grid.
4. Two (then four if possible) karts through T1 and south hairpin without an unrecoverable wedge.
5. Deliberate fall off the map → respawn at last checkpoint, same lap.
6. Full north-star loop: stipend → buy → pick → 20-lap race → top 3 paid → walk plaza again.

## Done when

The HANDOVER/v2 north star is playable without teleports except the countdown sit: **walk the plaza, shop, pick a car, race 20 laps, get paid, repeat**.
