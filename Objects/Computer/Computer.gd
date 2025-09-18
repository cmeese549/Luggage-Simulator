extends Node3D

class_name Computer

@onready var shop_screen : Shop = get_tree().get_first_node_in_group("Shop")

func interact():
	shop_screen.open_shop()
