extends Label

@export var fade_time := 0.0
@export var fade_duration := 1

func _ready():
	Events.water_dumped.connect(start_fade)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if fade_time > 0:
		fade_time -= delta
		var current_ratio = max(fade_time/fade_duration,0)
		var curColor = self_modulate
		self_modulate = lerp( Color(curColor.r,curColor.g,curColor.b,0), Color(curColor.r,curColor.g,curColor.b,1), current_ratio)
	else:
		self_modulate = Color(0,0,0,0)

func start_fade(delta):
	if delta != 0:
		if delta > 0:
			text = "+${delta}".format({"delta":add_comma_to_int(delta)})
			self_modulate = Color(0,1,0,1)
		else:
			text = str(delta)
			self_modulate = Color(1,0,0,1)
		fade_time = fade_duration

func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	for i in range(str_value.length()-3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value
