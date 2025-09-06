@tool
extends Resource
class_name EconomyConfig

@export var run_test: bool = false : set = _validate_economy_balance

# Box Value Settings
@export_group("Box Values")
@export var base_box_value: int = 1
@export var sticker_multiplier: float = 1.5  # Each sticker adds 50% value
@export var penalty_multiplier: float = -2.0  # Mistakes cost double

# Buildable Prices - Organized by category and progression tier
@export_group("Buildable Prices")
@export var conveyor_prices: Dictionary = {
	"1x1 Conveyor": 30,
	"1x1 Sky Conveyor": 30,
	"5x1 Conveyor": 150,
	"5x1 Sky Conveyor": 150,
	"Corner Conveyor": 30,
	"Sky Corner Conveyor": 30,
	"Ramp Conveyor": 150,
}

@export var sorter_prices: Dictionary = {
	"Destination Sorter": 500,
	"International Sorter": 300,
	"Disposable Sorter": 400,
	"Valid Destination Sorter": 300
}

@export var processor_prices: Dictionary = {
	"Approval Processor": 800,
	"Rejection Processor": 800
}

@export var skating_prices: Dictionary = {
	"Halfpipe": 2000,
	"Curved Rail": 2000,
	"Straight Rail": 2000,
	"Wiggle Rail": 2000,
}

# 31-Day Progression Settings
@export_group("Progression Curve")
@export var total_days: int = 31
@export var starting_boxes: int = 20
@export var ending_boxes: int = 600
@export var starting_spawn_rate: float = 0.3
@export var ending_spawn_rate: float = 5.0

# Progression curve type
@export_enum("Linear", "Exponential", "Sigmoid", "Custom") var progression_type: String = "Sigmoid"

# Income targets by milestone days (for validation/balancing)
@export_group("Income Milestones")
@export var expected_income_day_1: int = 16  # Can buy half a conveyor
@export var expected_income_day_5: int = 120  # Can buy basic infrastructure
@export var expected_income_day_10: int = 400  # Can buy first sorter
@export var expected_income_day_20: int = 2000  # Multiple purchases per day
@export var expected_income_day_31: int = 8000  # End-game optimization

func get_buildable_price(category: String, buildable_name: String) -> float:
	match category:
		"Ground Conveyors", "Sky Conveyors":
			return conveyor_prices.get(buildable_name, 100)
		"Sorters":
			return sorter_prices.get(buildable_name, 400)
		"Processors":
			return processor_prices.get(buildable_name, 800)
		"Skating":
			return skating_prices.get(buildable_name, 1500)
		_:
			return 100  # Default price

func calculate_day_progression(day: int) -> float:
	"""Returns a 0.0 to 1.0 progress value for the given day"""
	var t = float(day - 1) / float(total_days - 1)
	
	match progression_type:
		"Linear":
			return t
		"Exponential":
			return pow(t, 1.8)
		"Sigmoid":
			# S-curve: slow start, rapid middle, plateau end
			return 1.0 / (1.0 + exp(-10 * (t - 0.5)))
		"Custom":
			# Custom curve with different rates for different metrics
			return pow(t, 1.5)
		_:
			return t

func get_day_config(day: int) -> Dictionary:
	"""Generate config for a specific day"""
	var progress = calculate_day_progression(day)
	
	# Different curves for different metrics
	var box_progress = pow(progress, 1.2)  # Slightly steeper for boxes
	var spawn_progress = pow(progress, 0.9)  # Gentler for spawn rate
	
	var config = {
		"total_boxes": int(lerp(starting_boxes, ending_boxes, box_progress)),
		"boxes_per_second": lerp(starting_spawn_rate, ending_spawn_rate, spawn_progress),
		"expected_income": 0  # Will be calculated
	}
	
	config.expected_income = config.total_boxes * base_box_value
	
	return config

func _validate_economy_balance(value: bool):
	run_test = value
	if value:
		print("\n" + "==============================")
		print("       ECONOMY BALANCE VALIDATION - 31 DAY RUN")
		print("==============================")
		
		var milestones = [1, 5, 10, 15, 20, 25, 31]
		var total_earnings = 0
		var last_milestone_earnings = 0
		
		print("\n📊 DAILY PROGRESSION:")
		print("----------------------------------------")
		
		for day in milestones:
			var config = get_day_config(day)
			var daily_income = config.expected_income
			
			# Calculate cumulative earnings up to this day
			var days_since_last = 1 if day == 1 else (day - milestones[max(0, milestones.find(day) - 1)])
			var estimated_earnings_period = daily_income * days_since_last
			total_earnings += estimated_earnings_period
			
			print("Day %2d | Boxes: %3d @ %.1f/sec | Income: $%4d" % [
				day, 
				config.total_boxes, 
				config.boxes_per_second, 
				daily_income
			])
		
		print("\n💰 CUMULATIVE EARNINGS:")
		print("----------------------------------------")
		var cumulative = 0
		for day in milestones:
			var config = get_day_config(day)
			if day == 1:
				cumulative = config.expected_income
			else:
				var prev_day = milestones[max(0, milestones.find(day) - 1)]
				var days_span = day - prev_day
				cumulative += config.expected_income * days_span
			
			print("By Day %2d: $%s" % [day, format_number(cumulative)])
		
		print("\n🛒 PURCHASING POWER:")
		print("----------------------------------------")
		
		for day in [1, 5, 10, 20, 31]:
			var config = get_day_config(day)
			var affordable_items = []
			
			# Check all categories
			for item in conveyor_prices:
				if conveyor_prices[item] <= config.expected_income:
					affordable_items.append("%s($%d)" % [item, conveyor_prices[item]])
			
			for item in sorter_prices:
				if sorter_prices[item] <= config.expected_income:
					affordable_items.append("%s($%d)" % [item, sorter_prices[item]])
			
			for item in processor_prices:
				if processor_prices[item] <= config.expected_income:
					affordable_items.append("%s($%d)" % [item, processor_prices[item]])
			
			print("Day %2d income ($%4d) can buy:" % [day, config.expected_income])
			if affordable_items.is_empty():
				print("  ❌ Nothing affordable yet")
			else:
				for item in affordable_items:
					print("  ✓ " + item)
		
		print("\n📈 DIFFICULTY CURVE:")
		print("----------------------------------------")
		
		# Calculate growth rates
		var early_growth = float(get_day_config(10).total_boxes) / float(get_day_config(1).total_boxes)
		var mid_growth = float(get_day_config(20).total_boxes) / float(get_day_config(10).total_boxes)
		var late_growth = float(get_day_config(31).total_boxes) / float(get_day_config(20).total_boxes)
		
		print("Box count growth:")
		print("  Days 1-10:  x%.1f" % early_growth)
		print("  Days 10-20: x%.1f" % mid_growth)
		print("  Days 20-31: x%.1f" % late_growth)
		
		var spawn_early = get_day_config(10).boxes_per_second / get_day_config(1).boxes_per_second
		var spawn_mid = get_day_config(20).boxes_per_second / get_day_config(10).boxes_per_second
		var spawn_late = get_day_config(31).boxes_per_second / get_day_config(20).boxes_per_second
		
		print("\nSpawn rate growth:")
		print("  Days 1-10:  x%.1f" % spawn_early)
		print("  Days 10-20: x%.1f" % spawn_mid)
		print("  Days 20-31: x%.1f" % spawn_late)
		
		print("\n" + "==============================")
		print("TOTAL 31-DAY EARNINGS: $%d" % cumulative)
		print("==============================")
		
		run_test = false  # Reset checkboxordable))
		
		
func format_number(num: int) -> String:
	var s = str(num)
	var result = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		if count == 3:
			result = "," + result
			count = 0
		result = s[i] + result
		count += 1
	return result
