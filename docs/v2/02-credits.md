# v2.1 — Credits

**Status:** implemented (solo Studio Play verified; two-client Start Server still a manual check)  
**Depends on:** [v2.0 shared race](01-shared-race.md)  
**Unlocks:** v2.2 marketplace

## Playable outcome

Each round every racer gets a **stipend**. At podium, **top 3** get extra credits. Balance shows on the HUD. Wallets persist for the **server session** (quit = lose credits). No shop yet.

## Why this is second

The shop must debit a real wallet. Payout needs a finished match order from 2.0.

## Economy (starting, put in Constants)

| Event | Credits |
| --- | --- |
| Round stipend | 50 |
| 1st | 150 |
| 2nd | 90 |
| 3rd | 50 |

Rules from the roadmap:

- Stipend once per round per player when **Selecting** starts (including players who then DNF).
- Payout only if they **started Countdown** (`onGrid`).
- Wallet never goes negative (clamp in 2.2; 2.1 only adds).
- Credits carry across rounds in the same server.

## Implementation steps

### 1. Constants

```lua
Credits = {
  Stipend = 50,
  Payout = { 150, 90, 50 },
}
```

### 2. `ServerScriptService/CreditService.luau` (new)

```lua
get(player) -> number
add(player, amount, reason)  -- amount > 0
-- trySpend is v2.2
```

Store `{ [Player]: number }`. `PlayerRemoving` drops the entry (session-only).

Do **not** use DataStore in 2.1.

### 3. Grant stipend

`MatchService` entering `Selecting`: for each racer in this round, `CreditService.add(player, Stipend, "stipend")`. Use match `gen` so a double-enter cannot double-pay.

### 4. Payout on podium

When match enters `Podium`, sort finishers by `finishedAt` (winner first), then DNFs after. Pay `Payout[1..3]` to the first three **onGrid** players who have a finish time; if fewer than 3 finishers, pay who finished.

If only one racer, they get 1st.

Fire a payload `{ credits, delta, reason }` so the HUD can flash “+50 stipend” / “+150 1st”.

### 5. HUD

`RaceHud`: credit balance visible in Lobby / Selecting / Podium (and racing, small). Update from match state or a `CreditsChanged` remote.

### 6. Remote

Add `CreditsChanged` in `Remotes.luau` **or** fold `credits` into `RaceStateChanged`. Prefer a dedicated remote so shop (2.2) can listen without parsing the whole match.

## Files to touch

| File | Change |
| --- | --- |
| `ReplicatedStorage/Constants.luau` | `Credits` table |
| `ReplicatedStorage/Remotes.luau` | `CreditsChanged` |
| `ServerScriptService/CreditService.luau` | **New** |
| `ServerScriptService/MatchService.luau` | Stipend on Selecting; payout on Podium |
| `ServerScriptService/Bootstrap.server.luau` | Require/start if needed |
| `StarterPlayerScripts/RaceHud.luau` | Balance + toast |

## Do not in 2.1

- Shop, inventory, boost, mines
- DataStore
- Spending UI
- Paying spectators who never entered Selecting

## Test plan

1. Solo: Selecting shows +50; win podium shows +150; total 200; next Selecting +50 → 250.
2. Two players: both stipend 50; winner +150, second +90.
3. Third joins mid-race: no stipend until next Selecting.
4. Rejoin (leave and come back): wallet 0 (session-only).
5. Cannot get stipend twice in one Selecting (spam CharacterAdded).

## Done when

HUD numbers match server after stipend and after a 2-player podium, and a second round keeps the running total.
