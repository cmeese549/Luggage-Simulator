extends Node3D

class_name ToolSys

var tools: Array[tool]
var equipped_tool: tool

@onready var look_at_cast: RayCast3D = $"../LookAtCast"
@onready var camera_3d: Camera3D = $".."

@onready var water_crosshair : TextureRect = get_tree().get_first_node_in_group("WaterCrosshair")
@onready var interact_crosshair : TextureRect = get_tree().get_first_node_in_group("InteractCrosshair")

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
	tools[0].visible = true
	equipped_tool = tools[0]
	
func _process(_delta: float) -> void:
	if water_crosshair != null:
		var looked_at_object = check_for_interactable()
		if looked_at_object != null and looked_at_object.name == "WaterTop":
			if !water_crosshair.visible:
				water_crosshair.visible = true
		else:
			if water_crosshair.visible:
				water_crosshair.visible = false
	
	if interact_crosshair != null:
		var looked_at_object = check_for_interactable()
		if looked_at_object != null and looked_at_object.name != "WaterTop":
			if !interact_crosshair.visible:
				interact_crosshair.visible = true
		else:
			if interact_crosshair.visible:
				interact_crosshair.visible = false
		

func _unhandled_input(event):
	if event.is_action_pressed("primary"):
		var interact_thing = check_for_interactable()
		if interact_thing:
			if interact_thing.name == "WaterTop" || interact_thing.name == "DepositArea":
				equipped_tool.use(interact_thing.name)
			elif interact_thing.name == "PumpBuy":
				interact_thing.find_parent("Pump").attempt_buy()
			elif interact_thing.name == "PumpUpgrade":
				interact_thing.find_parent("Pump").attempt_upgrade()

func check_for_interactable():
	if look_at_cast.is_colliding():
		var col = look_at_cast.get_collider()
		#print("Looking at "+col.name)
		if "Interactable" in col.get_groups():
			return col
	return null
	
