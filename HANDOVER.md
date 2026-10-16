# Mini Racer — handover

Continue this work in **Cursor Desktop (the app)**, not Cursor CLI. The Desktop Agent chat already has **Roblox Studio MCP**. The CLI agent in the previous session did **not**.

Project path: `/Users/bonoliu/Projects/mini-racer-roblox`

---

## Goal

v1 is a **single-player time trial** on Roblox: sit in a Mini Racer, countdown, drive an oval, hit 4 checkpoints in order, finish, see time, press **R** to restart.

The place is meant to be edited in **Roblox Studio**, with Luau files on disk via **Script Sync**, and the Cursor app agent driving Studio via **MCP**.

---

## What exists today

### On disk (this repo)

Luau was written to the Mac folder only. **Studio was never updated through MCP** from the CLI session. If Explorer looks empty, Script Sync has not imported these files yet.

```text
mini-racer-roblox/
  HANDOVER.md                 ← this file
  .gitignore                  ← ignores *.lock
  MiniRacer.rbxlx.rbxl        ← local place file (Studio)
  MiniRacer.rbxlx.rbxl.lock
  ServerScriptService/
    Bootstrap.server.luau     ← server entry (do not rename to init.server.luau)
    TrackService.luau         ← builds oval + checkpoints at Play if missing
    VehicleService.luau       ← procedural red kart + drive loop
    RaceService.luau          ← countdown, checkpoints, finish, best time
    PlayerService.luau        ← join / character / R to restart
  ReplicatedStorage/
    Constants.luau
    Remotes.luau              ← creates RemoteEvents at runtime
  StarterPlayerScripts/
    Bootstrap.client.luau     ← client entry (do not rename to init.client.luau)
    RaceHud.luau
    CameraController.luau
```

Not a git repo yet.

### In Studio (last known)

- Place name **Place1**, default Baseplate (Camera, Terrain, Baseplate, SpawnLocation).
- MCP from **Cursor Desktop** successfully listed Workspace once.
- Script Sync: **Sync to…** was used on ServerScriptService → this folder. ReplicatedStorage and StarterPlayerScripts may **not** be synced yet.
- Studio MCP: enabled, Quick connect **Cursor** on. CLI never received `Roblox_Studio` tools.

### What you will not see until Play + scripts are in Explorer

The oval, rails, checkpoints, and car are **created in Luau at runtime** (`TrackService.buildIfNeeded`, `VehicleService.spawnFor`). Edit mode Workspace stays a Baseplate until `Bootstrap.server` runs.

---

## First actions in Cursor Desktop

1. Open this folder in the **Cursor app**.
2. Open **Roblox Studio** with `MiniRacer.rbxlx.rbxl` (or the saved place). Keep it open.
3. Confirm MCP: Assistant → **Manage MCP Servers** → green **clients connected**. In Cursor Agent, ask: *list Studio instances and Workspace*.
4. **Script Sync** each service to the **project parent** (`mini-racer-roblox`), not an inner folder:
   - ServerScriptService
   - ReplicatedStorage
   - StarterPlayer → **StarterPlayerScripts**
   - If a conflict dialog appears, choose **Keep Disk** so the Luau files win.
5. Explorer should then show `Bootstrap`, `RaceService`, `Constants`, etc.
6. **Play**. Expect: yellow spawn pad, oval rails, red car, 3-2-1-GO, HUD timer.

If scripts appear nested (`ServerScriptService.ServerScriptService`), SSS was synced to the repo root as the service itself. Stop sync, then Sync to the parent so folder names match services.

---

## How the pieces connect

```text
Bootstrap.server
  Remotes.ensure()           → ReplicatedStorage.Remotes (RemoteEvents)
  TrackService.buildIfNeeded → Workspace.MiniRacerTrack (if absent)
  RaceService.bindCheckpoints
  PlayerService.start        → CharacterAdded → RaceService.start

RaceService.start
  spawn car, freeze until GO
  Racing: checkpoints 1→2→3→4 (finish)
  Finished: best time in memory (no DataStore)

Bootstrap.client
  RaceHud + chase camera
  R → RequestRestart
```

CollectionService tags: `Checkpoint` (attribute `Index` 1–4), `RaceSpawn`.

Remotes: `RaceStateChanged`, `CheckpointPassed`, `RaceFinished`, `RequestRestart`. Script Sync cannot store RemoteEvents; they are created in `Remotes.ensure()`.

Drive model: `VehicleSeat` for input; server Heartbeat applies velocity (hinge wheels are visual only). Driving is disabled during countdown and after finish.

Do **not** add `init.server.luau` / `init.client.luau` at a synced service root. Script Sync would try to turn the whole service into a script. Use `Bootstrap.*.luau`.

---

## v1 rules (already in Constants)

| Setting | Value |
| --- | --- |
| Laps | 1 |
| Countdown | 3 seconds |
| Checkpoints | 4 (last is finish) |
| Max speed | 72 |
| Restart | R |

Best time is per session only.

---

## Why CLI playtest failed

Cursor Studio Quick Connect targets **Cursor Desktop**. The CLI agent’s MCP servers were Ref, Buildkite, Context7, CS Portal, Maestro, Gmail, Calendar, Postgres — **not** `Roblox_Studio`.

Keep Studio work in the Desktop Agent. This repo is still the source of the `.luau` files.

---

## Suggested next work (Desktop + MCP)

1. Confirm Script Sync + Play; fix Output errors if any.
2. Tune car feel and track (or replace procedural track with Studio models + same tags).
3. Disable/hide default Baseplate SpawnLocation if the character pops in the wrong place.
4. Optional: freeze camera until seated; ghost best-time ghost later.
5. DataStore for best times — out of v1.
6. Multiplayer lobby — out of v1.
7. `git init` when you want version control (place `.rbxl` is large; lock files already gitignored).

Useful Desktop prompts:

- *Use Roblox MCP: list scripts under ServerScriptService, ReplicatedStorage, StarterPlayerScripts.*
- *Start playtest, wait 8s, get console output and a screenshot.*
- *If Bootstrap is missing in Explorer, tell me which services are Script Synced.*

---

## File roles (quick)

| File | Role |
| --- | --- |
| `Bootstrap.server.luau` | Server boot |
| `TrackService.luau` | Oval + tagged checkpoints/spawn |
| `VehicleService.luau` | Kart + throttle/steer |
| `RaceService.luau` | Time trial state machine |
| `PlayerService.luau` | Lifecycle + restart remote |
| `Constants.luau` | Tunables |
| `Remotes.luau` | Remote folder helper |
| `Bootstrap.client.luau` | Client boot |
| `RaceHud.luau` | Timer / countdown / R |
| `CameraController.luau` | Chase cam while seated |
