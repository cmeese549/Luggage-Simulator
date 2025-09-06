# LevelGenerator.gd
extends Node3D
class_name RunGenerator

# Configuration parameters
@export var possible_destinations: Array[String] = ["DEN", "LAX", "JFK", "ATL", "ORD"]
@export var min_box_holes: int = 4
@export var max_box_holes: int = 8
@export var international_chance: float = 0.3
@export var disposal_holes_count: int = 1

# Difficulty scaling
@export var starting_boxes: int = 10
@export var ending_boxes: int = 100
@export var starting_spawn_rate: float = 0.5
@export var ending_spawn_rate: float = 3.0

var preset_hole_positions: Array[Vector3] = []

func collect_preset_positions() -> void:
	preset_hole_positions.clear()
	var existing_holes = get_tree().get_nodes_in_group("BoxHole")
	for hole in existing_holes:
		preset_hole_positions.append(hole.global_position)
		hole.queue_free()

func get_preset_hole_position(index: int) -> Vector3:
	if index < preset_hole_positions.size():
		return preset_hole_positions[index]
	else:
		# Fallback to grid if we need more positions than presets
		return get_random_hole_position(RandomNumberGenerator.new(), index)

func generate_run_config(seed: int = -1) -> RunConfig:
	var config = RunConfig.new()
	
	# Set seed for consistent generation
	if seed == -1:
		seed = randi()
	config.run_seed = seed
	config.run_name = "Run " + str(seed)
	
	# Use seed for consistent random generation
	var rng = RandomNumberGenerator.new()
	rng.seed = seed
	
	# Generate box holes
	config.box_holes = generate_box_holes(rng)
	
	# Generate daily progression
	config.daily_spawning = generate_daily_configs(rng)
	
	return config

func generate_box_holes(rng: RandomNumberGenerator) -> Array[BoxHoleConfig]:
	var holes: Array[BoxHoleConfig] = []
	
	# Always add both disposal holes first (active from day 1)
	var disposal_domestic = BoxHoleConfig.new()
	disposal_domestic.is_disposal = true
	disposal_domestic.international = false
	disposal_domestic.destination = ""  # Empty destination for disposal holes
	disposal_domestic.active = true
	disposal_domestic.activation_day = 1
	disposal_domestic.position = get_preset_hole_position(holes.size())
	holes.append(disposal_domestic)
	
	var disposal_international = BoxHoleConfig.new()
	disposal_international.is_disposal = true
	disposal_international.international = true
	disposal_international.destination = ""  # Empty destination for disposal holes
	disposal_international.active = true
	disposal_international.activation_day = 1
	disposal_international.position = get_preset_hole_position(holes.size())
	holes.append(disposal_international)
	
	# Generate 6 regular holes (8 total - 2 disposal = 6 regular)
	var used_combinations: Array[String] = []
	var activation_schedule = [1, 1, 1, 2, 4, 6]  # Days when each regular hole activates
	
	for i in range(6):
		var hole = BoxHoleConfig.new()
		
		# Try to find unique destination+international combination
		var attempts = 0
		var combination_key = ""
		
		while attempts < 50:  # Prevent infinite loops
			# Pick destination
			hole.destination = possible_destinations[rng.randi() % possible_destinations.size()]
			hole.international = rng.randf() < international_chance
			
			combination_key = hole.destination + ("_intl" if hole.international else "_dom")
			
			if combination_key not in used_combinations:
				break
			attempts += 1
		
		used_combinations.append(combination_key)
		hole.position = get_preset_hole_position(holes.size())
		hole.value_multiplier = rng.randf_range(0.8, 1.2)
		
		# Set activation day and initial active state
		hole.activation_day = activation_schedule[i]
		hole.active = (hole.activation_day == 1)
		
		holes.append(hole)
	
	return holes

func generate_daily_configs(rng: RandomNumberGenerator) -> Array[DayConfig]:
	var days: Array[DayConfig] = []
	
	for day in range(1, 8):  # Days 1-7 instead of 1-10
		var day_config = DayConfig.new()
		day_config.day_number = day
		
		# Progressive difficulty scaling
		var progress = float(day - 1) / 6.0  # 0.0 to 1.0 over 6 days instead of 9
		
		# Exponential growth for boxes and spawn rate
		day_config.total_boxes = int(lerp(starting_boxes, ending_boxes, pow(progress, 1.5)))
		day_config.boxes_per_second = lerp(starting_spawn_rate, ending_spawn_rate, pow(progress, 1.2))
		day_config.quota_target = int(day_config.total_boxes * 0.85)  # 85% success rate required
		
		# Add box type probabilities
		day_config.box_types = generate_box_type_probabilities(rng, progress)
		
		# Add special modifiers for later days
		day_config.special_modifiers = generate_special_modifiers(rng, day)
		
		days.append(day_config)
	
	return days

func generate_box_type_probabilities(rng: RandomNumberGenerator, progress: float) -> Array[Dictionary]:
	var probabilities: Array[Dictionary] = []
	
	# Base probability for international boxes increases over time
	var international_prob = lerp(0.1, 0.4, progress)
	probabilities.append({"type": "international", "chance": international_prob})
	
	# Disposable boxes increase over time
	var disposable_prob = lerp(0.05, 0.25, progress)
	probabilities.append({"type": "disposable", "chance": disposable_prob})
	
	return probabilities

func generate_special_modifiers(rng: RandomNumberGenerator, day: int) -> Array[String]:
	var modifiers: Array[String] = []
	
	# Add modifiers based on day and random chance
	if day >= 3 and rng.randf() < 0.3:
		modifiers.append("mislabeled_surge")
	
	if day >= 5 and rng.randf() < 0.2:
		modifiers.append("power_outage")
	
	if day >= 7 and rng.randf() < 0.15:
		modifiers.append("stricter_inspection")
	
	return modifiers

func get_random_hole_position(rng: RandomNumberGenerator, index: int) -> Vector3:
	# Simple grid-based positioning for now
	var spacing = 4.0
	var per_row = 3
	var row = index / per_row
	var col = index % per_row
	
	# Add some random offset
	var offset_x = rng.randf_range(-1.0, 1.0)
	var offset_z = rng.randf_range(-1.0, 1.0)
	
	return Vector3(col * spacing + offset_x, 0, row * spacing + offset_z)
