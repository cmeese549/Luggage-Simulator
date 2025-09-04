extends Sorter

@onready var box_spawner: BoxSpawner = get_tree().get_first_node_in_group("BoxSpawner")
	
func check_sort(box: Box) -> bool:
	return box_spawner.active_destinations.has(box.destination)
