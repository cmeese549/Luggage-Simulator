extends Node3D

class_name ToolSys

var tools: Array[tool]
var equipped_tool: tool

@onready var look_at_cast: RayCast3D = $"../LookAtCast"
@onready var camera_3d: Camera3D = $".."

#@onready var screen_rect = camera_3d.get_viewport_rect()
#@onready var screen_center = Vector2(screen_rect.size.x / 2, screen_rect.size.y / 2)

# Called when the node enters the scene tree for the first time.
func _ready():
	for child in get_children():
		if child is tool: 
			print("Found tool: "+child.name)
			tools.append(child)
	tools[0].unlock()
	equipped_tool = tools[0]

func _unhandled_input(event):
	if event.is_action_pressed("primary"):
		equipped_tool.use(check_for_water())

func check_for_water():
	if look_at_cast.is_colliding():
		var col = look_at_cast.get_collider()
		print("Looking at "+col.name)
		if "WaterTop" in col.get_groups():
			print("looking at some water bb")
			return true
	return false
