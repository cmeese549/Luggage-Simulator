@tool
extends Node

class_name InventoryItem

@export var item_name : String = "Epic Item"
@export var item_description : String = "A very cool and epic item.  Maybe you can trade it for a bucket?"
@export var item_icon : Texture2D = preload("res://icon.svg")

@export var twinkle_diameter_meters : float = 0.5

@onready var sprite : Sprite3D = $Bouncer/Sprite3D
@onready var text : Label3D = $Bouncer/Label3D
@onready var twinkle : AudioStreamPlayer3D = $Twinkle

func _ready() -> void:
	sprite.texture = item_icon
	text.text = item_name
	twinkle.unit_size = twinkle_diameter_meters
	
func _process(_delta: float) -> void:
	if !Engine.is_editor_hint():
		return
	sprite.texture = item_icon
	text.text = item_name
