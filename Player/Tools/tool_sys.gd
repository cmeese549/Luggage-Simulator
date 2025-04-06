extends Node3D

class_name ToolSys

var tools: Array[tool]
var equipped_tool: tool

# Called when the node enters the scene tree for the first time.
func _ready():
	for child in get_children():
		if child is tool: tools.append(child)
	tools[0].unlock()
	equipped_tool = tools[0]

func _unhandled_input(event):
	if event.is_action_pressed("primary"):
		equipped_tool.use()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
