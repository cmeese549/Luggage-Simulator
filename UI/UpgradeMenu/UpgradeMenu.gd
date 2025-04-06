extends MarginContainer

class_name UpgradeMenu

@onready var speed_upgrade_1 : Button = $PanelContainer/MarginContainer/Rows/HBoxContainer/SpeedUpgrades/VBoxContainer/Button
@onready var speed_upgrade_2 : Button = $PanelContainer/MarginContainer/Rows/HBoxContainer/SpeedUpgrades/VBoxContainer/Button2
@onready var speed_upgrade_3 : Button = $PanelContainer/MarginContainer/Rows/HBoxContainer/SpeedUpgrades/VBoxContainer/Button3

@onready var quality_upgrade_1 : Button = $PanelContainer/MarginContainer/Rows/HBoxContainer/QualityUpgrades/VBoxContainer/Button
@onready var quality_upgrade_2 : Button = $PanelContainer/MarginContainer/Rows/HBoxContainer/QualityUpgrades/VBoxContainer/Button2
@onready var quality_upgrade_3 : Button = $PanelContainer/MarginContainer/Rows/HBoxContainer/QualityUpgrades/VBoxContainer/Button3

@onready var upgrade_slots : HBoxContainer = find_child("UpgradeSlots")

@export var speed_upgrades : Array[pump_upgrade] = []
@export var qualtiy_upgrades : Array[pump_upgrade] = []

func open(pump: Pump) -> void:
	pass
