extends Node

class_name Money

@export var starting_money: int = 0

@onready var money_sound : AudioStreamPlayer = $MoneySound

var cur_money: float

var lifetime_money: float

func get_save_data() -> Dictionary:
	var data: Dictionary = {}
	data.cur_money = cur_money
	data.lifetime_money = lifetime_money
	return data

func load_save_data(data: Dictionary) -> void:
	cur_money = data.cur_money
	lifetime_money = data.lifetime_money

func _ready():
	cur_money = starting_money
	lifetime_money = starting_money
	Events.make_money.connect(make_money)

func make_money(amount, notify=false):
	if notify:
		#Could emit signal for money made here for UI
		print("Made "+str(amount)+" money")
	cur_money += amount
	lifetime_money += amount
	
func check_can_buy(amount: float) -> bool:
	if roundi(cur_money) >= amount:
		return true
	else:
		return false
	

func try_buy(amount: float) -> bool:
	if roundi(cur_money) >= amount:
		cur_money -= amount
		print("Paid "+str(amount))
		money_sound.play()
		return true
	else:
		print("Not enough money, need "+str(amount)+" have "+str(cur_money))
		return false
