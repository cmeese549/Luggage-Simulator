extends Node3D

var tools: Array[tool]
var equiped_tool: tool

# Called when the node enters the scene tree for the first time.
func _ready():
	for child in get_children():
		if child is tool: 
			print("Found tool: "+child.name)
			tools.append(child)
	tools[0].unlock()
	equiped_tool = tools[0]

func _unhandled_input(event):
	if event.is_action_pressed("primary"):
		equiped_tool.use()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
