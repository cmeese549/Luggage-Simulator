extends PathFollow3D

@onready var path: Path3D = $".."

var grinding: bool = false
var chosen: bool = false
var forward: bool = true
var direction_selected: bool = false
var detach: bool = false

@export var DEBUG: bool = false

var local_starting_progress: float = 0.0
var origin_point: float 

@export var move_speed: float = 8.0

signal end_of_rail()

func _ready():
	origin_point = progress
	if DEBUG: $Debug_Orb.visible = true

func _process(delta):
	if grinding:
		if forward:
			progress += move_speed * delta
		else:
			progress -= move_speed * delta
		
		if progress_ratio >= 0.99 or progress_ratio <= 0.002:
			end_of_rail.emit()
			detach = true
			grinding = false
			#direction_selected = false
	
	if chosen:
		grinding = true
	else:
		grinding = false
		progress = origin_point
		direction_selected = false
