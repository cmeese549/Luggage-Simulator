extends MarginContainer

class_name UpgradeMenu

@onready var upgrade_entry : PackedScene = preload("res://UI/UpgradeMenu/UpgradeSlot.tscn")
@onready var ui : UI = $".."
@onready var hud : Control = $"../HUD"

@onready var speed_upgrade_1 : Button = $PanelContainer/MarginContainer/Rows/HBoxContainer/SpeedUpgrades/VBoxContainer/Button
@onready var speed_upgrade_2 : Button = $PanelContainer/MarginContainer/Rows/HBoxContainer/SpeedUpgrades/VBoxContainer/Button2
@onready var speed_upgrade_3 : Button = $PanelContainer/MarginContainer/Rows/HBoxContainer/SpeedUpgrades/VBoxContainer/Button3

@onready var quality_upgrade_1 : Button = $PanelContainer/MarginContainer/Rows/HBoxContainer/QualityUpgrades/VBoxContainer/Button
@onready var quality_upgrade_2 : Button = $PanelContainer/MarginContainer/Rows/HBoxContainer/QualityUpgrades/VBoxContainer/Button2
@onready var quality_upgrade_3 : Button = $PanelContainer/MarginContainer/Rows/HBoxContainer/QualityUpgrades/VBoxContainer/Button3

@onready var upgrade_slots : HBoxContainer = find_child("UpgradeSlots")
@onready var close_button : Button = $PanelContainer/MarginContainer/Rows/Close/Button

@onready var wps : RichTextLabel = $PanelContainer/MarginContainer/Rows/HBoxContainer2/WPS
@onready var mps : RichTextLabel = $PanelContainer/MarginContainer/Rows/HBoxContainer2/MPS
var current_wps : float = 0
var current_mps : float = 0
var current_quality : float = 0

@onready var your_money : Label = $PanelContainer/MarginContainer/Rows/Close/YourMoney

var all_buttons_disabled : bool = false

var current_pump : Pump = null

func _input(event) -> void:
	if self.visible:
		if Input.is_action_just_released("ui_cancel") or Input.is_action_just_released("Pause"):
			close()

func _ready() -> void:
	close_button.pressed.connect(close)
	
func _process(_delta: float) -> void:
	if current_pump == null or !self.visible:
		return
	update_affordability()

func close() -> void:
	hud.visible = true
	current_pump = null
	self.visible = false
	get_tree().paused = false
	disconnect_buttons()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	ui.pauseable = true

func open(pump: Pump) -> void:
	hud.visible = false
	current_pump = pump
	self.visible = true
	get_tree().paused = true
	wps.text = "Water Per Second: [color=blue]" + str(snappedf(pump.cur_wps, 0.01)) + "[/color]"
	mps.text = "Money Per Second: [color=green]$" + str(snappedf(pump.cur_wps * pump.cur_quality, 0.01)) + "[/color]"
	current_wps = pump.cur_wps
	current_mps = pump.cur_wps * pump.cur_quality
	current_quality = pump.cur_quality
	render_upgrades(pump)
	connect_buttons(pump)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	ui.pauseable = false
	your_money.text = "You have: $" + add_comma_to_int(ui.money.cur_money)
	
func render_upgrades(pump: Pump) -> void:
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
	
func connect_buttons(pump: Pump) -> void:
	print(pump)
	var i : int = 0
	var speed_upgrade_buttons : Array[Button] = [
		speed_upgrade_1,
		speed_upgrade_2,
		speed_upgrade_3
	]
	for button: Button in speed_upgrade_buttons:
		var upgrade_data : pump_upgrade = pump.speed_upgrades[i]
		button.text = upgrade_data.upgrade_name + " - " + upgrade_data.description + " - $" + add_comma_to_int(upgrade_data.price)
		button.pressed.connect(apply_upgrade.bind(upgrade_data, pump))
		i += 1
	i = 0
	var quality_upgrade_buttons : Array[Button] = [
		quality_upgrade_1,
		quality_upgrade_2,
		quality_upgrade_3
	]
	for button: Button in quality_upgrade_buttons:
		var upgrade_data : pump_upgrade = pump.quality_upgrades[i]
		button.text = upgrade_data.upgrade_name + " - " + upgrade_data.description + " - $" + add_comma_to_int(upgrade_data.price)
		button.pressed.connect(apply_upgrade.bind(upgrade_data, pump))
		i += 1
		
func apply_upgrade(data: pump_upgrade, pump: Pump) -> void:
	if ui.money.try_buy(data.price):
		pump.apply_upgrade(data)
		match data.type:
			pump_upgrade.upgrade_type.QUALITY: 
				current_quality += data.effect
				current_mps = current_wps * current_quality
			pump_upgrade.upgrade_type.SPEED:
				current_wps += data.effect
		wps.text = "Water Per Second: [color=blue]" + str(snappedf(current_wps, 0.01)) + "[/color]"
		mps.text = "Money Per Second: [color=green]$" + str(snappedf(current_mps, 0.01)) + "[/color]"
		your_money.text = "You have: $" + add_comma_to_int(ui.money.cur_money)
		
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
	
func update_affordability() -> void:
	var applied_upgrades : int = 0
	for upgrade: pump_upgrade in current_pump.upgrade_slots:
		if upgrade != null:
			applied_upgrades += 1
	var i : int = 0
	var speed_upgrade_buttons : Array[Button] = [
		speed_upgrade_1,
		speed_upgrade_2,
		speed_upgrade_3
	]
	for button: Button in speed_upgrade_buttons:
		var upgrade_data : pump_upgrade = current_pump.speed_upgrades[i]
		if roundi(ui.money.cur_money) >= upgrade_data.price and applied_upgrades < 5:
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
		if roundi(ui.money.cur_money) >= upgrade_data.price and applied_upgrades < 5:
			button.disabled = false
		else:
			button.disabled = true
		i += 1
	
func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	for i in range(str_value.length()-3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value
