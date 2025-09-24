extends Node2D
class_name ProximityDetector

@export var detection_radius: float = 80.0
@export var max_influence_distance: float = 120.0

signal point_proximity_changed(point_index: int, stability: float)

var pentagram_generator: PentagramGenerator
var proximity_areas: Array[Area2D] = []
var point_stabilities: Array[float] = []

func _ready() -> void:
	# Get reference to pentagram generator
	pentagram_generator = get_parent().get_node("PentagramGenerator")
	
	# Wait for pentagram to be ready
	await get_tree().process_frame
	setup_proximity_areas()

func _process(_delta: float) -> void:
	update_proximities()

func setup_proximity_areas() -> void:
	# Clear existing areas
	for area in proximity_areas:
		if area:
			area.queue_free()
	proximity_areas.clear()
	point_stabilities.clear()
	
	if not pentagram_generator:
		return
		
	var pentagram_points: Array[Vector2] = pentagram_generator.get_pentagram_points()
	
	# Create Area2D for each pentagram point
	for i in range(pentagram_points.size()):
		var area: Area2D = Area2D.new()
		var collision: CollisionShape2D = CollisionShape2D.new()
		var circle_shape: CircleShape2D = CircleShape2D.new()
		
		# Setup collision shape
		circle_shape.radius = detection_radius
		collision.shape = circle_shape
		area.add_child(collision)
		
		# Position at pentagram point
		area.position = pentagram_points[i]
		add_child(area)
		
		proximity_areas.append(area)
		point_stabilities.append(0.0)

func update_proximities() -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	
	for i in range(proximity_areas.size()):
		var area: Area2D = proximity_areas[i]
		var distance: float = mouse_pos.distance_to(area.global_position)
		
		# Calculate stability based on distance
		var stability: float = calculate_stability(distance)
		
		# Only emit signal if stability changed significantly
		if abs(stability - point_stabilities[i]) > 0.01:
			point_stabilities[i] = stability
			point_proximity_changed.emit(i, stability)

func calculate_stability(distance: float) -> float:
	if distance >= max_influence_distance:
		return 0.0
	
	# Normalized distance (0 = at center, 1 = at max influence)
	var normalized_distance: float = distance / max_influence_distance
	
	# Use simple curve for smooth transition (quadratic falloff)
	var stability: float = 1.0 - (normalized_distance * normalized_distance)
	
	return clamp(stability, 0.0, 1.0)

func get_point_stability(point_index: int) -> float:
	if point_index < 0 or point_index >= point_stabilities.size():
		return 0.0
	return point_stabilities[point_index]
