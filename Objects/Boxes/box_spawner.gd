extends Node3D

class_name BoxSpawner

@export var spawn_rate: float = 1  # boxes per second
@export var box_scene: PackedScene  # your Box.tscn

signal clicked(spawner: BoxSpawner)

# Randomization ranges
@export var min_box_size: Vector3 = Vector3(0.4, 0.4, 0.4)
@export var max_box_size: Vector3 = Vector3(0.8, 0.8, 0.8)
@export var colors: Array[Color] = [Color.BLACK, Color.MIDNIGHT_BLUE, Color.SLATE_GRAY, Color.DIM_GRAY]

@onready var spawn_area : Area3D = $Area3D
@onready var label : Label3D = $Label3D
@onready var run_orchestrator = get_tree().get_first_node_in_group("RunOrchestrator")

var boxes_spawned: int = 0
var spawn_timer: float = 0.0
var active: bool = false

func get_save_data() -> Dictionary:
	var data: Dictionary = {}
	data.spawn_rate = spawn_rate
	data.boxes_spawned = boxes_spawned
	data.spawn_timer = spawn_timer
	data.active = active
	data.global_position = global_position
	data.rotation = rotation
	return data

func load_save_data(data: Dictionary) -> void:
	spawn_rate = data.spawn_rate
	boxes_spawned = data.boxes_spawned
	spawn_timer = data.spawn_timer
	active = data.active
	global_position = data.global_position
	rotation = data.rotation

func interact():
	clicked.emit(self)
	
func toggle_active():
	active = !active

func is_spawn_blocked() -> bool:
	return false if spawn_area.get_overlapping_bodies().size() < 2 else true
	
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
	box.destination = properties.destination
	
	if properties.has("needs_inspection"):
		box.needs_inspection = properties.needs_inspection
	else:
		box.needs_inspection = false
	
	if properties.has("disposable"):
		box.disposable = properties.disposable
	else:
		box.disposable = false

	if properties.has("cursed"):
		box.cursed = properties.cursed
	else:
		box.cursed = false
	
	# Set validity based on active destinations
	if run_orchestrator and run_orchestrator.current_run_config:
		var matching_holes = run_orchestrator.current_run_config.box_holes.filter(func(hole):
			return hole.active and hole.destination != null and box.destination != null and hole.destination.id == box.destination.id and hole.needs_inspection == box.needs_inspection and not hole.is_disposal
			)
		box.has_valid_destination = not matching_holes.is_empty()
	else:
		box.has_valid_destination = false
	
	box.just_loaded = true
	get_tree().root.get_node("MainLevel").add_child(box)
	box.global_position = $Marker3D.global_position
	box.spawn_location = $Marker3D.global_position
	boxes_spawned += 1
