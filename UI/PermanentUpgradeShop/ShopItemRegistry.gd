extends Node

# Pre-defined registry of all shop items
var all_shop_items: Array[ShopItem] = []
var items_by_category: Dictionary = {}

func _ready():
	register_all_shop_items()

func register_all_shop_items():
	# Manually register all shop items here
	var items: Array[ShopItem] = [
		# Processors
		preload("res://UI/PermanentUpgradeShop/ShopItems/Processors/approval_processor.tres"),
		preload("res://UI/PermanentUpgradeShop/ShopItems/Processors/rejection_processor.tres"),
		
		# Conveyors  
		preload("res://UI/PermanentUpgradeShop/ShopItems/Conveyors/corner_ground_conveyor.tres"),
		preload("res://UI/PermanentUpgradeShop/ShopItems/Conveyors/corner_sky_conveyor.tres"),
		preload("res://UI/PermanentUpgradeShop/ShopItems/Conveyors/straight_ground_conveyor.tres"),
		preload("res://UI/PermanentUpgradeShop/ShopItems/Conveyors/straight_sky_conveyor.tres"),
		
		# Sorters
		preload("res://UI/PermanentUpgradeShop/ShopItems/Sorters/needs_inspection_sorter.tres"),
		preload("res://UI/PermanentUpgradeShop/ShopItems/Sorters/disposable_sorter.tres"),
		preload("res://UI/PermanentUpgradeShop/ShopItems/Sorters/valid_destination_sorter.tres"),
		preload("res://UI/PermanentUpgradeShop/ShopItems/Sorters/destination_sorter.tres"),
		
		# QOL
		preload("res://UI/PermanentUpgradeShop/ShopItems/QOL/roller_skates.tres"),
		preload("res://UI/PermanentUpgradeShop/ShopItems/QOL/skateboard.tres"),
		preload("res://UI/PermanentUpgradeShop/ShopItems/QOL/starting_money.tres"),
		preload("res://UI/PermanentUpgradeShop/ShopItems/QOL/gold_stars_per_day.tres"),
	]
	
	all_shop_items = items
	organize_by_category()

func organize_by_category():
	for item in all_shop_items:
		if not items_by_category.has(item.category):
			items_by_category[item.category] = []
		items_by_category[item.category].append(item)

func get_items_by_category(category: String) -> Array[ShopItem]:
	var items: Array[ShopItem] = []
	var category_items = items_by_category.get(category, [])
	for item in category_items:
		items.append(item)
	return items

func get_all_categories() -> Array[String]:
	var categories: Array[String] = []
	for key in items_by_category.keys():
		categories.append(key)
	return categories
