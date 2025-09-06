extends Node3D

class_name BoxSpawner

@export var spawn_rate: float = 1  # boxes per second
@export var box_scene: PackedScene  # your Box.tscn

# Randomization ranges
@export var min_box_size: Vector3 = Vector3(0.4, 0.4, 0.4)
@export var max_box_size: Vector3 = Vector3(0.8, 0.8, 0.8)
@export var colors: Array[Color] = [Color.PALE_VIOLET_RED, Color.DODGER_BLUE, Color.FOREST_GREEN, Color.SANDY_BROWN]
@export var destinations: Array[String] = ["DEN", "LAX", "JFK", "ORD"]
var active_destinations: Array[String] =  ["DEN", "LAX", "JFK"]

@onready var spawn_area : Area3D = $Area3D
@onready var run_orchestrator = get_tree().get_first_node_in_group("RunOrchestrator")

var boxes_spawned: int = 0
var spawn_timer: float = 0.0
var active: bool = false

func get_save_data() -> Dictionary:
	var data: Dictionary = {}
	data.spawn_rate = spawn_rate
	data.destinations = destinations
	data.active_destinations = active_destinations
	data.boxes_spawned = boxes_spawned
	data.spawn_timer = spawn_timer
	data.active = active
	data.global_position = global_position
	data.rotation = rotation
	return data

func load_save_data(data: Dictionary) -> void:
	spawn_rate = data.spawn_rate
	destinations = data.destinations
	active_destinations = data.active_destinations
	boxes_spawned = data.boxes_spawned
	spawn_timer = data.spawn_timer
	active = data.active
	global_position = data.global_position
	rotation = data.rotation
	if active:
		$Label3D.text = "Click to pause box spawning"
	else:
		$Label3D.text = "Click to start box spawning"

func interact():
	toggle_active()
	
func toggle_active():
	active = !active
	if active:
		$Label3D.text = "Click to pause box spawning"
	else:
		$Label3D.text = "Click to start box spawning"
		
func _process(delta: float) -> void:
	if not active or not run_orchestrator.is_day_active:
		return
	spawn_timer += delta
	if spawn_timer >= 1.0 / spawn_rate:
		spawn_timer = 0.0
		# Check if spawn area is free
		if not is_spawn_blocked():
			spawn_random_box()

func is_spawn_blocked() -> bool:
	return false if spawn_area.get_overlapping_bodies().size() < 4 else true
	
func spawn_random_box() -> void:
	spawn_box_with_properties({})

func spawn_box_with_properties(properties: Dictionary) -> void:
	var box = box_scene.instantiate() as Box
	
	# Apply default randomization first
	box.box_size = Vector3(
		randf_range(min_box_size.x, max_box_size.x),
		randf_range(min_box_size.y, max_box_size.y),
		randf_range(min_box_size.z, max_box_size.z)
	)
	box.box_color = colors[randi() % colors.size()]
	
	# Override with specific properties from LevelManager
	if properties.has("destination"):
		box.destination = properties.destination
	else:
		box.destination = destinations[randi() % destinations.size()]
	
	if properties.has("international"):
		box.international = properties.international
	else:
		box.international = false
	
	if properties.has("disposable"):
		box.disposeable = properties.disposable
	else:
		box.disposeable = false
	
	# Set validity based on active destinations
	if run_orchestrator and run_orchestrator.current_run_config:
		var matching_holes = run_orchestrator.current_run_config.box_holes.filter(func(hole):
			return hole.active and hole.destination == box.destination and hole.international == box.international and not hole.is_disposal
			)
		box.has_valid_destination = not matching_holes.is_empty()
	else:
		box.has_valid_destination = false
	
	box.just_loaded = true
	get_tree().root.get_node("MainLevel").add_child(box)
	box.global_position = $Marker3D.global_position
	boxes_spawned += 1
