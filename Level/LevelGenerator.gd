@tool
extends Node3D

# Export variables that will appear in the inspector
@export var width: int = 10:
	set(value):
		width = max(1, value)
		
@export var height: int = 10:
	set(value):
		height = max(1, value)

# Asset paths - update these to match your asset locations
@export_file("*.tscn") var floor_tile_scene: String = ""
@export_file("*.tscn") var wall_tile_scene: String = ""

# Tile size - adjust based on your assets
@export var tile_size: float = 1.0

# Generation button
@export var generate_level: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_generate_level()

# Clear button
@export var clear_level: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_clear_level()

# Container for generated tiles
var tile_container: Node3D

#func _ready():
	## Create container if it doesn't exist
	#if not tile_container:
		#tile_container = Node3D.new()
		#tile_container.name = "GeneratedTiles"
		#add_child(tile_container)
		## Set ownership after adding to tree
		#if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
			#tile_container.set_owner(get_tree().edited_scene_root)

func _generate_level():
	if not _validate_assets():
		print("Error: Please set both floor_tile_scene and wall_tile_scene paths")
		return
	
	# Clear existing tiles
	_clear_level()
	
	# Ensure container exists
	if not tile_container:
		tile_container = Node3D.new()
		tile_container.name = "GeneratedTiles"
		add_child(tile_container)
		# Set ownership after adding to tree
		if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
			tile_container.set_owner(get_tree().edited_scene_root)
	
	print("Generating level: ", width, "x", height, " tiles")
	
	# Load the tile scenes
	var floor_scene = load(floor_tile_scene)
	var wall_scene = load(wall_tile_scene)
	
	if not floor_scene or not wall_scene:
		print("Error: Could not load tile scenes")
		return
	
	# Generate floor tiles
	_generate_floor_tiles(floor_scene)
	
	# Generate walls
	_generate_walls(wall_scene)
	
	print("Level generation complete!")

func _generate_floor_tiles(floor_scene: PackedScene):
	# Calculate offsets to center the level
	var offset_x = -((width - 1) * tile_size) / 2.0
	var offset_z = -((height - 1) * tile_size) / 2.0
	for x in range(width):
		for z in range(height):
			var tile_instance = floor_scene.instantiate()
			tile_instance.position = Vector3(x * tile_size + offset_x, 0, z * tile_size + offset_z)
			tile_instance.name = "Floor_" + str(x) + "_" + str(z)
			
			tile_container.add_child(tile_instance)
			if Engine.is_editor_hint() and get_tree().edited_scene_root:
				tile_instance.set_owner(get_tree().edited_scene_root)

func _generate_walls(wall_scene: PackedScene):
	# Generate walls around the perimeter
	# Calculate offsets to center the level
	var offset_x = -((width - 1) * tile_size) / 2.0
	var offset_z = -((height - 1) * tile_size) / 2.0
	# Top wall (z = -1)
	for x in range(-1, width + 1):
		var wall_instance = wall_scene.instantiate()
		wall_instance.position = Vector3(x * tile_size + offset_x, 0, -0.5 * tile_size + offset_z)
		wall_instance.rotation_degrees.y = 90
		wall_instance.name = "Wall_top_" + str(x)
		
		tile_container.add_child(wall_instance)
		if Engine.is_editor_hint() and get_tree().edited_scene_root:
			wall_instance.set_owner(get_tree().edited_scene_root)
	
	# Bottom wall (z = height)
	for x in range(-1, width + 1):
		var wall_instance = wall_scene.instantiate()
		wall_instance.position = Vector3(x * tile_size + offset_x, 0, (height - 0.5) * tile_size + offset_z)
		wall_instance.rotation_degrees.y = 90
		wall_instance.name = "Wall_bottom_" + str(x)
		
		tile_container.add_child(wall_instance)
		if Engine.is_editor_hint() and get_tree().edited_scene_root:
			wall_instance.set_owner(get_tree().edited_scene_root)
	
	# Left wall (x = -1, excluding corners already placed)
	for z in range(0, height):
		var wall_instance = wall_scene.instantiate()
		wall_instance.position = Vector3(-0.5 * tile_size + offset_x, 0, z * tile_size + offset_z)
		wall_instance.name = "Wall_left_" + str(z)
		
		tile_container.add_child(wall_instance)
		if Engine.is_editor_hint() and get_tree().edited_scene_root:
			wall_instance.set_owner(get_tree().edited_scene_root)
	
	# Right wall (x = width, excluding corners already placed)
	for z in range(0, height):
		var wall_instance = wall_scene.instantiate()
		wall_instance.position = Vector3((width - 0.5) * tile_size + offset_x, 0, z * tile_size + offset_z)
		wall_instance.name = "Wall_right_" + str(z)
		
		tile_container.add_child(wall_instance)
		if Engine.is_editor_hint() and get_tree().edited_scene_root:
			wall_instance.set_owner(get_tree().edited_scene_root)

func _clear_level():
	if tile_container:
		# Remove all children
		for child in tile_container.get_children():
			child.queue_free()
		
		# Wait a frame and remove from tree immediately for editor
		if Engine.is_editor_hint():
			for child in tile_container.get_children():
				tile_container.remove_child(child)
	
	print("Level cleared!")

func _validate_assets() -> bool:
	return floor_tile_scene != "" and wall_tile_scene != ""

# Optional: Preview the bounds in the editor
func _get_configuration_warnings():
	var warnings = []
	
	if floor_tile_scene == "":
		warnings.append("Floor tile scene not set")
	
	if wall_tile_scene == "":
		warnings.append("Wall tile scene not set")
	
	return warnings
