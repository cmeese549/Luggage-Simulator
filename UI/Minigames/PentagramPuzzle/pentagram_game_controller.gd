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

func _ready() -> void:
	# Start completely invisible
	modulate.a = 0.0
	
	# Get component references
	chaos_renderer = $ChaosRenderer
	pentagram_generator = $PentagramGenerator
	
	# Find distortion controller
	var ui_node = get_node_or_null("UI")
	if ui_node:
		distortion_controller = ui_node.get_node_or_null("DistortionOverlay")
	
	hover_particles = get_node_or_null("HoverParticles")
	if hover_particles:
		hover_particles.emitting = false
	
	get_viewport().size_changed.connect(_on_viewport_resized)
	
	# Generate random sequence and start
	generate_random_sequence()
	start_game()
	
	# Fade in
	fade_from_black(0.8)
	
func _on_viewport_resized() -> void:
	await get_tree().process_frame
	
	# Update particle positions
	var pentagram_points = pentagram_generator.get_pentagram_points()
	for point_idx in active_particles:
		if point_idx < pentagram_points.size():
			active_particles[point_idx].global_position = pentagram_points[point_idx]

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
	
	# Big success pulse
	if distortion_controller:
		distortion_controller.pulse_distortion(0.1, 1.0)
	await fade_to_black(0.8)
	stop_all_particles()

func restart_game() -> void:
	generate_random_sequence()
	start_game()

# Call this to restart after win/loss
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):  # Space or Enter
		if current_state != GameState.PLAYING:
			restart_game()
			
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
		if child is GPUParticles2D:
			child.emitting = false
			child.queue_free()
	active_particles.clear()

func fade_to_black(duration: float) -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, duration)
	
	# Also fade UI layer
	var ui_node = get_node_or_null("UI")
	tween.parallel().tween_property(ui_node, "modulate:a", 0.0, duration)
	
	await tween.finished
	visible = false
	ui_node.visible = false

func fade_from_black(duration: float) -> void:
	var ui_node = get_node_or_null("UI")
	var tween = create_tween()
	visible = true
	ui_node.visible = true
	tween.tween_property(self, "modulate:a", 1.0, duration)
	
	# Also fade UI layer

	tween.parallel().tween_property(ui_node, "modulate:a", 1.0, duration)
	
	await tween.finished
	
