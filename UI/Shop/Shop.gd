extends MarginContainer

class_name Shop

@onready var player : Player = get_tree().get_first_node_in_group("Player")

@onready var shop_item : PackedScene = preload("res://UI/Shop/ShopItem.tscn")

@onready var ui : UI = $".."
@onready var items_dad : GridContainer = $PanelContainer/MarginContainer/Rows/ScrollContainer/GridContainer
@onready var dialogue_box  : DialogueBox = $PanelContainer/MarginContainer/Rows/HBoxContainer/RichTextLabel
@onready var hud : Control = $"../HUD"
@onready var close_button : Button = $PanelContainer/MarginContainer/Rows/Close/Button

@export var shop_items : Array[ShopItem]

var rng = RandomNumberGenerator.new()

var shop_opened_quips : Array[String] = [
	"Howdy there young weak child, Welcome to my shop.  I am [b]UNCLE UPGRADE[/b], the greatest upgrade purveyor in all the lands...{pause=1.0}... now please [rainbow]buy something.[/rainbow]{pause=0.5} You interrupted my nap.",
	"Boy I sure do love sellin upgrades.  {pause=0.5}And napping.  {pause=0.5}Mostly napping.  {pause=0.5}I actually only even started selling upgrades so that I could afford a better place to nap. {pause=1.0} God I love napping...."
]
var used_shop_opened_quips : Array[String] = []

var cant_afford_quips : Array[String] = [
	"Get ur money up",
	"You don't have enough money... {pause=1.0} You really woke me up for this?"
]
var used_cant_afford_quips : Array[String] = []

var item_purchased_quips : Array[String] = [
	"That is the worst item I have ever sold. {pause=0.5} Congrats.",
	"Sick new item bro.  Can I go take a nap now?"
]
var used_item_purchased_quips : Array[String] = []

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
	display_random_quip(shop_opened_quips, used_shop_opened_quips)
	ui.pauseable = false
	
func close_shop() -> void:
	dialogue_box.stop_dialogue()
	self.visible = false
	hud.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().paused = false
	ui.pauseable = true
	
func display_random_quip(quips, used_quips) -> void:
	rng.randomize()
	var quip : String = quips[rng.randi_range(0, quips.size() - 1)]
	dialogue_box.render_dialogue(quip)
	quips.erase(quip)
	used_quips.append(quip)
	check_all_quips_used()
	
func check_all_quips_used() -> void:
	if shop_opened_quips.size() == 0:
		shop_opened_quips = used_shop_opened_quips
		used_shop_opened_quips = []
	if cant_afford_quips.size() == 0:
		cant_afford_quips = used_cant_afford_quips
		used_cant_afford_quips = []
	if item_purchased_quips.size() == 0:
		item_purchased_quips = used_item_purchased_quips
		used_item_purchased_quips = []
	
func render_shop_items() -> void:
	for item: ShopItem in shop_items:
		var new_shop_item : Button = shop_item.instantiate()
		new_shop_item.find_child("VBoxContainer").find_child("ItemName").text = item.item_name
		new_shop_item.find_child("VBoxContainer").find_child("ItemIcon").texture = item.item_icon
		new_shop_item.find_child("VBoxContainer").find_child("ItemPrice").text = "$" + str(item.price)
		new_shop_item.find_child("VBoxContainer").find_child("ItemDescription").text = item.item_description
		new_shop_item.find_child("VBoxContainer").find_child("ItemRequirements").text = item.required_items_string
		new_shop_item.pressed.connect(attempt_purchase.bind(item, new_shop_item))
		items_dad.add_child(new_shop_item)
		
func attempt_purchase(item: ShopItem, button: Button) -> void:
	var has_required_items = check_has_inventory_items(item)
	if has_required_items:
		has_required_items = check_has_tool(item)
	if !has_required_items:
		dialogue_box.render_dialogue(item.required_items_quip)
		return
	
	if ui.money.try_buy(item.price):
		display_random_quip(item_purchased_quips, used_item_purchased_quips)
		button.call_deferred("queue_free")
		player.remove_inventory_items(item.required_inventory_items)
		if item.item_type == "Tool":
			Events.tool_purchased.emit(item)
	else:
		display_random_quip(cant_afford_quips, used_cant_afford_quips)

func check_has_inventory_items(item: ShopItem) -> bool:
	for required_item: String in item.required_inventory_items:
		var player_has_item = player.check_has_inventory_item(required_item)
		if !player_has_item:
			return false
	return true

func check_has_tool(item: ShopItem) -> bool:
	for required_tool : String in item.required_tools:
		var player_has_tool = player.check_has_tool(required_tool)
		if !player_has_tool:
			return false
	return true
