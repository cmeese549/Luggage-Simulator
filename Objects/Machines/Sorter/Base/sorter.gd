extends Buildable

class_name Sorter

@export var max_queue_size: int = 10
@export var processing_time: float = 2.0
@export var output_icon: String = "🌐"
@export var expected_destination: String = "DEN"

@onready var input_detector: Area3D = $"BaseSorter/Box Detectors/Input"
@onready var other_output_detector: Area3D = $"BaseSorter/Box Detectors/Other Output"
@onready var sorted_output_detector: Area3D = $"BaseSorter/Box Detectors/Sorted Output"

@onready var output_icon_label: Label3D = $"BaseSorter/Output Icon Label"

@onready var other_spawn_point: Marker3D = $"BaseSorter/Box Droppers/Other"
@onready var sorted_spawn_point: Marker3D = $"BaseSorter/Box Droppers/Sorted"

@onready var county_labels = $"BaseSorter/County Labels".get_children()

var turned_off: bool = false
@onready var turned_off_labels = $"BaseSorter/Turned Off Labels".get_children()

var queue: Array[Box] = []
var processing_progress: float = processing_time
var waiting_to_export: bool = false
var reversed: bool = false

func get_save_data() -> Dictionary:
	var data: Dictionary = {}
	data.queue = serialize_box_queue(queue)
	data.processing_progress = processing_progress
	data.turned_off = turned_off
	data.processing_time = processing_time
	data.max_queue_size = max_queue_size
	data.output_icon = output_icon
	data.waiting_to_export = waiting_to_export
	data.expected_destination = expected_destination
	data.reversed = reversed
	return data

func load_save_data(data: Dictionary) -> void:
	queue = []
	for box_data in data.queue:
		var box_scene = load("res://Objects/Boxes/box.tscn")
		if box_scene:
			var box_instance = box_scene.instantiate() as Box
			if box_instance:
				box_instance.load_save_data(box_data)
				queue.append(box_instance)
	processing_progress = data.processing_progress
	turned_off = data.turned_off
	processing_time = data.processing_time
	max_queue_size = data.max_queue_size
	output_icon = data.output_icon
	waiting_to_export = data.waiting_to_export
	expected_destination = data.expected_destination
	global_position = data.global_position
	rotation = data.rotation
	reversed = data.reversed
	is_built = true

func _ready() -> void:
	if is_built:
		input_detector.body_entered.connect(new_box_available)
	update_county_labels()
	output_icon_label.text = output_icon
	
func _process(delta: float) -> void:
	if turned_off: 
		update_turned_off_labels()
		return
	if waiting_to_export:
		attempt_export()
	elif queue.size() > 0:
		if processing_progress > 0:
			processing_progress -= delta
		else:
			box_complete()
	else:
		processing_progress = processing_time
	update_county_labels()
	update_turned_off_labels()
		
func update_county_labels() -> void:
	for label in county_labels:
		label.text = str(queue.size()) + " / " + str(max_queue_size)
		
func update_turned_off_labels() -> void:
	if turned_off:
		for label in turned_off_labels:
			label.visible = true
	else:
		for label in turned_off_labels:
			label.visible = false
			
func interact() -> void:
	turned_off = !turned_off
	if not turned_off:
		attempt_import()
		
func secondary_interact() -> void:
	pass
	
func new_box_available(box: Box) -> void:
	if queue.size() < max_queue_size and not turned_off:
		await box.dissolve(1)
		queue.append(box)
		get_tree().root.get_node("MainLevel").remove_child(box)
		
func box_complete() -> void:
	waiting_to_export = true
	attempt_export()
	
func on_object_built():
	is_built = true
	input_detector.body_entered.connect(new_box_available)
	
func attempt_export() -> void:
	var sort_result =  check_sort(queue[0])
	var use_sorted_output = sort_result if not reversed else not sort_result
	var export_zone = sorted_output_detector if use_sorted_output else other_output_detector
	var spawn_point = sorted_spawn_point if use_sorted_output else other_spawn_point
	var blocked = export_zone.get_overlapping_bodies().size() > 0
	if not blocked:
		get_tree().root.get_node("MainLevel").add_child(queue[0])
		queue[0].global_position = spawn_point.global_position
		queue[0].dissolve(-0.15)
		queue.remove_at(0)
		waiting_to_export = false
		attempt_import()
		processing_progress = processing_time
		
func attempt_import() -> void:
	var waiting_boxes = input_detector.get_overlapping_bodies()
	if waiting_boxes.size() > 0:
		new_box_available(waiting_boxes[0])
		
func check_sort(_box: Box) -> bool:
	#Meant to be overwritten
	return false
	
func set_belt_reversed(is_reversed: bool) -> void:
	if reversed != is_reversed:
		$"BaseSorter/Output Icon Label".position = Vector3($"BaseSorter/Output Icon Label".position.x, $"BaseSorter/Output Icon Label".position.y, $"BaseSorter/Output Icon Label".position.z * -1)
	reversed = is_reversed
