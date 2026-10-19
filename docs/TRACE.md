# Commit trace

In-repo journal of what shipped and how it was play-checked. Newest first. Git commit messages stay 1–2 sentences of *why*; this file is the durable record.

When committing, add an entry below this intro **in the same commit**:

```markdown
## YYYY-MM-DD — commit subject
What: …
Play: Playtesters | other Studio | skipped (MCP down) — one-line evidence
```

---

## 2026-10-19 — Hop the kart, keep it on the circuit

What: Space hops the kart (~1.2× height) with gravity; bombs use a 10% Y slab; downhill boost no longer flies. Invisible 28-stud BarrierWall on the rails so hops cannot leave the circuit.

Play: Playtesters (`98798376352087`) — MiniRacerTrack rebuilt with 1689 BarrierWalls (H=28, T=1); boosted hop into a rail peaked ~7.9 studs, stayed on Road (maxSide −4.8, 0 grass).

## 2026-10-19 — Compact kart picker, plaza after race, extra stings

What: Half-size kart dock; podium despawns to plaza with shop open and 12s lobby wait. Extra Toolbox stings: BombDrop, BombHit swap, LastLap, BoostUse, second background bed.

Play: Playtesters (`98798376352087`) — Selecting cards 75×105 in a 520×124 dock with plaza/shop visible; after finish, on foot at plaza (298, 7, −257), no race kart, bought Bomb (220→210 cr).

## 2026-10-18 — Replace the Classic start gantry with a castle gatehouse

What: Classic S/F is a drive-through castle gatehouse (towers, keep, tapestries). Sponsor boards, extra finish boards, and barrier art use the same cream / purple / gold dress.

Play: Playtesters (`98798376352087`) — MiniRacerTrack rebuilt with 845 road planks, castle ThemeDecor, gold-framed boards; Play seated on grid and drove through the gate.

## 2026-10-18 — Dress Classic banners and keep Space from ejecting the racer

What: Classic theme IDs on the generated track; trackside boards 168×30, each sponsor ×3, tall S/F gantry. Space no longer jumps the racer out of the race kart (car stayed, no start teleport).

Play: Playtesters (`98798376352087`) — 18 boards at 168×30, gantry 91×90, MiniRacerCup/Bolt Boost art visible; Space ×3 during Racing still seated (`Sit` true, JumpPower 0, car at grid).

## 2026-10-18 — Ship plaza walking, 30° climbs, Q bombs, and race audio after Playtesters confirmed the loop

What: Plaza/grid/paddock loop; 30° curve climbs (peak 48); Landmine → Bomb at 10 cr / Booster 20 cr; lobby stipend 20; `MusicController` with the seven Toolbox ids; storefront images; v2.4 marked implemented.

Play: Playtesters (`98798376352087`) — track rebuilt (road Y ≈ 49); stalls 20/10; HUD credits 30; Q bomb drop + hit (Slowed, SPD 84, BombHit playing); BoostPickup and Lap stings loaded. Countdown/winner stings not captured that round (rebuild skipped lobby).
