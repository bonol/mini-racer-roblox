-- Add a theme here to make it available in the round rotation. Sponsor IDs
-- stay stable across themes; their artwork can change with each theme.
-- Surroundings (materials, lighting, sky, world shell) are part of the theme.
-- Off-track tiles keep the instance name "Grass" so DriveSim / bombs still see ground.
local TrackThemes = {}

export type AtmosphereSpec = {
	Density: number,
	Offset: number?,
	Color: Color3,
	Decay: Color3,
	Haze: number,
	Glare: number,
}

export type LightingSpec = {
	ClockTime: number,
	Brightness: number,
	Ambient: Color3,
	OutdoorAmbient: Color3,
	FogColor: Color3,
	FogStart: number,
	FogEnd: number,
	EnvironmentDiffuseScale: number?,
	EnvironmentSpecularScale: number?,
	ExposureCompensation: number?,
	Atmosphere: AtmosphereSpec?,
}

export type SkySpec = {
	Bk: string,
	Dn: string,
	Ft: string,
	Lf: string,
	Rt: string,
	Up: string,
}

export type WorldSpec = {
	Gate: "Castle" | "Portal",
	ShellHeight: number,
	ShellOffset: number,
	ShellRole: string,
}

export type Theme = {
	Id: string,
	Name: string,
	Colors: { [string]: Color3 },
	Materials: { [string]: Enum.Material },
	Images: { [string]: string },
	Sponsors: { [string]: string },
	Lighting: LightingSpec,
	Sky: SkySpec?,
	World: WorldSpec,
}

local CLASSIC_SPONSORS = {
	MiniRacerCup = "rbxassetid://140695092815748",
	KoalaRacing = "rbxassetid://85395568055054",
	BoltBoost = "rbxassetid://79798610330221",
	TurboTires = "rbxassetid://104021789006578",
	PlazaPitstop = "rbxassetid://76845063427534",
	BombBox = "rbxassetid://140586940348473",
}

local classic: Theme = {
	Id = "Classic",
	Name = "Mini Racer Classic",
	Colors = {
		Grass = Color3.fromRGB(74, 148, 58),
		Road = Color3.fromRGB(36, 38, 42),
		KerbA = Color3.fromRGB(200, 40, 40),
		KerbB = Color3.fromRGB(230, 230, 230),
		Barrier = Color3.fromRGB(214, 190, 148),
		StartSpawn = Color3.fromRGB(255, 220, 70),
		Finish = Color3.fromRGB(240, 240, 240),
		Checkpoint = Color3.fromRGB(80, 200, 120),
		PlazaFloor = Color3.fromRGB(162, 148, 128),
		PaddockPad = Color3.fromRGB(148, 134, 112),
		MarketPad = Color3.fromRGB(138, 108, 86),
		PlazaCurb = Color3.fromRGB(232, 228, 214),
		Arch = Color3.fromRGB(210, 162, 58),
		SponsorFrame = Color3.fromRGB(210, 162, 58),
		CastleStone = Color3.fromRGB(214, 190, 148),
		CastleStoneDark = Color3.fromRGB(156, 134, 106),
		CastleRoof = Color3.fromRGB(196, 52, 48),
		CastleWindow = Color3.fromRGB(48, 36, 72),
	},
	Materials = {
		Grass = Enum.Material.Grass,
		Road = Enum.Material.Asphalt,
		Barrier = Enum.Material.Slate,
		PlazaFloor = Enum.Material.Cobblestone,
		PaddockPad = Enum.Material.Cobblestone,
		MarketPad = Enum.Material.Cobblestone,
		PlazaCurb = Enum.Material.SmoothPlastic,
		CastleStone = Enum.Material.Slate,
		CastleStoneDark = Enum.Material.Slate,
		WorldShell = Enum.Material.Slate,
	},
	Images = {
		Barrier = "rbxassetid://118110440386002",
		StartLine = "rbxassetid://73625917521760",
		FinishBanner = "rbxassetid://122615315404933",
		ChevronLeft = "rbxassetid://89191748334118",
		ChevronRight = "rbxassetid://111291036653365",
		ChevronHairpin = "rbxassetid://99458837081193",
	},
	Sponsors = CLASSIC_SPONSORS,
	Lighting = {
		ClockTime = 14.6,
		Brightness = 1.45,
		Ambient = Color3.fromRGB(92, 108, 122),
		OutdoorAmbient = Color3.fromRGB(108, 128, 148),
		FogColor = Color3.fromRGB(148, 186, 224),
		FogStart = 320,
		FogEnd = 1600,
		EnvironmentDiffuseScale = 0.7,
		EnvironmentSpecularScale = 0.4,
		ExposureCompensation = -0.35,
		Atmosphere = {
			Density = 0.14,
			Color = Color3.fromRGB(155, 190, 225),
			Decay = Color3.fromRGB(90, 120, 80),
			Haze = 0.35,
			Glare = 0.1,
		},
	},
	World = {
		Gate = "Castle",
		ShellHeight = 96,
		ShellOffset = 36,
		ShellRole = "CastleStone",
	},
}

local scifi: Theme = {
	Id = "SciFi",
	Name = "Mini Racer Neon",
	Colors = {
		Grass = Color3.fromRGB(40, 54, 72),
		Road = Color3.fromRGB(28, 34, 48),
		KerbA = Color3.fromRGB(0, 220, 255),
		KerbB = Color3.fromRGB(255, 40, 180),
		Barrier = Color3.fromRGB(70, 90, 120),
		StartSpawn = Color3.fromRGB(0, 255, 210),
		Finish = Color3.fromRGB(80, 220, 255),
		Checkpoint = Color3.fromRGB(0, 180, 255),
		PlazaFloor = Color3.fromRGB(36, 48, 68),
		PaddockPad = Color3.fromRGB(30, 40, 58),
		MarketPad = Color3.fromRGB(32, 24, 48),
		PlazaCurb = Color3.fromRGB(0, 200, 255),
		Arch = Color3.fromRGB(0, 255, 220),
		SponsorFrame = Color3.fromRGB(0, 220, 255),
		CastleStone = Color3.fromRGB(48, 56, 72),
		CastleStoneDark = Color3.fromRGB(28, 34, 48),
		CastleRoof = Color3.fromRGB(0, 160, 255),
		CastleWindow = Color3.fromRGB(80, 255, 220),
		SciHull = Color3.fromRGB(36, 44, 58),
		SciAccent = Color3.fromRGB(0, 230, 255),
		SciGlow = Color3.fromRGB(90, 40, 255),
	},
	Materials = {
		Grass = Enum.Material.DiamondPlate,
		Road = Enum.Material.Asphalt,
		KerbA = Enum.Material.Neon,
		KerbB = Enum.Material.Neon,
		Barrier = Enum.Material.Metal,
		PlazaFloor = Enum.Material.DiamondPlate,
		PaddockPad = Enum.Material.Metal,
		MarketPad = Enum.Material.Metal,
		PlazaCurb = Enum.Material.Neon,
		CastleStone = Enum.Material.Metal,
		CastleStoneDark = Enum.Material.Metal,
		SciHull = Enum.Material.Metal,
		SciAccent = Enum.Material.Neon,
		SciGlow = Enum.Material.Neon,
		WorldShell = Enum.Material.Metal,
	},
	Images = {
		Barrier = "",
		StartLine = "rbxassetid://73625917521760",
		FinishBanner = "",
		ChevronLeft = "",
		ChevronRight = "",
		ChevronHairpin = "",
	},
	Sponsors = CLASSIC_SPONSORS,
	Lighting = {
		ClockTime = 4.2,
		Brightness = 3.4,
		Ambient = Color3.fromRGB(48, 72, 110),
		OutdoorAmbient = Color3.fromRGB(36, 60, 95),
		FogColor = Color3.fromRGB(40, 90, 140),
		FogStart = 200,
		FogEnd = 1100,
		EnvironmentDiffuseScale = 1,
		EnvironmentSpecularScale = 1,
		Atmosphere = {
			Density = 0.22,
			Color = Color3.fromRGB(50, 110, 170),
			Decay = Color3.fromRGB(20, 40, 70),
			Haze = 1.1,
			Glare = 0.9,
		},
	},
	World = {
		Gate = "Portal",
		ShellHeight = 88,
		ShellOffset = 36,
		ShellRole = "SciHull",
	},
}

TrackThemes.Order = { classic.Id, scifi.Id }
TrackThemes.ById = {
	[classic.Id] = classic,
	[scifi.Id] = scifi,
}

function TrackThemes.get(id: string): Theme
	return TrackThemes.ById[id] or classic
end

return TrackThemes
