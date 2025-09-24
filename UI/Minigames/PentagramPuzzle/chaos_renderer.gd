@tool
extends Node2D
class_name ChaosRenderer

@export var base_chaos_intensity: float = 100.0
@export var line_segments: int = 15
@export var lines_per_point: int = 6
@export var max_line_length: float = 80.0
@export var chaos_color: Color = Color(0.3, 0.8, 0.3, 0.7)
@export var line_width: float = 2.0
@export var animation_speed: float = 2.0
@export var disappear_threshold: float = 0.95

var noise_instances: Array[FastNoiseLite] = []
var pentagram_generator: PentagramGenerator
var proximity_detector: ProximityDetector
var time_elapsed: float = 0.0
var chaos_lines: Array[Array] = []
var point_order_levels: Array[float] = []
var tuned_points: Array[bool] = []
var point_colors: Array[Color] = [
	Color.RED,
	Color.GREEN, 
	Color.BLUE,
	Color.YELLOW,
	Color.MAGENTA
]

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
	
	# Initialize tuned points array
	tuned_points.resize(5)  # 5 pentagram points
	tuned_points.fill(false)
	
	# Generate initial chaos lines
	generate_chaos_lines()

func _process(delta: float) -> void:
	time_elapsed += delta * animation_speed
	update_point_order_levels()
	queue_redraw()

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
			
		var line_color: Color = point_colors[point_index % point_colors.size()]
		
		for i in range(line_points.size() - 1):
			var start: Vector2 = line_points[i]
			var end: Vector2 = line_points[i + 1]
			
			# Apply chaos/order transformation
			var transformed_start: Vector2 = transform_point(start, i, line_index)
			var transformed_end: Vector2 = transform_point(end, i + 1, line_index)
			
			draw_line(transformed_start, transformed_end, line_color, line_width)

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
		if order_level >= disappear_threshold:
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
	
	# Get the actual pentagram point this line belongs to
	var pentagram_points: Array[Vector2] = pentagram_generator.get_pentagram_points()
	var pentagram_point: Vector2 = pentagram_points[point_index]
	
	# Calculate chaotic point with reduced chaos as mouse gets closer
	var chaotic_point: Vector2 = apply_extreme_chaos(base_position, segment_index, local_order_level, line_index)
	
	# Calculate straight/ordered point (converging toward pentagram point)  
	var straight_point: Vector2 = lerp(base_position, pentagram_point, local_order_level)
	
	# Smoothly interpolate between chaos and straightness
	var chaos_strength: float = 1.0 - local_order_level
	return lerp(straight_point, chaotic_point, chaos_strength)

func apply_extreme_chaos(base_position: Vector2, segment_index: int, local_order_level: float, line_index: int = 0) -> Vector2:
	var chaos_factor: float = base_chaos_intensity * pow(1.0 - local_order_level, 0.7)
	
	# Get the correct noise instance for this line's pentagram point
	var point_index: int = line_index / lines_per_point
	var noise: FastNoiseLite = noise_instances[point_index % noise_instances.size()]

	# Add both point-specific and line-specific offsets
	var point_offset: float = point_index * 5000.0  # Different regions for each pentagram point
	var line_offset: float = line_index * 1000.0   # Different regions for each line

	# Time-based coordinate drift for evolving patterns
	var time_drift_x: float = time_elapsed * 5
	var time_drift_y: float = time_elapsed * 2

	# Layer 1: Large sweeping movements
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

	# Layer 2: Spiraling chaos
	var spiral_time: float = time_elapsed * 3.0 + segment_index * 0.5 + point_offset * 0.001 + line_offset * 0.0001
	var spiral_x: float = sin(spiral_time) * cos(spiral_time * 1.7) * 1.5
	var spiral_y: float = cos(spiral_time) * sin(spiral_time * 1.3) * 1.5

	# Layer 3: High frequency writhing - faster time drift
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

	# Layer 4: Tentacle-like loops
	var loop_time: float = time_elapsed * 1.5 + segment_index * 0.3 + point_offset * 0.0005 + line_offset * 0.00005
	var loop_radius: float = sin(loop_time * 0.7) * 40.0
	var loop_x: float = cos(loop_time * 2.3) * loop_radius
	var loop_y: float = sin(loop_time * 1.9) * loop_radius
	
	# Combine all chaos layers
	var total_chaos: Vector2 = Vector2(
		(sweep_x + spiral_x + writhe_x + loop_x) * chaos_factor,
		(sweep_y + spiral_y + writhe_y + loop_y) * chaos_factor
	)
	
	return base_position + total_chaos
