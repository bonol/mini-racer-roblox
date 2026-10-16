local Constants = {
	Race = {
		LapCount = 20,
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
}

return Constants
