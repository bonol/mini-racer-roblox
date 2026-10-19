# Product decisions

Chronological *why* for product calls. Newest first.

**Current law** lives in [ROADMAP.md](ROADMAP.md) Rules and must match `ReplicatedStorage/Constants.luau`. This file is the history. [`docs/v2/`](v2/) phase docs are historical checklists — do not rewrite them for a tunable change.

When a product decision is made, add an entry below this intro:

```markdown
## YYYY-MM-DD — short title
Decided: …
Why: …
Supersedes: … (or none)
```

---

## 2026-10-19 — Hop is two karts tall

Decided: `Car.JumpHeightFrac = 2.4` (peak ≈ **7.7 studs**, ~0.60s hang). Bomb slab stays **10%** of kart height. Chase cam follows only **35%** of hop lift so the kart pops in frame while racing. Same gravity; boost/slow still scale takeoff by `√mul`. Invisible `BarrierWall` (28) still contains a boosted hop.

Why: The 1.2× hop still read as a twitch on the racing chase cam. Testers asked for at least 2× more obvious, especially during a race.

Supersedes: 2026-10-19 Hop is about one kart tall

## 2026-10-19 — Classic lobby is a castle village in daylight

Decided: Classic lobby is a **clear afternoon village square**, not a dusk limestone lot. Grass is green; plaza pads are cobble; castle roofs are terracotta. Kart pads stay open. Around them: a keep backdrop, cottages, round trees, white picket fences, flowers, and lamp posts. Lighting is even (lower brightness, cool sky, exposure −0.35) so the shop cubes do not blow out.

Why: Testers found the lobby too bright and not grand enough; the bar is Mario Kart Wii Mario Circuit density (castle + town + trees + fences), not a few props on the pads.

Supersedes: 2026-10-19 SciFi is a lit night; Classic courtyard is dressed (Classic plaza props + dusk limestone only)

## 2026-10-19 — SciFi is a lit night; Classic courtyard is dressed

Decided: SciFi stays night/neon but is **readable** (higher ambient, cyan/magenta PointLights on the portal, shell, and plaza). Classic keeps courtyard stone and adds set dressing: torches, merlons, tapestries, plaza fountain/benches/planters.

Why: Testers found SciFi too dark; the castle stone read empty without props.

Supersedes: SciFi lighting was pitch-dark fog with no practical lights

## 2026-10-19 — Theme owns the surroundings

Decided: A theme includes lighting, ground material, and a non-collide world shell — not only rail/plaza colors and banners. v3 rotation is **Classic** (castle grounds: courtyard limestone, dusk fog, curtain walls, existing castle gate) and **SciFi** (metal deck, night/neon, hangar shell, portal gate). Same centerline and `DriveSim`. Off-track tiles keep the instance name `Grass`. No roof over the circuit.

Why: The dressed rails still sat on default blue sky and flat green grass, so the castle gate read as a facade on a field.

Supersedes: theme dress was colors + tagged images only; `TrackThemes.Order` was Classic-only

## 2026-10-19 — Invisible wall on the rails

Decided: Visual rails stay `BarrierHeight = 6`. An invisible `BarrierWall` on the same line is `BarrierWallHeight = 28`. DriveSim treats both as walls; hops cannot leave the circuit.

Why: A 1.2× kart hop peaks above the 6-stud rail. Testers could jump onto the grass.

Supersedes: none

## 2026-10-19 — Hop is about one kart tall

Decided: `Car.JumpHeightFrac = 1.2` (peak ≈ **3.8 studs**, ~0.43s hang). Bomb slab stays **10%** of kart height. Same gravity; boost/slow still scale takeoff by `√mul`.

Why: The 25% hop was a twitch on camera. One-kart-tall is obvious and still clears the 10% slab with timing.

Supersedes: 2026-10-19 Space hops the kart (peak 25% only)

## 2026-10-19 — Space hops the kart; bombs have height

Decided: Space jumps the **kart** (humanoid stays seated; still no eject). Kart envelope `Car.Height = 3.2`. A normal hop peaks at **25%** of that height. Bomb hit is XZ radius **7** and a vertical slab **10%** of kart height above the road under the kart — grounded karts still hit; a timed hop clears. Jump uses DriveSim gravity (`vy = √(2gh)`). Air travel follows physics: boost/slow at takeoff scales hop height by `√mul`; horizontal speed sets distance; downhill/uphill change hang because the road falls away or rises; air steer is `0.35×`. Slow in the air keeps the current `vy` and cuts XZ speed.

Why: Testers wanted to hop bombs. A 10% slab vs a 25% hop leaves a timing window without launching off the 30° grades.

Supersedes: Space only blocked as seat-eject; bomb hit was XZ-only

## 2026-10-19 — Compact kart picker; plaza after race

Decided: Kart-select cards are **half size** (75×105) in a compact bottom dock so the plaza stays visible. After a race, `enterPodium` despawns grid karts and teleports everyone to the plaza immediately. Shop is open in **Podium / Lobby / Selecting**. `LobbyWaitSeconds = 12` (was 8).

Why: The picker covered the paddock and shop; racers stayed on the circuit through the podium, so they had no time to spend credits before the next grid.

Supersedes: Shop only open in Lobby / Selecting; LobbyWaitSeconds 8

## 2026-10-19 — Bomb hit sting

Decided: Being slowed by a Bomb plays `Constants.Audio.BombHit` = `rbxassetid://133988811001179`. Drop and pickup stings are unchanged.

Why: The previous hit clip was the wrong cue.

Supersedes: 2026-10-18 Keep the seven Toolbox audio IDs (BombHit id only)

## 2026-10-19 — Last lap, boost use, second bed

Decided: Passing S/F to **start the last lap** (server `lap` becomes `LapCount - 1`) plays `LastLap` = `rbxassetid://6370343522`. Using a Booster (E) plays `BoostUse` = `rbxassetid://120495627817675`. Background is a **two-track bed**: existing `Background` plus `Background2` = `rbxassetid://133431699431690`; each round restart (MusicController start, and each return to `Lobby`) picks one at random and keeps it through that round. Intermediate lap crosses still use `Lap`; finish still uses `Winner`.

Why: Last-lap and boost needed their own cues; a second bed so lobby/race music is not the same every round.

Supersedes: 2026-10-18 Bomb drop sting (count only — those ids stay)

## 2026-10-18 — Bomb drop sting

Decided: Dropping a Bomb (UseItem Q, after the server consumes it) plays `Constants.Audio.BombDrop` = `rbxassetid://79335982953739`. Pickup and hit keep their existing stings. This is an eighth Toolbox id, not a swap of the previous seven.

Why: Racers needed a distinct drop cue; pickup and hit already had sounds.

Supersedes: 2026-10-18 Keep the seven Toolbox audio IDs (count only — those seven stay)

## 2026-10-18 — Start castle is a full gatehouse

Decided: The S/F castle is a **deep gatehouse**, not two posts. Four round towers, wing turrets and curtain walls, a keep with a central spire and gold clock, conical purple roofs, merlons, gold bands. Drive-through clearance stays **32**. Same circuit.

Why: The first castle gate read as a thin doorway. Testers asked for more detail and a bigger starting-line castle.

Supersedes: 2026-10-18 Classic dress is a castle gate, not a billboard (two square towers + a slab)

## 2026-10-18 — Classic dress is a castle gate, not a billboard

Decided: The start/finish is a **3D castle gate** the kart drives through (stone towers, purple roofs, merlons, gold portcullis, clearance 32). Finish art is a tapestry on the gatehouse, not a solid 90-stud poster. All six sponsor boards, the two extra finish boards, and barrier chevrons use the same cream / purple / gold castle palette. `SponsorFrame` is gold. Kerbs stay red/white so the racing line still reads. Ground checker `StartLine` is unchanged. Still Classic dress on the same circuit — not a new course.

Why: Testers wanted to feel like they were driving into a castle, and the rest of the boards still looked like a blue race meeting.

Supersedes: 2026-10-18 Classic S/F banner is castle palette (flat gantry + racing-blue sponsors)

## 2026-10-18 — Classic S/F banner is castle palette

Decided: The start/finish gantry (and its two trackside copies) uses original castle-themed art: cream stone, purple roofs, gold trim, purple/cream checkers, **MINI RACER START/FINISH**. Gantry posts (`Arch`) are gold `210, 162, 58`. The ground checker `StartLine` is unchanged. This is still Classic dress, not a second theme or a new circuit.

Why: The starting-line banner should read castle, not racing-blue flags, while the racing line stays the same.

Supersedes: Classic `finish-banner.png` racing-blue chevron art; `Arch` racing blue

## 2026-10-18 — Classic banners 3× taller, 6× longer, three times around the lap

Decided: Trackside boards are **168 × 30** (was 28 × 10). Each of the six sponsor arts appears **3** times around the circuit. Finish/start art appears **3** times: one taller S/F gantry (banner height 90) plus two trackside copies. Same PNGs; chevrons still unplaced.

Why: The first Classic boards read as small signs. Testers asked for bigger banners repeated along the lap, not a new circuit.

Supersedes: one small board per sponsor in `TrackService.buildThemeDecor`

## 2026-10-18 — v3 identity: Roblox avatar as-is; new kart bodies, same physics

Decided: In v3, **do not** ship an in-experience character editor. The racer is whatever Roblox already spawned. **Do** add new kart **bodies / models**; they still use the same `DriveSim` (no new handling per body). Palettes can stay as paint on a body.

Why: “Change character and car” was about showing up in a car that looks like a choice. Avatar customization is Roblox’s job; extra physics per body would rewrite the kart.

Supersedes: v3 pillar “change character and car” as two equal workstreams — character is out of v3 scope

## 2026-10-18 — v3 is racer experience; 3 laps stays; listing still open

Decided:

- Multi-racer play is accepted (two-client is no longer an open v2 blocker).
- `LapCount = 3` is current product. 20 laps is deferred; not this version.
- Creator Hub storefront upload stays **ongoing** (files in `assets/storefront/`, listing still blank).
- Next version is **v3 — racer experience**: track should look good, players can change character and car in-game, track theme can change per round.
- Old “Later” items (DataStore, ranked, ghosts, extra *courses*, private servers) stay **after v3**, not dumped into racer-experience.

Why: v2 gameplay loop is playable with multiple racers at 3 laps. The next gap testers feel is identity and presentation, not a longer race or persistence.

Supersedes: ROADMAP Status todos for two-client and “flip to 20 laps”; 20-lap north-star as this-version work

## 2026-10-18 — v2.0–2.4 accepted as shipped (solo)

Decided: The v2 phase map (shared race, credits, shop, pickups, plaza/track) is **implemented** and solo Playtesters-verified. That is not the closed north star.

Still open (not “Later”):

- Two-client Studio Start Server (shared countdown, bomb-on-other, HUD place)
- `LapCount` stays **3** until we choose to flip to **20**
- Place sort is lap, then checkpoint (sector distance was optional in v2.0 and is not built)

`docs/Later` stays later: extra tracks, DataStore, ranked, ghosts.

Why: ROADMAP and `docs/v2/00-index.md` still described v1 (LapCount 1, lobby not started). Testers thought the product map was finished; the build is, the north-star checklist is not.

Supersedes: ROADMAP v1 review claiming multiplayer lobby not started; 00-index “Current code (v1)”

## 2026-10-18 — Keep the seven Toolbox audio IDs

Decided: Background `104976378455015`, Countdown `133467521581745`, Lap `82669582574373`, BoostPickup `122016420402975`, BombPickup `93170321014352`, BombHit `89479472135872`, Winner `120657237573902`. Do not replace with generic APM/ProSound packs. Play-verify on Playtesters; PlaceId 0 (`.rbxlx`) 401s these clips.

Why: Licensed stand-ins played, but they were not the clips we already used. Creating bomb Sounds with a bad id previously aborted `MusicController.start()` so countdown/boost never bound.

Supersedes: none

## 2026-10-18 — Verify on Playtesters, not the local rbxlx

Decided: Gameplay and audio checks run in **Mini Racer [testing]**, PlaceId `98798376352087` (UniverseId `10771404739`). Do not treat `MiniRacer.rbxlx.rbxl` (PlaceId 0) as the playtest place. Do not rewrite the kart / `DriveSim` controller.

Why: Private Toolbox audio is not trusted on PlaceId 0. The cloud place is the one testers join.

Supersedes: none

## 2026-10-18 — 30° curve climbs, peak 48

Decided: `ClimbDegrees = 30`, `ClimbPeakMax = 48`, `ClimbMinMul = 0.25`. `TrackService.applyCurveClimbs` raises marked corners; `DriveSim` drops speed on grade (`1 - sin(climbPitch)`). After TrackService changes, destroy `Workspace.MiniRacerTrack` so the circuit rebuilds.

Why: Flat whoops were not enough; testers asked for two visible climbs without rewriting the racing-line silhouette.

Supersedes: none

## 2026-10-18 — Testing lap count is 3

Decided: `Constants.Race.LapCount = 3` while we iterate. North star remains **20 laps** (ROADMAP).

Why: 20-lap solo Playtesters loops are too long to confirm shop, bombs, audio, and climbs in one session.

Supersedes: none (north star unchanged)

## 2026-10-18 — Lobby stipend 20, start 10, finish 20

Decided: `StartingBalance = 10`, `Stipend = 20` once per round (Lobby, and Selecting if they join then — do not double-pay), `FinishBonus = 20`. Payout still `{ 150, 90, 50 }` for grid finishers.

Why: Shop at 10/20 needs a wallet that can buy a bomb in the first lobby without a 50-credit dump.

Supersedes: stipend-on-Selecting-only wording in older ROADMAP / v2.1 notes

## 2026-10-18 — Bomb 10, Booster 20; Q drop; no owner immunity

Decided: Shop item id `Bomb` (not Landmine), cost **10**; Booster cost **20**. Q drops a neon bomb; anyone within 7 studs is slowed **0.7× for 3s**, including the dropper. Slow wins over boost. Pickups randomly Booster or Bomb.

Why: Landmine + owner immunity + 70/80 prices blocked first-round buys and made Q feel like a trap for yourself. Testers confirmed 10/20 + bomb-hit slow on Playtesters.

Supersedes: Landmine 70 / Booster 80 / 5s slow / owner arming immunity in ROADMAP and v2.2–v2.3 catalogs
