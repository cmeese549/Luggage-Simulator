extends Node3D
class_name RunOrchestrator

signal day_started(day_number: int)
signal day_completed(day_number: int, success: bool)
signal run_completed(success: bool)

@onready var run_generator: RunGenerator = $RunGenerator
@export var box_hole_scene: PackedScene  # Assign your BoxHole scene in inspector

var current_run_config: RunConfig
var current_day: int = 1
var boxes_processed_today: int = 0
var boxes_processed_correctly: int = 0
var is_day_active: bool = false

# Box spawning state
var boxes_spawned_today: int = 0
var spawn_timer: float = 0.0
var current_spawn_interval: float = 1.0

func _ready():
	await get_tree().process_frame
	start_new_run()

func start_new_run(seed: int = -1) -> void:
	run_generator.collect_preset_positions()
	current_run_config = run_generator.generate_run_config(seed)
	current_day = 1
	setup_box_holes()
	start_day(1)

func setup_box_holes() -> void:
	print("Setting up ", current_run_config.box_holes.size(), " box holes")
	
	# Debug: Check the scene path
	print("BoxHole scene path: ", box_hole_scene.resource_path if box_hole_scene else "NULL")
	
	for i in range(current_run_config.box_holes.size()):
		var hole_config = current_run_config.box_holes[i]
		print("Creating hole ", i, ": ", hole_config.destination, " at ", hole_config.position)
		
		var hole_instance = box_hole_scene.instantiate()
		print("Hole instance created: ", hole_instance)
		print("Hole instance name: ", hole_instance.name)
		
		hole_instance.destination = hole_config.destination
		hole_instance.international = hole_config.international
		hole_instance.is_disposal = hole_config.is_disposal
		hole_instance.global_position = hole_config.position
		hole_instance.scale = Vector3(6, 6, 6)
		
		print("About to add to scene...")
		print("MainLevel node exists: ", get_tree().root.has_node("MainLevel"))
		print("MainLevel node: ", get_tree().root.get_node_or_null("MainLevel"))
		print("Current scene: ", get_tree().current_scene)
		print("Current scene name: ", get_tree().current_scene.name if get_tree().current_scene else "NULL")
		get_tree().root.get_node("MainLevel").add_child(hole_instance)
		print("Added to scene. Is in tree: ", hole_instance.is_inside_tree())
		print("Final position: ", hole_instance.global_position)
		print("Scene tree child count: ", get_tree().current_scene.get_child_count())

func start_day(day_number: int) -> void:
	if day_number > current_run_config.daily_spawning.size():
		complete_run(true)
		return
	
	current_day = day_number
	boxes_processed_today = 0
	boxes_processed_correctly = 0
	boxes_spawned_today = 0
	is_day_active = true
	
	var day_config = get_current_day_config()
	current_spawn_interval = 1.0 / day_config.boxes_per_second
	spawn_timer = 0.0
	
	# Apply special modifiers
	apply_special_modifiers(day_config.special_modifiers)
	
	day_started.emit(day_number)
	print("Day ", day_number, " started - Target: ", day_config.quota_target, " boxes")

func get_current_day_config() -> DayConfig:
	if current_day <= 0 or current_day > current_run_config.daily_spawning.size():
		return null
	return current_run_config.daily_spawning[current_day - 1]

func _process(delta: float) -> void:
	if not is_day_active:
		return
	
	var day_config = get_current_day_config()
	if not day_config:
		return
	
	# Handle box spawning
	if boxes_spawned_today < day_config.total_boxes:
		spawn_timer += delta
		if spawn_timer >= current_spawn_interval:
			spawn_box(day_config)
			spawn_timer = 0.0
	
	# Check if day is complete
	elif boxes_processed_today >= day_config.total_boxes:
		complete_day()

func spawn_box(day_config: DayConfig) -> void:
	# This would integrate with your existing box spawning system
	var box_spawners = get_tree().get_nodes_in_group("BoxSpawner")
	if box_spawners.is_empty():
		print("Warning: No box spawners found")
		return
	
	# Pick random spawner
	var spawner = box_spawners[randi() % box_spawners.size()]
	
	# Apply box type probabilities from day config
	var box_properties = generate_box_properties(day_config)
	
	# Tell spawner to spawn a box with these properties
	if spawner.has_method("spawn_box_with_properties"):
		spawner.spawn_box_with_properties(box_properties)
	else:
		# Fallback to default spawning
		if spawner.has_method("spawn_box"):
			spawner.spawn_box()
	
	boxes_spawned_today += 1

func generate_box_properties(day_config: DayConfig) -> Dictionary:
	var properties = {}
	
	# Apply box type probabilities
	for box_type in day_config.box_types:
		if randf() < box_type.chance:
			if box_type.type == "international":
				properties.international = true
			elif box_type.type == "disposable":
				properties.disposable = true
	
	# Assign random destination from available box holes
	var destination_holes = current_run_config.box_holes.filter(func(hole): return not hole.is_disposal)
	if not destination_holes.is_empty():
		var random_hole = destination_holes[randi() % destination_holes.size()]
		properties.destination = random_hole.destination
		properties.international = random_hole.international
	
	return properties

func on_box_processed(correct: bool) -> void:
	boxes_processed_today += 1
	if correct:
		boxes_processed_correctly += 1

func complete_day() -> void:
	is_day_active = false
	var day_config = get_current_day_config()
	var success = boxes_processed_correctly >= day_config.quota_target
	
	print("Day ", current_day, " complete - Processed: ", boxes_processed_correctly, "/", day_config.quota_target)
	
	day_completed.emit(current_day, success)
	
	if not success:
		complete_run(false)
	elif current_day >= 10:
		complete_run(true)
	else:
		# Start next day after a brief delay
		await get_tree().create_timer(2.0).timeout
		start_day(current_day + 1)

func complete_run(success: bool) -> void:
	run_completed.emit(success)
	if success:
		print("Run completed successfully!")
	else:
		print("Run failed on day ", current_day)

func apply_special_modifiers(modifiers: Array[String]) -> void:
	for modifier in modifiers:
		match modifier:
			"mislabeled_surge":
				print("Special modifier: Mislabeled boxes surge!")
				# Could increase mislabeling probability
			"power_outage":
				print("Special modifier: Power outage!")
				# Could disable some machines temporarily
			"stricter_inspection":
				print("Special modifier: Stricter inspection required!")
				# Could require more careful processing

func get_save_data() -> Dictionary:
	var data = {}
	data.current_run_config = current_run_config
	data.current_day = current_day
	data.boxes_processed_today = boxes_processed_today
	data.boxes_processed_correctly = boxes_processed_correctly
	data.is_day_active = is_day_active
	data.boxes_spawned_today = boxes_spawned_today
	return data

func load_save_data(data: Dictionary) -> void:
	current_run_config = data.current_run_config
	current_day = data.current_day
	boxes_processed_today = data.boxes_processed_today
	boxes_processed_correctly = data.boxes_processed_correctly
	is_day_active = data.is_day_active
	boxes_spawned_today = data.boxes_spawned_today
	
	if current_run_config:
		setup_box_holes()
		if is_day_active:
			var day_config = get_current_day_config()
			current_spawn_interval = 1.0 / day_config.boxes_per_second
