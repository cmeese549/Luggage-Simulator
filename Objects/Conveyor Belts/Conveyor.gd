extends Buildable

class_name Conveyor

@export var belt_speed: float = 1.0
@export var is_attached_to_building: bool = false
@export var belt_direction: Vector3 = Vector3(0, 0, 1)
@export var is_corner: bool = false
@export var input_direction: Vector3 = Vector3(0, 0, -1) # Direction items come from
@export var corner_pull_strength: float = 0.6 # How much to pull from input direction
@export var corner_curve_sharpness: float = 1.0 # Higher = sharper transition
@export var corner_speed_multiplier: float = 1.1 # Slightly faster on corners
@export var corner_offset_bias: float = 0.0 # Shift transition point (-0.5 to 0.5)
@export var rotation_offset: float = -0.3

var collision_shapes : Array[CollisionShape3D]
@onready var building_system = get_tree().get_first_node_in_group("BuildingSystem")

var material: StandardMaterial3D
var uv_offset: float = 0.0

var is_ready = false
var reversed: bool = false

func get_save_data() -> Dictionary:
	var data: Dictionary = {}
	data.belt_speed = belt_speed
	data.is_attached_to_building = is_attached_to_building
	data.belt_direction = belt_direction
	data.is_corner = is_corner
	data.input_direction = input_direction
	data.corner_pull_strength = corner_pull_strength
	data.corner_curve_sharpness = corner_curve_sharpness
	data.corner_speed_multiplier = corner_speed_multiplier
	data.corner_offset_bias = corner_offset_bias
	data.rotation_offset = rotation_offset
	data.reversed = reversed
	data.is_ready = is_ready
	return data

func load_save_data(_data: Dictionary) -> void:
	belt_speed = _data.belt_speed
	is_attached_to_building = _data.is_attached_to_building
	belt_direction = _data.belt_direction
	is_corner = _data.is_corner
	input_direction = _data.input_direction
	corner_pull_strength = _data.corner_pull_strength
	corner_curve_sharpness = _data.corner_curve_sharpness
	corner_speed_multiplier = _data.corner_speed_multiplier
	corner_offset_bias = _data.corner_offset_bias
	rotation_offset = _data.rotation_offset
	reversed = _data.reversed
	is_ready = _data.is_ready
	if not is_attached_to_building:
		global_position = _data.global_position
		rotation = _data.rotation
	is_built = true

func _ready():
	var shapes = find_children("*", "CollisionShape3D", true, false)
	for shape in shapes:
		if shape.get_parent().is_in_group("Belt"):
			collision_shapes.append(shape)
	if is_built:
		on_object_built()
	if not is_built:
		apply_building_rotation()
		
func on_object_built():
	is_built = true
	 # Calculate belt direction from the object's actual rotation
	var current_rotation = rotation_degrees.y
	update_belt_direction_from_rotation(current_rotation)
	
	# For corners, also update input direction
	if is_corner:
		update_input_direction_from_rotation(current_rotation)
	
	if is_attached_to_building:
		apply_building_rotation()
		
	setup_direction_and_physics()
	load_rotation_offset()
	$Label3D.visible = false
	
func apply_building_rotation():
	if building_system:
		var _rotation_degrees = rotation_degrees.y + building_system.get_object_rotation_degrees() if is_attached_to_building else building_system.get_object_rotation_degrees()
		update_belt_direction_from_rotation(_rotation_degrees)
		if is_corner:
			update_input_direction_from_rotation(_rotation_degrees)
			
func apply_default_rotation():
	update_belt_direction_from_rotation(rotation_degrees.y)
	if is_corner:
		update_input_direction_from_rotation(rotation_degrees.y)

func update_belt_direction_from_rotation(y_rotation: float):
	var angle_rad = deg_to_rad(y_rotation)
	belt_direction = Vector3(sin(angle_rad), 0, cos(angle_rad)).normalized()
	# Remove the reversal logic from here

func update_input_direction_from_rotation(y_rotation: float):
	var angle_rad = deg_to_rad(y_rotation - 90)
	input_direction = Vector3(sin(angle_rad), 0, cos(angle_rad)).normalized()
	# Remove the reversal logic from here

func calculate_corner_progress(segment_position: Vector3) -> float:
	var corner_center = global_position
	var to_segment = segment_position - corner_center
	
	var input_dot = to_segment.dot(input_direction)
	var output_dot = to_segment.dot(belt_direction)
	
	var angle = atan2(output_dot, input_dot)
	var progress = clamp((angle + PI / 2) / PI, 0.0, 1.0)
	
	# Apply bias and curve sharpness
	progress = clamp(progress + corner_offset_bias, 0.0, 1.0)
	progress = pow(progress, corner_curve_sharpness)
	
	return progress

func setup_direction_and_physics():
	var static_bodies = find_children("*", "StaticBody3D", true, false)

	for body in static_bodies:
		if body is StaticBody3D and body.is_in_group("Belt"):
			var speed = belt_speed
			if body.is_in_group("Booster"):
				speed *= 4
			if is_corner:
				var corner_progress = calculate_corner_progress(body.global_position)
				var transition_direction = input_direction.slerp(belt_direction, corner_progress)
				
				# Simply invert the direction if reversed
				if reversed:
					transition_direction *= -1
					
				body.constant_linear_velocity = transition_direction * speed * corner_speed_multiplier
			else:
				var final_direction = belt_direction
				if reversed:
					final_direction *= -1
					var meshes = find_children("*", "MeshInstance3D", true, false)
					for mesh in meshes:
						if mesh.is_in_group("ConveyorMesh"):
							mesh.rotation = Vector3(mesh.rotation.x, deg_to_rad(180), mesh.rotation.z)
							mesh.position = Vector3(-0.095, 0, 0.204)
				else:
					var meshes = find_children("*", "MeshInstance3D", true, false)
					for mesh in meshes:
						if mesh.is_in_group("ConveyorMesh"):
							mesh.rotation = Vector3(mesh.rotation.x, 0, mesh.rotation.z)
							mesh.position = Vector3(0, 0, 0)
				body.constant_linear_velocity = final_direction * speed
	
func load_rotation_offset() -> void:
	if is_corner:
		return
	for collision_shape in collision_shapes:
		if reversed:
			collision_shape.rotation_degrees = Vector3(rotation_offset * -1, 0, 0)
		else:
			collision_shape.rotation_degrees = Vector3(rotation_offset, 0, 0)
	
func set_belt_reversed(is_reversed) -> void:
	if is_attached_to_building:
		return
	reversed = is_reversed
	
	if is_reversed:
		if is_corner:
			$Label3D.rotation_degrees.y = 180
		else:
			if not is_corner:
				for collision_shape in collision_shapes:
					collision_shape.rotation_degrees = Vector3(rotation_offset * -1, 0, 0)
				belt_direction *= -1
				$Label3D.rotation_degrees.y = 270
			else:
				$Label3D.rotation_degrees.y = 0
	else:
		for collision_shape in collision_shapes:
			collision_shape.rotation_degrees = Vector3(rotation_offset, 0, 0)
		belt_direction *= -1
		$Label3D.rotation_degrees.y = 90
	setup_direction_and_physics()
