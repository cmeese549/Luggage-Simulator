extends Node

class_name DialoguePause

var float_pattern : String = "\\d+\\.\\d+"
var pause_position : int
var pause_duration : float

func _init(position: int, tag: String) -> void:
	var duration_regex : RegEx = RegEx.new()
	duration_regex.compile(float_pattern)
	pause_duration = float(duration_regex.search(tag).get_string())
	pause_position = int(clamp(position - 1, 0, abs(position)))
