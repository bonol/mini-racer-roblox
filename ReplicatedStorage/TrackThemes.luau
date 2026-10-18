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
		Barrier = Color3.fromRGB(196, 200, 210),
		StartSpawn = Color3.fromRGB(255, 220, 70),
		Finish = Color3.fromRGB(240, 240, 240),
		Checkpoint = Color3.fromRGB(80, 200, 120),
		PlazaFloor = Color3.fromRGB(52, 56, 64),
		PaddockPad = Color3.fromRGB(38, 42, 50),
		MarketPad = Color3.fromRGB(64, 48, 36),
		PlazaCurb = Color3.fromRGB(210, 210, 216),
		Arch = Color3.fromRGB(36, 98, 222),
		SponsorFrame = Color3.fromRGB(36, 98, 222),
	},
	Images = {
		Barrier = "rbxassetid://117460574970310",
		StartLine = "rbxassetid://73625917521760",
		FinishBanner = "rbxassetid://107126072271958",
		ChevronLeft = "rbxassetid://89191748334118",
		ChevronRight = "rbxassetid://111291036653365",
		ChevronHairpin = "rbxassetid://99458837081193",
	},
	Sponsors = {
		MiniRacerCup = "rbxassetid://126578249905531",
		KoalaRacing = "rbxassetid://135627531796174",
		BoltBoost = "rbxassetid://114325621648969",
		TurboTires = "rbxassetid://111188679120247",
		PlazaPitstop = "rbxassetid://119457440551458",
		BombBox = "rbxassetid://105303519594270",
	},
}

TrackThemes.Order = { classic.Id }
TrackThemes.ById = { [classic.Id] = classic }

function TrackThemes.get(id: string): Theme
	return TrackThemes.ById[id] or classic
end

return TrackThemes
