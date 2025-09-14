# LevelGenerator.gd
extends Node3D
class_name RunGenerator

# Configuration parameters
@export var possible_destinations: Array[Destination] = []
@export var min_box_holes: int = 4
@export var max_box_holes: int = 8
@export var inspection_chance: float = 0.4
@export var disposable_chance: float = 0.15

# Difficulty scaling
@export var starting_boxes: int = 10
@export var ending_boxes: int = 100
@export var starting_spawn_rate: float = 0.5
@export var ending_spawn_rate: float = 3.0



var preset_hole_data: Array[Dictionary] = []

func collect_preset_positions() -> void:
	preset_hole_data.clear()
	var existing_holes = get_tree().get_nodes_in_group("BoxHole")
	for hole in existing_holes:
		preset_hole_data.append({
			"position": hole.global_position,
			"rotation": hole.rotation
		})
		hole.queue_free()

func get_preset_hole_position(rng: RandomNumberGenerator, index: int) -> Dictionary:
	return preset_hole_data[index]

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
	disposal_domestic.needs_inspection = false
	disposal_domestic.destination = null
	disposal_domestic.active = true
	disposal_domestic.activation_day = 1
	
	# Randomly select position for domestic disposal
	var domestic_pos_index = rng.randi() % preset_hole_data.size()
	disposal_domestic.position = preset_hole_data[domestic_pos_index].position
	disposal_domestic.rotation = preset_hole_data[domestic_pos_index].rotation
	used_positions.append(domestic_pos_index)
	holes.append(disposal_domestic)
	
	var disposal_inspection = BoxHoleConfig.new()
	disposal_inspection.is_disposal = true
	disposal_inspection.needs_inspection = true
	disposal_inspection.destination = null
	disposal_inspection.active = true
	disposal_inspection.activation_day = 1
	
	# Randomly select different position for international disposal
	var insp_pos_index = domestic_pos_index
	while insp_pos_index == domestic_pos_index:
		insp_pos_index = rng.randi() % preset_hole_data.size()
	disposal_inspection.position = preset_hole_data[insp_pos_index].position
	disposal_inspection.rotation = preset_hole_data[insp_pos_index].rotation
	used_positions.append(insp_pos_index)
	holes.append(disposal_inspection)
	
	# Generate 6 regular holes (8 total - 2 disposal = 6 regular)
	var used_combinations: Array[String] = []
	var activation_schedule = [1, 1, 1, 8, 16, 24]  # Days when each regular hole activates
	
	# Force first hole to be domestic (day 1)
	var first_hole = BoxHoleConfig.new()
	first_hole.destination = possible_destinations[rng.randi() % possible_destinations.size()]
	first_hole.needs_inspection = false
	first_hole.activation_day = 1
	first_hole.active = true
	first_hole.value_multiplier = rng.randf_range(0.8, 1.2)
	var first_pos_index = get_unused_position_index(used_positions, rng)
	first_hole.position = preset_hole_data[first_pos_index].position
	first_hole.rotation = preset_hole_data[first_pos_index].rotation
	used_positions.append(first_pos_index)
	holes.append(first_hole)
	used_combinations.append(str(first_hole.destination.id) + "_dom")
	
	# Force second hole to be international (day 1) 
	var second_hole = BoxHoleConfig.new()
	second_hole.destination = possible_destinations[rng.randi() % possible_destinations.size()]
	second_hole.needs_inspection = true
	second_hole.activation_day = 1
	second_hole.active = true
	second_hole.value_multiplier = rng.randf_range(0.8, 1.2)
	var second_pos_index = get_unused_position_index(used_positions, rng)
	second_hole.position = preset_hole_data[second_pos_index].position
	second_hole.rotation = preset_hole_data[second_pos_index].rotation
	used_positions.append(second_pos_index)
	holes.append(second_hole)
	used_combinations.append(str(second_hole.destination.id) + "_insp")
	
	# Generate remaining 4 holes normally
	for i in range(2, 6):
		var hole = BoxHoleConfig.new()
		
		# Try to find unique destination+international combination
		var attempts = 0
		var combination_key = ""
		
		while attempts < 50:  # Prevent infinite loops
			# Pick destination
			hole.destination = possible_destinations[rng.randi() % possible_destinations.size()]
			hole.needs_inspection = rng.randf() < inspection_chance
			
			combination_key = str(hole.destination.id) + ("_insp" if hole.needs_inspection else "_dom")
			
			if combination_key not in used_combinations:
				break
			attempts += 1
		
		used_combinations.append(combination_key)
		
		# Select random unused position
		var available_positions = []
		for j in range(preset_hole_data.size()):
			if j not in used_positions:
				available_positions.append(j)
		
		var selected_index = available_positions[rng.randi() % available_positions.size()]
		hole.position = preset_hole_data[selected_index].position
		hole.rotation = preset_hole_data[selected_index].rotation
		used_positions.append(selected_index)
		
		hole.value_multiplier = rng.randf_range(0.8, 1.2)
		
		# Set activation day and initial active state
		hole.activation_day = activation_schedule[i]
		hole.active = (hole.activation_day == 1)
		
		holes.append(hole)
	
	return holes

func get_unused_position_index(used_positions: Array, rng: RandomNumberGenerator) -> int:
	var available_positions = []
	for j in range(preset_hole_data.size()):
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
	var needs_inspection_prob = lerp(0.3, 0.5, progress)
	probabilities.append({"type": "needs_inspection", "chance": needs_inspection_prob})
	
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
