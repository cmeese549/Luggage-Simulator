extends Resource

class_name DayConfig

@export var day_number: int = 1
@export var total_boxes: int = 10
@export var boxes_per_second: float = 0.5
@export var box_types: Array[Dictionary] = []  # Array of box type probabilities
@export var special_modifiers: Array[String] = []  # Power outages, mislabeling, etc.
@export var quota_target: int = 8  # How many boxes must be processed correctly
