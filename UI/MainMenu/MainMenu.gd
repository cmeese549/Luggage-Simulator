extends Control

class_name MainMenu

@onready var player : Player = get_tree().get_first_node_in_group("Player")
@onready var shader : ShaderMaterial = $Fader.material
@onready var begin_prompt : Label = $Begin

var fade_completed = false
var fade_delay : float = 2
var fade_delay_progress : float = 0
var fade_time : float = 5
var lerp_progress : float = 0

func _process(delta: float) -> void:
	if fade_completed:
		return
	
	if fade_delay_progress < fade_delay:
		fade_delay_progress += delta
		return
	
	lerp_progress += delta
	var new_fade_progress = remap(lerp_progress, 0, fade_time, 0, 1)
	shader.set_shader_parameter("Progress", new_fade_progress)
	
	if lerp_progress >= fade_time:
		shader.set_shader_parameter("Progress", 1.0)
		fade_completed = true 
		begin_prompt.visible = true
		if player != null:
			player.ready_to_start_game = true
