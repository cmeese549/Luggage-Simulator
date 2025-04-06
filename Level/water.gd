extends Node3D

@export var starting_y: float = -1
@export var ending_y: float = -90

@export var starting_amount: float = 1000000000000

var cur_amount: float
var cur_y: float
var cur_wps_out: float

var pumps: Array[pump] = []

func _ready():
	cur_amount = starting_amount
	position.y = starting_y
	
	Events.remove_water.connect(remove_water)

func _process(delta):
	cur_wps_out = 0
	for w_pump in pumps:
		cur_amount -= w_pump.cur_wps * delta
		cur_wps_out +=w_pump.cur_wps
	
	if cur_amount <= 0: now_empty()
	
	cur_y = remap(cur_amount, starting_amount, 0, starting_y, ending_y)
	position.y = cur_y

func remove_water(amount):
	print("Removing "+str(amount)+" water")
	cur_amount -= amount

func add_pump(new_pump: pump):
	pumps.append(new_pump)

func now_empty():
	print("All the water is gone hurray!!!")
