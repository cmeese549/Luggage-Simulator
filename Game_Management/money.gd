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
	
func start_new_run():
	if ProfileManager.current_profile:
		starting_money = ProfileManager.current_profile.get_starting_money()
		cur_money = starting_money
		print("Starting new run with $", starting_money, " (progression bonus: +$", ProfileManager.current_profile.get_starting_money() - ProfileManager.current_profile.base_starting_money, ")")
	else:
		cur_money = 0

func make_money(amount, notify=false):
	if notify:
		#Could emit signal for money made here for UI
		pass
	cur_money += amount
	lifetime_money += amount
	
func check_can_buy(amount: float) -> bool:
	if roundi(cur_money) >= amount:
		return true
	else:
		return false
	
func try_buy_gold_stars(amount: float) -> bool:
	var stars: int = ProfileManager.current_profile.gold_stars
	if stars >= amount:
		stars -= amount
		print("Paid "+str(amount))
		money_sound.play()
		return true
	else:
		print("Not enough stars, need "+str(amount)+" have "+str(stars))
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
