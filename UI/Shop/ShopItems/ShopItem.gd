extends Resource

class_name ShopItem

@export var item_name : String = "Epic Item"
@export_multiline var item_description : String = "A very cool and epic item."
@export var item_icon : Texture2D = preload("res://icon.svg")
@export var price : int = 1

@export var item_type : String = "Tool"

@export_multiline var required_items_quip : String = "You'll need to bring me a Lit Test Item to buy that buddy.{pause=0.5}  You should be able to find one along the shore like 2 feet away."

@export_multiline var required_items_string : String = "Requires you to have the Lit Test Item before purchase."

@export var required_inventory_items : Array[String] = [
	"Lit Test Item"
]

@export var required_tools : Array[String] = [
	
]
