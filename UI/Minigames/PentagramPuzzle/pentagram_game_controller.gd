extends Minigame
class_name PentagramGameController

# Sequence tracking
@export var sequence_length: int = 5
var correct_sequence: Array[int] = []  # The order to tune points
var player_sequence: Array[int] = []   # What player has completed so far

# Components
var chaos_renderer: ChaosRenderer
var pentagram_generator: PentagramGenerator
var distortion_controller: DistortionController

signal _point_completed(point_index: int)
signal chaos_level_changed(chaos_amount: float)

var completion_particle_scene: PackedScene = preload("res://UI/Minigames/PentagramPuzzle/PointCompletionParticles.tscn")
var active_particles: Dictionary = {}

@onready var hover_particles: GPUParticles2D = $HoverParticles
@onready var ethereal_orbs: GPUParticles2D = $EtherealOrbs

@onready var ui_node: CanvasLayer = $UI

@export var cursor_3d_scene: PackedScene  # Assign your 3D cursor scene in inspector
var cursor_sprite: Sprite2D

func _ready() -> void:
	# Start completely invisible
	modulate.a = 0.0
	
	# Get component references
	chaos_renderer = $ChaosRenderer
	pentagram_generator = $PentagramGenerator
	
	# Find distortion controller
	var ui_node = get_node_or_null("UI")
	if ui_node:
		ui_node.visible = false
		distortion_controller = ui_node.get_node_or_null("DistortionOverlay")
	
	hover_particles = get_node_or_null("HoverParticles")
	if hover_particles:
		hover_particles.emitting = false
	
	get_viewport().size_changed.connect(_on_viewport_resized)
	
	# Generate random sequence and start
	generate_random_sequence()
	
	_create_background_polygon()
	var size = get_viewport().get_visible_rect().size
	ethereal_orbs.global_position = size / 2.0
	
	# Create cursor sprite
	cursor_sprite = Sprite2D.new()
	cursor_sprite.z_index = 100
	add_child(cursor_sprite)
	cursor_sprite.visible = false
	
	# Generate texture from 3D scene
	if cursor_3d_scene:
		var scene_texture = SceneTexture.new()
		scene_texture.scene = cursor_3d_scene
		scene_texture.camera_position = Vector3(2, 0, 2)
		var look_at_transform = Transform3D().looking_at(Vector3.ZERO - scene_texture.camera_position, Vector3.UP)
		scene_texture.camera_rotation = look_at_transform.basis.get_euler()
		scene_texture.size = Vector2(64, 64)
		cursor_sprite.texture = scene_texture
		cursor_sprite.centered = true
		
		# Brighten the main cursor significantly
		cursor_sprite.self_modulate = Color(6.0, 6.0, 6.0, 1.0)
		
		# Create multiple glow layers for stronger effect
		# Outer glow (largest)
		var outer_glow = Sprite2D.new()
		outer_glow.texture = scene_texture
		outer_glow.centered = true
		outer_glow.modulate = Color(2.0, 1.5, 0.0, 0.4)  # Bright orange
		outer_glow.scale = Vector2(2.0, 2.0)
		outer_glow.z_index = 98
		cursor_sprite.add_child(outer_glow)
		
		# Middle glow
		var mid_glow = Sprite2D.new()
		mid_glow.texture = scene_texture
		mid_glow.centered = true
		mid_glow.modulate = Color(2.5, 2.0, 0.5, 0.6)  # Bright yellow-orange
		mid_glow.scale = Vector2(1.5, 1.5)
		mid_glow.z_index = 99
		cursor_sprite.add_child(mid_glow)

	
func _on_viewport_resized() -> void:
	await get_tree().process_frame
	
	# Update particle positions
	var pentagram_points = pentagram_generator.get_pentagram_points()
	for point_idx in active_particles:
		if point_idx < pentagram_points.size():
			active_particles[point_idx].global_position = pentagram_points[point_idx]
			
	var size = get_viewport().get_visible_rect().size
	ethereal_orbs.process_material.emission_box_extents = Vector3(size.x * 0.6, size.y * 0.6, 0)
	ethereal_orbs.global_position = size / 2.0

func _process(_delta: float) -> void:
	if current_state == GameState.PLAYING:
		check_tuned_points()
		if chaos_renderer:
			var avg_chaos = 0.0
			for level in chaos_renderer.point_order_levels:
				avg_chaos += (1.0 - level)
			avg_chaos /= 5.0
			chaos_level_changed.emit(avg_chaos)
		hover_particles.emitting = true
		hover_particles.global_position = get_global_mouse_position()
		if cursor_sprite and cursor_sprite.visible:
			cursor_sprite.global_position = get_global_mouse_position()

func generate_random_sequence() -> void:
	correct_sequence.clear()
	var available_points = [0, 1, 2, 3, 4]
	
	# Shuffle the points for a random sequence
	for i in range(sequence_length):
		var random_index = randi() % available_points.size()
		correct_sequence.append(available_points[random_index])
		available_points.erase(available_points[random_index])
	

func start_game() -> void:
	generate_random_sequence()
	current_state = GameState.PLAYING
	player_sequence.clear()
	
	if chaos_renderer:
		chaos_renderer.reset_all_points()
	
	# Set the first target
	update_target_point()
		# Fade in
	fade_from_black(0.8)

func check_tuned_points() -> void:
	if not chaos_renderer:
		return
	
	# Check each point to see if it's newly tuned
	for i in range(chaos_renderer.tuned_points.size()):
		# Only process if tuned AND not already completed
		if chaos_renderer.tuned_points[i] and not chaos_renderer.completed_points[i]:
			# New point was tuned!
			on_point_tuned(i)
			break

func on_point_tuned(point_index: int) -> void:
	var sequence_position = player_sequence.size()
	
	if sequence_position < correct_sequence.size():
		var expected_point = correct_sequence[sequence_position]
		
		if point_index == expected_point:
			# Correct point!
			player_sequence.append(point_index)
			spawn_completion_particles(point_index)
			# Mark this point as completed (turns green)
			chaos_renderer.mark_point_completed(point_index)
			
			# Emit signal for any effects
			_point_completed.emit(point_index)
			
			# Small distortion pulse for feedback
			if distortion_controller:
				distortion_controller.pulse_distortion(0.06, 0.3)
			
			# Check for win
			if player_sequence.size() == correct_sequence.size():
				game_won()
			else:
				# Move to next target
				update_target_point()
		# If wrong point somehow got tuned, just ignore it (shouldn't happen)

func update_target_point() -> void:
	# Determine which point should be the current target
	var sequence_position = player_sequence.size()
	
	if sequence_position < correct_sequence.size():
		var target_point = correct_sequence[sequence_position]
		chaos_renderer.set_target_point(target_point)
	else:
		chaos_renderer.set_target_point(-1)  # No target

func game_won() -> void:
	current_state = GameState.WON
	chaos_renderer.set_target_point(-1)
	
	_game_won.emit()
	if cursor_sprite:
		cursor_sprite.visible = false
	# Big success pulse
	if distortion_controller:
		distortion_controller.pulse_distortion(0.1, 1.0)
	await fade_to_black(0.8)
	stop_all_particles()

func restart_game() -> void:
	generate_random_sequence()
	start_game()
	fade_from_black(0.8)
	if cursor_sprite:
		cursor_sprite.visible = true
			
func spawn_completion_particles(point_index: int) -> void:
	if not pentagram_generator:
		return
	
	var pentagram_points = pentagram_generator.get_pentagram_points()
	if point_index >= pentagram_points.size():
		return
	
	var particles = completion_particle_scene.instantiate()
	add_child(particles)
	particles.global_position = pentagram_points[point_index]
	particles.emitting = true
	particles.set_meta("point_index", point_index)
	active_particles[point_index] = particles

func stop_all_particles() -> void:
	for child in get_children():
		if child is GPUParticles2D and not child.is_in_group("preserve"):
			child.emitting = false
			child.queue_free()
	active_particles.clear()
	
func _create_background_polygon() -> void:
	var bg = Polygon2D.new()
	bg.name = "Background"
	add_child(bg)
	move_child(bg, 0)  # Move to first position
	bg.color = Color.BLACK
	_resize_background(bg)
	get_viewport().size_changed.connect(func(): _resize_background(bg))

func _resize_background(bg: Polygon2D) -> void:
	var size = get_viewport().get_visible_rect().size
	bg.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(size.x, 0),
		Vector2(size.x, size.y),
		Vector2(0, size.y)
	])

func fade_to_black(duration: float) -> void:
	# Hide UI immediately at the start
	var ui_node = get_node_or_null("UI")
	if ui_node:
		ui_node.visible = false
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, duration)
	
	await tween.finished
	visible = false

func fade_from_black(duration: float) -> void:
	# Show UI instantly at the start
	var ui_node = get_node_or_null("UI")
	if ui_node:
		ui_node.visible = true
	
	# IMPORTANT: Set visible first, THEN set alpha to 0, THEN tween
	visible = true
	modulate.a = 0.0
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, duration)
	
	await tween.finished
