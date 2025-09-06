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
	print("Collected ", preset_hole_positions.size(), " preset positions")

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
	var hole_count = rng.randi_range(min_box_holes, max_box_holes)
	
	# Always add disposal hole first
	for i in disposal_holes_count:
		var disposal_hole = BoxHoleConfig.new()
		disposal_hole.is_disposal = true
		disposal_hole.international = rng.randf() < 0.5  # Can handle either
		disposal_hole.position = get_preset_hole_position(holes.size())
		holes.append(disposal_hole)
	
	# Add regular destination holes
	var used_destinations: Array[String] = []
	for i in range(disposal_holes_count, hole_count):
		var hole = BoxHoleConfig.new()
		
		# Pick unique destination
		var available_destinations = possible_destinations.filter(func(dest): return dest not in used_destinations)
		if available_destinations.is_empty():
			used_destinations.clear()  # Reset if we run out
			available_destinations = possible_destinations
		
		hole.destination = available_destinations[rng.randi() % available_destinations.size()]
		used_destinations.append(hole.destination)
		
		hole.international = rng.randf() < international_chance
		hole.position = get_preset_hole_position(holes.size())
		hole.value_multiplier = rng.randf_range(0.8, 1.2)
		
		holes.append(hole)
	
	return holes

func generate_daily_configs(rng: RandomNumberGenerator) -> Array[DayConfig]:
	var days: Array[DayConfig] = []
	
	for day in range(1, 11):  # Days 1-10
		var day_config = DayConfig.new()
		day_config.day_number = day
		
		# Progressive difficulty scaling
		var progress = float(day - 1) / 9.0  # 0.0 to 1.0
		
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
