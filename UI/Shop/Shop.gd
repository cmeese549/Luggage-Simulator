extends MarginContainer

class_name Shop

@onready var player : Player = get_tree().get_first_node_in_group("Player")

@onready var shop_item : PackedScene = preload("res://UI/Shop/ShopItem.tscn")

@onready var ui : UI = $".."
@onready var items_dad : GridContainer = $PanelContainer/MarginContainer/Rows/ScrollContainer/GridContainer
@onready var dialogue_box  : DialogueBox = $PanelContainer/MarginContainer/Rows/HBoxContainer/RichTextLabel
@onready var hud : Control = $"../HUD"
@onready var close_button : Button = $PanelContainer/MarginContainer/Rows/Close/Button
@onready var your_money : Label = $PanelContainer/MarginContainer/Rows/Close/YourMoney

@export var shop_items : Array[ShopItem]

var rng = RandomNumberGenerator.new()

var shop_opened_quips : Array[String] = [
	"Howdy there young weak child, Welcome to my shop.  [color=blue]Have you seen my keys?[/color] I am [b]UNCLE UPGRADE[/b], the greatest upgrade purveyor in all the lands...{pause=1.0}... now please [rainbow]buy something.[/rainbow]{pause=0.5} You interrupted my nap.",
	"Boy I sure do love sellin upgrades.  {pause=0.5}And napping.  {pause=0.5}Mostly napping.  {pause=0.5}I actually only even started selling upgrades so that I could afford a better place to nap. {pause=1.0} God I love napping.... {pause=2.0} By the way, [color=blue]Have you seen my keys?[/color]",
	"You are the only customer I have ever had. {pause=1.0} It's tricky staying in business with just a single customer but luckily you are seemingly addicted to buying stuff at my shop.",
	"Sup? [color=blue]Have you seen my keys?[/color]",
	"[color=blue]Have you seen my keys?[/color]  I really miss my [color=blue]keys.[/color]"
]
var used_shop_opened_quips : Array[String] = []

var cant_afford_quips : Array[String] = [
	"Get ur money up.  And also can you let me know if you see my [color=blue]keys?[/color]",
	"You don't have enough money... {pause=1.0} You really woke me up for this? {pause=0.5}  Do you at least have my [color=blue]keys?[/color]",
	"UR BROKE.  Build more pumps to get more cash. {pause=1.0} Also [color=blue]have you seen my keys?[/color]"
]
var used_cant_afford_quips : Array[String] = []

var item_purchased_quips : Array[String] = [
	"That is the worst item I have ever sold. {pause=0.5} Congrats. {pause=0.5} [color=blue]Have you seen my keys?[/color]",
	"Sick new item bro.  Can I go take a nap now?  I wish I had my [color=blue]keys...[/color]",
	"I never thought I'd find a single person willing to buy that... {pause=1.0}Am I the worlds greatest salesman?{pause=0.5} Even though I [color=blue]lost my keys?[/color]"
]
var used_item_purchased_quips : Array[String] = []

var has_delivered_final_quip : bool = false
var final_quip : String = "OMG!!!{pause=0.5} MY KEYS!!!{pause=0.5} Thank you so much.  Now I can finally get out of here.  By the way...{pause=0.5} [b]I reported you to the government.[/b]{pause=1.5}  You've been fined for damaging the environment.{pause=0.5} All of your money is gone now.{pause=1.0} [rainbow]S{pause=0.1}o{pause=0.1}r{pause=0.1}r{pause=0.1}y{pause=0.1}.{pause=0.1}.{pause=0.1}.{pause=0.1}.[/rainbow]"
@onready var hsep = $PanelContainer/MarginContainer/Rows/HSeparator4
@onready var other_hsep = $PanelContainer/MarginContainer/Rows/HSeparator3
@onready var scroll_container = $PanelContainer/MarginContainer/Rows/ScrollContainer
var final_final_quip : String = "What are you still doing here?{pause=1.0} The game is over.  You can close it now."

func _ready() -> void:
	close_button.pressed.connect(close_shop)
	render_shop_items()
	Events.open_shop.connect(open_shop)
	
func _process(_delta: float) -> void:
	if has_delivered_final_quip:
		ui.money.cur_money = 0

func _input(event) -> void:
	if Input.is_action_just_pressed("OpenShopDebug"):
		open_shop()
	elif Input.is_action_just_released("Pause") or Input.is_action_just_released("ui_cancel"):
		if self.visible:
			close_shop()
	elif Input.is_action_just_pressed("primary") and self.visible:
		dialogue_box.skip_dialogue()

func open_shop() -> void:
	self.visible = true
	hud.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
	var player_has_keys : bool = player.check_has_inventory_item("Uncle Upgrade's Keys")
	ui.pauseable = false
	your_money.text = 'You have: $' + add_comma_to_int(ui.money.cur_money)
	if player_has_keys:
		if !has_delivered_final_quip:
			deliver_final_quip()
	elif has_delivered_final_quip:
		your_money.text = " "
		dialogue_box.render_dialogue(final_final_quip)
	else:
		display_random_quip(shop_opened_quips, used_shop_opened_quips)
	
func deliver_final_quip() -> void:
	player.remove_inventory_items(["Uncle Upgrade's Keys"])
	dialogue_box.render_dialogue(final_quip)
	has_delivered_final_quip = true
	hsep.visible = false
	other_hsep.visible = false
	scroll_container.visible = false
	your_money.text = " "
	
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
		new_shop_item.find_child("VBoxContainer").find_child("ItemPrice").text = "$" + add_comma_to_int(item.price)
		new_shop_item.find_child("VBoxContainer").find_child("ItemDescription").text = item.item_description
		new_shop_item.find_child("VBoxContainer").find_child("ItemRequirements").text = item.required_items_string
		new_shop_item.pressed.connect(attempt_purchase.bind(item, new_shop_item))
		items_dad.add_child(new_shop_item)
		
func attempt_purchase(item: ShopItem, button: Button) -> void:
	var has_required_items = check_has_inventory_items(item)
	if has_required_items:
		print(item.item_name + " has items")
		has_required_items = check_has_tool(item)
	if !has_required_items:
		if dialogue_box.content.text == dialogue_box.pauser.extract_pauses_from_dialogue(item.required_items_quip):
			dialogue_box.skip_dialogue()
		else:
			dialogue_box.render_dialogue(item.required_items_quip)
		return
	
	if ui.money.try_buy(item.price):
		display_random_quip(item_purchased_quips, used_item_purchased_quips)
		button.call_deferred("queue_free")
		player.remove_inventory_items(item.required_inventory_items)
		your_money.text = 'You have: $' + add_comma_to_int(ui.money.cur_money)
		if item.item_type == "Tool":
			Events.tool_purchased.emit(item)
		elif item.item_type == "Speed":
			Events.speed_purchased.emit(item)
	else:
		display_random_quip(cant_afford_quips, used_cant_afford_quips)

func check_has_inventory_items(item: ShopItem) -> bool:
	for required_item: String in item.required_inventory_items:
		var player_has_item = player.check_has_inventory_item(required_item)
		if !player_has_item:
			return false
	return true

func check_has_tool(item: ShopItem) -> bool:
	print(item.item_name)
	for required_tool : String in item.required_tools:
		print(required_tool)
		var player_has_tool = player.check_has_tool(required_tool)
		if !player_has_tool:
			return false
	return true
	
func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	for i in range(str_value.length()-3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value
