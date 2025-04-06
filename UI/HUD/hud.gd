extends Control

@onready var money_label : Label = $Money/PanelContainer/HBoxContainer/MoneyLabel
@onready var ui : Control = $".."

func _process(delta):
	if ui.money:
		money_label.text = "$"+str(roundi(ui.money.cur_money))
