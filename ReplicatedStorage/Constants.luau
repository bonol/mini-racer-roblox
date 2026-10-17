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
			{ Id = "Booster", Name = "Booster", Cost = 80 },
			{ Id = "Landmine", Name = "Landmine", Cost = 70 },
		},
	},
	Items = {
		BoostMul = 1.5,
		BoostSeconds = 3,
		SlowMul = 0.7,
		SlowSeconds = 5,
		MineArmSeconds = 0.6,
		PickupRespawnSeconds = 10,
	},
}

return Constants
