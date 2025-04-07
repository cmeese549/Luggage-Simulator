extends Node3D

@onready var timer : Timer = $AhemTimer
@onready var cougher : AudioStreamPlayer3D = $AudioStreamPlayer3D

func _ready() -> void:
	timer.timeout.connect(cougher.play)
