extends ColorRect
class_name DistortionController

@export var base_distortion_strength: float = 0.02
@export var max_distortion_strength: float = 0.05
@export var writhe_speed: float = 1.5
@export var vortex_power: float = 0.4
@export var chaos_color: Color = Color(0.8, 0.2, 0.3, 0.15)

var chaos_renderer: ChaosRenderer
var pentagram_generator: PentagramGenerator
var shader_material: ShaderMaterial
var average_order_level: float = 0.0

func _ready() -> void:
	# Set up the shader material
	shader_material = ShaderMaterial.new()
	shader_material.shader = preload("res://UI/Minigames/PentagramPuzzle/pentagram_distortion.gdshader")
	material = shader_material
	
	# Get references to other components
	await get_tree().process_frame  # Wait for scene to be ready
	var puzzle_root = get_tree().get_root().find_child("PentagramPuzzle", true, false)
	if puzzle_root:
		chaos_renderer = puzzle_root.get_node("ChaosRenderer")
		pentagram_generator = puzzle_root.get_node("PentagramGenerator")
	
	# Set initial shader parameters
	_update_shader_params()

func _process(_delta: float) -> void:
	if not chaos_renderer:
		return
	
	# Calculate average order level across all pentagram points
	average_order_level = 0.0
	var point_count: int = 0
	
	for level in chaos_renderer.point_order_levels:
		average_order_level += level
		point_count += 1
	
	if point_count > 0:
		average_order_level /= float(point_count)
	
	_update_shader_params()

func _update_shader_params() -> void:
	if not shader_material:
		return
	
	# Update distortion strength based on chaos level
	var chaos_level: float = 1.0 - average_order_level
	var current_distortion: float = lerp(
		base_distortion_strength * 0.2,
		max_distortion_strength,
		chaos_level
	)
	
	shader_material.set_shader_parameter("distortion_strength", current_distortion)
	shader_material.set_shader_parameter("time_speed", writhe_speed)
	shader_material.set_shader_parameter("writhe_frequency", 3.0 + chaos_level * 5.0)
	shader_material.set_shader_parameter("vortex_strength", vortex_power * chaos_level)
	shader_material.set_shader_parameter("order_level", average_order_level)
	shader_material.set_shader_parameter("chaos_tint", chaos_color)
	
	# Update center position to viewport center
	shader_material.set_shader_parameter("center_position", Vector2(0.5, 0.5))

func get_average_order_level() -> float:
	return average_order_level

func set_distortion_enabled(enabled: bool) -> void:
	visible = enabled

func pulse_distortion(strength: float, duration: float) -> void:
	# Create a temporary distortion pulse effect
	var tween = create_tween()
	var original_strength = base_distortion_strength
	
	tween.tween_method(
		func(value: float): base_distortion_strength = value,
		original_strength,
		strength,
		duration * 0.3
	)
	tween.tween_method(
		func(value: float): base_distortion_strength = value,
		strength,
		original_strength,
		duration * 0.7
	)
