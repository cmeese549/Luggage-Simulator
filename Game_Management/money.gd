extends Node

@export var starting_money: int = 0

var cur_money: float

func _ready():
	cur_money = starting_money
	Events.make_money.connect(make_money)

func make_money(amount, notify=false):
	if notify:
		#Could emit signal for money made here for UI
		print("Made "+str(amount)+" money")
	cur_money += amount
	

func try_buy(amount):
	if cur_money >= amount:
		cur_money -= amount
		print("Paid "+str(amount))
		return true
	else:
		print("Not enough money, need "+str(amount)+" have "+str(cur_money))
		return false
