extends Buildable

@export var rail_follower = preload("res://Objects/Rail/rail_follower.tscn")

@export var DEBUG: bool = false
@export var path: Path3D
@export var spacing: float = 1.9

var followers: Array[PathFollow3D] = []

func _ready():
	var path_length = path.curve.get_baked_length()
	var points_total: int = floori(path_length/spacing)
	var current_distance = 0
	for i in range(points_total + 2):
		var obj: PathFollow3D = rail_follower.instantiate()
		obj.progress = current_distance
		obj.DEBUG = DEBUG
		path.add_child(obj)
		followers.append(obj)
		current_distance += spacing
