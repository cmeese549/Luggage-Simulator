extends Node2D
class_name PentagramGameController

# Game state
enum GameState { PLAYING, WON }
var current_state: GameState = GameState.PLAYING

# Sequence tracking
@export var sequence_length: int = 5
var correct_sequence: Array[int] = []  # The order to tune points
var player_sequence: Array[int] = []   # What player has completed so far
var last_tuned_point: int = -1

# Components
var chaos_renderer: ChaosRenderer
var pentagram_generator: PentagramGenerator
var distortion_controller: DistortionController

# Signals
signal _game_won
signal _point_completed(point_index: int)

func _ready() -> void:
	# Get component references
	chaos_renderer = $ChaosRenderer
	pentagram_generator = $PentagramGenerator
	
	# Find distortion controller
	var ui_node = get_node_or_null("UI")
	if ui_node:
		distortion_controller = ui_node.get_node_or_null("DistortionOverlay")
	
	# Generate random sequence and start
	generate_random_sequence()
	start_game()

func _process(_delta: float) -> void:
	if current_state == GameState.PLAYING:
		check_tuned_points()

func generate_random_sequence() -> void:
	correct_sequence.clear()
	var available_points = [0, 1, 2, 3, 4]
	
	# Shuffle the points for a random sequence
	for i in range(sequence_length):
		var random_index = randi() % available_points.size()
		correct_sequence.append(available_points[random_index])
		available_points.erase(available_points[random_index])
	
	print("Game sequence generated: ", correct_sequence)

func start_game() -> void:
	current_state = GameState.PLAYING
	player_sequence.clear()
	last_tuned_point = -1
	
	if chaos_renderer:
		chaos_renderer.reset_all_points()
	
	# Set the first target
	update_target_point()

func check_tuned_points() -> void:
	if not chaos_renderer:
		return
	
	# Check each point to see if it's newly tuned
	for i in range(chaos_renderer.tuned_points.size()):
		if chaos_renderer.tuned_points[i] and i != last_tuned_point:
			# New point was tuned!
			last_tuned_point = i
			on_point_tuned(i)
			break

func on_point_tuned(point_index: int) -> void:
	# Check if it's the correct target point
	var sequence_position = player_sequence.size()
	
	if sequence_position < correct_sequence.size():
		var expected_point = correct_sequence[sequence_position]
		
		if point_index == expected_point:
			# Correct point!
			print("Correct! Point %d completed" % point_index)
			player_sequence.append(point_index)
			
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
		print("New target: Point %d" % target_point)
	else:
		chaos_renderer.set_target_point(-1)  # No target

func game_won() -> void:
	current_state = GameState.WON
	chaos_renderer.set_target_point(-1)
	print("GAME WON! Sequence completed!")
	_game_won.emit()
	
	# Big success pulse
	if distortion_controller:
		distortion_controller.pulse_distortion(0.1, 1.0)

func restart_game() -> void:
	generate_random_sequence()
	start_game()

# Call this to restart after win/loss
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):  # Space or Enter
		if current_state != GameState.PLAYING:
			restart_game()
