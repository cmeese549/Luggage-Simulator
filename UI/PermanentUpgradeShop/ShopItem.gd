extends Resource

class_name ShopItem

@export var item_name : String = "Belt Speed Upgrade"
@export_multiline var item_description : String = "A very cool and epic item."
@export var item_icon : Texture2D = preload("res://icon.svg")
@export var is_boolean_unlock: bool = true
@export var is_buildable_unlock: bool = true
@export var buildable_scenes: Array[PackedScene]
@export var fixed_price: int = 25
@export var category : String = "Conveyors"
var price : int 
var item_level : int
var item_value : int 

@export var stat_target : String = "belt_speed"
