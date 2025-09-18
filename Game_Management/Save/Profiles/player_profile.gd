extends Resource
class_name PlayerProfile

@export var profile_id: int
@export var player_data: Dictionary = {}
@export var hotkeys: Dictionary = {}
@export var lifetime_money: int = 0

# Base values
@export var base_belt_speed: float = 1.0
@export var base_machine_speed: float = 10.0  
@export var base_health_drain_rate: float = 1.0
@export var base_health_recovery_rate: float = 15.0
@export var base_box_value_multiplier: float = 1.0
@export var base_build_cost_multiplier: float = 1.0
@export var base_starting_money: int = 0

# Upgrade amounts per level
@export var belt_speed_per_level: float = 0.45  # 1.0 + (20 * 0.45) = 10.0
@export var machine_speed_per_level: float = 0.25  # 10.0 - (20 * 0.25) = 5.0
@export var health_drain_reduction_per_level: float = 0.025  # 1.0 - (20 * 0.025) = 0.5
@export var health_recovery_per_level: float = 0.75  # 15.0 + (20 * 0.75) = 30.0
@export var box_value_bonus_per_level: float = 0.1
@export var build_cost_reduction_per_level: float = 0.025  # 1.0 - (20 * 0.025) = 0.5 (50% cost)
@export var starting_money_per_level: int = 250
@export var gold_stars_per_day_per_level: int = 1

# Level-based upgrades
@export var upgrade_levels: Dictionary = {
	"belt_speed": 0,
	"machine_speed": 0, 
	"health_drain_rate": 0,
	"health_recovery_rate": 0,
	"box_value_bonus": 0,
	"build_cost_reduction": 0,
	"starting_money": 0,
	"gold_stars_per_day": 0
}

# Max levels (all 20)
@export var max_levels: Dictionary = {
	"belt_speed": 20,
	"machine_speed": 20, 
	"health_drain_rate": 20,
	"health_recovery_rate": 20,
	"box_value_bonus": 20,
	"build_cost_reduction": 20,
	"starting_money": 20,
	"gold_stars_per_day": 20
}

# Boolean unlocks
@export var unlocks: Dictionary = {
	"roller_skates": false,
	"skateboard": false
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

func get_belt_speed() -> float:
	return base_belt_speed + (upgrade_levels.belt_speed * belt_speed_per_level)

func get_machine_speed() -> float:
	return base_machine_speed - (upgrade_levels.machine_speed * machine_speed_per_level)

func get_health_drain_rate() -> float:
	return base_health_drain_rate - (upgrade_levels.health_drain_rate * health_drain_reduction_per_level)

func get_health_recovery_rate() -> float:
	return base_health_recovery_rate + (upgrade_levels.health_recovery_rate * health_recovery_per_level)

func get_build_cost_multiplier() -> float:
	return base_build_cost_multiplier - (upgrade_levels.build_cost_reduction * build_cost_reduction_per_level)

func get_starting_money() -> int:
	return base_starting_money + (upgrade_levels.starting_money * starting_money_per_level)

func get_box_value_multiplier() -> float:
	return base_box_value_multiplier + (upgrade_levels.box_value_bonus * box_value_bonus_per_level)

func get_gold_stars_per_day() -> int:
	return 1 + (upgrade_levels.gold_stars_per_day * gold_stars_per_day_per_level)

# Money-related functions return rounded ints
func calculate_build_cost(base_cost: int) -> int:
	return int(round(base_cost * get_build_cost_multiplier()))

func calculate_box_value(base_value: int) -> int:
	return int(round(base_value * get_box_value_multiplier()))

# Boolean unlock functions
func has_roller_skates() -> bool:
	return unlocks.roller_skates

func has_skateboard() -> bool:
	return unlocks.skateboard
