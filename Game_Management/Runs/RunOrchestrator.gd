extends Node3D
class_name RunOrchestrator

signal day_started(day_number: int)
signal day_completed(day_number: int, success: bool)
signal run_completed(success: bool)

@onready var run_generator: RunGenerator = $RunGenerator
@onready var health_system: HealthSystem = $Health
@onready var box_counter: Label = get_tree().get_first_node_in_group("BoxCounter")
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

func get_save_data() -> Dictionary:
	var data = {}
	data.current_run_config = current_run_config
	data.current_day = current_day
	data.boxes_processed_today = boxes_processed_today
	data.boxes_processed_correctly = boxes_processed_correctly
	data.is_day_active = is_day_active
	data.boxes_spawned_today = boxes_spawned_today
	data.health_system_data = health_system.get_save_data()
	data.economy_seed = Economy.config._seed
	return data

func load_save_data(data: Dictionary) -> void:
	current_run_config = data.current_run_config
	current_day = data.current_day
	boxes_processed_today = data.boxes_processed_today
	boxes_processed_correctly = data.boxes_processed_correctly
	is_day_active = data.is_day_active
	boxes_spawned_today = data.boxes_spawned_today
	
	if not is_day_active:
		boxes_spawned_today = 0
		boxes_processed_today = 0
		boxes_processed_correctly = 0
	
	if current_run_config:
		var day_config = get_current_day_config()
		if day_config:
			box_counter.text = "Boxes: " + str(boxes_processed_today) + "/" + str(day_config.total_boxes)
		
		setup_box_holes()
		if is_day_active:
			current_spawn_interval = 1.0 / day_config.boxes_per_second
		
		Economy.config._seed = data.economy_seed
		health_system.load_save_data(data.health_system_data)
		
		await get_tree().process_frame  # Wait for spawners to be restored
		var box_spawners = get_tree().get_nodes_in_group("BoxSpawner")
		for spawner in box_spawners:
			# Reconnect the click signal
			if not spawner.clicked.is_connected(_on_spawner_clicked):
				spawner.clicked.connect(_on_spawner_clicked)
			# Update spawner label based on current state
			if is_day_active:
				if boxes_spawned_today >= day_config.total_boxes:
					spawner.label.text = "Quota reached - finish processing!"
				elif spawner.active:
					spawner.label.text = "Click to pause box spawning"
				else:
					spawner.label.text = "Click to resume box spawning"
			else:
				spawner.label.text = "Click to start day"
			
func auto_save_run() -> void:
	ProfileManager.save_current_run()

func _ready():
	await get_tree().process_frame
	ProfileManager.auto_load()

func start_new_run() -> void:
	run_generator.collect_preset_positions()
	if Economy.config._seed == 0:
		Economy.config._seed = randi()
	current_run_config = run_generator.generate_run_config(Economy.config._seed)
	current_day = 1
	setup_box_holes()
	start_day(1)

func setup_box_holes() -> void:
	# Clear existing box holes first
	var existing_holes = get_tree().get_nodes_in_group("BoxHole")
	for hole in existing_holes:
		hole.queue_free()
	
	# Wait a frame for cleanup  
	await get_tree().process_frame
	
	for i in range(current_run_config.box_holes.size()):
		var hole_config = current_run_config.box_holes[i]
		var hole_instance = box_hole_scene.instantiate()
		hole_instance.destination = hole_config.destination
		hole_instance.needs_inspection = hole_config.needs_inspection
		hole_instance.is_disposal = hole_config.is_disposal
		hole_instance.active = hole_config.active
		
		get_tree().root.get_node("MainLevel").add_child(hole_instance)
		hole_instance.global_position = hole_config.position
		hole_instance.rotation = hole_config.rotation
		hole_instance.scale = Vector3(6, 6, 6)


func start_day(day_number: int) -> void:
	if day_number > 31:  
		complete_run(true)
		return
	
	current_day = day_number
	boxes_processed_today = 0
	boxes_processed_correctly = 0
	boxes_spawned_today = 0
	is_day_active = false  # Don't start active until player clicks spawner
	
	# Setup health for this day
	health_system.setup_for_day(day_number)
	health_system.stop_draining()  # Don't drain until day actually starts
	
	# Connect health depletion signal if not already connected
	if not health_system.health_depleted.is_connected(_on_health_depleted):
		health_system.health_depleted.connect(_on_health_depleted)
	
	activate_holes_for_day(day_number)
	
	var day_config = get_current_day_config()
	current_spawn_interval = 1.0 / day_config.boxes_per_second
	spawn_timer = 0.0
	box_counter.text = "Boxes: 0/" + str(day_config.total_boxes)
	var box_spawners = get_tree().get_nodes_in_group("BoxSpawner")
	for spawner in box_spawners:
		spawner.active = false
		spawner.label.text = "Click to start day"
		
		# Connect spawner click to start the day
		if not spawner.clicked.is_connected(_on_spawner_clicked):
			spawner.clicked.connect(_on_spawner_clicked)
	
	apply_special_modifiers(day_config.special_modifiers)
	
	day_started.emit(day_number)
	print("Day ", day_number, " started - Target: ", day_config.quota_target, " boxes")
	
func _on_spawner_clicked(spawner) -> void:
	if not is_day_active and boxes_spawned_today == 0:
		is_day_active = true
		spawner.active = true
		health_system.start_draining()
		spawner.label.text = "Click to pause box spawning"
		print("Day %d active - health draining started" % current_day)
	elif is_day_active:
		var day_config: DayConfig = get_current_day_config()
		if boxes_spawned_today < day_config.total_boxes:
			spawner.toggle_active()
			if not spawner.active:
				spawner.label.text = "Click to resume box spawning"
			else:
				spawner.label.text = "Click to pause box spawning"
	


func activate_holes_for_day(day: int) -> void:
	var newly_activated = 0
	var scene_holes = get_tree().get_nodes_in_group("BoxHole")
	
	for i in range(current_run_config.box_holes.size()):
		var hole_config = current_run_config.box_holes[i]
		
		if not hole_config.active and hole_config.activation_day <= day:
			hole_config.active = true
			newly_activated += 1
			
			# Find corresponding scene hole and update its label
			if i < scene_holes.size():
				var scene_hole = scene_holes[i]
				# Restore the proper label (re-run the label setup logic)
				scene_hole._ready()
	
	if newly_activated > 0:
		print("Activated ", newly_activated, " new holes for day ", day)



func get_current_day_config() -> DayConfig:
	if current_day <= 0 or current_day > current_run_config.daily_spawning.size():
		return null
	return current_run_config.daily_spawning[current_day - 1]

func _process(delta: float) -> void:
	if not is_day_active or health_system.current_health <= 0:
		return
	
	var day_config = get_current_day_config()
	if not day_config:
		return
	
	var box_spawners = get_tree().get_nodes_in_group("BoxSpawner")
	var any_spawner_active = box_spawners.any(func(spawner): return spawner.active)
	
	# Handle box spawning
	if boxes_spawned_today < day_config.total_boxes and any_spawner_active:
		spawn_timer += delta
		if spawn_timer >= current_spawn_interval:
			spawn_box(day_config)
			spawn_timer = 0.0
			# Force pause spawners when done spawning
			if boxes_spawned_today >= day_config.total_boxes:
				for spawner in box_spawners:
					spawner.active = false
					spawner.label.text = "Quota reached - finish processing!"

	# Check if day is complete  
	if boxes_spawned_today >= day_config.total_boxes and boxes_processed_today >= day_config.total_boxes:
		complete_day()

func spawn_box(day_config: DayConfig) -> void:
	if boxes_spawned_today >= day_config.total_boxes:
		return
	# This would integrate with your existing box spawning system
	var box_spawners = get_tree().get_nodes_in_group("BoxSpawner")
	if box_spawners.is_empty():
		print("Warning: No box spawners found")
		return
	
	# Pick random spawner
	var spawner = box_spawners[randi() % box_spawners.size()]
	if  spawner.is_spawn_blocked():
		return
	
	# Apply box type probabilities from day config
	var box_properties = generate_box_properties(day_config)
	spawner.spawn_box_with_properties(box_properties)
	
	boxes_spawned_today += 1

# Modify generate_box_properties() in RunOrchestrator.gd

func generate_box_properties(day_config: DayConfig) -> Dictionary:
	var properties = {}
	
	# First check if this should be an invalid destination box (10-30% chance scaling with day)
	var invalid_chance = lerp(0.1, 0.3, float(current_day) / 31.0)
	if randf() < invalid_chance:
		# Pick a destination that has NO active holes
		var all_destinations = run_generator.possible_destinations
		var active_destination_ids = []
		
		# Collect all active destinations from holes
		for hole in current_run_config.box_holes:
			if hole.active and not hole.is_disposal and hole.destination.id not in active_destination_ids:
				active_destination_ids.append(hole.destination.id)
		
		# Find destinations that don't have active holes
		var invalid_destinations = []
		for dest in all_destinations:
			if dest not in active_destination_ids:
				invalid_destinations.append(dest)
		
		# If we have invalid destinations available, use one
		if invalid_destinations.size() > 0:
			properties["destination"] = invalid_destinations[randi() % invalid_destinations.size()]
			properties["needs_inspection"] = randf() < 0.5  # Can be international too
			return properties  # Return early, this box is invalid
	
	# Otherwise, pick a valid destination from active holes
	var valid_holes = current_run_config.box_holes.filter(func(hole): 
		return hole.active and not hole.is_disposal
	)
	
	if valid_holes.size() > 0:
		var selected_hole = valid_holes[randi() % valid_holes.size()]
		properties["destination"] = selected_hole.destination
		properties["needs_inspection"] = selected_hole.needs_inspection
	
	# Apply box type probabilities for disposable flag
	for box_type in day_config.box_types:
		if box_type.type == "disposable" and randf() < box_type.chance:
			properties["disposable"] = true
			break
	
	return properties

func on_box_processed(correct: bool) -> void:
	boxes_processed_today += 1
	if correct:
		boxes_processed_correctly += 1
	health_system.on_box_processed(correct)
	box_counter.text = "Boxes: " + str(boxes_processed_today) + "/" + str(get_current_day_config().total_boxes)

func complete_day() -> void:
	is_day_active = false
	health_system.stop_draining()
	var day_config = get_current_day_config()
	var success = true
	
	print("Day ", current_day, " complete - Processed: ", boxes_processed_correctly, "/", day_config.quota_target)
	
	day_completed.emit(current_day, success)
	current_day += 1
	auto_save_run()
			
	if not success:
		complete_run(false)
	elif current_day > 10:
		complete_run(true)
	else:
		# Start next day after a brief delay
		var box_spawners = get_tree().get_nodes_in_group("BoxSpawner")
		for spawner in box_spawners:
			spawner.label.text = ""
		await get_tree().create_timer(2.0).timeout
		start_day(current_day)

func complete_run(success: bool) -> void:
	run_completed.emit(success)
	ProfileManager.clear_active_run()
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

# Add health depletion handler
func _on_health_depleted() -> void:
	return
	print("FAILED: Health depleted on day %d" % current_day)
	is_day_active = false
	health_system.stop_draining()
	
	# Stop all spawners
	var box_spawners = get_tree().get_nodes_in_group("BoxSpawner")
	for spawner in box_spawners:
		spawner.active = false
	
	day_completed.emit(current_day, false)
	
	get_tree().quit()
