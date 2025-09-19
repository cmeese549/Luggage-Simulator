extends MarginContainer

class_name Shop

@onready var building_system = get_tree().get_first_node_in_group("BuildingSystem")
@onready var player : Player = get_tree().get_first_node_in_group("Player")

var shop_item : PackedScene = preload("res://UI/PermanentUpgradeShop/ShopItem.tscn")

@onready var ui : UI = $".."
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
	
	# Use registry instead of folder scanning
	var categories = ShopItemRegistry.get_all_categories()
	
	for category_name in categories:
		# Create new tab with GridContainer
		var grid_container = GridContainer.new()
		grid_container.columns = 4
		grid_container.name = category_name
		
		tab_container.add_child(grid_container)
	
	populate_tabs_with_items()

func populate_tabs_with_items() -> void:
	var tab_container = $PanelContainer/MarginContainer/Rows/ScrollContainer/TabContainer
	
	for tab in tab_container.get_children():
		var grid_container = tab as GridContainer
		var category_name = grid_container.name
		
		# Get items from registry
		var items_in_category = ShopItemRegistry.get_items_by_category(category_name)
		
		for shop_item in items_in_category:
			create_shop_item_button(shop_item, grid_container)
		
func create_shop_item_button(item: ShopItem, parent_container: GridContainer) -> void:
	var new_shop_item : Button = shop_item.instantiate()
	new_shop_item.find_child("VBoxContainer").find_child("ItemName").text = item.item_name
	new_shop_item.find_child("VBoxContainer").find_child("ItemDescription").text = item.item_description
	new_shop_item.pressed.connect(attempt_purchase.bind(item, new_shop_item))
	
	# Generate buildable icon using centralized system
	var icon_texture: Texture2D
	if item.is_buildable_unlock and not item.buildable_scenes.is_empty():
		icon_texture = BuildableIconGenerator.get_buildable_icon(item.buildable_scenes[0])
	else:
		icon_texture = item.item_icon
	
	new_shop_item.find_child("VBoxContainer").find_child("ItemIcon").texture = icon_texture
	
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
		
		# Refresh building system if we just unlocked a buildable
		if item.is_buildable_unlock:
			var building_system = get_tree().get_first_node_in_group("BuildingSystem")
			if building_system:
				building_system.refresh_buildables_for_profile()
			
			# Refresh ALL shop items since category pricing changed
			refresh_shop_display()
		else:
			# For non-buildables, just update this single item
			update_shop_item_display(item, button)
		
		your_money.text = 'Gold Stars: ' + add_comma_to_int(profile.gold_stars)
		print("Purchased ", item.item_name)
	else:
		print("Not enough gold stars! Need ", item_price, ", have ", profile.gold_stars)
		
func is_item_owned(item: ShopItem, profile: PlayerProfile) -> bool:
	if item.is_buildable_unlock:
		return profile.buildable_unlocks.get(item.stat_target, false)
	elif item.category == "QOL":
		if item.is_boolean_unlock:
			# Boolean QOL items (rollerskates, skateboard)
			return profile.qol_unlocks.get(item.stat_target, false)
		else:
			# Stat upgrades in QOL (starting_money, gold_stars_per_day) use max level logic
			return not profile.can_upgrade(item.stat_target)
	else:
		# Other stat upgrades use max level logic, not "owned"
		return not profile.can_upgrade(item.stat_target)
	
func update_shop_item_display(item: ShopItem, button: Button) -> void:
	var profile = ProfileManager.current_profile
	
	var level_label = button.find_child("VBoxContainer").find_child("ItemLevel")
	var value_label = button.find_child("VBoxContainer").find_child("ItemValue")
	var price_label = button.find_child("VBoxContainer").find_child("ItemPrice")
	var action_label = button.find_child("VBoxContainer").find_child("nuttin")
	
	if item.is_buildable_unlock or (item.category == "QOL" and item.is_boolean_unlock):
		# Boolean unlocks (buildables + QOL booleans like rollerskates)
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
		# Stat upgrades (including QOL stat upgrades like starting_money/gold_stars_per_day)
		level_label.visible = true
		value_label.visible = true
		action_label.visible = true
		
		var current_level = profile.upgrade_levels.get(item.stat_target, 0)
		var max_level = profile.max_levels.get(item.stat_target, 20)
		var can_upgrade = profile.can_upgrade(item.stat_target)
		
		level_label.text = "Current Level: " + str(current_level) + "/" + str(max_level)
		value_label.text = "Current value: " + get_current_stat_value(item.stat_target, profile)
		
		if can_upgrade:
			var next_price = profile.get_item_price(item)  # Use the new pricing function
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
