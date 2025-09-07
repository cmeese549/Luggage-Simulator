extends Control
class_name Killfeed

@onready var entries_container: VBoxContainer = $Entries
@export var max_entries: int = 7
@export var entry_lifetime: float = 3.5
@export var batch_delay: float = 0.1  # Delay between entries when batching
@export var removal_animation_time: float = 0.3

var entry_scene: PackedScene = preload("res://UI/Killfeed/killfeed_entry.tscn")
var entry_queue: Array[Dictionary] = []
var processing_queue: bool = false

func _ready():
	Events.box_deposited.connect(_on_box_deposited)
	
func _on_box_deposited(money_amount: int, box: Box, success: bool):
	entry_queue.append({
		"money": money_amount,
		"box": box, 
		"success": success
	})
	
	if not processing_queue:
		process_queue()

func process_queue():
	if entry_queue.is_empty():
		processing_queue = false
		return
		
	processing_queue = true
	var entry_data = entry_queue.pop_front()
	add_entry(entry_data.money, entry_data.box, entry_data.success)
	
	await get_tree().create_timer(batch_delay).timeout
	process_queue()


func add_entry(money_amount: int, box: Box, success: bool):
	var entry = entry_scene.instantiate()
	entries_container.add_child(entry)
	entry.setup(money_amount, box, success)
	
	# Remove oldest if exceeding max
	while entries_container.get_child_count() > max_entries:
		var oldest = entries_container.get_child(0)
		remove_entry_smoothly(oldest)
	
	# Auto-remove after lifetime
	get_tree().create_timer(entry_lifetime).timeout.connect(func(): 
		if is_instance_valid(entry):
			remove_entry_smoothly(entry)
	)

func remove_entry_smoothly(entry: KillfeedEntry):
	if not is_instance_valid(entry):
		return
	
	# Check if this is the last entry
	var is_last_entry = entries_container.get_child_count() == 1
	
	# Animate the entry shrinking vertically while fading out
	var tween = create_tween()
	tween.parallel().tween_property(entry, "modulate:a", 0.0, 0.2)
	
	# Only apply vertical shrinking if there are other entries to smooth with
	if not is_last_entry:
		tween.parallel().tween_property(entry, "custom_minimum_size:y", 0.0, 0.3).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(entry, "scale:y", 0.0, 0.3).set_ease(Tween.EASE_OUT)
	
	tween.tween_callback(func(): entry.queue_free())
