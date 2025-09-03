extends Control

class_name BuildingUI

@onready var category_row: HBoxContainer = $Categories
@onready var buildable_row: HBoxContainer = $Buildables
@onready var animation_player: AnimationPlayer = $AnimationPlayer

@onready var building_system: BuildingSystem = get_tree().get_first_node_in_group("BuildingSystem")
var categories: Array[Dictionary] = []
var current_category_index: int = 0

var category_header: PackedScene = preload("res://UI/BuildMode/category_header.tscn")

@export var active_category_color: Color 
@export var inactive_category_color: Color

func _ready():
	building_system = get_tree().get_first_node_in_group("BuildingSystem")
	setup_categories()
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
	populate_buildable_row()
	
	if categories[current_category_index].buildables.size() > 0:
		building_system.selected_object_index = 0
		update_building_system_active_buildables()
	
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
		header.get_child(0).text = "[font_size={32}]" + category.name + " " + category.icon
		category_row.add_child(header)
	update_category_colors()
	
func populate_buildable_row():
	# Clear existing buildable items
	for child in buildable_row.get_children():
		child.queue_free()
	
	var current_buildables = categories[current_category_index].buildables
	
	for i in range(current_buildables.size()):
		var buildable = current_buildables[i].instantiate()
		var container = ColorRect.new()  # Use ColorRect for highlighting
		container.custom_minimum_size = Vector2(80, 60)
		container.name = "BuildableItem_" + str(i)
		
		# Set highlight color
		if i == building_system.selected_object_index:
			container.color = active_category_color
		else:
			container.color = Color.TRANSPARENT
		
		# Add border/outline
		container.add_theme_stylebox_override("panel", create_buildable_style(i == building_system.selected_object_index))
		
		var label = Label.new()
		label.text = buildable.building_name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		container.add_child(label)
		
		buildable_row.add_child(container)
		buildable.queue_free()
		
func create_buildable_style(is_selected: bool) -> StyleBox:
	var style = StyleBoxFlat.new()
	style.border_width_left = 2
	style.border_width_right = 2  
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = active_category_color if is_selected else Color.GRAY
	return style

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
