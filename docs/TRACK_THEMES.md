# Track themes

The server chooses one track theme for the whole match. A theme begins when the
next lobby opens, after the previous podium. The course, checkpoint positions,
and kart physics stay the same; only presentation changes — including
**surroundings** (lighting, ground material, world shell). `MatchService`
includes `themeId` in `RaceStateChanged`, and Workspace carries the
`MiniRacerThemeId` attribute for other scripts.

`TrackThemes.Order` is `{ Classic, SciFi }`. Classic is a castle village in daylight; SciFi
is a neon hangar. The list cycles once per completed round.

## Add a theme

1. Add a theme record to `ReplicatedStorage/TrackThemes.luau` with a unique
   stable `Id`, display `Name`, `Colors`, `Materials`, `Images`, six
   `Sponsors`, `Lighting`, optional `Sky`, and `World`.
2. Add its ID to `TrackThemes.Order`.
3. Upload images to Roblox and put their `rbxassetid://...` values in the new
   record. Leave an image ID empty while its artwork is unavailable. Empty
   `Sky` faces keep procedural fog/atmosphere (no custom skybox).

Keep theme IDs stable if player-facing UI or analytics begin using them.

## Colors, materials, and the Grass name

Give any part that needs a theme color a `ThemeColorRole` string attribute
matching a `Colors` key. Existing road, grass, kerbs, barriers, start/finish
markers, and plaza pads are recolored **and rematerialed** by name.

**Invariant:** off-track tiles stay named `Grass`. DriveSim and bombs only
treat `Road` and `Grass` as ground. Change `Colors.Grass` and
`Materials.Grass` (green grounds, diamond-plate deck, …) — do not rename
the parts.

`ThemeService.apply` also writes `Lighting` (`ClockTime`, brightness, ambient,
fog) and an `Atmosphere` / `Sky`. World-shell parts are named `WorldShell`
(not `Barrier`) so DriveSim ignores them. They do not collide.

## World shell and gates

`World.Gate` is `Castle` or `Portal`. `ThemeService.apply` calls
`TrackService.applyThemeWorld`, which rebuilds `ThemeDecor` (gate + boards)
and `ThemeWorld` (curtain strips on `offsetLoop` at `half + ShellOffset`,
height `ShellHeight`) without destroying the road or `BarrierWall`.

No roof over the circuit (chase camera). Horizon is curtain + sky.

## Image slots for track decoration

An image-bearing `Decal`, `Texture`, or `ImageLabel` becomes theme controlled
when it has the CollectionService tag `MiniRacerThemeImage` and a string
attribute `ThemeImageSlot`. Supported slot values are `Barrier`, `StartLine`,
`FinishBanner`, `ChevronLeft`, `ChevronRight`, `ChevronHairpin`, and `Sponsor`.
For `Sponsor`, also set the string attribute `SponsorId` to one of
`MiniRacerCup`, `KoalaRacing`, `BoltBoost`, `TurboTires`, `PlazaPitstop`, or
`BombBox`. These IDs give each brand a fixed placement while allowing its
artwork to change with the theme.
The theme service sets the image and hides the slot when its asset ID is empty.

Place banner faces and other decoration in `MiniRacerTrack`, `KartPlaza`, or
`KartGrid`. Theme image slots can be added after startup; the service applies
the active theme when the tag appears.

## Classic artwork

The PNG sources are in `assets/track-themes/classic/`. Import them as images
through Studio's Asset Manager, then paste each returned `rbxassetid://...`
value into the matching `Classic` entry in `TrackThemes.luau`:

| Theme field | Source PNG | Asset ID |
| --- | --- | --- |
| `Images.Barrier` | `barrier-panel.png` | `rbxassetid://118110440386002` |
| `Images.StartLine` | `start-line.png` | `rbxassetid://73625917521760` |
| `Images.FinishBanner` | `finish-banner.png` | `rbxassetid://122615315404933` |
| `Images.ChevronLeft` | `chevron-left.png` | `rbxassetid://89191748334118` |
| `Images.ChevronRight` | `chevron-right.png` | `rbxassetid://111291036653365` |
| `Images.ChevronHairpin` | `chevron-hairpin.png` | `rbxassetid://99458837081193` |
| `Sponsors.MiniRacerCup` | `sponsor-mini-racer-cup.png` | `rbxassetid://140695092815748` |
| `Sponsors.KoalaRacing` | `sponsor-koala-racing.png` | `rbxassetid://85395568055054` |
| `Sponsors.BoltBoost` | `sponsor-bolt-boost.png` | `rbxassetid://79798610330221` |
| `Sponsors.TurboTires` | `sponsor-turbo-tires.png` | `rbxassetid://104021789006578` |
| `Sponsors.PlazaPitstop` | `sponsor-plaza-pitstop.png` | `rbxassetid://76845063427534` |
| `Sponsors.BombBox` | `sponsor-bomb-box.png` | `rbxassetid://140586940348473` |

Classic S/F is the castle gatehouse (clearance **32**). SciFi S/F is a neon
portal with the same clearance. Trackside boards are **168 × 30**, each
sponsor ×3 around the lap. Chevrons still need corner placement. Boards do
not collide with cars. SciFi barrier/finish/chevron image slots are empty
until those assets exist; lighting and the hangar shell still sell the world.
