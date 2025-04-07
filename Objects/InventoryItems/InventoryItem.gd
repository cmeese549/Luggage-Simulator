extends Node

class_name InventoryItem

@export var item_name : String = "Epic Item"
@export var item_description : String = "A very cool and epic item.  Maybe you can trade it for a bucket?"
@export var item_icon : Texture2D = preload("res://icon.svg")

@onready var sprite : Sprite3D = $Bouncer/Sprite3D
@onready var text : Label3D = $Bouncer/Label3D

func _ready() -> void:
	print(self.global_position)
	sprite.texture = item_icon
	text.text = item_name
