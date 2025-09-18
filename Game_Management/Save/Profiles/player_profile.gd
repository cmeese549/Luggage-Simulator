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

@export var gold_stars: int = 0 
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
