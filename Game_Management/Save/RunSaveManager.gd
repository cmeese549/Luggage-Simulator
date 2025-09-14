extends Node

const SAVE_FILE_PATH = "user://factory_save.tres"

func collect_run_save_data() -> RunSaveData:
	var save_data = RunSaveData.new()
	save_data.buildables = collect_buildable_data()
	save_data.boxes = collect_all_boxes()
	save_data.money = collect_money_data()
	save_data.box_spawners = collect_box_spawners()
	save_data.run_orchestrator_data = collect_run_data()
	return save_data

func load_from_run_save_data(save_data: RunSaveData) -> bool:
	if not save_data:
		return false
	
	clear_existing_buildables()
	clear_existing_boxes()
	clear_existing_spawners()
	restore_buildables(save_data.buildables)
	restore_boxes(save_data.boxes)
	restore_money(save_data.money)
	restore_spawners(save_data.box_spawners)
	restore_run_data(save_data.run_orchestrator_data)
	
	Events.game_loaded.emit()
	return true
	
	
func collect_run_data() -> Dictionary:
	return get_tree().get_first_node_in_group("RunOrchestrator").get_save_data()
	
func collect_money_data() -> Dictionary:
	return get_tree().get_first_node_in_group("Money").get_save_data()
	
func collect_box_spawners() -> Array[Dictionary]:
	var spawner_data: Array[Dictionary] = []
	var spawners =  get_tree().get_nodes_in_group("BoxSpawner")
	
	for spawner in spawners:
		var data = {
			"scene_path": spawner.scene_file_path,
			"global_position": spawner.global_position,
			"rotation": spawner.rotation,
			"type": spawner.get_script().get_global_name(),
		}
		if spawner.has_method("get_save_data"):
			data = add_all_properties_to_dictionary(data, spawner.get_save_data())
		spawner_data.append(data)
	return spawner_data

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

func clear_existing_buildables():
	var building_system = get_tree().get_first_node_in_group("BuildingSystem")
	for child in building_system.get_children():
		if child is Buildable and child.is_built:
			child.queue_free()
			
func clear_existing_boxes():
	var boxes = get_tree().get_nodes_in_group("Box")
	for box in boxes:
		box.queue_free()
	
func restore_run_data(data: Dictionary) -> void:
	get_tree().get_first_node_in_group("RunOrchestrator").load_save_data(data)
		
func restore_money(data: Dictionary) -> void:
	get_tree().get_first_node_in_group("Money").load_save_data(data)
	
func clear_existing_spawners() -> void:
	var spawners = get_tree().get_nodes_in_group("BoxSpawner")
	for spawner in spawners:
		spawner.queue_free()
	
func restore_spawners(data: Array[Dictionary]) -> void:
	var main_level = get_tree().root.get_node("MainLevel")
	for spawner in data:
		var scene = load(spawner.scene_path) as PackedScene
		if not scene:
			continue
		var new_spawner = scene.instantiate()
		new_spawner.load_save_data(spawner)
		main_level.add_child(new_spawner)

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
