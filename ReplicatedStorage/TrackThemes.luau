-- Add a theme here to make it available in the round rotation. Sponsor IDs
-- stay stable across themes; their artwork can change with each theme.
local TrackThemes = {}

export type Theme = {
	Id: string,
	Name: string,
	Colors: { [string]: Color3 },
	Images: { [string]: string },
	Sponsors: { [string]: string },
}

local classic: Theme = {
	Id = "Classic",
	Name = "Mini Racer Classic",
	Colors = {
		Grass = Color3.fromRGB(46, 112, 52),
		Road = Color3.fromRGB(36, 38, 42),
		KerbA = Color3.fromRGB(200, 40, 40),
		KerbB = Color3.fromRGB(230, 230, 230),
		Barrier = Color3.fromRGB(214, 190, 148),
		StartSpawn = Color3.fromRGB(255, 220, 70),
		Finish = Color3.fromRGB(240, 240, 240),
		Checkpoint = Color3.fromRGB(80, 200, 120),
		PlazaFloor = Color3.fromRGB(52, 56, 64),
		PaddockPad = Color3.fromRGB(38, 42, 50),
		MarketPad = Color3.fromRGB(64, 48, 36),
		PlazaCurb = Color3.fromRGB(210, 210, 216),
		Arch = Color3.fromRGB(210, 162, 58),
		SponsorFrame = Color3.fromRGB(210, 162, 58),
		CastleStone = Color3.fromRGB(214, 190, 148),
		CastleStoneDark = Color3.fromRGB(156, 134, 106),
		CastleRoof = Color3.fromRGB(118, 52, 138),
		CastleWindow = Color3.fromRGB(48, 36, 72),
	},
	Images = {
		Barrier = "rbxassetid://118110440386002",
		StartLine = "rbxassetid://73625917521760",
		FinishBanner = "rbxassetid://122615315404933",
		ChevronLeft = "rbxassetid://89191748334118",
		ChevronRight = "rbxassetid://111291036653365",
		ChevronHairpin = "rbxassetid://99458837081193",
	},
	Sponsors = {
		MiniRacerCup = "rbxassetid://140695092815748",
		KoalaRacing = "rbxassetid://85395568055054",
		BoltBoost = "rbxassetid://79798610330221",
		TurboTires = "rbxassetid://104021789006578",
		PlazaPitstop = "rbxassetid://76845063427534",
		BombBox = "rbxassetid://140586940348473",
	},
}

TrackThemes.Order = { classic.Id }
TrackThemes.ById = { [classic.Id] = classic }

function TrackThemes.get(id: string): Theme
	return TrackThemes.ById[id] or classic
end

return TrackThemes
