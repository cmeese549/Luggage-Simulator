extends Resource

class_name RunConfig

@export var run_seed: int = 0
@export var box_holes: Array[BoxHoleConfig] = []
@export var daily_spawning: Array[DayConfig] = []
@export var run_name: String = ""
@export var difficulty_multiplier: float = 1.0

func _init():
	run_seed = randi()
	run_name = "Run " + str(run_seed)
