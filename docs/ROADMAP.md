# Mini Racer — product roadmap

v1 (HANDOVER time trial) is **done**. This file is the plan from here: a **multiplayer 20-lap race** with credits, a pre-race marketplace, and on-track attachments.

Phase-by-phase implementation: [v2/00-index.md](v2/00-index.md).

---

## v1 review (HANDOVER.md)

HANDOVER described a single-player oval time trial and a Desktop/Studio setup. That work is complete, and the live game has already gone past the original oval.

| HANDOVER item | Status |
| --- | --- |
| Cursor Desktop + Roblox Studio MCP + Script Sync | Done |
| Git repo | Done (`main`) |
| Procedural track, spawn, 4 ordered checkpoints | Done — circuit, not oval |
| Kart, countdown, race, finish time, **R** restart | Done |
| Hide default Baseplate / SpawnLocation | Done |
| Best time in memory only (no DataStore) | Still true (v1) |
| Multiplayer lobby | **Not started — this is v2** |
| Ghost best-time, DataStore | Still later |

**Shipped beyond HANDOVER**

- Shared kart prototype + 6 color palettes (Azure, Forest, Blush, Ember, Midnight, Voltage)
- 20s car select (paddock + UI); timeout uses Azure
- Client-frame driving (`DriveSim`) with wall bounce
- Longer lap: T1 hairpin, south hairpin, pit whoops, post-T1 whoops

**v1 loop today:** one player → pick a kart → 3-2-1 → 1 lap → 4 checkpoints → time → R to restart.

Constants still say `LapCount = 1`. Driving and race state are **per player**, not a shared session.

---

## North star

A Roblox server is one race weekend.

1. Racers spawn **on foot** in the start plaza (paddock + shop).
2. Each round they get a **minimum credit stipend**.
3. They pick a kart and spend credits on **attachments**.
4. They sit down; the field counts down together.
5. First racer to **complete 20 laps** wins.
6. **Top 3** earn extra credits for the next round.
7. During the race, each checkpoint holds **one random pickup** to drive through.

Win condition is **race position / laps**, not time trial.

---

## Round loop

```text
Join server
    → on-foot plaza (paddock + marketplace)
    → stipend credited
    → select kart + shop attachments
    → sit in kart / grid
    → shared countdown
    → 20 laps (checkpoints + pickups + items)
    → first to 20 laps wins
    → top 3 paid
    → short podium, then next round (credits keep)
```

Pre-race is walkable: **run to the grid**, browse the shop, click a paddock kart. The circuit is for racing, not for hanging out.

---

## v2 phases

Ship in this order. Each phase should be playable. Details live in `docs/v2/`.

| Phase | Doc | Playable outcome |
| --- | --- | --- |
| v2.0 | [01-shared-race.md](v2/01-shared-race.md) | Everyone races the same 20-lap event |
| v2.1 | [02-credits.md](v2/02-credits.md) | Stipend + top-3 credits |
| v2.2 | [03-marketplace.md](v2/03-marketplace.md) | Shop booster / landmine before green |
| v2.3 | [04-pickups.md](v2/04-pickups.md) | Checkpoint pickups + use items on track |
| v2.4 | [05-track-plaza.md](v2/05-track-plaza.md) | Walkable plaza, grid, racing-safe track |

---

## Rules (lock these unless playtests say otherwise)

**Race**

- 20 laps, checkpoints 1→2→3→4 must be taken in order each lap
- Place = laps completed, then checkpoint, then distance along the sector
- Winner = first to complete lap 20’s finish line
- Items do not skip checkpoints

**Credits**

- Stipend is granted when `Selecting` starts, once per round per player
- Payout only for racers who started the countdown
- Shop prices cannot put the wallet below 0
- Credits carry across rounds in the same server

**Attachments**

- Booster: multiply `MaxSpeed` (and accel if needed) by **1.5** while active; does not stack with itself
- Landmine: one-hit, then gone; victim speed **0.7×** for **5s**; owner is immune for a brief arming delay so you cannot mine yourself on drop
- Slow and boost: if both apply, **slow wins** until it expires
- Checkpoint pickup: 1 live pickup per checkpoint; random type from the pool; cannot vacuum the same pad twice in one pass

**Pre-race**

- Everyone can select a kart
- Shop is only open in `Lobby` / `Selecting`
- If you never sit, you are not on the grid (spectator until next round)

---

## What we build on

Keep the current modules; do not rewrite the kart.

| Now | v2 adds |
| --- | --- |
| `RaceService` per-player state | Server `MatchService` / shared `RaceSession` |
| `KartSelect` + paddock | Same select, plus all players in one timer |
| `TrackService` tags | Grid parts, plaza, pickup pads, market stands |
| `KartPrototype` palettes | Unchanged; attachments are modifiers, not new bodies |
| `DriveSim` | Speed multiplier from boost/slow; mine overlap |
| `Constants` | Laps, payouts, item tunables |
| `Remotes` | Shop, use item, match state, scores |

Server owns: credits, inventory, pickups, mines, lap/place, win.

---

## Later (not v2)

- Extra tracks / votes
- More shop tiers (permanent 1.5× is a **no** unless it is a cosmetic-only prestige)
- DataStore seasons / leaderboards
- Ghosts from v1 time trial
- Private servers / ranked
- Traitor-style items that grief the whole lobby

---

## Done when

A full server can: walk the plaza → get stipend → buy a booster or mine → pick a kart → race 20 laps → first across wins → top 3 paid → immediately run it again without a teleport.

Playtest checklist: 2-player Studio, then 4+. Confirm mines don’t false-hit the dropper, pickups respawn, and the whoops still feel fair on lap 15.
