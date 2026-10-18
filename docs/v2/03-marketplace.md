# v2.2 — Marketplace + loadout

**Status:** implemented (solo Playtesters; shop is Bomb 10 / Booster 20 — see ROADMAP Rules). Two-client still open. Historical catalog (still says Landmine 70).  
**Depends on:** [v2.1 credits](02-credits.md)  
**Unlocks:** v2.3 (using items on track; 2.2 can grant items but **using** them in race is 2.3 if you want a smaller bite — **this phase includes buy + hold + HUD**. Activation on track is 2.3.)

## Playable outcome

Next to the start/paddock, racers can **spend credits** on **Booster** and **Landmine** during `Lobby` / `Selecting` only. Inventory shows on HUD. At green they still cannot fire items yet (that is 2.3) **unless** you implement a no-op “use” that only logs — prefer **buy/hold only** here so 2.3 stays clean.

If 2.4 plaza is not built, a **temporary stall** at the paddock (infield offset from spawn, same pattern as `KartPaddock`) is enough.

## Catalog

| Id | Name | Cost | Effect (resolved in 2.3) |
| --- | --- | --- | --- |
| `Booster` | Booster | 80 | One activation: 1.5× speed |
| `Landmine` | Landmine | 70 | One drop: next kart 0.7× for 5s |

Booster is **not** a whole-race 1.5×.

## Implementation steps

### 1. Constants

```lua
Shop = {
  OpenStates = { Lobby = true, Selecting = true },
  Items = {
    { Id = "Booster", Name = "Booster", Cost = 80 },
    { Id = "Landmine", Name = "Landmine", Cost = 70 },
  },
}
```

### 2. `CreditService.trySpend(player, amount) -> boolean`

Atomic: if `get >= amount` then subtract and return true.

### 3. `ServerScriptService/InventoryService.luau` (new)

```lua
get(player) -> { Booster: number, Landmine: number }
add(player, itemId, n)
tryConsume(player, itemId) -> boolean   -- used in 2.3; can exist now
```

Clear **race-consumed** counts at podium if you want shop leftovers to carry; **carry unused items** across rounds (bought booster you didn’t use stays). Checkpoint pickups in 2.3 also go here.

### 4. `BuyItem` remote

Client: `{ itemId }`. Server:

1. Match state is `Lobby` or `Selecting`
2. Item exists
3. `trySpend(cost)`
4. `inventory.add(itemId, 1)`
5. Fire `InventoryChanged` + `CreditsChanged`

Reject during Countdown / Racing / Podium.

### 5. Physical stall (minimal)

`VehicleService` or a small `MarketService.build()`:

- Folder `Workspace.KartMarket`
- Two parts with `ClickDetector` + billboard (Booster 80, Landmine 70)
- Place with `origin * CFrame.new(-48, 0, 8)` or similar **infield**, not on the racing line
- Click → `BuyItem`

Optional UI list in `KartSelect` / a thin `ShopGui` for keyboard (1–2). Click in world is the product requirement.

### 6. HUD

Show `Booster xN  Landmine xN` and disable buy feedback if too poor (“need 80”).

### 7. Car select unchanged

Still 20s shared. Shop does not skip select. You can buy then pick, or pick then buy, until Selecting ends.

## Files to touch

| File | Change |
| --- | --- |
| `Constants.luau` | `Shop` |
| `Remotes.luau` | `BuyItem`, `InventoryChanged` |
| `CreditService.luau` | `trySpend` |
| `InventoryService.luau` | **New** |
| `MarketService.luau` or `VehicleService` | Stall parts + clicks |
| `MatchService.luau` | Gate buys by state |
| `RaceHud` / new `ShopGui` | Balances + counts |
| `Bootstrap.server.luau` | Build market |

## Do not in 2.2

- Activating booster or dropping mines (2.3)
- Checkpoint crates
- Permanent speed upgrades
- Walking plaza polish (2.4) — a stall in the grass is OK

## Test plan

1. Stipend 50: cannot buy Booster 80; can after a win (200) or two stipends.
2. Buy Landmine 70: credits 50→ wait, stipend 50 cannot buy 70 either until payout. After 1st (50+150=200): buy booster 80 → 120, inventory 1.
3. Spam click: one debit per item, never negative.
4. After countdown starts, click stall does nothing.
5. Unused booster still in inventory next round.
6. Two players: A’s buy does not add to B.

## Done when

Two players can each spend their own credits on stalls during select, see counts on HUD, and cannot shop after green.
