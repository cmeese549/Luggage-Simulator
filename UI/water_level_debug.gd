extends Control

@onready var water_amount_num = $MarginContainer/PanelContainer/VBoxContainer/WaterAmount/WaterAmountNum
@onready var water_level_num = $MarginContainer/PanelContainer/VBoxContainer/WaterLevel/WaterLevelNum
@onready var wps_num = $MarginContainer/PanelContainer/VBoxContainer/WPS/WPSNum
@onready var money_num = $MarginContainer/PanelContainer/VBoxContainer/Money/MoneyNum

var water_obj: Node3D
var money: Node

func _ready():
	Events.all_ready.connect(all_ready)

func all_ready():
	water_obj = %Water
	money = %Money

func _process(_delta):
	if water_obj:
		water_amount_num.text = str(water_obj.cur_amount)
		water_level_num.text = "%.2f" % water_obj.cur_y
		wps_num.text = "%.2f" % water_obj.cur_wps_out
	else:
		print("No Water Obje")
	
	if money:
		money_num.text = "$"+str(money.cur_money)
