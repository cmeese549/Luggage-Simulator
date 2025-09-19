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

@onready var scroll_container = $PanelContainer/MarginContainer/Rows/ScrollContainer

var shop_items_by_button: Dictionary = {}

func _ready() -> void:
	close_button.pressed.connect(close_shop)
	setup_dynamic_tabs()

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
	
func setup_dynamic_tabs() -> void:
	var tab_container = $PanelContainer/MarginContainer/Rows/ScrollContainer/TabContainer
	
	# Clear existing tabs
	for child in tab_container.get_children():
		child.queue_free()
	
	# Scan ShopItems folders
	var dir = DirAccess.open("res://UI/PermanentUpgradeShop/ShopItems/")
	if not dir:
		push_error("Failed to access ShopItems directory")
		return
	
	dir.list_dir_begin()
	var folder_name = dir.get_next()
	
	while folder_name != "":
		if dir.current_is_dir() and not folder_name.begins_with("."):
			# Create new tab with GridContainer
			var grid_container = GridContainer.new()
			grid_container.columns = 4
			grid_container.name = folder_name
			
			tab_container.add_child(grid_container)
		
		folder_name = dir.get_next()
	
	dir.list_dir_end()
	populate_tabs_with_items()
	
func populate_tabs_with_items() -> void:
	var tab_container = $PanelContainer/MarginContainer/Rows/ScrollContainer/TabContainer
	
	for tab in tab_container.get_children():
		var grid_container = tab as GridContainer
		var folder_name = grid_container.name
		
		# Scan folder for .tres files
		var folder_path = "res://UI/PermanentUpgradeShop/ShopItems/" + folder_name + "/"
		var dir = DirAccess.open(folder_path)
		if not dir:
			print("Failed to access folder: ", folder_path)
			continue
		
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".tres"):
				var item_path = folder_path + file_name
				var shop_item_resource = ResourceLoader.load(item_path) as ShopItem
				
				if shop_item_resource:
					create_shop_item_button(shop_item_resource, grid_container)
			
			file_name = dir.get_next()
		
		dir.list_dir_end()
		
func create_shop_item_button(item: ShopItem, parent_container: GridContainer) -> void:
	var new_shop_item : Button = shop_item.instantiate()
	new_shop_item.find_child("VBoxContainer").find_child("ItemName").text = item.item_name
	new_shop_item.find_child("VBoxContainer").find_child("ItemIcon").texture = item.item_icon
	new_shop_item.find_child("VBoxContainer").find_child("ItemDescription").text = item.item_description
	new_shop_item.pressed.connect(attempt_purchase.bind(item, new_shop_item))
	
	# Store the ShopItem reference in dictionary
	shop_items_by_button[new_shop_item] = item
	
	parent_container.add_child(new_shop_item)
	
func refresh_shop_display():
	for button in shop_items_by_button.keys():
		var item = shop_items_by_button[button]
		update_shop_item_display(item, button)
	
func attempt_purchase(item: ShopItem, button: Button) -> void:
	var profile = ProfileManager.current_profile
	if not profile:
		return
	
	var item_price = profile.get_item_price(item)
	var is_already_owned = is_item_owned(item, profile)
	
	if is_already_owned:
		print("Already own ", item.stat_target)
		return
		
	if profile.gold_stars >= item_price:
		profile.gold_stars -= item_price
		star_counter.text = "⭐ " + str(profile.gold_stars)
		profile.apply_item_purchase(item)
		ProfileManager.save_current_profile()
		
		your_money.text = 'Gold Stars: ' + add_comma_to_int(profile.gold_stars)
		update_shop_item_display(item, button)
		print("Purchased ", item.item_name)
	else:
		print("Not enough gold stars! Need ", item_price, ", have ", profile.gold_stars)
		
func is_item_owned(item: ShopItem, profile: PlayerProfile) -> bool:
	if item.is_buildable_unlock:
		return profile.buildable_unlocks.get(item.stat_target, false)
	elif item.category == "QOL":
		return profile.qol_unlocks.get(item.stat_target, false)
	else:
		# Stat upgrades use max level logic, not "owned"
		return not profile.can_upgrade(item.stat_target)

func update_shop_item_display(item: ShopItem, button: Button) -> void:
	var profile = ProfileManager.current_profile
	
	
	var level_label = button.find_child("VBoxContainer").find_child("ItemLevel")
	var value_label = button.find_child("VBoxContainer").find_child("ItemValue")
	var price_label = button.find_child("VBoxContainer").find_child("ItemPrice")
	var action_label = button.find_child("VBoxContainer").find_child("nuttin")
	
	if item.is_buildable_unlock or item.category == "QOL":
		level_label.visible = false
		value_label.visible = false
		action_label.visible = true
		
		var is_owned = is_item_owned(item, profile)
		if is_owned:
			price_label.text = "OWNED"
			action_label.text = "Already unlocked!"
			button.disabled = true
		else:
			price_label.text = str(profile.get_item_price(item)) + " ⭐"
			action_label.text = "Click to unlock"
			button.disabled = false
			
	else:
		# Stat upgrade - show all labels with existing logic
		level_label.visible = true
		value_label.visible = true
		action_label.visible = true
		
		var current_level = profile.upgrade_levels.get(item.stat_target, 0)
		var max_level = profile.max_levels.get(item.stat_target, 20)
		var can_upgrade = profile.can_upgrade(item.stat_target)
		
		level_label.text = "Current Level: " + str(current_level) + "/" + str(max_level)
		value_label.text = "Current value: " + get_current_stat_value(item.stat_target, profile)
		
		if can_upgrade:
			var next_price = profile.get_upgrade_cost(item.stat_target)
			price_label.text = str(next_price) + " ⭐"
			action_label.text = "Click to add 1 level"
			button.disabled = false
		else:
			price_label.text = "MAX LEVEL"
			action_label.text = "Fully upgraded!"
			button.disabled = true

func get_current_stat_value(stat_name: String, profile: PlayerProfile) -> String:
	match stat_name:
		"starting_money":
			return "$" + str(profile.get_starting_money())
		"gold_stars_per_day":
			return str(profile.get_gold_stars_per_day())
		_:
			return "N/A"
			
func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	for i in range(str_value.length()-3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value
