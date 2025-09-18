extends MarginContainer

class_name Shop

@onready var player : Player = get_tree().get_first_node_in_group("Player")

var shop_item : PackedScene = preload("res://UI/PermanentUpgradeShop/ShopItem.tscn")

@onready var ui : UI = $".."
@onready var items_dad : GridContainer = $PanelContainer/MarginContainer/Rows/ScrollContainer/GridContainer
@onready var hud : Control = $"../HUD"
@onready var close_button : Button = $PanelContainer/MarginContainer/Rows/HBoxContainer/CloseButton
@onready var your_money : Label = $PanelContainer/MarginContainer/Rows/HBoxContainer/StarsLabel

@onready var star_counter: Label = get_tree().get_first_node_in_group("StarCounter")

@export var shop_items : Array[ShopItem]

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

	ui.pauseable = false
	your_money.text = 'Gold Stars: ' + add_comma_to_int(ProfileManager.current_profile.gold_stars)
	refresh_shop_display()
	
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
		new_shop_item.find_child("VBoxContainer").find_child("ItemDescription").text = item.item_description
		new_shop_item.pressed.connect(attempt_purchase.bind(item, new_shop_item))
		
		# Set dynamic pricing and level info from active profile
		update_shop_item_display(item, new_shop_item)
		
		items_dad.add_child(new_shop_item)
		

func update_shop_item_display(item: ShopItem, button: Button) -> void:
	var profile = ProfileManager.current_profile
	if not profile:
		return
	
	if item.is_boolean_unlock:
		update_boolean_unlock_display(item, button, profile)
	else:
		update_stat_upgrade_display(item, button, profile)

func update_boolean_unlock_display(item: ShopItem, button: Button, profile: PlayerProfile) -> void:
	var is_owned = profile.unlocks.get(item.stat_target, false)
	
	# Update level display
	var level_label = button.find_child("VBoxContainer").find_child("ItemLevel")
	level_label.text = "Status: " + ("OWNED" if is_owned else "Not Owned")
	
	# Update value display 
	var value_label = button.find_child("VBoxContainer").find_child("ItemValue")
	value_label.text = "Unlock: " + item.item_name
	
	# Update price and purchase info
	var price_label = button.find_child("VBoxContainer").find_child("ItemPrice")
	var action_label = button.find_child("VBoxContainer").find_child("nuttin")
	
	if is_owned:
		price_label.text = "OWNED"
		action_label.text = "Already unlocked!"
		button.disabled = true
	else:
		price_label.text = str(item.fixed_price) + " ⭐"
		action_label.text = "Click to unlock"
		button.disabled = false

func update_stat_upgrade_display(item: ShopItem, button: Button, profile: PlayerProfile) -> void:
	var current_level = profile.upgrade_levels.get(item.stat_target, 0)
	var max_level = profile.max_levels.get(item.stat_target, 20)
	var can_upgrade = profile.can_upgrade(item.stat_target)
	
	# Update level display
	var level_label = button.find_child("VBoxContainer").find_child("ItemLevel")
	level_label.text = "Current Level: " + str(current_level) + "/" + str(max_level)
	
	# Update value display (current stat value)
	var value_label = button.find_child("VBoxContainer").find_child("ItemValue")
	var current_value = get_current_stat_value(item.stat_target, profile)
	value_label.text = "Current value: " + str(current_value)
	
	# Update price and purchase info
	var price_label = button.find_child("VBoxContainer").find_child("ItemPrice")
	var action_label = button.find_child("VBoxContainer").find_child("nuttin")
	
	if can_upgrade:
		var next_price = profile.get_upgrade_cost(item.stat_target)
		price_label.text = str(next_price) + " ⭐"
		
		# Calculate value gain for next level
		var next_level_value = get_next_level_stat_value(item.stat_target, profile)
		var value_gain = get_value_gain_text(item.stat_target, current_value, next_level_value)
		action_label.text = "Click to add 1 level (+" + value_gain + ")"
		button.disabled = false
	else:
		price_label.text = "MAX LEVEL"
		action_label.text = "Fully upgraded!"
		button.disabled = true

func attempt_purchase(item: ShopItem, button: Button) -> void:
	var profile = ProfileManager.current_profile
	if not profile:
		return
	
	if item.is_boolean_unlock:
		# Handle boolean unlock purchase
		if profile.unlocks.get(item.stat_target, false):
			print("Already own ", item.stat_target)
			return
			
		if profile.gold_stars >= item.fixed_price:
			profile.gold_stars -= item.fixed_price
			star_counter.text = "⭐ " + str(profile.gold_stars)
			profile.unlocks[item.stat_target] = true
			ProfileManager.save_current_profile()
			
			player.apply_upgrade_by_name(item.item_name)
			
			your_money.text = 'Gold Stars: ' + add_comma_to_int(profile.gold_stars)
			update_shop_item_display(item, button)
			print("Unlocked ", item.stat_target)
		else:
			print("Not enough gold stars! Need ", item.fixed_price, ", have ", profile.gold_stars)
	else:
		# Handle stat upgrade purchase (existing logic)
		if not profile.can_upgrade(item.stat_target):
			print("Already at max level for ", item.stat_target)
			return
		
		var current_price = profile.get_upgrade_cost(item.stat_target)
		
		if profile.gold_stars >= current_price:
			profile.gold_stars -= current_price
			star_counter.text = "⭐ " + str(profile.gold_stars)
			profile.upgrade_levels[item.stat_target] += 1
			ProfileManager.save_current_profile()
			
			your_money.text = 'Gold Stars: ' + add_comma_to_int(profile.gold_stars)
			update_shop_item_display(item, button)
			print("Upgraded ", item.stat_target, " to level ", profile.upgrade_levels[item.stat_target])
		else:
			print("Not enough gold stars! Need ", current_price, ", have ", profile.gold_stars)

func get_next_level_stat_value(stat_name: String, profile: PlayerProfile) -> String:
	# Temporarily increase level to calculate next value
	var original_level = profile.upgrade_levels[stat_name]
	profile.upgrade_levels[stat_name] = original_level + 1
	var next_value = get_current_stat_value(stat_name, profile)
	profile.upgrade_levels[stat_name] = original_level  # Restore original
	return next_value

func get_value_gain_text(stat_name: String, current_value: String, next_value: String) -> String:
	match stat_name:
		"belt_speed", "machine_speed", "health_drain_rate", "health_recovery_rate":
			var current_float = float(current_value)
			var next_float = float(next_value)
			var gain = next_float - current_float
			return "%.2f" % gain
		"box_value_bonus", "build_cost_reduction":
			# These are percentages, extract the number
			var current_num = float(current_value.replace("%", ""))
			var next_num = float(next_value.replace("%", ""))
			var gain = next_num - current_num
			return "%.0f%%" % gain
		"starting_money":
			var current_num = int(current_value.replace("$", ""))
			var next_num = int(next_value.replace("$", ""))
			var gain = next_num - current_num
			return "$" + str(gain)
		"gold_stars_per_day":
			var gain = int(next_value) - int(current_value)
			return str(gain)
		_:
			return "N/A"

func get_current_stat_value(stat_name: String, profile: PlayerProfile) -> String:
	match stat_name:
		"belt_speed":
			return "%.1f" % profile.get_belt_speed()
		"machine_speed":
			return "%.1f" % profile.get_machine_speed()
		"health_drain_rate":
			return "%.2f" % profile.get_health_drain_rate()
		"health_recovery_rate":
			return "%.1f" % profile.get_health_recovery_rate()
		"box_value_bonus":
			return "%.0f%%" % (profile.get_box_value_multiplier() * 100)
		"build_cost_reduction":
			return "%.0f%%" % ((1.0 - profile.get_build_cost_multiplier()) * 100)
		"starting_money":
			return "$" + str(profile.get_starting_money())
		"gold_stars_per_day":
			return str(profile.get_gold_stars_per_day())
		_:
			return "N/A"
			
func refresh_shop_display() -> void:
	# Update all existing shop item displays with current profile data
	for i in range(items_dad.get_child_count()):
		var shop_button = items_dad.get_child(i)
		var shop_item = shop_items[i]
		update_shop_item_display(shop_item, shop_button)
	
func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	for i in range(str_value.length()-3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value
