local Constants = {
	Race = {
		LapCount = 3,
		CountdownSeconds = 3,
		CheckpointCount = 4,
		SelectSeconds = 20,
		MinPlayers = 1,
		MaxPlayers = 8,
		LobbyWaitSeconds = 8,
		PodiumSeconds = 8,
		DnfAfterWinnerSeconds = 20,
	},
	Car = {
		Name = "MiniRacer",
		DefaultPalette = "Default",
		MaxSpeed = 120,
		Acceleration = 58,
		Brake = 72,
		TurnSpeed = 1.85,
		SpawnHeight = 3.2,
	},
	Track = {
		CheckpointTag = "Checkpoint",
		SpawnTag = "RaceSpawn",
		RoadWidth = 80,
		BarrierHeight = 6,
		WallBounce = 0.58,
		ClimbDegrees = 30,
		ClimbMinMul = 0.25,
		ClimbPeakMax = 48,
	},
	Credits = {
		StartingBalance = 10,
		Stipend = 20,
		FinishBonus = 20,
		Payout = { 150, 90, 50 },
	},
	Shop = {
		OpenStates = { Lobby = true, Selecting = true },
		Items = {
			{ Id = "Booster", Name = "Booster", Cost = 20 },
			{ Id = "Bomb", Name = "Bomb", Cost = 10 },
		},
	},
	Items = {
		BoostMul = 1.5,
		BoostSeconds = 3,
		SlowMul = 0.7,
		SlowSeconds = 3,
		PickupRespawnSeconds = 10,
	},
	Audio = {
		Background = "rbxassetid://104976378455015",
		Countdown = "rbxassetid://133467521581745",
		Lap = "rbxassetid://82669582574373",
		BoostPickup = "rbxassetid://122016420402975",
		BombPickup = "rbxassetid://93170321014352",
		BombHit = "rbxassetid://89479472135872",
		Winner = "rbxassetid://120657237573902",
	},
}

return Constants
