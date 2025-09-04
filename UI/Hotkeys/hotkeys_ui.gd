extends Control

class_name HotkeysUI

@onready var hotkeys : Array[Node] = $HBoxContainer.get_children()
@onready var building_system: BuildingSystem = get_tree().get_first_node_in_group("BuildingSystem")
@onready var building_ui: BuildingUI = $"../BuildMode"

func _ready():
	Events.game_loaded.connect(update_hotkeys)
	update_labels()
			
func update_hotkeys() -> void:
	for i in 10:
		var buildable: PackedScene = building_system.hotkeys[i]
		if buildable:
			#TODO: get cached texture for buildable
			pass
			
func update_labels() -> void:
	var i = 1
	for hotkey in hotkeys:
		hotkey.get_child(0).get_child(1).text = str(i)
		i += 1
