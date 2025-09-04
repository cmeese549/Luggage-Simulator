extends Node3D

class_name BuildingSystem

@onready var building_ui = get_tree().get_first_node_in_group("BuildingUI")
@onready var destroy_ui = get_tree().get_first_node_in_group("DestroyUI")
@onready var player: Player = get_tree().get_first_node_in_group("Player")

@export var level_generator: Node3D
var tile_size
var grid_width
var grid_height

var building_mode_active: bool = false
var grid_positions: Array[Vector3] = []

var cursor_position: Vector3
var valid_cursor_position: bool = false

var grid_visual_container: Node3D
var cursor_indicator: MeshInstance3D

@export var buildable_objects: Array[PackedScene] = []
var selected_object_index: int = 0

var ghost_object: Node3D

var reverse_belt: bool = false

var current_rotation: int = 0  # 0, 1, 2, 3 for 0°, 90°, 180°, 270°

var destroy_mode_active: bool = false


func _ready():
	# Get values directly from level generator
	tile_size = level_generator.tile_size
	grid_width = level_generator.width
	grid_height = level_generator.height
	generate_grid_positions()

func toggle_building_mode():
	building_mode_active = !building_mode_active
	
	# Clear destroy preview when entering build mode
	if building_mode_active and destroy_mode_active:
		clear_destroy_preview()
		destroy_ui.get_child(0).play_backwards("fade_destroy_border")
		destroy_mode_active = false
	
	if not building_mode_active and ghost_object:
		ghost_object.queue_free()
		ghost_object = null
	elif building_mode_active:
		reverse_belt = false
		
	if building_ui:
		if building_mode_active:
			building_ui.show_ui()
		else:
			building_ui.hide_ui()
		
func toggle_destroy_mode():
	if destroy_mode_active:
		destroy_ui.get_child(0).play_backwards("fade_destroy_border")
	else:
		destroy_ui.get_child(0).play("fade_destroy_border")
	destroy_mode_active = !destroy_mode_active
	
	# Clear building ghost when entering destroy mode
	if destroy_mode_active and building_mode_active:
		if building_ui:
			building_ui.hide_ui()
		building_mode_active = false
		if ghost_object:
			ghost_object.queue_free()
			ghost_object = null
	
	if not destroy_mode_active:
		clear_destroy_preview()

func rotate_object(direction: int = 1):
	if not building_mode_active:
		return
		
	current_rotation += direction
	
	# Wrap around (0-3)
	if current_rotation > 3:
		current_rotation = 0
	elif current_rotation < 0:
		current_rotation = 3

func get_object_rotation_degrees() -> float:
	return current_rotation * 90.0

func update_ghost_preview():
	if not building_mode_active or not valid_cursor_position:
		if ghost_object:
			ghost_object.visible = false
		return
	
	if buildable_objects.is_empty() or selected_object_index >= buildable_objects.size():
		return
	
	# Only create new ghost if we don't have one or if object type changed
	if not ghost_object or ghost_object.scene_file_path != buildable_objects[selected_object_index].resource_path:
		if ghost_object:
			ghost_object.queue_free()
		
		var object_scene = buildable_objects[selected_object_index]
		ghost_object = object_scene.instantiate()
		ghost_object.is_built = false
		setup_ghost_object(ghost_object)
		add_child(ghost_object, true)
	
	# Just update existing ghost position/rotation
	ghost_object.visible = true
	ghost_object.position = cursor_position
	ghost_object.rotation_degrees.y = get_object_rotation_degrees()
	if ghost_object.has_method("set_belt_reversed"):
		ghost_object.set_belt_reversed(reverse_belt)
	update_ghost_color()
	
func update_ghost_color():
	if not ghost_object:
		print("No Ghost Object")
		return
	
	var material = 0 if %Money.check_can_buy(ghost_object.price) and can_build_at_position(cursor_position) else 1
	ghost_object.material_index = material
	
func setup_ghost_object(obj: Node3D):
	# Apply ghost material to all mesh instances
	var material = 0 if can_build_at_position(cursor_position) else 1
	ghost_object.material_index = material
	
	# Disable physics/collision for the ghost
	disable_ghost_physics(obj)

func disable_ghost_physics(node: Node):
	if node is RigidBody3D or node is CharacterBody3D or node is StaticBody3D:
		node.set_collision_layer(0)
		node.set_collision_mask(0)
	elif node is CollisionShape3D:
		node.disabled = true
	
	# Recursively disable for children
	for child in node.get_children():
		disable_ghost_physics(child)
		
func eyedropper_select_buildable(buildable: Buildable):
	if not buildable:
		return
	var target_scene_path = buildable.scene_file_path
	
	# Find which category contains this buildable
	if building_ui:
		building_ui.select_buildable_by_scene_path(target_scene_path)
	
	# Enter building mode if not already active
	if not building_mode_active:
		toggle_building_mode()
	
func cycle_selected_object(direction: int = 1):
	if buildable_objects.is_empty():
		return
	
	selected_object_index += direction
	
	# Handle wrapping in both directions
	if selected_object_index >= buildable_objects.size():
		selected_object_index = 0
	elif selected_object_index < 0:
		selected_object_index = buildable_objects.size() - 1
		
	if building_ui and building_ui.visible:
		building_ui.update_buildable_selection()

func get_selected_object_name() -> String:
	if buildable_objects.is_empty() or selected_object_index >= buildable_objects.size():
		return "None"
	return buildable_objects[selected_object_index].resource_path.get_file().get_basename()
	
func can_build_at_position(grid_pos: Vector3) -> bool:
	if not ghost_object:
		return false
	
	# Use the ghost object's collision shape to test
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	
	# Get the collision shape from the ghost object
	var collision_shape = ghost_object.find_child("BuildingCollider").get_child(0).shape
	if not collision_shape:
		print("NO collision shape for ")
		print(ghost_object.name)
		return true  # No collider means we can place it
	
	query.shape = collision_shape
	query.transform = Transform3D(Basis().rotated(Vector3.UP, deg_to_rad(get_object_rotation_degrees())), grid_pos)
	query.collision_mask = 1  # Adjust to match your collision layers
	
	var result = space_state.intersect_shape(query)
	return result.is_empty()

func place_object_at_cursor():
	if not building_mode_active or not valid_cursor_position:
		return
		
	if not can_build_at_position(cursor_position):
		return
		
	if buildable_objects.is_empty() or selected_object_index >= buildable_objects.size():
		return
		
	
	# Directly instantiate and place the object
	var object_scene = buildable_objects[selected_object_index]
	var object_instance = object_scene.instantiate()
	if not %Money.try_buy(object_instance.price):
		object_instance.queue_free()
		return
	object_instance.position = cursor_position
	object_instance.rotation_degrees.y = get_object_rotation_degrees()
	
	# Apply belt reversal for conveyors
	if object_instance.has_method("set_belt_reversed"):
			object_instance.set_belt_reversed(reverse_belt)
	
	add_child(object_instance)
	
	if object_instance.has_method("on_object_built"):
		object_instance.on_object_built()
	
func update_cursor_position(player_raycast: RayCast3D):
	if not building_mode_active and not destroy_mode_active:
		valid_cursor_position = false
		return
		
	if player_raycast.is_colliding():
		var hit_point = player_raycast.get_collision_point()
		cursor_position = get_nearest_grid_position(hit_point)
		valid_cursor_position = true
	else:
		valid_cursor_position = false
	
	if destroy_mode_active:
		update_destroy_ghost_preview()
	else:
		update_ghost_preview()

func get_nearest_grid_position(world_pos: Vector3) -> Vector3:
	var closest_pos = grid_positions[0]
	var closest_distance = world_pos.distance_to(closest_pos)
	
	for grid_pos in grid_positions:
		var distance = world_pos.distance_to(grid_pos)
		if distance < closest_distance:
			closest_distance = distance
			closest_pos = grid_pos
	
	return closest_pos

func generate_grid_positions():
	grid_positions.clear()
	
	# Calculate the same offset as your level generator for centering
	var offset_x = -((grid_width - 1) * tile_size) / 2.0
	var offset_z = -((grid_height - 1) * tile_size) / 2.0
	
	# Create grid positions that match floor tile positions
	for x in range(grid_width):
		for z in range(grid_height):
			var grid_pos = Vector3(x * tile_size + offset_x, 0, z * tile_size + offset_z)
			grid_positions.append(grid_pos)

func destroy_object_at_cursor():
	if not destroy_mode_active or not valid_cursor_position:
		return
		
	var buildable_to_destroy = find_buildable_at_position(player.delete_cast)
	if buildable_to_destroy and buildable_to_destroy.is_built:
		buildable_to_destroy.die()
		

func find_buildable_at_position(caster: RayCast3D) -> Buildable:
	# Use a shape query at the cursor position instead of distance checking
	if caster.is_colliding():
		var current_node = caster.get_collider()
		while current_node:
			if current_node is Buildable and current_node.is_built:
				return current_node
			current_node = current_node.get_parent()
	return null
	
func update_destroy_ghost_preview():
	if not destroy_mode_active or not valid_cursor_position:
		clear_destroy_preview()
		return
	
	var buildable_to_destroy = find_buildable_at_position(player.delete_cast)
	
	if buildable_to_destroy and buildable_to_destroy.is_built:
		if ghost_object != buildable_to_destroy:
			clear_destroy_preview()  # Clear previous
			ghost_object = buildable_to_destroy
			ghost_object.set_destroy_preview(true)
	else:
		clear_destroy_preview()

func clear_destroy_preview():
	if ghost_object and ghost_object.is_built:
		ghost_object.set_destroy_preview(false)
		ghost_object = null
