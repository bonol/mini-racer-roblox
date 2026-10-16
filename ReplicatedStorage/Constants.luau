local Constants = {
	Race = {
		LapCount = 1,
		CountdownSeconds = 3,
		CheckpointCount = 4,
	},
	Car = {
		Name = "MiniRacer",
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
