extends MarginContainer

class_name Shop

@onready var player : Player = get_tree().get_first_node_in_group("Player")

var shop_item : PackedScene = preload("res://UI/PermanentUpgradeShop/ShopItem.tscn")

@onready var ui : UI = $".."
@onready var items_dad : GridContainer = $PanelContainer/MarginContainer/Rows/ScrollContainer/GridContainer
@onready var hud : Control = $"../HUD"
@onready var close_button : Button = $PanelContainer/MarginContainer/Rows/Close/Button
@onready var your_money : Label = $PanelContainer/MarginContainer/Rows/Close/YourMoney

@export var shop_items : Array[ShopItem]

@onready var hsep = $PanelContainer/MarginContainer/Rows/HSeparator4
@onready var other_hsep = $PanelContainer/MarginContainer/Rows/HSeparator3
@onready var scroll_container = $PanelContainer/MarginContainer/Rows/ScrollContainer

func _ready() -> void:
	close_button.pressed.connect(close_shop)
	render_shop_items()

func _input(event) -> void:
	if Input.is_action_just_pressed("OpenShopDebug"):
		open_shop()
	elif Input.is_action_just_released("Pause") or Input.is_action_just_released("ui_cancel"):
		if self.visible:
			close_shop()

func open_shop() -> void:
	self.visible = true
	hud.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
	
	if items_dad.get_children().size() > 0:
		items_dad.get_child(0).grab_focus()
	else:
		close_button.grab_focus()

	ui.pauseable = false
	your_money.text = 'Gold Stars: ' + add_comma_to_int(ProfileManager.current_profile.gold_stars)
	
	
func close_shop() -> void:
	self.visible = false
	hud.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().paused = false
	ui.pauseable = true
	
func render_shop_items() -> void:
	for item: ShopItem in shop_items:
		var new_shop_item : Button = shop_item.instantiate()
		new_shop_item.find_child("VBoxContainer").find_child("ItemName").text = item.item_name
		new_shop_item.find_child("VBoxContainer").find_child("ItemIcon").texture = item.item_icon
		new_shop_item.find_child("VBoxContainer").find_child("ItemPrice").text = "$" + add_comma_to_int(item.price)
		new_shop_item.find_child("VBoxContainer").find_child("ItemDescription").text = item.item_description
		new_shop_item.find_child("VBoxContainer").find_child("ItemRequirements").text = item.required_items_string
		new_shop_item.pressed.connect(attempt_purchase.bind(item, new_shop_item))
		items_dad.add_child(new_shop_item)
		
func attempt_purchase(item: ShopItem, button: Button) -> void:
	if ui.money.try_buy_gold_stars(item.price):
		your_money.text = 'Gold Stars: ' + add_comma_to_int(ProfileManager.current_profile.gold_stars)
		#TODO APPLY UPGRADE

	
func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	for i in range(str_value.length()-3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value
