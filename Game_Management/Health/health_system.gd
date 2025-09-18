extends Node
class_name HealthSystem

signal health_changed(current: float, max: float)
signal health_depleted()
signal critical_health(is_critical: bool)

@onready var ui_health_bar: ProgressBar = get_tree().get_first_node_in_group("HealthBar").get_child(0)
@export var critical_threshold: float = 0.20  # Below 20% is critical

var current_health: float = 100.0
var max_health: float = 100.0
var drain_per_second: float = 1.0
var recovery_per_correct: float = 15.0
var penalty_per_wrong: float = 20.0
var is_draining: bool = false
var is_critical: bool = false

func get_save_data() -> Dictionary:
	var data = {}
	data.current_health = current_health
	data.max_health = max_health
	data.drain_per_second = drain_per_second
	data.recovery_per_correct = recovery_per_correct
	data.penalty_per_wrong = penalty_per_wrong
	data.is_draining = is_draining
	data.is_critical = is_critical
	return data

func load_save_data(data: Dictionary) -> void:
	current_health = data.current_health
	max_health = data.max_health
	drain_per_second = data.drain_per_second
	recovery_per_correct = data.recovery_per_correct
	penalty_per_wrong = data.penalty_per_wrong
	is_draining = data.is_draining
	is_critical = data.is_critical
	update_ui()

func setup_for_day(day_number: int) -> void:
	var config = Economy.config.get_health_config(day_number)
	var profile = ProfileManager.current_profile
	
	max_health = config.max_health
	current_health = max_health * config.starting_health_percent
	
	# Use profile values directly (they're already calculated final values)
	drain_per_second = config.drain_per_second * profile.get_health_drain_rate()
	recovery_per_correct = profile.get_health_recovery_rate()  # Don't multiply!
	penalty_per_wrong = config.penalty_per_wrong
	
	update_ui()
	print("Health System Day %d: Max %.0f, Starting %.0f, Drain %.1f/s (%.1fx), Recovery %.1f" % 
		[day_number, max_health, current_health, drain_per_second, profile.get_health_drain_rate(), 
		recovery_per_correct])

func start_draining() -> void:
	is_draining = true

func stop_draining() -> void:
	is_draining = false

func add_health(amount: float) -> void:
	current_health = min(current_health + amount, max_health)
	update_ui()
	check_critical_status()

func remove_health(amount: float) -> void:
	current_health = max(0, current_health - amount)
	update_ui()
	check_critical_status()
	
	if current_health <= 0:
		health_depleted.emit()

func on_box_processed(correct: bool) -> void:
	if correct:
		add_health(recovery_per_correct)
	else:
		remove_health(penalty_per_wrong)

func _process(delta: float) -> void:
	if is_draining and current_health > 0:
		current_health = max(0, current_health - (drain_per_second * delta))
		update_ui()
		check_critical_status()
		
		if current_health <= 0:
			health_depleted.emit()

func check_critical_status() -> void:
	var was_critical = is_critical
	is_critical = (current_health / max_health) <= critical_threshold
	
	if is_critical != was_critical:
		critical_health.emit(is_critical)
		if is_critical:
			print("WARNING: Health critical! %.0f/%.0f" % [current_health, max_health])

func update_ui() -> void:
	if ui_health_bar:
		ui_health_bar.max_value = max_health
		ui_health_bar.value = current_health
		
		# Change color based on health level
		var health_percent = current_health / max_health
		if health_percent > 0.5:
			ui_health_bar.modulate = Color.GREEN
		elif health_percent > critical_threshold:
			ui_health_bar.modulate = Color.YELLOW
		else:
			ui_health_bar.modulate = Color.RED
	
	health_changed.emit(current_health, max_health)

func get_health_percentage() -> float:
	return current_health / max_health if max_health > 0 else 0.0
