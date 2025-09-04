extends Control

class_name BuildingUI

@onready var category_row: HBoxContainer = $Categories
@onready var buildable_row: HBoxContainer = $Buildables
@onready var animation_player: AnimationPlayer = $AnimationPlayer

@onready var building_system: BuildingSystem = get_tree().get_first_node_in_group("BuildingSystem")
var categories: Array[Dictionary] = []
var current_category_index: int = 0

var category_header: PackedScene = preload("res://UI/BuildMode/category_header.tscn")
var buildable_preview: PackedScene = preload("res://UI/BuildMode/buildable_preview.tscn")

@export var active_category_color: Color 
@export var inactive_category_color: Color

var buildable_textures: Dictionary = {}

func _ready():
	building_system = get_tree().get_first_node_in_group("BuildingSystem")
	setup_categories()
	generate_buildable_textures() 
	populate_category_row()
	populate_buildable_row()
	update_building_system_active_buildables()
	hide() # Start hidden
	await get_tree().process_frame
	update_category_colors()
	
	
func _input(event):
	if not visible:
		return
	if event.is_action_pressed("ui_left"):  # Q key
		change_category(-1)
	elif event.is_action_pressed("ui_right"):  # E key  
		change_category(1)
		
func show_ui():
	show()
	animation_player.play("slide_up")

func hide_ui():
	animation_player.play_backwards("slide_up")
	await animation_player.animation_finished
	hide()
		
func change_category(direction: int):
	current_category_index = (current_category_index + direction + categories.size()) % categories.size()
	
	update_category_colors()
	animation_player.play("fade_buildables")

	if categories[current_category_index].buildables.size() > 0:
		building_system.selected_object_index = 0
		update_building_system_active_buildables()
		
	populate_buildable_row()
		
	
func setup_categories():
	categories = [
		{
			"name": "Ground Coneyors", 
			"icon": "🔛",
			"buildables": []
		},
				{
			"name": "Sky Coneyors", 
			"icon": "🔝",
			"buildables": []
		},
				{
			"name": "Sorters", 
			"icon": "🔀",
			"buildables": []
		},
				{
			"name": "Processors", 
			"icon": "🔄",
			"buildables": []
		},
		{
			"name": "Skating", 
			"icon": "🛹",
			"buildables": []
		},
	]
	for buildable in building_system.buildable_objects:
		var instance = buildable.instantiate()
		if instance.category == "Ground Conveyors":
			categories[0].buildables.append(buildable)
		elif instance.category == "Sky Conveyors":
			categories[1].buildables.append(buildable)
		elif instance.category == "Sorters":
			categories[2].buildables.append(buildable)
		elif instance.category == "Processors":
			categories[3].buildables.append(buildable)
		elif instance.category == "Skating":
			categories[4].buildables.append(buildable)
		instance.queue_free()
	
func populate_category_row():
	 # Clear existing category buttons
	for child in category_row.get_children():
		child.queue_free()
	# Create category buttons
	for category in categories:
		var header = category_header.instantiate()
		var count = category.buildables.size()
		header.get_child(0).text = "[font_size={32}]" + category.name + " (" + str(count) + ") " + category.icon
		category_row.add_child(header)
	update_category_colors()
	
func populate_buildable_row():
	# Clear existing buildable items
	for child in buildable_row.get_children():
		if not child.is_in_group("Spacer"):
			child.queue_free()
	
	var current_buildables = categories[current_category_index].buildables
	
	for i in range(current_buildables.size()):
		var buildable = current_buildables[i].instantiate()
		var cached_texture = buildable_textures.get(current_buildables[i].resource_path)
		var container = buildable_preview.instantiate()  # Use ColorRect for highlighting
		buildable_row.add_child(container)
		container.setup(buildable, cached_texture, i == building_system.selected_object_index)
		buildable.queue_free()
		
func update_buildable_selection():
	# Update existing previews instead of recreating them all
	var i: int = 0
	for preview in buildable_row.get_children():
		if preview and preview is BuildablePreview:
			var is_selected = (i == building_system.selected_object_index)
			if is_selected:
				preview.animation_player.play("fade_selected_highlight")
			else:
				if preview.highlight.modulate.a == 1:
					preview.animation_player.play_backwards("fade_selected_highlight")
			i += 1

func update_building_system_active_buildables():
	# Cast to the proper typed array
	var typed_buildables: Array[PackedScene] = []
	for buildable in categories[current_category_index].buildables:
		typed_buildables.append(buildable)
	
	building_system.buildable_objects = typed_buildables
	building_system.selected_object_index = 0
	
	# Force ghost update if in building mode
	if building_system.building_mode_active:
		building_system.update_ghost_preview()

func update_category_colors():
	for i in range(category_row.get_child_count()):
		var category = category_row.get_child(i)
		category.color = active_category_color if i == current_category_index else inactive_category_color
		
func generate_buildable_textures():
	for category in categories:
		for buildable_scene in category.buildables:
			var instance = buildable_scene.instantiate()
			var packed_scene = PackedScene.new()
			packed_scene.pack(instance)
			
			var scene_texture = SceneTexture.new()
			scene_texture.scene = packed_scene
			scene_texture.camera_position = Vector3(5, 5, 5)
			var look_at_transform = Transform3D().looking_at(Vector3.ZERO - scene_texture.camera_position, Vector3.UP)
			scene_texture.camera_rotation = look_at_transform.basis.get_euler()
			scene_texture.size = Vector2(256, 256)
			
			buildable_textures[buildable_scene.resource_path] = scene_texture
			instance.queue_free()
			
func select_buildable_by_scene_path(scene_path: String):
	# Find the category and index
	for cat_index in range(categories.size()):
		var category = categories[cat_index]
		for build_index in range(category.buildables.size()):
			if category.buildables[build_index].resource_path == scene_path:
				# Switch to this category and select the item
				current_category_index = cat_index
				# Update UI
				update_category_colors()
				update_building_system_active_buildables()  # This resets selected_object_index to 0
				building_system.selected_object_index = build_index  # So we set it AFTER
				# Force ghost update if in building mode
				if building_system.building_mode_active:
					building_system.update_ghost_preview()
				populate_buildable_row()
				return
	print("Buildable not found in categories: ", scene_path)
