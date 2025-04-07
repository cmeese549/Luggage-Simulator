extends Node

var all_pumps: Array[Pump]
var built_pumps: Array[Pump]

var current_pump_price = 10

func _ready():
	Events.add_pump.connect(new_pump)
	all_pumps = find_all_pumps()

func find_all_pumps():
	var result: Array[Pump] = []
	for layer in get_children():
		for p in layer.get_children():
			result.append(p)
	return result

func new_pump(n_pump: Pump):
	built_pumps.append(n_pump)
	current_pump_price = current_pump_price * (1.16)
	for p in all_pumps:
		p.update_price(int(current_pump_price))
