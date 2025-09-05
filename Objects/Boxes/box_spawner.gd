extends Node3D

class_name BoxSpawner

@export var total_boxes: int = 500
@export var spawn_rate: float = 1  # boxes per second
@export var box_scene: PackedScene  # your Box.tscn

# Randomization ranges
@export var min_box_size: Vector3 = Vector3(0.4, 0.4, 0.4)
@export var max_box_size: Vector3 = Vector3(0.8, 0.8, 0.8)
@export var colors: Array[Color] = [Color.PALE_VIOLET_RED, Color.DODGER_BLUE, Color.FOREST_GREEN, Color.SANDY_BROWN]
@export var destinations: Array[String] = ["DEN", "LAX", "JFK", "ORD"]
var active_destinations: Array[String] =  ["DEN", "LAX", "JFK"]

@onready var spawn_area : Area3D = $Area3D

var boxes_spawned: int = 0
var spawn_timer: float = 0.0
var active: bool = false

func get_save_data() -> Dictionary:
	var data: Dictionary = {}
	data.total_boxes = total_boxes
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
	total_boxes = data.total_boxes
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
	active = !active
	if active:
		$Label3D.text = "Click to pause box spawning"
	else:
		$Label3D.text = "Click to start box spawning"

func _process(delta: float) -> void:
	if boxes_spawned >= total_boxes or !active:
		if active:
			active = false
			print("All boxes spawned!")
		return

	spawn_timer += delta
	if spawn_timer >= 1.0 / spawn_rate:
		spawn_timer = 0.0
		# Check if spawn area is free
		if not is_spawn_blocked():
			spawn_box()

func is_spawn_blocked() -> bool:
	return false if spawn_area.get_overlapping_bodies().size() == 0 else true

func spawn_box() -> void:
	var box = box_scene.instantiate() as Box
	box.box_size = Vector3(
		randf_range(min_box_size.x, max_box_size.x),
		randf_range(min_box_size.y, max_box_size.y),
		randf_range(min_box_size.z, max_box_size.z)
	)
	box.box_color = colors[randi() % colors.size()]
	box.destination = destinations[randi() % destinations.size()]
	box.has_valid_destination = active_destinations.has(box.destination)

	get_tree().root.get_node("MainLevel").add_child(box)
	box.global_position = $Marker3D.global_position
	boxes_spawned += 1
