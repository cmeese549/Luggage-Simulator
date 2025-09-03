extends Control

class_name MainMenu

@onready var music : Node = get_tree().get_first_node_in_group("Music")

@onready var player : Player = get_tree().get_first_node_in_group("Player")
@onready var shader : ShaderMaterial = $Fader.material
@onready var begin_prompt : Label = $Begin

@onready var line : Line2D = find_child("Line2D")

var ready_to_start : bool = false

var fade_completed = false
var fade_delay : float = 6
var music_fade_delay : float = 3
var music_delay_progress : float = 0
var music_started : bool = false
var fade_delay_progress : float = 0
var fade_time : float = 6
var lerp_progress : float = 0

func start() -> void:
	ready_to_start = true

func _process(delta: float) -> void:
	if !ready_to_start:
		return
	
	if fade_completed:
		return
		
	if music_delay_progress >= music_fade_delay and !music_started:
		music_started = true
		music.start_game()
	else:
		music_delay_progress += delta
	
	if fade_delay_progress < fade_delay:
		fade_delay_progress += delta
		return
	
	lerp_progress += delta
	var new_fade_progress = remap(lerp_progress, 0, fade_time, 0, 1)
	shader.set_shader_parameter("Progress", line.width_curve.sample(new_fade_progress))
	
	if lerp_progress >= fade_time:
		shader.set_shader_parameter("Progress", 1.0)
		fade_completed = true 
		begin_prompt.visible = true
