# LevelGenerator.gd
extends Node3D
class_name RunGenerator

# Configuration parameters
@export var possible_destinations: Array[String] = ["DEN", "LAX", "JFK", "ORD", "ATL", "SFO", "BOS", "TOR"]
@export var min_box_holes: int = 4
@export var max_box_holes: int = 8
@export var international_chance: float = 0.4
@export var disposable_chance: float = 0.15

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

func get_preset_hole_position(rng: RandomNumberGenerator, index: int) -> Vector3:
	if index < preset_hole_positions.size():
		return preset_hole_positions[index]
	else:
		# Fallback to grid if we need more positions than presets
		return get_random_hole_position(rng, index)

func generate_run_config(_seed: int = -1) -> RunConfig:
	var config = RunConfig.new()
	
	# Set seed for consistent generation
	config.run_seed = _seed
	config.run_name = "Run " + str(_seed)
	
	# Use seed for consistent random generation
	var rng = RandomNumberGenerator.new()
	rng.seed = _seed
	
	# Generate box holes
	config.box_holes = generate_box_holes(rng)
	
	# Generate daily progression
	config.daily_spawning = generate_daily_configs(rng)
	
	return config

func generate_box_holes(rng: RandomNumberGenerator) -> Array[BoxHoleConfig]:
	var holes: Array[BoxHoleConfig] = []
	var used_positions: Array[int] = []
	
	# Always add both disposal holes first (active from day 1)
	var disposal_domestic = BoxHoleConfig.new()
	disposal_domestic.is_disposal = true
	disposal_domestic.international = false
	disposal_domestic.destination = ""  # Empty destination for disposal holes
	disposal_domestic.active = true
	disposal_domestic.activation_day = 1
	
	# Randomly select position for domestic disposal
	var domestic_pos_index = rng.randi() % preset_hole_positions.size()
	disposal_domestic.position = preset_hole_positions[domestic_pos_index]
	used_positions.append(domestic_pos_index)
	holes.append(disposal_domestic)
	
	var disposal_international = BoxHoleConfig.new()
	disposal_international.is_disposal = true
	disposal_international.international = true
	disposal_international.destination = ""  # Empty destination for disposal holes
	disposal_international.active = true
	disposal_international.activation_day = 1
	
	# Randomly select different position for international disposal
	var intl_pos_index = domestic_pos_index
	while intl_pos_index == domestic_pos_index:
		intl_pos_index = rng.randi() % preset_hole_positions.size()
	disposal_international.position = preset_hole_positions[intl_pos_index]
	used_positions.append(intl_pos_index)
	holes.append(disposal_international)
	
	# Generate 6 regular holes (8 total - 2 disposal = 6 regular)
	var used_combinations: Array[String] = []
	var activation_schedule = [1, 1, 1, 8, 16, 24]  # Days when each regular hole activates
	
	# Force first hole to be domestic (day 1)
	var first_hole = BoxHoleConfig.new()
	first_hole.destination = possible_destinations[rng.randi() % possible_destinations.size()]
	first_hole.international = false
	first_hole.activation_day = 1
	first_hole.active = true
	first_hole.value_multiplier = rng.randf_range(0.8, 1.2)
	var first_pos_index = get_unused_position_index(used_positions, rng)
	first_hole.position = preset_hole_positions[first_pos_index]
	used_positions.append(first_pos_index)
	holes.append(first_hole)
	used_combinations.append(first_hole.destination + "_dom")
	
	# Force second hole to be international (day 1) 
	var second_hole = BoxHoleConfig.new()
	second_hole.destination = possible_destinations[rng.randi() % possible_destinations.size()]
	second_hole.international = true
	second_hole.activation_day = 1
	second_hole.active = true
	second_hole.value_multiplier = rng.randf_range(0.8, 1.2)
	var second_pos_index = get_unused_position_index(used_positions, rng)
	second_hole.position = preset_hole_positions[second_pos_index]
	used_positions.append(second_pos_index)
	holes.append(second_hole)
	used_combinations.append(second_hole.destination + "_intl")
	
	# Generate remaining 4 holes normally
	for i in range(2, 6):
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
		
		# Select random unused position
		var available_positions = []
		for j in range(preset_hole_positions.size()):
			if j not in used_positions:
				available_positions.append(j)
		
		if available_positions.size() > 0:
			var selected_index = available_positions[rng.randi() % available_positions.size()]
			hole.position = preset_hole_positions[selected_index]
			used_positions.append(selected_index)
		else:
			# Fallback to grid if we run out of preset positions
			hole.position = get_random_hole_position(rng, holes.size())
		
		hole.value_multiplier = rng.randf_range(0.8, 1.2)
		
		# Set activation day and initial active state
		hole.activation_day = activation_schedule[i]
		hole.active = (hole.activation_day == 1)
		
		holes.append(hole)
	
	return holes

func get_unused_position_index(used_positions: Array, rng: RandomNumberGenerator) -> int:
	var available_positions = []
	for j in range(preset_hole_positions.size()):
		if j not in used_positions:
			available_positions.append(j)
	return available_positions[rng.randi() % available_positions.size()]

func generate_daily_configs(rng: RandomNumberGenerator) -> Array[DayConfig]:
	var days: Array[DayConfig] = []
	
	for day in range(1, 8):  # Days 1-7 instead of 1-10
		var day_config = DayConfig.new()
		day_config.day_number = day
		
		# Use economy config for progression
		var eco_data = Economy.config.get_day_config(day)
		day_config.total_boxes = eco_data.total_boxes
		day_config.boxes_per_second = eco_data.boxes_per_second
		day_config.quota_target = eco_data.total_boxes  # Must hit exact number
		
		# Add box type probabilities
		var progress = Economy.config.calculate_day_progression(day)
		day_config.box_types = generate_box_type_probabilities(rng, progress)
		day_config.special_modifiers = generate_special_modifiers(rng, day)
		
		days.append(day_config)
	
	return days

func generate_box_type_probabilities(_rng: RandomNumberGenerator, progress: float) -> Array[Dictionary]:
	var probabilities: Array[Dictionary] = []
	
	# Base probability for international boxes increases over time
	var international_prob = lerp(0.3, 0.5, progress)
	probabilities.append({"type": "international", "chance": international_prob})
	
	# Disposable boxes increase over time
	var disposable_prob = lerp(0.3, 0.35, progress)
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
