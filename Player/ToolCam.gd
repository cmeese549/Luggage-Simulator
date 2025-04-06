extends Camera3D

@onready var neck : Node3D = $"../../../Neck"

func _process(_delta: float) -> void:
	rotation_degrees.y = neck.rotation_degrees.y
	rotation_degrees.x = neck.find_child("Camera3D").rotation_degrees.x
	global_position = Vector3(neck.global_position.x, neck.global_position.y + 0.51, neck.global_position.z)
