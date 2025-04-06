extends MarginContainer

class_name UpgradeMenu

@onready var upgrade_entry : PackedScene = preload("res://UI/UpgradeMenu/UpgradeSlot.tscn")
@onready var ui : UI = $".."

@onready var speed_upgrade_1 : Button = $PanelContainer/MarginContainer/Rows/HBoxContainer/SpeedUpgrades/VBoxContainer/Button
@onready var speed_upgrade_2 : Button = $PanelContainer/MarginContainer/Rows/HBoxContainer/SpeedUpgrades/VBoxContainer/Button2
@onready var speed_upgrade_3 : Button = $PanelContainer/MarginContainer/Rows/HBoxContainer/SpeedUpgrades/VBoxContainer/Button3

@onready var quality_upgrade_1 : Button = $PanelContainer/MarginContainer/Rows/HBoxContainer/QualityUpgrades/VBoxContainer/Button
@onready var quality_upgrade_2 : Button = $PanelContainer/MarginContainer/Rows/HBoxContainer/QualityUpgrades/VBoxContainer/Button2
@onready var quality_upgrade_3 : Button = $PanelContainer/MarginContainer/Rows/HBoxContainer/QualityUpgrades/VBoxContainer/Button3

@onready var upgrade_slots : HBoxContainer = find_child("UpgradeSlots")
@onready var close_button : Button = $PanelContainer/MarginContainer/Rows/Close/Button

var all_buttons_disabled : bool = false

var current_pump : Pump = null

func _input(event) -> void:
	if self.visible:
		if Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("Pause"):
			close()

func _ready() -> void:
	close_button.pressed.connect(close)
	
func _process(_delta: float) -> void:
	if current_pump == null or !self.visible:
		return
	update_affordability()

func close() -> void:
	current_pump = null
	self.visible = false
	get_tree().paused = false
	disconnect_buttons()

func open(pump: Pump) -> void:
	current_pump = pump
	self.visible = true
	get_tree().paused = true
	var i : int = 0
	var applied_upgrades : int = 0
	for entry: VBoxContainer in upgrade_slots.get_children():
		entry.call_deferred("queue_free")
	for upgrade: pump_upgrade in pump.upgrade_slots:
		if upgrade == null:
			display_empty_upgrade_slot()
		else:
			display_populated_upgrade_slot(upgrade)
			applied_upgrades += 1
		i += 1
	
	
	if applied_upgrades == 5:
		disable_upgrade_buttons()
	else:
		if pump.speed_upgrades.size() == 3 and pump.quality_upgrades.size() == 3:
			enable_upgrade_buttons()
	connect_buttons(pump)
	
func connect_buttons(pump: Pump) -> void:
	var i : int = 0
	var speed_upgrade_buttons : Array[Button] = [
		speed_upgrade_1,
		speed_upgrade_2,
		speed_upgrade_3
	]
	for button: Button in speed_upgrade_buttons:
		var upgrade_data : pump_upgrade = pump.speed_upgrades[i]
		button.text = upgrade_data.upgrade_name + " - " + upgrade_data.description + " - $" + str(upgrade_data.price)
		button.pressed.connect(pump.apply_upgrade.bind(upgrade_data))
		i += 1
	i = 0
	var quality_upgrade_buttons : Array[Button] = [
		quality_upgrade_1,
		quality_upgrade_2,
		quality_upgrade_3
	]
	for button: Button in quality_upgrade_buttons:
		var upgrade_data : pump_upgrade = pump.quality_upgrades[i]
		button.text = upgrade_data.upgrade_name + " - " + upgrade_data.description + " - $" + str(upgrade_data.price)
		button.pressed.connect(pump.apply_upgrade.bind(upgrade_data))
		i += 1
		
func disconnect_buttons() -> void:
	detach_all_connections(speed_upgrade_1)
	detach_all_connections(speed_upgrade_2)
	detach_all_connections(speed_upgrade_3)
	detach_all_connections(quality_upgrade_1)
	detach_all_connections(quality_upgrade_2)
	detach_all_connections(quality_upgrade_3)
	
func detach_all_connections(button: Button) -> void:
	for cur_conn in button.pressed.get_connections():
		cur_conn.signal.disconnect(cur_conn.callable)
		
func display_empty_upgrade_slot() -> void:
	var entry : VBoxContainer = upgrade_entry.instantiate()
	upgrade_slots.add_child(entry)
	
func display_populated_upgrade_slot(upgrade: pump_upgrade) -> void:
	var entry : VBoxContainer = upgrade_entry.instantiate()
	entry.find_child("Name").text = upgrade.upgrade_name
	entry.find_child("Icon").texture = upgrade.icon
	entry.find_child("Description").text = upgrade.description
	upgrade_slots.add_child(entry)
		
func disable_upgrade_buttons() -> void:
	all_buttons_disabled = true
	speed_upgrade_1.disabled = true
	speed_upgrade_2.disabled = true
	speed_upgrade_3.disabled = true
	quality_upgrade_1.disabled = true
	quality_upgrade_2.disabled = true
	quality_upgrade_3.disabled = true
	
func enable_upgrade_buttons() -> void:
	all_buttons_disabled = false
	speed_upgrade_1.disabled = false
	speed_upgrade_2.disabled = false
	speed_upgrade_3.disabled = false
	quality_upgrade_1.disabled = false
	quality_upgrade_2.disabled = false
	quality_upgrade_3.disabled = false
	
func update_affordability() -> void:
	var i : int = 0
	var speed_upgrade_buttons : Array[Button] = [
		speed_upgrade_1,
		speed_upgrade_2,
		speed_upgrade_3
	]
	for button: Button in speed_upgrade_buttons:
		var upgrade_data : pump_upgrade = current_pump.speed_upgrades[i]
		if ui.money.cur_money >= upgrade_data.price:
			button.disabled = false
		else:
			button.disabled = true
		i += 1
	i = 0
	var quality_upgrade_buttons : Array[Button] = [
		quality_upgrade_1,
		quality_upgrade_2,
		quality_upgrade_3
	]
	for button: Button in quality_upgrade_buttons:
		var upgrade_data : pump_upgrade = current_pump.quality_upgrades[i]
		if ui.money.cur_money >= upgrade_data.price:
			button.disabled = false
		else:
			button.disabled = true
		i += 1
	
