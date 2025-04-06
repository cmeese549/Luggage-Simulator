extends Node

@export var starting_money: int = 0

var cur_money: int

func _ready():
	cur_money = starting_money
	Events.make_money.connect(make_money)

func make_money(amount):
	print("Made "+str(amount)+" money")
	cur_money += amount
	#Could emit signal for money made here for UI

func try_buy(amount):
	if cur_money >= amount:
		cur_money -= amount
		print("Paid "+str(amount))
		return true
	else:
		return false
