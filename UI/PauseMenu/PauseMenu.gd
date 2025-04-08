extends MarginContainer

class_name PauseMenu

@onready var player : Player = get_tree().get_first_node_in_group("Player")

@onready var ui : UI = $".."
@onready var shop : Shop = $"../Shop"
@onready var upgrade_menu : MarginContainer = $"../UpgradeMenu"

@onready var config = ConfigFile.new()
@onready var audioServer = AudioServer

@onready var hud : Control = $"../HUD"
@onready var resume_button : Button = $PanelContainer/MarginContainer/Rows/Close/Resume
@onready var help_button : Button = $PanelContainer/MarginContainer/Rows/Close/HowToPlay
@onready var unstick_button : Button = $PanelContainer/MarginContainer/Rows/Close/Unstick
@onready var quit_button : Button = $PanelContainer/MarginContainer/Rows/Close/Quit

@onready var actually_quit_button : Button = $PanelContainer/MarginContainer/Rows/QuitConfirm/Quit
@onready var nevermind_button : Button = $PanelContainer/MarginContainer/Rows/QuitConfirm/Nevermind
@onready var buttons : HBoxContainer = $PanelContainer/MarginContainer/Rows/Close
@onready var quit_confirm : HBoxContainer = $PanelContainer/MarginContainer/Rows/QuitConfirm

@onready var sensitivity_slider : HSlider = $PanelContainer/MarginContainer/Rows/PauseDad/VBoxContainer/Sensitivity/SensitivitySlider
@onready var fov_slider : HSlider = $PanelContainer/MarginContainer/Rows/PauseDad/VBoxContainer/FOV/FOVSlider
@onready var volume_slider : HSlider = $PanelContainer/MarginContainer/Rows/PauseDad/VBoxContainer/Volume/VolumeSlider
@onready var music_slider : HSlider = $PanelContainer/MarginContainer/Rows/PauseDad/VBoxContainer/MusicVolume/MusicVolumeSlider
@onready var sfx_slider : HSlider = $PanelContainer/MarginContainer/Rows/PauseDad/VBoxContainer/SfxVolume/SfxVolumeSlider

@onready var pause_dad : HBoxContainer = $PanelContainer/MarginContainer/Rows/PauseDad
@onready var tutorial_dad : HBoxContainer = $PanelContainer/MarginContainer/Rows/Tutorial

var inventory_item : PackedScene = preload("res://UI/PauseMenu/InventoryItem.tscn")
@onready var inventory_dad : GridContainer = $PanelContainer/MarginContainer/Rows/PauseDad/Rows/ScrollContainer/GridContainer

func _ready() -> void:
	quit_button.pressed.connect(prompt_quit)
	resume_button.pressed.connect(unpause)
	unstick_button.pressed.connect(unstick)
	help_button.pressed.connect(show_tutorial)
	actually_quit_button.pressed.connect(quit)
	nevermind_button.pressed.connect(cancel_quit)
	connect_sliders()
	var loadStatus = config.load("user://config.ini")
	if loadStatus == OK: #0 = loaded, so this means data found
		load_config()
		
func cancel_quit() -> void:
	buttons.visible = true
	quit_confirm.visible = false
		
func prompt_quit() -> void:
	buttons.visible = false
	quit_confirm.visible = true
	
func quit() -> void:
	get_tree().quit()
		
func unstick() -> void:
	player.global_position = Vector3(0, 1, 0)
	unpause()
		
func connect_sliders():
	sensitivity_slider.value_changed.connect(sensitivity_slider_changed)
	fov_slider.value_changed.connect(fov_slider_changed)
	volume_slider.value_changed.connect(volume_slider_changed)
	music_slider.value_changed.connect(music_slider_changed)
	sfx_slider.value_changed.connect(sfx_slider_changed)
	
func sensitivity_slider_changed(value: float) -> void:
	player.mouse_sens = value
	store_config("sensitivity", value)
	
func fov_slider_changed(value: float) -> void:
	player.update_fov(value)
	store_config("fov", value)
	
func volume_slider_changed(value: float) -> void:
	set_bus_db("Master", value)
	store_config("volume", value)
	
func music_slider_changed(value: float) -> void:
	set_bus_db("Music", value)
	store_config("music_volume", value)
	
func sfx_slider_changed(value: float) -> void:
	set_bus_db("Sfx", value)
	store_config("sfx_volume", value)
	
func update_inventory_items() -> void:
	var old_items : Array[Node] = inventory_dad.get_children()
	for item: Node in old_items:
		item.call_deferred("queue_free")
	
	for item: InventoryItem in player.inventory:
		var new_item : Button = inventory_item.instantiate()
		new_item.find_child("ItemName").text = item.item_name
		new_item.find_child("ItemDescription").text = item.item_description
		new_item.find_child("ItemIcon").texture = item.item_icon
		inventory_dad.add_child(new_item)
	
func _unhandled_input(event):
	if shop.visible or upgrade_menu.visible:
		return
		
	if Input.is_action_just_pressed("Pause") and ui.pauseable and player.ready_to_start_game:
		print("Freakin paus time")
		toggle_pause()
		
	if event is InputEventJoypadButton and event.is_action_pressed("ui_cancel") and ui.pauseable:
		if get_tree().paused:
			unpause()
		
func toggle_pause() -> void:
	if get_tree().paused:
		unpause()
	else:
		pause()
		
func show_tutorial() -> void:
	pause_dad.visible = false
	tutorial_dad.visible = true

func pause() -> void:
	pause_dad.visible = true
	tutorial_dad.visible = false
	update_inventory_items()
	self.visible = true
	hud.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
	sensitivity_slider.grab_focus()

		
func unpause() -> void:
	self.visible = false
	hud.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().paused = false
	
func load_config():
	var settingKeys = config.get_section_keys("settings")
	print(settingKeys)
	for key in settingKeys:
		if key == "fov":
			fov_slider.value = config.get_value("settings", key)
			player.update_fov(config.get_value("settings", key))
		elif key == "sensitivity":
			sensitivity_slider.value = config.get_value("settings", key)
			player.mouse_sens = config.get_value("settings", key)
		elif key == "volume":
			set_bus_db("Master", config.get_value("settings", key))
			volume_slider.value = config.get_value("settings", key)
		elif key == "music_volume":
			set_bus_db("Music", config.get_value("settings", key))
			music_slider.value = config.get_value("settings", key)
		elif key == "sfx_volume":
			set_bus_db("Sfx", config.get_value("settings", key))
			sfx_slider.value = config.get_value("settings", key)
			
func set_bus_db(busName, linear):
	audioServer.set_bus_volume_db(audioServer.get_bus_index(busName), linear_to_db(linear))

func store_config(key,value):
	config.set_value("settings",key,value)
	save_config()
			
func save_config():
	var saveStatus = config.save("user://config.ini")
	if saveStatus:
		push_error("config save failed")
