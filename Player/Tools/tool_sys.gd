extends Node3D

class_name ToolSys

var tools: Array[tool]
var equipped_tool: tool
var next_tool: tool

@onready var player : Player = $"../../.."

@onready var look_at_cast: RayCast3D = $"../InteractCast"
@onready var box_cast: RayCast3D = $"../BoxCast"
@onready var camera_3d: Camera3D = $".."

@onready var water_crosshair : TextureRect = get_tree().get_first_node_in_group("WaterCrosshair")
@onready var interact_crosshair : TextureRect = get_tree().get_first_node_in_group("InteractCrosshair")

@onready var cant_afford_audio : AudioStreamPlayer = $"../../../Audio/CantAfford"

#@onready var screen_rect = camera_3d.get_viewport_rect()
#@onready var screen_center = Vector2(screen_rect.size.x / 2, screen_rect.size.y / 2)

# Called when the node enters the scene tree for the first time.
func start_game():
	for child in get_children():
		if child is tool: 
			print("Found tool: "+child.name)
			child.visible = false
			tools.append(child)
	tools[0].unlock()
	equipped_tool = tools[0]
	
func _process(_delta: float) -> void:	
	if interact_crosshair != null and !player.building_system.building_mode_active and !player.building_system.destroy_mode_active and !player.held_box:
		var looked_at_object = check_for_interactable()
		if looked_at_object != null and check_interactive(looked_at_object):
			if !interact_crosshair.visible:
				interact_crosshair.visible = true
		else:
			looked_at_object = check_for_box()
			if looked_at_object != null and looked_at_object is Box:
				interact_crosshair.visible = true
			elif interact_crosshair.visible:
				interact_crosshair.visible = false
	elif interact_crosshair != null and interact_crosshair.visible and (player.held_box or player.building_system.building_mode_active or player.building_system.destroy_mode_active):
		interact_crosshair.visible = false

func upgrade_tool(tool_name: String):
	equipped_tool.stow_finished.connect(equip_next_tool)
	equipped_tool.stow()
	var found_tool = false
	for t in tools:
		if t.tool_name == tool_name:
			next_tool = t
			next_tool.unlocked = true
			found_tool = true
	if not found_tool: push_error("Couldn't find tool: "+tool_name)

func equip_next_tool(old_tool):
	#This is called from the stow finished signal from the old tool
	equipped_tool.visible = false
	equipped_tool = next_tool
	equipped_tool.unlock()
	
func check_interactive(node: Node3D) -> bool:
	var is_interactive: bool = node.has_method("interact") or node.has_method("secondary_interact")
	if not is_interactive:
		is_interactive = node.get_parent().has_method("interact") or node.get_parent().has_method("secondary_interact")
	return is_interactive

func _unhandled_input(event):
	if !player.building_system.building_mode_active and !player.building_system.destroy_mode_active and !player.held_box:
		if event.is_action_pressed("primary"):
			var interact_thing = check_for_interactable()
			if interact_thing and interact_thing.has_method("interact"):
				interact_thing.interact()
			elif interact_thing:
				interact_thing = interact_thing.get_parent()
				if interact_thing and interact_thing.has_method("interact"):
					interact_thing.interact()
		elif event.is_action_pressed("secondary"):
			var interact_thing = check_for_interactable()
			if interact_thing and interact_thing.has_method("secondary_interact"):
				interact_thing.secondary_interact()
			elif interact_thing:
				interact_thing = interact_thing.get_parent()
				if interact_thing and interact_thing.has_method("secondary_interact"):
					interact_thing.secondary_interact()

func check_for_interactable():
	if look_at_cast.is_colliding():
		var col = look_at_cast.get_collider()
		#print("Looking at "+col.name)
		if col and "Interactable" in col.get_groups():
			return col.get_parent()
			
func check_for_box():
	if box_cast.is_colliding():
		var col = box_cast.get_collider()
		if col and col is Box:
			return col
	
