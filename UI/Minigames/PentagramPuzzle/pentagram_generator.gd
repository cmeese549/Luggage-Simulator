@tool
extends Node2D
class_name PentagramGenerator

var center_position: Vector2
@export var radius: float = 200.0
@export var line_width: float = 3.0
@export var pentagram_color: Color = Color.WHITE

var pentagram_points: Array[Vector2] = []
var pentagram_lines: Array[Array] = []

func _ready() -> void:
	get_viewport().size_changed.connect(_recalculate_pentagram)
	_recalculate_pentagram()
	calculate_pentagram_points()
	calculate_pentagram_lines()
	
func _recalculate_pentagram() -> void:
	# Calculate center based on actual viewport size
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	center_position = viewport_size / 2.0
	
	calculate_pentagram_points()
	calculate_pentagram_lines()
	queue_redraw()  # Force redraw with new calculations

func _draw() -> void:
	# Draw the pentagram lines
	for line_pair in pentagram_lines:
		var start: Vector2 = line_pair[0]
		var end: Vector2 = line_pair[1]
		draw_line(start, end, pentagram_color, line_width)
	
	# Draw points as small circles for debugging
	for point in pentagram_points:
		draw_circle(point, 8.0, Color.RED)

func calculate_pentagram_points() -> void:
	pentagram_points.clear()
	
	# Calculate 5 points on a circle, starting from top (-90 degrees)
	for i in range(5):
		var angle_degrees: float = -90.0 + (i * 72.0)  # 72° intervals, starting from top
		var angle_radians: float = deg_to_rad(angle_degrees)
		
		var point: Vector2 = Vector2(
			center_position.x + cos(angle_radians) * radius,
			center_position.y + sin(angle_radians) * radius
		)
		pentagram_points.append(point)

func calculate_pentagram_lines() -> void:
	pentagram_lines.clear()
	
	# Connect every 2nd vertex to create pentagram star pattern
	for i in range(5):
		var start_point: Vector2 = pentagram_points[i]
		var end_point: Vector2 = pentagram_points[(i + 2) % 5]  # Connect to point 2 positions ahead
		pentagram_lines.append([start_point, end_point])

func get_pentagram_points() -> Array[Vector2]:
	return pentagram_points
