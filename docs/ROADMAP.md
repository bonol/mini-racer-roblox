# Mini Racer — product roadmap

v1 (HANDOVER time trial) is **done**. v2 is the **shared 3-lap race** with credits, shop, pickups, plaza, and bombs. v3 is **racer experience** (looks, identity, themes).

Phase-by-phase implementation: [v2/00-index.md](v2/00-index.md).

**Current law** is the Rules section below (must match `ReplicatedStorage/Constants.luau`). Why a rule changed: [DECISIONS.md](DECISIONS.md). What each commit shipped: [TRACE.md](TRACE.md). `docs/v2/` phase docs are historical checklists — do not rewrite their catalogs for a tunable change.

---

## Status

**v2 is playable** with multiple racers. Loop today:

plaza walk → stipend 20 → shop Bomb 10 / Booster 20 → kart select → shared countdown → **3 laps** with pickups, E boost, Q bomb, 30° climbs → podium → next lobby.

v2 leftover (still this version, not v3 gameplay):

- [ ] Upload `assets/storefront/` to Creator Hub (icon / 16:9 thumbnail / gallery) — files exist, Roblox listing is still blank

**v3 (next) — racer experience:**

- Track should look good (same racing line; presentation, not a new circuit)
- **Car:** new bodies/models in the plaza; same `DriveSim`. No in-game character editor (Roblox avatar as spawned)
- Track **theme can change per round** (`ThemeService` already cycles; only `Classic` exists and image slots are empty)

Deferred: 20 laps. After v3: DataStore, ranked, ghosts, extra *courses*, private servers.

v1 time trial is **historical**.

---

## North star

A Roblox server is one race weekend.

1. Racers spawn **on foot** in the start plaza (paddock + shop).
2. Each round they get a **minimum credit stipend**.
3. They pick a kart and spend credits on **attachments**.
4. They sit down; the field counts down together.
5. First racer to complete **`LapCount` laps** wins (**3** now; **20** deferred).
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
    → 3 laps (checkpoints + pickups + items)
    → first to LapCount wins
    → top 3 paid
    → short podium, then next round (credits keep)
```

Pre-race is walkable: **run to the grid**, browse the shop, click a paddock kart. The circuit is for racing, not for hanging out.

---

## v2 phases

All five phases are **implemented**. Catalogs in `docs/v2/` are historical (they still say Landmine / 80 cr / 20 laps). Current tunables: Rules below.

| Phase | Doc | Playable outcome | Status |
| --- | --- | --- | --- |
| v2.0 | [01-shared-race.md](v2/01-shared-race.md) | Shared match, select, countdown, laps | Done (incl. multi-racer) |
| v2.1 | [02-credits.md](v2/02-credits.md) | Stipend + top-3 credits | Done |
| v2.2 | [03-marketplace.md](v2/03-marketplace.md) | Shop before green | Done |
| v2.3 | [04-pickups.md](v2/04-pickups.md) | Checkpoint pickups + E/Q | Done |
| v2.4 | [05-track-plaza.md](v2/05-track-plaza.md) | Walkable plaza, grid, climbs | Done |

---

## Rules (lock these unless playtests say otherwise)

**Race**

- Current race: `LapCount = 3`. **20 laps** is deferred (not this version).
- Checkpoints 1→2→3→4 must be taken in order each lap
- Place = laps completed, then next checkpoint (sector distance not built)
- Winner = first to complete `LapCount` at the finish line
- Items do not skip checkpoints
- Curve climbs: **30°**, peak cap **48**, grade speed floor **0.25×**

**Credits**

- `StartingBalance = 10`
- Stipend **20**, once per round per player (Lobby; also Selecting if they join then — do not double-pay)
- Finish bonus **20**; podium payout `{ 150, 90, 50 }` only for racers who started the countdown
- Shop prices cannot put the wallet below 0
- Credits carry across rounds in the same server

**Attachments**

- Booster: cost **20**; **1.5×** speed for **3s**; does not stack with itself
- Bomb: cost **10**; Q drops a neon bomb; anyone within 7 studs is slowed **0.7×** for **3s**, including the dropper
- Slow and boost: if both apply, **slow wins** until it expires
- Checkpoint pickup: 1 live pickup per checkpoint; random Booster or Bomb; cannot vacuum the same pad twice in one pass

**Pre-race**

- Everyone can select a kart
- Shop is only open in `Lobby` / `Selecting`
- If you never sit, you are not on the grid (spectator until next round)

**Studio / audio**

- Play-verify on **Mini Racer [testing]**, PlaceId `98798376352087` (not PlaceId 0 / `.rbxlx`)
- Keep the seven Toolbox ids in `Constants.Audio`; do not swap for generic packs
- Do not rewrite the kart / `DriveSim` controller

---

## What we build on

Keep the current modules; do not rewrite the kart.

| Now | v2 adds |
| --- | --- |
| `RaceService` per-player state | Server `MatchService` / shared `RaceSession` |
| `KartSelect` + paddock | Same select, plus all players in one timer |
| `TrackService` tags | Grid parts, plaza, pickup pads, market stands |
| `KartPrototype` palettes | Unchanged; attachments are modifiers, not new bodies |
| `DriveSim` | Speed multiplier from boost/slow/grade; bomb overlap |
| `Constants` | Laps, payouts, item tunables |
| `Remotes` | Shop, use item, match state, scores |

Server owns: credits, inventory, pickups, bombs, lap/place, win.

---

## v3 — racer experience (next)

Same circuit and physics. Players should *feel* like racers: the place looks like a weekend, you can show up as yourself (character + car), and the meeting changes dress each round.

What already exists to build on:

- Kart: 6 palettes at **Selecting** only (`KartPrototype`). Locked until next round. **v3 adds bodies/models**, same physics.
- Character: Roblox avatar as spawned. **No v3 editor.**
- Theme: `ThemeService` recolors the generated track and applies tagged decals; `nextRound()` already runs at lobby. **Classic** IDs are filled. Trackside banners are 168×30, each art ×3 around the lap; S/F gantry is 90 tall. Chevrons unplaced. Only Classic is in `TrackThemes.Order`.

Pillars:

1. **Track looks good** — dress the existing line (materials, large repeating banners, plaza, lighting). Do not design a new fantasy circuit.
2. **New kart bodies** — plaza, before green. Same `DriveSim`.
3. **Theme per round** — 2+ real themes so `Classic` is not the only look.

Detail: [v3/00-index.md](v3/00-index.md).

---

## After v3

- Extra *courses* / votes (new centerlines — not the same as a theme)
- More shop tiers (permanent 1.5× is a **no** unless cosmetic-only prestige)
- DataStore seasons / leaderboards
- Ghosts from v1 time trial
- Private servers / ranked
- Traitor-style items that grief the whole lobby
- 20-lap weekend

---

## Done when

**v2:** true — multi-racer 3-lap loop on Playtesters.

**v2 leftover:** Creator Hub listing uses `assets/storefront/`.

**v3:** a racer can tell the round’s theme, pick a **kart body** (not just a color), and the track reads as a dressed circuit rather than grey boxes. Avatar stays Roblox’s. Physics and 3-lap rules stay.
