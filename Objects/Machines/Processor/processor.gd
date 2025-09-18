extends Buildable

class_name Processor

@export var max_queue_size: int = 1
@export var processing_time: float = 2.0
@export var output_icon: String = "✔️❌"

@onready var input_detector: Area3D = $"BaseProcessor/Box Detectors/Input"
@onready var sorted_output_detector: Area3D = $"BaseProcessor/Box Detectors/Sorted Output"

@onready var sorted_spawn_point: Marker3D = $"BaseProcessor/Box Droppers/Sorted"

@onready var county_labels = $"BaseProcessor/County Labels".get_children()

var turned_off: bool = false
@onready var turned_off_labels = $"BaseProcessor/Turned Off Labels".get_children()

var queue: Array[Box] = []
var processing_progress: float = processing_time
var waiting_to_export: bool = false

func get_save_data() -> Dictionary:
	var data: Dictionary = {}
	data.queue = serialize_box_queue(queue)
	data.processing_progress = processing_progress
	data.turned_off = turned_off
	data.processing_time = processing_time
	data.max_queue_size = max_queue_size
	data.output_icon = output_icon
	data.waiting_to_export = waiting_to_export
	return data

func load_save_data(data: Dictionary) -> void:
	queue = []
	for box_data in data.queue:
		var box_scene = load(box_data.scene_path)
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
	global_position = data.global_position
	rotation = data.rotation
	is_built = true

func _ready() -> void:
	if is_built:
		input_detector.body_entered.connect(new_box_available)
	update_county_labels()
	$"BaseProcessor/Output Icon Label".text = output_icon
	processing_time = ProfileManager.current_profile.get_machine_speed()
	
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
	
func new_box_available(box: Box) -> void:
	if queue.size() < max_queue_size and not turned_off:
		await box.dissolve(1)
		box.inward_particles.emitting = false
		await get_tree().create_timer(box.inward_particles.lifetime + 0.1).timeout
		queue.append(box)
		get_tree().root.get_node("MainLevel").remove_child(box)
		
func box_complete() -> void:
	waiting_to_export = true
	process(queue[0])
	attempt_export()
	
func on_object_built():
	is_built = true
	input_detector.body_entered.connect(new_box_available)
	
func attempt_export() -> void:
	var export_zone = sorted_output_detector
	var blocked = export_zone.get_overlapping_bodies().size() > 0
	if not blocked:
		var box_to_add : Box = queue[0]
		queue.remove_at(0)
		attempt_import()
		processing_progress = processing_time
		get_tree().root.get_node("MainLevel").add_child(box_to_add)
		box_to_add.global_position = sorted_spawn_point.global_position
		waiting_to_export = false
		await box_to_add.dissolve(-0.15)
		box_to_add.inward_particles.emitting = false
		await get_tree().create_timer(box_to_add.inward_particles.lifetime + 0.1).timeout

		
func attempt_import() -> void:
	var waiting_boxes = input_detector.get_overlapping_bodies()
	if waiting_boxes.size() > 0:
		new_box_available(waiting_boxes[0])
		
func process(_box: Box) -> void:
	#Meant to be overwritten
	pass
