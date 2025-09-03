extends Node

const SAVE_FILE_PATH = "user://factory_save.tres"

func save_game() -> bool:
	var save_data = SaveData.new()
	
	# Save buildables
	save_data.buildables = collect_buildable_data()
	save_data.boxes = collect_all_boxes()
	# Save player data
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		save_data.player_data = player.get_save_data()
	
	# Save to file
	return ResourceSaver.save(save_data, SAVE_FILE_PATH) == OK

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		return false
	
	var save_data = ResourceLoader.load(SAVE_FILE_PATH) as SaveData
	if not save_data:
		return false
	
	# Clear existing buildables and restore from save
	clear_existing_buildables()
	clear_existing_boxes()
	restore_buildables(save_data.buildables)
	restore_boxes(save_data.boxes)
	restore_player_data(save_data)
	
	return true

func collect_all_boxes() -> Array[Dictionary]:
	var boxes_data: Array[Dictionary] = []
	var boxes = get_tree().get_nodes_in_group("Box")
	
	for box in boxes:
		var data = {}
		if box.has_method("get_save_data"):
			data = add_all_properties_to_dictionary(data, box.get_save_data())
		boxes_data.append(data)
	return boxes_data

func collect_buildable_data() -> Array[Dictionary]:
	var buildables_data: Array[Dictionary] = []
	var building_system = get_tree().get_first_node_in_group("BuildingSystem")
	
	for child in building_system.get_children():
		if child is Buildable and child.is_built:
			var data = {
				"scene_path": child.scene_file_path,
				"global_position": child.global_position,
				"rotation": child.rotation,
				"type": child.get_script().get_global_name(),
			}
			if child.has_method("get_save_data"):
				data = add_all_properties_to_dictionary(data, child.get_save_data())
			buildables_data.append(data)
	return buildables_data

func add_all_properties_to_dictionary(input_dict: Dictionary, target_dict: Dictionary) -> Dictionary:
	for key in input_dict.keys():
		target_dict[key] = input_dict[key]
	return target_dict

func collect_player_data(player: Player) -> Dictionary:
	return {
		"inventory": player.inventory,
		"roller_unlocked": player.roller_unlocked,
		"skate_unlocked": player.skate_unlocked,
		"cur_move_tech": player.cur_move_tech
	}

func clear_existing_buildables():
	var building_system = get_tree().get_first_node_in_group("BuildingSystem")
	for child in building_system.get_children():
		if child is Buildable and child.is_built:
			child.queue_free()
			
func clear_existing_boxes():
	var boxes = get_tree().get_nodes_in_group("Box")
	for box in boxes:
		box.queue_free()

func restore_buildables(buildables_data: Array[Dictionary]):
	var building_system = get_tree().get_first_node_in_group("BuildingSystem")
	
	for data in buildables_data:
		var scene = load(data.scene_path) as PackedScene
		if not scene:
			continue
			
		var buildable = scene.instantiate()
		if buildable.has_method("load_save_data"):
			buildable.load_save_data(data)
		building_system.add_child(buildable)
	
func restore_boxes(boxes_data: Array[Dictionary]):
	var main_level = get_tree().root.get_node("MainLevel")
	
	for data in boxes_data:
		var box_scene = load(data.scene_path) as PackedScene
		var box = box_scene.instantiate()
		if box.has_method("load_save_data"):
			box.load_save_data(data)
		main_level.add_child(box)
		
func restore_player_data(save_data: SaveData):
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		player.load_save_data(save_data.player_data)
