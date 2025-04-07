extends Control

@onready var money_label : Label = $Money/PanelContainer/HBoxContainer/MoneyLabel
@onready var ui : Control = $".."

@onready var shop : Shop = $"../Shop"

func _process(delta):
	if shop.has_delivered_final_quip:
		if ui.money:
			money_label.text = "$0 :("
	else:
		if ui.money:
			money_label.text = "$" + add_comma_to_int(roundi(ui.money.cur_money))

func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	for i in range(str_value.length()-3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value
