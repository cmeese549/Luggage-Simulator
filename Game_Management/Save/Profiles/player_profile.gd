extends Resource
class_name PlayerProfile

@export var profile_id: int
@export var player_data: Dictionary = {}
@export var hotkeys: Dictionary = {}
@export var lifetime_money: int = 0

@export var base_starting_money: int = 0
@export var starting_money_per_level: int = 250
@export var gold_stars_per_day_per_level: int = 1

# Level-based upgrades
@export var upgrade_levels: Dictionary = {
	"starting_money": 0,
	"gold_stars_per_day": 0
}

# Max levels (all 20)
@export var max_levels: Dictionary = {
	"starting_money": 20,
	"gold_stars_per_day": 20
}

# Boolean unlocks
@export var qol_unlocks: Dictionary = {
	"roller_skates": false,
	"skateboard": false,
}

@export var buildable_unlocks: Dictionary = {
	"straight_ground_conveyor": false,
	"corner_ground_conveyor": false,
	"straight_sky_conveyor": false,
	"corner_sky_conveyor": false,
	"valid_destination_sorter": false,
	"destination_sorter": false,
	"disposable_sorter": false,
	"needs_inspection_sorter": false,
	"approval_processor": false,
	"rejection_processor": false
}

var buildable_categories: Dictionary = {}

@export var gold_stars: int = 100 
@export var active_run_data : RunSaveData

# Helper functions
func can_upgrade(stat_name: String) -> bool:
	return upgrade_levels.get(stat_name, 0) < max_levels.get(stat_name, 0)

func get_upgrade_cost(stat_name: String) -> int:
	var current_level = upgrade_levels.get(stat_name, 0)
	if current_level == 0:
		return 1  # First upgrade always costs 1 star
	else:
		return current_level * 5

func get_starting_money() -> int:
	return base_starting_money + (upgrade_levels.starting_money * starting_money_per_level)

func get_gold_stars_per_day() -> int:
	return 1 + (upgrade_levels.gold_stars_per_day * gold_stars_per_day_per_level)

# Boolean unlock functions
func has_roller_skates() -> bool:
	return qol_unlocks.roller_skates

func has_skateboard() -> bool:
	return qol_unlocks.skateboard
	  
func get_item_price(item: ShopItem) -> int:
	if item.category == "QOL":
		# Check if it's a boolean unlock or stat upgrade
		if item.is_boolean_unlock:
			# Boolean QOL items (rollerskates, skateboard) use fixed price
			return item.fixed_price
		else:
			# Stat upgrades in QOL (starting_money, gold_stars_per_day) use progressive pricing
			return get_upgrade_cost(item.stat_target)
	elif item.is_buildable_unlock:
		# Buildable unlocks: base price of 1 + 5 per already unlocked item in same category
		var unlocked_count_in_category = count_unlocked_buildables_in_category(item.category)
		return 1 + (unlocked_count_in_category * 5)
	else:
		# Fallback to progressive pricing
		return get_upgrade_cost(item.stat_target)

func count_unlocked_buildables_in_category(category: String) -> int:
	var count = 0
	
	var items_in_category = ShopItemRegistry.get_items_by_category(category)
	
	for item in items_in_category:
		if item.is_buildable_unlock and buildable_unlocks.get(item.stat_target, false):
			count += 1
	
	return count

func apply_item_purchase(item: ShopItem) -> void:
	if item.is_buildable_unlock:
		buildable_unlocks[item.stat_target] = true
		buildable_categories[item.stat_target] = item.category  # Cache the category
		print("Unlocked buildable: ", item.item_name)
	elif item.category == "QOL":
		if item.is_boolean_unlock:
			# Boolean QOL items (rollerskates, skateboard)
			qol_unlocks[item.stat_target] = true  
			print("Unlocked QOL item: ", item.item_name)
		else:
			# Stat upgrades in QOL (starting_money, gold_stars_per_day)
			upgrade_levels[item.stat_target] += 1
			print("Upgraded stat: ", item.stat_target, " to level ", upgrade_levels[item.stat_target])
	else:
		# Other stat upgrades 
		upgrade_levels[item.stat_target] += 1
		print("Upgraded stat: ", item.stat_target)
