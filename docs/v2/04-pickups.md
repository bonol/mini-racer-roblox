# v2.3 — Checkpoint pickups + using items

**Status:** not started  
**Depends on:** [v2.2 marketplace](03-marketplace.md)  
**Unlocks:** v2.4 track plaza (independent visually; this phase is gameplay)

## Playable outcome

- During `Racing`, each checkpoint has **one** live attachment pickup.
- Driving through it **adds that item** to inventory (same Booster / Landmine pool).
- After pickup, a new random item respawns after a delay.
- **E** (or a bound key) **activates booster** (1.5× speed, short burst).
- **Q** (or second bind) **drops a landmine** behind the kart; the next *other* kart that hits it is slowed to **0.7× for 5 seconds**.

Server decides pickups, boosts, slows, and mine hits.

## Item rules (locked)

| Item | Use | Effect | Stacking |
| --- | --- | --- | --- |
| Booster | Consume 1 | `MaxSpeed` and accel × **1.5** for `BoostSeconds` (start **3s**) | Does not stack; refresh duration if already boosting |
| Landmine | Consume 1, drop behind | Arm after `MineArmSeconds` (start **0.6s**) so dropper is immune; first other kart overlapping is slowed × **0.7** for **5s**; mine destroyed | Slow beats boost while both would apply |

`DriveSim` must read a **speed multiplier** from the kart (`Attribute` `SpeedMul` default 1). Server sets the attribute; client `DriveSim` uses `Constants.Car.MaxSpeed * mul`.

Do not trust the client to set `SpeedMul`.

## Pickups

- One `Pickup` part per checkpoint, slightly above the road, `CanCollide = false`.
- Attribute `ItemId`.
- Random from `{ "Booster", "Landmine" }` (equal weight).
- On collect: `InventoryService.add`, destroy/hide, `task.delay(RespawnSeconds)` spawn another (default **10s**).
- Same racer cannot collect the same pad twice in one **pass** (touch debounce already exists on checkpoints; reuse per-pickup touching).
- Only while match `state == Racing`.

## Implementation steps

### 1. Constants

```lua
Items = {
  BoostMul = 1.5,
  BoostSeconds = 3,
  SlowMul = 0.7,
  SlowSeconds = 5,
  MineArmSeconds = 0.6,
  PickupRespawnSeconds = 10,
}
```

### 2. `DriveSim`

```lua
local mul = model:GetAttribute("SpeedMul")
if typeof(mul) ~= "number" or mul <= 0 then
  mul = 1
end
-- clamp speed to MaxSpeed * mul
```

Default attribute `1` on spawn in `VehicleService`.

### 3. `ItemService` (new)

- `useBooster(player)`
- `dropMine(player)`
- Heartbeat: expire boost/slow; overlap mines vs other cars (`VehicleService.getCar`)
- Set `SpeedMul` = slow if slowed else boost if boosting else 1

### 4. Remotes

- `UseItem` client → server `{ "Booster" | "Landmine" }`
- Bind keys on client only while `Racing` and seated

### 5. Pickup pads

`TrackService` after checkpoints exist, or `PickupService.build()`:

- Place at each checkpoint CFrame, offset along look so it sits on the gate
- Tag `ItemPickup`
- Server overlap (same `DriveInput` position check as checkpoints) **or** `Touched` — prefer the existing `considerCarPosition` style so anchored karts still collect

### 6. HUD

- Boosted / Slowed timer
- Flash “picked up Landmine”
- Key hint: `E boost · Q mine`

### 7. VFX (minimum)

- Mine: small dark part on the road, destroyed on hit
- Boost: optional particle on kart; skip if slow

## Files to touch

| File | Change |
| --- | --- |
| `Constants.luau` | `Items` |
| `Remotes.luau` | `UseItem` |
| `DriveSim.luau` | `SpeedMul` cap |
| `VehicleService.luau` | Default `SpeedMul = 1` |
| `ItemService.luau` | **New** — use, mines, multipliers |
| `PickupService.luau` | **New** — spawn/collect/respawn |
| `MatchService` / `RaceService` | Only racing collects; clear mines on Podium |
| `RaceHud` + `DriveController` | Keys + status |
| `Bootstrap.server.luau` | Start item/pickup services |

## Do not in 2.3

- New item types (shield, oil)
- Client-authoritative speed
- Catch-up
- Plaza rebuild (2.4)

## Test plan

1. Buy a booster, press E in race: speed feels higher for 3s, count drops by 1, second E with 0 inventory does nothing.
2. Drop mine, drive over it yourself immediately: no self-slow (arming).
3. Player B hits armed mine: 5s slow, mine gone, A does not slow.
4. Slow while boosting: slow wins until it ends.
5. Each of 4 checkpoints has one pickup; collecting one does not clear the others.
6. Pickup respawns ~10s later as a (possibly different) item.
7. Cannot collect pickups in Selecting.
8. Two players racing: A’s pickup is not given to B.

## Done when

A 2-player race can buy or pick up both items, boost, and land a mine that actually slows the other kart for 5s.
