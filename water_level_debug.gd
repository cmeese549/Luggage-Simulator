extends Control

@onready var water_amount_num = $MarginContainer/PanelContainer/VBoxContainer/WaterAmount/WaterAmountNum
@onready var water_level_num = $MarginContainer/PanelContainer/VBoxContainer/WaterLevel/WaterLevelNum
@onready var wps_num = $MarginContainer/PanelContainer/VBoxContainer/WPS/WPSNum


var water_obj: Node3D

func _ready():
	Events.all_ready.connect(all_ready)

func all_ready():
	water_obj = %Water

func _process(delta):
	if water_obj:
		water_amount_num.text = str(water_obj.cur_amount)
		water_level_num.text = str(water_obj.cur_y)
		wps_num.text = "%.2f" % water_obj.cur_wps_out
	else:
		print("No Water Obje")
