extends Node3D

@export var destination_stickers : Array[Mesh]

@onready var mesh_instance : MeshInstance3D = $MeshInstance3D

func _ready():
	mesh_instance.mesh = destination_stickers[randi_range(0, destination_stickers.size() - 1)]
