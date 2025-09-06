extends RigidBody3D

class_name Box

# Basic box properties
@export var box_size: Vector3 = Vector3(1, 1, 1)
@export var box_color: Color = Color.BROWN

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
var original_material: StandardMaterial3D
var highlight_material: StandardMaterial3D
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
	
	# Setup basic physics properties
	mass = 1.0
	gravity_scale = 1.0
	
	# Create visual mesh if not already present
	if not has_node("MeshInstance3D"):
		create_box_visual()
	
	# Create collision shape if not already present
	if not has_node("CollisionShape3D"):
		create_box_collision()
	
	# Create highlight materials after visual is ready
	create_highlight_materials()
	create_destination_label()
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
	
	# Create and store original material
	original_material = StandardMaterial3D.new()
	original_material.albedo_color = box_color
	original_material.roughness = 0.8
	mesh_instance.material_override = original_material
	
	add_child(mesh_instance)

func create_highlight_materials():
	# Create highlight material with stencil outline
	highlight_material = StandardMaterial3D.new()
	highlight_material.albedo_color = box_color
	highlight_material.roughness = 0.8
	
	# Add cyan emission for highlighting
	highlight_material.emission_enabled = true
	highlight_material.emission = Color.CYAN
	highlight_material.emission_energy = 0.5
	
	# Try to use Godot 4.5 stencil features
	#highlight_material.stencil_mode = StandardMaterial3D.STENCIL_MODE_OUTLINE
	#highlight_material.stencil_color = Color.CYAN
	#highlight_material.stencil_outline_thickness = 2.0

func set_highlighted(highlighted: bool):
	is_highlighted = highlighted
	var mesh_instance = get_node("MeshInstance3D")
	if mesh_instance:
		if highlighted:
			mesh_instance.material_override = highlight_material
		else:
			mesh_instance.material_override = original_material

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
	var offset = 0.02
	
	# Create icons on the 4 main faces (front, back, left, right)
	var face_configs = [
		{"pos": Vector3(0, 0, half.z + offset), "rot": Vector3(0, 0, 0)},    # front
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
	
func create_destination_label():
	var label = Label3D.new()
	label.name = "DestinationLabel"
	label.text = destination

	label.font_size = 24
	label.modulate = Color(0.1, 0.1, 0.1)
	label.outline_size = 1
	label.outline_modulate = Color.WHITE

	label.scale = Vector3(1, 1, 1)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED

	# Use corner system
	var corner = select_available_corner()
	if corner == "":
		return  # No available corners
	
	position_label_at_corner(label, corner)
	add_child(label)
	
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
	
func _physics_process(delta):
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
	
	# Get all corners that aren't occupied
	for corner_key in corner_positions.keys():
		if corner_key not in occupied_corners:
			available_corners.append(corner_key)
	
	# Return a random available corner, or empty string if none available
	if available_corners.is_empty():
		return ""
	
	var selected_corner = available_corners[randi() % available_corners.size()]
	occupied_corners.append(selected_corner)  # Mark as occupied
	return selected_corner
