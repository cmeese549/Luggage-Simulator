extends Sorter

@onready var box_spawner: BoxSpawner = get_tree().get_first_node_in_group("BoxSpawner")

func _ready() -> void:
	if is_built:
		input_detector.body_entered.connect(new_box_available)
	update_county_labels()
	$"BaseSorter/Output Icon Label".text = expected_destination
	
func secondary_interact() -> void:
	var current_destination_index = box_spawner.destinations.find(expected_destination)
	expected_destination = box_spawner.destinations[(current_destination_index + 1) % box_spawner.destinations.size()]
	$"BaseSorter/Output Icon Label".text = expected_destination
	
func check_sort(box: Box) -> bool:
	return box.destination == expected_destination
