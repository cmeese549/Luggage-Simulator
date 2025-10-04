@tool
extends Node2D
class_name ChaosRenderer

@export var base_chaos_intensity: float = 100.0
@export var line_segments: int = 15
@export var lines_per_point: int = 6
@export var max_line_length: float = 80.0
@export var line_width: float = 2.0
@export var animation_speed: float = 2.0
@export var disappear_threshold: float = 1.3

# Color settings
@export var target_color: Color = Color.ORANGE  # Color for current target point
@export var inactive_color: Color = Color.PURPLE  # Color for non-target points
@export var completed_color: Color = Color.GREEN  # Color for completed points
var current_target_point: int = -1  # Which point is currently the target (-1 = none)
var completed_points: Array[bool] = []  # Track which points have been completed

var noise_instances: Array[FastNoiseLite] = []
var pentagram_generator: PentagramGenerator
var proximity_detector: ProximityDetector
var time_elapsed: float = 0.0
var chaos_lines: Array[Array] = []
var point_order_levels: Array[float] = []
var tuned_points: Array[bool] = []

func _ready() -> void:
	# Setup separate noise instances for each pentagram point
	for i in range(5):  # 5 pentagram points
		var noise: FastNoiseLite = FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_PERLIN
		noise.frequency = 0.05
		noise.fractal_octaves = 4
		noise.fractal_gain = 0.6
		noise.seed = i * 12345  # Different seed for each point
		noise_instances.append(noise)
	
	# Get references
	pentagram_generator = get_parent().get_node("PentagramGenerator")
	proximity_detector = get_parent().get_node("ProximityDetector")
	
	# Initialize arrays
	tuned_points.resize(5)  # 5 pentagram points
	tuned_points.fill(false)
	completed_points.resize(5)
	completed_points.fill(false)
	
	# Generate initial chaos lines
	generate_chaos_lines()
	get_viewport().size_changed.connect(_on_viewport_resized)

func _process(delta: float) -> void:
	time_elapsed += delta * animation_speed
	update_point_order_levels()
	queue_redraw()
	
func _on_viewport_resized() -> void:
	# Wait a frame for pentagram to recalculate
	await get_tree().process_frame
	generate_chaos_lines()

func _draw() -> void:
	if chaos_lines.is_empty():
		return
		
	# Draw all chaos lines with writhing animation
	for line_index in range(chaos_lines.size()):
		var line_points: Array = chaos_lines[line_index]
		
		# Determine color and order level for this line
		var point_index: int = line_index / lines_per_point
		var local_order_level: float = 0.2
		if point_index < point_order_levels.size():
			local_order_level = point_order_levels[point_index]
		
		# Skip drawing if this point is too ordered (tuned)
		if local_order_level >= disappear_threshold:
			continue
		
		# Determine base line color
		var base_color: Color = get_point_color(point_index)
		
		for i in range(line_points.size() - 1):
			var start: Vector2 = line_points[i]
			var end: Vector2 = line_points[i + 1]
			
			# Calculate gradient fade (darker toward tips)
			var gradient_t: float = float(i) / float(line_points.size() - 1)
			var segment_color: Color = base_color.lerp(Color(base_color, 0.2), gradient_t)
			
			# Apply chaos/order transformation
			var transformed_start: Vector2 = transform_point(start, i, line_index)
			var transformed_end: Vector2 = transform_point(end, i + 1, line_index)
			
			draw_line(transformed_start, transformed_end, segment_color, line_width)

func get_point_color(point_index: int) -> Color:
	# Check if this point is completed
	if point_index < completed_points.size() and completed_points[point_index]:
		return completed_color
	
	# Check if this is the current target
	if point_index == current_target_point:
		return target_color
	
	# Otherwise it's inactive
	return inactive_color

func set_target_point(point_index: int) -> void:
	current_target_point = point_index
	queue_redraw()

func mark_point_completed(point_index: int) -> void:
	if point_index >= 0 and point_index < completed_points.size():
		completed_points[point_index] = true
		queue_redraw()

func reset_all_points() -> void:
	# Ensure arrays are properly sized
	tuned_points.resize(5)
	tuned_points.fill(false)
	
	point_order_levels.resize(5)
	for i in range(5):
		point_order_levels[i] = 0.2
	
	completed_points.resize(5)
	completed_points.fill(false)
	
	current_target_point = -1
	queue_redraw()

func generate_chaos_lines() -> void:
	chaos_lines.clear()
	
	if not pentagram_generator:
		return
		
	var pentagram_points: Array[Vector2] = pentagram_generator.get_pentagram_points()
	
	# Generate chaotic lines from each pentagram point
	for point in pentagram_points:
		for line_idx in range(lines_per_point):
			var line_points: Array[Vector2] = []
			
			# Create base line points for this line
			var direction: float = randf() * TAU
			var length_step: float = max_line_length / line_segments
			
			for segment in range(line_segments + 1):
				var distance: float = segment * length_step
				var base_pos: Vector2 = point + Vector2(
					cos(direction) * distance,
					sin(direction) * distance
				)
				line_points.append(base_pos)
			
			chaos_lines.append(line_points)

func update_point_order_levels() -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	var pentagram_points: Array[Vector2] = pentagram_generator.get_pentagram_points()
	
	# Ensure array is correct size
	point_order_levels.resize(pentagram_points.size())
	
	# Calculate order level for each individual pentagram point
	for i in range(pentagram_points.size()):
		# If already tuned, keep it tuned
		if tuned_points[i]:
			point_order_levels[i] = 1.0
			continue
			
		var distance: float = mouse_pos.distance_to(pentagram_points[i])
		
		# Use full screen diagonal for smooth transition
		var viewport_size: Vector2 = get_viewport().get_visible_rect().size
		var max_screen_distance: float = viewport_size.length()
		
		var normalized_distance: float = distance / max_screen_distance
		var order_level: float = 1.0 - sqrt(normalized_distance)
		order_level = clamp(order_level, 0.2, 1.0)
		
		# Check if this point should become permanently tuned
		# ONLY if it's the current target
		if order_level >= disappear_threshold and i == current_target_point:
			tuned_points[i] = true
			point_order_levels[i] = 1.0
		else:
			point_order_levels[i] = order_level

func transform_point(base_position: Vector2, segment_index: int, line_index: int) -> Vector2:
	# Calculate which pentagram point this line belongs to
	var point_index: int = line_index / lines_per_point
	var local_order_level: float = 0.2  # Default near-chaos
	
	if point_index < point_order_levels.size():
		local_order_level = point_order_levels[point_index]
	
	# When near full order, just return the straight line
	if local_order_level > 0.95:
		return base_position
	
	# Get ONLY the chaos offset (not base + offset)
	var chaos_offset: Vector2 = get_chaos_offset(base_position, segment_index, line_index)
	
	# Scale chaos by inverse of order level (exponential for smooth transition)
	var chaos_strength: float = pow(1.0 - local_order_level, 2.0)
	
	# Add scaled chaos to the base straight line position
	return base_position + (chaos_offset * chaos_strength)

func get_chaos_offset(base_position: Vector2, segment_index: int, line_index: int = 0) -> Vector2:
	var point_index: int = line_index / lines_per_point
	var noise: FastNoiseLite = noise_instances[point_index % noise_instances.size()]

	# Add both point-specific and line-specific offsets
	var point_offset: float = point_index * 5000.0
	var line_offset: float = line_index * 1000.0

	# Time-based coordinate drift for evolving patterns
	var time_drift_x: float = time_elapsed * 5
	var time_drift_y: float = time_elapsed * 2

	var sweep_x: float = noise.get_noise_3d(
		base_position.x * 0.003 + point_offset + time_drift_x, 
		base_position.y * 0.003 + line_offset + time_drift_y, 
		time_elapsed * 0.5 + segment_index * 0.1
	) * 2.0

	var sweep_y: float = noise.get_noise_3d(
		base_position.x * 0.003 + point_offset + time_drift_x + 1000.0, 
		base_position.y * 0.003 + line_offset + time_drift_y + 1000.0, 
		time_elapsed * 0.5 + segment_index * 0.1
	) * 2.0

	var spiral_time: float = time_elapsed * 3.0 + segment_index * 0.5 + point_offset * 0.001 + line_offset * 0.0001
	var spiral_x: float = sin(spiral_time) * cos(spiral_time * 1.7) * 1.5
	var spiral_y: float = cos(spiral_time) * sin(spiral_time * 1.3) * 1.5

	var writhe_x: float = noise.get_noise_3d(
		base_position.x * 0.05 + point_offset + time_drift_x * 3.0 + 2000.0, 
		base_position.y * 0.05 + line_offset + time_drift_y * 2.5 + 2000.0, 
		time_elapsed * 2.0 + segment_index * 0.7
	) * 0.8

	var writhe_y: float = noise.get_noise_3d(
		base_position.x * 0.05 + point_offset + time_drift_x * 2.7 + 3000.0, 
		base_position.y * 0.05 + line_offset + time_drift_y * 3.2 + 3000.0, 
		time_elapsed * 2.0 + segment_index * 0.7
	) * 0.8

	var loop_time: float = time_elapsed * 1.5 + segment_index * 0.3 + point_offset * 0.0005 + line_offset * 0.00005
	var loop_radius: float = sin(loop_time * 0.7) * 40.0
	var loop_x: float = cos(loop_time * 2.3) * loop_radius
	var loop_y: float = sin(loop_time * 1.9) * loop_radius
	
	return Vector2(
		(sweep_x + spiral_x + writhe_x + loop_x) * base_chaos_intensity,
		(sweep_y + spiral_y + writhe_y + loop_y) * base_chaos_intensity
	)
