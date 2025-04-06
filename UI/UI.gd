extends Control

class_name UI

@onready var player : Player = get_tree().get_first_node_in_group("Player")

var money: Money

func _ready():
	Events.all_ready.connect(all_ready)

func all_ready():
	money = %Money
