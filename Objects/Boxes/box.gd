extends RigidBody3D

class_name Box

# Basic box properties
@export var box_size: Vector3 = Vector3(1, 1, 1)
@export var box_color: Color = Color.BROWN

@export var sad_dissolve_highligh_collor: Color = Color.from_rgba8(255, 97, 97, 1)
@export var happy_dissolve_highligh_collor: Color = Color.from_rgba8(123, 246, 0, 1)
@export var sticker_color: Color = Color.from_rgba8(240, 94, 28, 1)

var box_shader = preload("res://Art_Assets/Shaders/Box Dissolve/box_dissolve.tres")
var destination_mesh = preload("res://Objects/Boxes/destination_sticker.tscn")
var disposable_mesh = preload("res://Objects/Boxes/disposable_sticker.tscn")
var international_mesh = preload("res://Objects/Boxes/needs_inspection_sticker.tscn")
@onready var outward_particles : GPUParticles3D = $OutwardBoxParticles
@onready var inward_particles : GPUParticles3D = $InwardBoxParticles
@onready var approval_particles : GPUParticles3D = $ApprovalParticles
@onready var rejection_particles : GPUParticles3D = $RejectionParticles
var dissolve_duration = 2
var stickers_to_kill : Array[MeshInstance3D] = []

@export var value: int = 10
@export var needs_inspection: bool = false
@export var disposable: bool = false
@export var destination: Destination
var has_valid_destination: bool = false

enum ApprovalState {
	NONE,
	APPROVED, 
	REJECTED
}
var approval_state: ApprovalState = ApprovalState.NONE

# Corner tracking system
var occupied_corners: Array[String] = []  # Track which corners are taken

# Corner positions for each face (face_corner format)
var corner_positions = {
	"0_TL": Vector3(-1, 1, -1),    # back top-left
	"0_TR": Vector3(1, 1, -1),     # back top-right  
	"0_BL": Vector3(-1, -1, -1),   # back bottom-left
	"0_BR": Vector3(1, -1, -1),    # back bottom-right
	"1_TL": Vector3(-1, 1, 1),     # front top-left
	"1_TR": Vector3(1, 1, 1),      # front top-right
	"1_BL": Vector3(-1, -1, 1),    # front bottom-left
	"1_BR": Vector3(1, -1, 1),     # front bottom-right
	"2_TL": Vector3(-1, 1, -1),    # left top-left
	"2_TR": Vector3(-1, 1, 1),     # left top-right
	"2_BL": Vector3(-1, -1, -1),   # left bottom-left
	"2_BR": Vector3(-1, -1, 1),    # left bottom-right
	"3_TL": Vector3(1, 1, 1),      # right top-left
	"3_TR": Vector3(1, 1, -1),     # right top-right
	"3_BL": Vector3(1, -1, 1),     # right bottom-left
	"3_BR": Vector3(1, -1, -1)     # right bottom-right
}

# Highlighting system
var original_material: ShaderMaterial
var is_highlighted: bool = false
var fog_tween: Tween
var just_loaded: bool = false

var spawn_location: Vector3

@onready var camera = get_viewport().get_camera_3d()
var star_offset: Vector2 = Vector2.ZERO
var last_camera_position: Vector3
var last_camera_rotation: Vector3

func get_save_data() -> Dictionary:
	var data: Dictionary = {}
	data.box_size = box_size
	data.box_color = box_color
	data.value = value
	data.needs_inspection = needs_inspection
	data.disposable = disposable
	data.destination = destination
	data.has_valid_destination = has_valid_destination
	data.approval_state = approval_state
	data.occupied_corners = occupied_corners
	data.scene_path = scene_file_path
	data.global_position = global_position
	data.rotation = rotation
	data.type = get_script().get_global_name()
	return data

func load_save_data(data: Dictionary) -> void:
	box_size = data.box_size
	box_color = data.box_color
	value = data.value
	needs_inspection = data.needs_inspection
	disposable = data.disposable
	destination = data.destination
	has_valid_destination = data.has_valid_destination
	approval_state = data.approval_state
	occupied_corners = data.occupied_corners
	global_position = data.global_position
	rotation = data.rotation
	just_loaded = true
	
func _ready():
	if camera:
		last_camera_position = camera.global_position
		last_camera_rotation = camera.global_rotation
	# Add to Box group for pickup detection
	add_to_group("Box")
	
	# Create visual mesh if not already present
	if not has_node("MeshInstance3D"):
		create_box_visual()
	
	# Create collision shape if not already present
	if not has_node("CollisionShape3D"):
		create_box_collision()
	
	create_destination_mesh()
	
	if just_loaded:
		if needs_inspection:
			create_international_mesh()
		if disposable:
			create_disposable_mesh()
	update_approval_state()


func create_box_visual():
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = box_size
	mesh_instance.mesh = box_mesh
	mesh_instance.name = "MeshInstance3D"

	original_material = ShaderMaterial.new()
	original_material.shader = box_shader.duplicate()
	original_material.set_shader_parameter("Box_Color", box_color)
	mesh_instance.material_override = original_material
	
	inward_particles.process_material.emission_box_extents = box_size
	outward_particles.process_material.emission_box_extents = box_size * 0.7
	approval_particles.process_material.emission_box_extents = box_size
	rejection_particles.process_material.emission_box_extents = box_size
	#particles.emitting = false
	add_child(mesh_instance)

func set_highlighted(highlighted: bool):
	return
	is_highlighted = highlighted
	var mesh_instance = get_node("MeshInstance3D")
	if mesh_instance:
		if highlighted:
			mesh_instance.material_override.set_shader_parameter("Box_Color", Color.CYAN)
		else:
			mesh_instance.material_override.set_shader_parameter("Box_Color", box_color)

func create_box_collision():
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = box_size
	
	collision_shape.shape = box_shape
	collision_shape.name = "CollisionShape3D"
	
	add_child(collision_shape)
	
func set_approval_state(state: ApprovalState):
	approval_state = state
	if original_material != null:
		update_approval_state()

func update_approval_state():
	match approval_state:
		ApprovalState.APPROVED:
			set_fog_color_animated(Color.GREEN)
			approval_particles.restart()
			approval_particles.emitting = true
		ApprovalState.REJECTED:
			set_fog_color_animated(Color.RED)
			rejection_particles.restart()
			rejection_particles.emitting = true
		_:
			set_fog_color_animated(Color.BLACK)
			
func set_fog_color_animated(target_color: Color, duration: float = 1.0):
	# Kill existing tween if running
	if fog_tween:
		fog_tween.kill()
	
	fog_tween = create_tween()
	var current_color = original_material.get_shader_parameter("Fog_Color")
	
	if current_color == null:
		current_color = Vector3(0, 0, 0)
	
	fog_tween.tween_method(
		func(color): original_material.set_shader_parameter("Fog_Color", color),
		current_color,
		Vector3(target_color.r, target_color.g, target_color.b),
		duration
	)
	
func create_destination_mesh():
	var mesh_instance = destination_mesh.instantiate()
	add_child(mesh_instance)
	mesh_instance.mesh_instance.mesh = destination.symbol_mesh 
	mesh_instance.name = "DestinationMesh"
	
	# Center on front face
	var half = box_size * 0.5
	var offset = 0
	mesh_instance.position = Vector3(0, 0, half.z + offset)
	mesh_instance.rotation_degrees = Vector3(0, 0, 0)
	
	# Scale to fit face while maintaining aspect ratio
	scale_mesh_to_face(mesh_instance)
	
	stickers_to_kill.append(mesh_instance.get_child(0))
	
func create_disposable_mesh():
	disposable = true
	var mesh_instance = disposable_mesh.instantiate()
	add_child(mesh_instance)
	mesh_instance.name = "disposableMesh"
	
	# Use corner system like the old labels
	var corner = select_available_corner()
	if corner == "":
		return  # No available corners
		
	position_mesh_at_corner(mesh_instance, corner)
	stickers_to_kill.append(mesh_instance.get_child(0))

func create_international_mesh():
	needs_inspection = true
	var mesh_instance = international_mesh.instantiate()
	add_child(mesh_instance)
	mesh_instance.name = "InternationalMesh"
	
	# Use corner system like the old labels
	var corner = select_available_corner()
	if corner == "":
		return  # No available corners
		
	position_mesh_at_corner(mesh_instance, corner)
	stickers_to_kill.append(mesh_instance.get_child(0))

func scale_mesh_to_face(mesh_parent: Node3D):
	var mesh_child = mesh_parent.get_child(0)
	var mesh_aabb = mesh_child.mesh.get_aabb()
	
	# Apply transform to get actual bounds
	var transformed_aabb = mesh_child.transform * mesh_aabb
	
	var face_size = Vector2(box_size.x, box_size.y) * 0.8
	
	var scale_x = face_size.x / transformed_aabb.size.x
	var scale_y = face_size.y / transformed_aabb.size.y
	var uniform_scale = min(scale_x, scale_y)
	
	mesh_parent.scale = Vector3(uniform_scale, uniform_scale, uniform_scale)
	
func position_mesh_at_corner(mesh_instance: Node3D, corner: String):
	var half = box_size * 0.5
	var offset = 0
	var inset = 0.15  # Pull meshes towards center of face
	
	var parts = corner.split("_")
	var face = int(parts[0])
	var corner_pos = parts[1]
	
	# Check corner position
	var is_left = corner_pos[1] == "L"
	var is_bottom = corner_pos[0] == "B"
	
	match face:
		0: # back
			mesh_instance.position = Vector3(
				((-half.x + inset) if is_left else (half.x - inset)), 
				((-half.y + inset) if is_bottom else (half.y - inset)), 
				-half.z - offset
			)
			mesh_instance.rotation_degrees = Vector3(0, 180, 0)
		2: # left
			mesh_instance.position = Vector3(
				-half.x - offset, 
				((-half.y + inset) if is_bottom else (half.y - inset)), 
				((-half.z + inset) if is_left else (half.z - inset))
			)
			mesh_instance.rotation_degrees = Vector3(0, 270, 0)
		3: # right
			mesh_instance.position = Vector3(
				half.x + offset, 
				((-half.y + inset) if is_bottom else (half.y - inset)), 
				((-half.z + inset) if is_left else (half.z - inset))
			)
			mesh_instance.rotation_degrees = Vector3(0, 90, 0)
	
	# Scale mesh to appropriate corner size
	scale_mesh_to_corner(mesh_instance)
	
func scale_mesh_to_corner(mesh_parent: Node3D):
	var mesh_child = mesh_parent.get_child(0)
	var mesh_aabb = mesh_child.mesh.get_aabb()
	
	# Apply transform to get actual bounds
	var transformed_aabb = mesh_child.transform * mesh_aabb
	
	# Corner size should be smaller than face size
	var corner_size = Vector2(box_size.x, box_size.y) * 0.3  # 30% of face size
	
	var scale_x = corner_size.x / transformed_aabb.size.x
	var scale_y = corner_size.y / transformed_aabb.size.y
	var uniform_scale = min(scale_x, scale_y)
	
	mesh_parent.scale = Vector3(uniform_scale, uniform_scale, uniform_scale)
	
func _process(_delta: float):
	if camera:
		var current_cam_pos = camera.global_position
		var current_cam_rot = camera.global_rotation
		
		var camera_movement = current_cam_pos - last_camera_position
		var rotation_delta_x = angle_difference(last_camera_rotation.x, current_cam_rot.x)
		var rotation_delta_y = angle_difference(last_camera_rotation.y, current_cam_rot.y)
		
		# Movement affects stars
		star_offset.x += camera_movement.x * 0.02
		star_offset.y += camera_movement.z * 0.02
		
		# Rotation also affects stars (spinning in place)
		star_offset.x += rotation_delta_y * -0.05
		star_offset.y += rotation_delta_x * 0.05
		
		original_material.set_shader_parameter("Parallax_Offset", star_offset)
		
		last_camera_position = current_cam_pos
		last_camera_rotation = current_cam_rot
	
func _physics_process(_delta: float):
	# Respawn if fallen through map
	if global_position.y < -50:
		global_position = Vector3(0, 5, 0)
		linear_velocity = Vector3.ZERO

func select_available_corner() -> String:
	var available_corners: Array[String] = []
	
	# Get all corners that aren't occupied and not on front face (face 1)
	for corner_key in corner_positions.keys():
		if corner_key not in occupied_corners and not corner_key.begins_with("1_"):
			available_corners.append(corner_key)
	
	if available_corners.is_empty():
		return ""
	
	var selected_corner = available_corners[randi() % available_corners.size()]
	occupied_corners.append(selected_corner)
	return selected_corner
	
func dissolve(target_value: float, inward: bool = true, target_color: Color = sad_dissolve_highligh_collor):
	var particles : GPUParticles3D = inward_particles if inward else outward_particles
	particles.emitting = true
	var tween = create_tween()
	original_material.set_shader_parameter("Light_Color", target_color)
	if target_value < 0:
		original_material.set_shader_parameter("Progress", 1.0)
	else:
		original_material.set_shader_parameter("Progress", -0.15)

	tween.tween_property(original_material, "shader_parameter/Progress", target_value, dissolve_duration)
	return get_tree().create_timer(dissolve_duration - particles.lifetime + 0.1).timeout

func kill_stickers():
	var tween = create_tween()
	
	for mesh in stickers_to_kill:
		mesh.reparent(get_tree().root.get_node("MainLevel"))
		tween.parallel().tween_property(mesh, "transparency", 1, 1.6)
		tween.parallel().tween_property(mesh, "scale", mesh.scale * 24, 1.7)
		
	tween.tween_callback(func(): 
		for mesh in stickers_to_kill:
			mesh.queue_free()
	)
	
	return tween.finished

func die(was_legit: bool):  # Recursively check nested children
	remove_from_group("Box")
	gravity_scale = -0.1
	kill_stickers()
	if was_legit:
		await dissolve(1, false, happy_dissolve_highligh_collor)
	else:
		await dissolve(1, false, sad_dissolve_highligh_collor)
	outward_particles.emitting = false
	await get_tree().create_timer(outward_particles.lifetime + 0.1).timeout
	queue_free()
