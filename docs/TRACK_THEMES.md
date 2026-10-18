# Track themes

The server chooses one track theme for the whole match. A theme begins when the
next lobby opens, after the previous podium. The course, checkpoint positions,
and kart physics stay the same; only presentation changes. `MatchService`
includes `themeId` in `RaceStateChanged`, and Workspace carries the
`MiniRacerThemeId` attribute for other scripts.

## Add a theme

1. Add a theme record to `ReplicatedStorage/TrackThemes.luau` with a unique
   stable `Id`, display `Name`, `Colors`, `Images`, and six `Sponsors` entries.
2. Add its ID to `TrackThemes.Order`. The list cycles once per completed round.
   `Classic` is the only entry until another theme is ready.
3. Upload images to Roblox and put their `rbxassetid://...` values in the new
   record. Leave an image ID empty while its artwork is unavailable.

Keep theme IDs stable if player-facing UI or analytics begin using them.

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
`KartGrid`. Give any part that needs a theme color a `ThemeColorRole` string
attribute matching a `Colors` key. Existing road, grass, kerbs, barriers,
start/finish markers, and plaza pads are recolored by name. The generated
kerbs also carry `ThemeIndex` for alternating colors.

Theme image slots can be added after startup; the service applies the active
theme when the tag appears. Rebuilt track/plaza folders are also recolored.

## Classic artwork and first Studio test

The PNG sources are in `assets/track-themes/classic/`. Import them as images
through Studio's Asset Manager, then paste each returned `rbxassetid://...`
value into the matching `Classic` entry in `TrackThemes.luau`:

| Theme field | Source PNG | Asset ID |
| --- | --- | --- |
| `Images.Barrier` | `barrier-panel.png` | `rbxassetid://117460574970310` |
| `Images.StartLine` | `start-line.png` | `rbxassetid://73625917521760` |
| `Images.FinishBanner` | `finish-banner.png` | `rbxassetid://107126072271958` |
| `Images.ChevronLeft` | `chevron-left.png` | `rbxassetid://89191748334118` |
| `Images.ChevronRight` | `chevron-right.png` | `rbxassetid://111291036653365` |
| `Images.ChevronHairpin` | `chevron-hairpin.png` | `rbxassetid://99458837081193` |
| `Sponsors.MiniRacerCup` | `sponsor-mini-racer-cup.png` | `rbxassetid://126578249905531` |
| `Sponsors.KoalaRacing` | `sponsor-koala-racing.png` | `rbxassetid://135627531796174` |
| `Sponsors.BoltBoost` | `sponsor-bolt-boost.png` | `rbxassetid://114325621648969` |
| `Sponsors.TurboTires` | `sponsor-turbo-tires.png` | `rbxassetid://111188679120247` |
| `Sponsors.PlazaPitstop` | `sponsor-plaza-pitstop.png` | `rbxassetid://119457440551458` |
| `Sponsors.BombBox` | `sponsor-bomb-box.png` | `rbxassetid://105303519594270` |

The procedural track creates image slots on inward-facing barriers, the
start stripe, a tall S/F gantry, two extra finish boards, and each of the
six sponsor arts **three times** around the lap. Trackside boards are
**168 × 30** (6× longer, 3× taller than the first Classic test). The
gantry banner is **90** studs high. Chevrons still need corner placement.

Boards do not collide with cars. Until a second theme is added, Classic
art appears every round.
