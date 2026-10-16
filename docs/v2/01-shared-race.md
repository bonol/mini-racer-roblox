# v2.0 — Shared race

**Status:** implemented (solo Studio Play verified)  
**Depends on:** v1 time trial (done)  
**Unlocks:** v2.1 credits

## Playable outcome

Everyone in the server is in **one race**. They pick karts in the same 20s window, count down together, and the first to finish **20 laps** wins. HUD shows **lap** and **place**. Late joiners wait for the next round.

Solo Studio still works (one racer, still 20 laps).

## Why this is first

Credits, shop, and mines need a shared clock and a shared finish. Today `RaceService` is one session per player: picking a kart starts **that player’s** countdown, and checkpoint 4 ends the run.

## Match state machine

Replace per-player `Idle | Selecting | Countdown | Racing | Finished` as the source of truth.

```text
Lobby → Selecting → Countdown → Racing → Podium → Lobby
```

| State | What happens |
| --- | --- |
| `Lobby` | Waiting for racers. Character can exist; no personal countdown. |
| `Selecting` | Shared 20s. Everyone picks (UI + paddock). Early picks **wait**. Timeout → Azure. |
| `Countdown` | All racers spawned on **grid slots**. Frozen. Shared 3-2-1. |
| `Racing` | Drive enabled for everyone who is on the grid. |
| `Podium` | Winner + order frozen. Short hold, then back to `Lobby`. |

**Player flags** on the match: `enteredSelecting`, `paletteId`, `onGrid`, `lap`, `nextCheckpoint`, `place`, `finishedAt`.

Late join during `Racing` / `Countdown` / `Podium`: spectator until next `Lobby` → `Selecting`.

**R** during a race: do **not** restart the whole match. Ignore or “wait for next round”. Restart of the **match** only from `Podium` / `Lobby`.

## Lap rules

- Checkpoints still 1→2→3→4 in order.
- Passing checkpoint **4** (finish) increments `lap` and sets `nextCheckpoint = 1`, unless `lap` is already `LapCount`.
- Winner: first racer whose finish-line pass makes `lap == LapCount` (20).
- Others keep racing until they finish or `Podium` cutoff (e.g. 20s after winner, then DNF).
- Place sort: `lap` desc, then `nextCheckpoint` desc, then distance along current sector (optional in 2.0: lap + checkpoint is enough; add distance if ties look bad).

## Implementation steps

### 1. Constants

In `ReplicatedStorage/Constants.luau`:

```lua
Race.LapCount = 20
Race.MinPlayers = 1          -- Studio
Race.MaxPlayers = 8
Race.LobbyWaitSeconds = 8    -- after MinPlayers, then Selecting
Race.PodiumSeconds = 8
Race.DnfAfterWinnerSeconds = 20
```

Keep `SelectSeconds = 20`, `CountdownSeconds = 3`, `CheckpointCount = 4`.

### 2. New module `ServerScriptService/MatchService.luau`

Own the **one** match. `RaceService` becomes helpers (checkpoint pass, place sort) **or** is rewritten around this module — do not keep two competing state machines.

Suggested match table:

```lua
{
  state: "Lobby" | "Selecting" | "Countdown" | "Racing" | "Podium",
  gen: number,                 -- bump to cancel old timers
  startedAt: number?,
  winner: Player?,
  racers: { [Player]: {
    paletteId: string?,
    locked: boolean,
    lap: number,               -- laps completed (0 at green)
    nextCheckpoint: number,
    finishedAt: number?,
    onGrid: boolean,
  }}
}
```

Timers always check `gen` (same pattern as today’s `selectGen`).

### 3. Stop personal auto-start

`PlayerService`:

- `PlayerAdded` / `CharacterAdded` → `MatchService.addPlayer(player)` (Lobby or spectator).
- Remove `RaceService.start(player)` on every character spawn.
- `RequestRestart`: if `Podium` or `Lobby`, ok to stay; if racing, no private restart.

### 4. Shared select

- Enter `Selecting` for all current lobby players at once.
- `SelectKart` + paddock click sets `paletteId` + `locked`; does **not** call `beginCountdown`.
- When 20s ends (or everyone locked, optional): assign Azure to unlocked, go `Countdown`.

`KartSelect.luau`: copy still works; HUD must say “waiting for others” after you lock.

### 5. Grid spawn

`TrackService`:

- Add `TrackService.getGridCFrame(slotIndex: number, slotCount: number): CFrame`
- Layout: rows along the pit **behind** the yellow stripe, facing race direction (`LookVector` of spawn). Offset right/left so karts are side by side (road width 80 → ~3–4 per row).
- Tag slots `RaceGrid` if useful.

`VehicleService.spawnFor(player, paletteId, slotIndex)`:

- `PivotTo(getGridCFrame(slot, n))` instead of everyone on the same stripe.

### 6. Broadcast match state

Extend `RaceStateChanged` payload (or add `MatchStateChanged` fired to **all** clients):

```lua
{
  state, selectRemaining?, countdown?,
  lapCount = 20,
  racers = { { userId, name, lap, nextCheckpoint, place, paletteId } }
}
```

Keep per-player fields (`nextCheckpoint`, `lap`, `place`) so HUD stays simple.

### 7. HUD

`RaceHud.luau`:

- `Lap {n} / 20`
- `P{place}`
- Status: Lobby / Pick / countdown / Racing / `{name} wins`
- Drop “Time trial” and best-time as the primary goal (timer can stay as elapsed).

### 8. Camera

Selecting: keep paddock camera. Countdown/Racing: chase cam. Podium: optional freeze on winner; chase is fine for 2.0.

## Files to touch

| File | Change |
| --- | --- |
| `ReplicatedStorage/Constants.luau` | LapCount 20, lobby/podium tunables |
| `ReplicatedStorage/Remotes.luau` | Only if you add `MatchStateChanged`; otherwise overload `RaceStateChanged` |
| `ServerScriptService/MatchService.luau` | **New** |
| `ServerScriptService/RaceService.luau` | Checkpoint + finish against match racers; no personal countdown |
| `ServerScriptService/PlayerService.luau` | Join match, not `start(player)` |
| `ServerScriptService/VehicleService.luau` | Grid spawn |
| `ServerScriptService/TrackService.luau` | `getGridCFrame` |
| `ServerScriptService/Bootstrap.server.luau` | Start MatchService |
| `StarterPlayerScripts/RaceHud.luau` | Lap / place |
| `StarterPlayerScripts/KartSelect.luau` | Lock + wait; don’t assume countdown starts on click |

## Do not in 2.0

- Credits, shop, mines, pickups
- Walking plaza (still freeze-at-select is OK)
- DataStore
- Catch-up rubber band
- Rewriting `DriveSim`

## Test plan

1. Solo Play: 20s select → countdown → 20 laps still theoretically required (for Studio, temporarily set `LapCount = 2` if you don’t want to drive 20; **put 20 back** before calling the phase done, or add `Constants.Race.LapCount` override only in Studio via an attribute — prefer driving 2 laps in a Studio-only `if RunService:IsStudio()` **no**: keep one constant, test with `LapCount = 2` locally then restore 20, or test checkpoint wrap with 2 and trust 20. **Recommendation:** `LapCount = 20` in Constants; for the first playtest set it to **2**, confirm wrap, then set 20.
2. Two clients: both see the same countdown numbers. Neither starts driving early.
3. Player A locks Azure at t=3s; Player B waits; both spawn together.
4. Player A finishes 20 (or test-lap count); Player B still racing; then podium; both return to lobby/select.
5. Third player joins mid-race: no kart, waits, joins next select.
6. Checkpoint skip still ignored.
7. **R** mid-race does not give a new private time trial.

## Done when

Two Studio players share one green light, share one winner, and HUD place/lap match the server.
