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
@onready var outward_particles : GPUParticles3D = $OutwardBoxParticles
@onready var inward_particles : GPUParticles3D = $InwardBoxParticles
var dissolve_duration = 2
var stickers_to_kill : Array[MeshInstance3D] = []

@export var value: int = 10
@export var international: bool = false
@export var disposeable: bool = false
@export var destination: String = "DEN"
var has_valid_destination: bool = false
var all_qualification_icons: Array[Dictionary] = [
	{ "icon": "⚠", "text": "Disposeable", "chance": 0.2 },
	{ "icon": "🌐", "text": "International", "chance": 0.4 },
]
var active_qualification_icons: Array[Dictionary] = []
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
var just_loaded: bool = false

var spawn_location: Vector3

func get_save_data() -> Dictionary:
	var data: Dictionary = {}
	data.box_size = box_size
	data.box_color = box_color
	data.value = value
	data.international = international
	data.disposeable = disposeable
	data.destination = destination
	data.has_valid_destination = has_valid_destination
	data.approval_state = approval_state
	data.active_qualification_icons = active_qualification_icons
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
	international = data.international
	disposeable = data.disposeable
	destination = data.destination
	has_valid_destination = data.has_valid_destination
	approval_state = data.approval_state
	active_qualification_icons = data.active_qualification_icons
	occupied_corners = data.occupied_corners
	global_position = data.global_position
	rotation = data.rotation
	just_loaded = true

func _ready():
	# Add to Box group for pickup detection
	add_to_group("Box")
	
	# Create visual mesh if not already present
	if not has_node("MeshInstance3D"):
		create_box_visual()
	
	# Create collision shape if not already present
	if not has_node("CollisionShape3D"):
		create_box_collision()
	
	create_destination_mesh()
	create_approval_icons()
	
	if just_loaded:
		# Create stickers for explicitly set properties only
		if international:
			var intl_icon = {"icon": "🌐", "text": "International"}
			active_qualification_icons.append(intl_icon)
			create_icon_label(intl_icon)
		if disposeable:
			var disp_icon = {"icon": "⚠", "text": "Disposeable"}
			active_qualification_icons.append(disp_icon)
			create_icon_label(disp_icon)
		update_approval_icons()
	else:
		# Original random generation logic
		for icon in all_qualification_icons:
			if randf() < icon.chance:
				active_qualification_icons.append(icon)
				if icon.text == "Disposeable":
					disposeable = true
				elif icon.text == "International":
					international = true
				create_icon_label(icon)
		update_approval_icons()

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
	#particles.emitting = false
	add_child(mesh_instance)

func set_highlighted(highlighted: bool):
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
	update_approval_icons()
	
func create_approval_icons():
	var half = box_size * 0.5
	var offset = 0.01
	
	# Create icons on the 4 main faces (front, back, left, right)
	var face_configs = [
		{"pos": Vector3(0, 0, -half.z - offset), "rot": Vector3(0, 180, 0)}, # back  
		{"pos": Vector3(-half.x - offset, 0, 0), "rot": Vector3(0, 270, 0)}, # left
		{"pos": Vector3(half.x + offset, 0, 0), "rot": Vector3(0, 90, 0)}    # right
	]
	
	for i in range(face_configs.size()):
		var icon_label = Label3D.new()
		icon_label.name = "ApprovalIcon" + str(i)
		icon_label.font_size = 48
		icon_label.outline_size = 2
		icon_label.outline_modulate = Color.BLACK
		icon_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		icon_label.visible = false  # Start hidden
		
		icon_label.position = face_configs[i].pos
		icon_label.rotation_degrees = face_configs[i].rot
		
		add_child(icon_label)

func update_approval_icons():
	var approval_icons = get_children().filter(func(child): return child.name.begins_with("ApprovalIcon"))
	
	for icon in approval_icons:
		if approval_state == ApprovalState.NONE:
			icon.visible = false
		else:
			icon.visible = true
			icon.text = "✔️" if approval_state == ApprovalState.APPROVED else "❌"
	
#func create_destination_label():
	#var label = Label3D.new()
	#label.name = "DestinationLabel"
	#label.text = destination
#
	#label.font_size = 24
	#label.modulate = Color(0.1, 0.1, 0.1)
	#label.outline_size = 1
	#label.outline_modulate = Color.WHITE
#
	#label.scale = Vector3(1, 1, 1)
	#label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
#
	## Use corner system
	#var corner = select_available_corner()
	#if corner == "":
		#return  # No available corners
	#
	#position_label_at_corner(label, corner)
	#add_child(label)
	
func create_destination_mesh():
	var mesh_instance = destination_mesh.instantiate()
	add_child(mesh_instance)
	mesh_instance.name = "DestinationMesh"
	
	# Center on front face
	var half = box_size * 0.5
	var offset = 0
	mesh_instance.position = Vector3(0, 0, half.z + offset)
	mesh_instance.rotation_degrees = Vector3(0, 0, 0)
	
	# Scale to fit face while maintaining aspect ratio
	scale_mesh_to_face(mesh_instance)
	
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
	
func create_icon_label(icon: Dictionary):
	var icon_label = Label3D.new()
	icon_label.name = "IconLabel"
	icon_label.text = icon.icon
	
	icon_label.font_size = 32
	#icon_label.modulate = Color.ORANGE
	#icon_label.outline_size = 1
	icon_label.outline_modulate = Color.BLACK
	
	icon_label.scale = Vector3(1, 1, 1)
	icon_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	
	var corner = select_available_corner()
	if corner == "":
		return  # No available corners
		
	position_label_at_corner(icon_label, corner)
	add_child(icon_label)
	
func _physics_process(_delta: float):
	# Respawn if fallen through map
	if global_position.y < -50:
		global_position = Vector3(0, 5, 0)
		linear_velocity = Vector3.ZERO
	
func position_label_at_corner(label: Label3D, corner: String):
	var half = box_size * 0.5
	var offset = 0.02
	var inset = 0.15  # Pull labels towards center of face
	
	var parts = corner.split("_")
	var face = int(parts[0])
	var corner_pos = parts[1]
	
	# Check corner position
	var is_left = corner_pos[1] == "L"
	var is_bottom = corner_pos[0] == "B"
	
	match face:
		0: # back
			label.position = Vector3(
				((-half.x + inset) if is_left else (half.x - inset)), 
				((-half.y + inset) if is_bottom else (half.y - inset)), 
				-half.z - offset
			)
			label.rotation_degrees = Vector3(0, 180, 0)
		1: # front  
			label.position = Vector3(
				((-half.x + inset) if is_left else (half.x - inset)), 
				((-half.y + inset) if is_bottom else (half.y - inset)), 
				half.z + offset
			)
			label.rotation_degrees = Vector3(0, 0, 0)
		2: # left
			label.position = Vector3(
				-half.x - offset, 
				((-half.y + inset) if is_bottom else (half.y - inset)), 
				((-half.z + inset) if is_left else (half.z - inset))
			)
			label.rotation_degrees = Vector3(0, 270, 0)
		3: # right
			label.position = Vector3(
				half.x + offset, 
				((-half.y + inset) if is_bottom else (half.y - inset)), 
				((half.z - inset) if is_left else (-half.z + inset))
			)
			label.rotation_degrees = Vector3(0, 90, 0)

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
	gravity_scale = -0.1
	kill_stickers()
	if was_legit:
		await dissolve(1, false, happy_dissolve_highligh_collor)
	else:
		await dissolve(1, false, sad_dissolve_highligh_collor)
	outward_particles.emitting = false
	await get_tree().create_timer(outward_particles.lifetime + 0.1).timeout
	queue_free()
