extends Node

const PROFILE_1_PATH = "user://player_profile_1.tres"
const PROFILE_2_PATH = "user://player_profile_2.tres"
const PROFILE_3_PATH = "user://player_profile_3.tres"

var current_profile: PlayerProfile
var current_profile_id: int = -1

@onready var profile_container : HBoxContainer = get_tree().get_first_node_in_group("ProfileUI")
@onready var player : Player = get_tree().get_first_node_in_group("Player")
@onready var money_system = get_tree().get_first_node_in_group("Money")
@onready var star_counter: Label = get_tree().get_first_node_in_group("StarCounter")
@onready var day_counter: Label = get_tree().get_first_node_in_group("DayCounter")
var profile_entry : PackedScene = preload("res://UI/Profiles/profile_entry.tscn")

func _ready():
	populate_profile_data()
	
func auto_load():
	# Auto-load logic for seamless gameplay
	var found_profile = false
	
	# First, try to find a profile with an active run
	for i in range(1, 4):
		if profile_exists(i):
			var profile = load_profile(i)
			if profile and profile.active_run_data:
				print("Auto-loading profile ", i, " with active run")
				select_profile(i)
				found_profile = true
				break
	
	# If no profile with active run, load the first existing profile
	if not found_profile:
		for i in range(1, 4):
			if profile_exists(i):
				print("Auto-loading profile ", i)
				select_profile(i)
				found_profile = true
				break
	
	# If no profiles exist, create one and start a run
	if not found_profile:
		print("No profiles found, creating new profile")
		create_new_profile(1)
		# create_new_profile already calls select_profile which starts a run

func get_profile_path(profile_id: int) -> String:
	match profile_id:
		1: return PROFILE_1_PATH
		2: return PROFILE_2_PATH
		3: return PROFILE_3_PATH
		_: return ""

func profile_exists(profile_id: int) -> bool:
	var path = get_profile_path(profile_id)
	return FileAccess.file_exists(path)

func load_profile(profile_id: int) -> PlayerProfile:
	var path = get_profile_path(profile_id)
	if not FileAccess.file_exists(path):
		return null
	
	var profile = ResourceLoader.load(path) as PlayerProfile
	return profile

func create_new_profile(profile_id: int) -> PlayerProfile:
	var profile = PlayerProfile.new()
	profile.profile_id = profile_id
	profile.player_data = {}
	profile.hotkeys = {}
	profile.active_run_data = null
	save_profile(profile)
	select_profile(profile_id)
	refresh_profile_ui()
	return profile

func save_profile(profile: PlayerProfile) -> bool:
	var path = get_profile_path(profile.profile_id)
	var save = ResourceSaver.save(profile, path)
	print(save)
	return save == OK

func select_profile(profile_id: int, load_run_data: bool = true) -> bool:
	if profile_id < 1 or profile_id > 3:
		return false
	
	var profile = load_profile(profile_id)
	if not profile:
		profile = create_new_profile(profile_id)
	
	current_profile = profile
	current_profile_id = profile_id
	restore_hotkeys_to_building_system()
	if not profile.player_data.is_empty():
		player.load_save_data(profile.player_data)
	player.apply_profile_unlocks()

	star_counter.text = "⭐ " + str(current_profile.gold_stars)
	
	# Only load run data if requested
	if load_run_data:
		if profile.active_run_data:
			# Load existing run
			RunSaveManager.load_from_run_save_data(profile.active_run_data)
			print("Loaded existing run - Day ", profile.active_run_data.run_orchestrator_data.current_day)
			day_counter.text = "Day " + str(profile.active_run_data.run_orchestrator_data.current_day) + "/30"
		else:
			# Start new run
			get_tree().get_first_node_in_group("RunOrchestrator").start_new_run()
			print("Started new run for profile ", profile_id)

		if get_tree().paused:
			get_tree().get_first_node_in_group("PauseMenu").unpause()
	
	return true
	
func update_hotkeys(hotkeys_data: Dictionary) -> void:
	if current_profile:
		current_profile.hotkeys = hotkeys_data
		save_current_profile()

func get_hotkeys() -> Dictionary:
	if current_profile:
		return current_profile.hotkeys
	return {}

func restore_hotkeys_to_building_system() -> void:
	if current_profile:
		var building_system = get_tree().get_first_node_in_group("BuildingSystem")
		if building_system and building_system.has_method("load_save_data"):
			building_system.load_save_data(current_profile.hotkeys)

func get_current_profile() -> PlayerProfile:
	return current_profile

func save_current_profile() -> bool:
	if not current_profile:
		return false
	return save_profile(current_profile)
	
func delete_profile(profile_id: int, entry: ProfileEntry):
	# Check if we're deleting the currently active profile
	if current_profile and current_profile.profile_id == profile_id:
		print("Deleting active profile - stopping current run...")
		
		# Stop the current run
		var run_orchestrator = get_tree().get_first_node_in_group("RunOrchestrator")
		if run_orchestrator:
			run_orchestrator.is_day_active = false
			run_orchestrator.health_system.stop_draining()
			
			# Stop box spawners
			var box_spawners = get_tree().get_nodes_in_group("BoxSpawner")
			for spawner in box_spawners:
				spawner.active = false
		
		# Delete the file
		DirAccess.remove_absolute(get_profile_path(profile_id))
		
		# Create fresh profile and start new run
		print("Creating fresh profile ", profile_id, " and starting new run...")
		var new_profile = create_new_profile(profile_id)
		select_profile(profile_id)  # This will start a new run automatically
		
	else:
		# Just deleting a non-active profile - simple cleanup
		print("Deleting non-active profile ", profile_id)
		DirAccess.remove_absolute(get_profile_path(profile_id))
	
	refresh_profile_ui()
	
func show_empty_profile_data(profile_id: int, entry: ProfileEntry):
	entry.active_run_label.text = ""
	entry.name_label.text = "Empty"
	entry.lifetime_money_label.text = ""
	entry.load_button.visible = false
	entry.create_button.pressed.connect(create_new_profile.bind(profile_id))
	entry.create_button.visible = true
	entry.delete_button.visible = false

func has_active_run() -> bool:
	return current_profile and current_profile.active_run_data != null

func clear_active_run() -> void:
	if current_profile:
		current_profile.active_run_data = null
		save_current_profile()
		refresh_profile_ui()
		
func populate_profile_data():
	var profile_summaries = get_all_profile_summaries()
	var i = 1
	for summary in profile_summaries:
		var entry: ProfileEntry = profile_entry.instantiate()
		profile_container.add_child(entry)
		await get_tree().process_frame
		if summary.exists:
			entry.active_run_label.text = "Day " + str(summary.active_run_day) if summary.has_active_run else "Day 1"
			entry.name_label.text = "Profile " + str(i)
			entry.lifetime_money_label.text = "Lifetime $: " + str(summary.lifetime_money)
			entry.load_button.pressed.connect(select_profile.bind(i))
			entry.create_button.visible = false
			entry.delete_button.pressed.connect(delete_profile.bind(i, entry))
		else:
			show_empty_profile_data(i, entry)
		i += 1

func refresh_profile_ui() -> void:
	var profile_summaries = get_all_profile_summaries()
	var entries = profile_container.get_children()
	
	for i in range(entries.size()):
		if i < profile_summaries.size():
			var entry = entries[i] as ProfileEntry
			var summary = profile_summaries[i]
			update_profile_entry(entry, summary, i + 1)

func update_profile_entry(entry: ProfileEntry, summary: Dictionary, profile_id: int) -> void:
	# Disconnect existing signals to avoid duplicates
	if entry.load_button.pressed.is_connected(select_profile):
		entry.load_button.pressed.disconnect(select_profile)
	if entry.delete_button.pressed.is_connected(delete_profile):
		entry.delete_button.pressed.disconnect(delete_profile)
	if entry.create_button.pressed.is_connected(create_new_profile):
		entry.create_button.pressed.disconnect(create_new_profile)
	
	if summary.exists:
		entry.active_run_label.text = "Day " + str(summary.active_run_day) if summary.has_active_run else "Day 1"
		entry.name_label.text = "Profile " + str(profile_id)
		entry.lifetime_money_label.text = "Lifetime $: " + str(summary.lifetime_money)
		entry.load_button.pressed.connect(select_profile.bind(profile_id))
		entry.create_button.visible = false
		entry.load_button.visible = true
		entry.delete_button.visible = true
		entry.delete_button.pressed.connect(delete_profile.bind(profile_id, entry))
	else:
		entry.active_run_label.text = ""
		entry.name_label.text = "Empty"
		entry.lifetime_money_label.text = ""
		entry.load_button.visible = false
		entry.create_button.visible = true
		entry.delete_button.visible = false
		entry.create_button.pressed.connect(create_new_profile.bind(profile_id))

func save_current_run() -> bool:
	# Auto-create Profile 1 if no profile selected, but don't load run data
	if not current_profile:
		if not select_profile(1, false):  # Pass false to skip loading
			return false
	
	# Now save the run data
	if current_profile:
		current_profile.active_run_data = RunSaveManager.collect_run_save_data()
		current_profile.player_data = player.get_save_data()
		current_profile.lifetime_money = money_system.lifetime_money
		var success: bool = save_current_profile()
		if success:
			print("Run Saved")
			refresh_profile_ui()
		return success
	return false

func load_current_run() -> bool:
	if not current_profile or not current_profile.active_run_data:
		return false
	
	return RunSaveManager.load_from_run_save_data(current_profile.active_run_data)
	

func get_all_profile_summaries() -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []
	
	for i in range(1, 4):
		var summary = {
			"profile_id": i,
			"exists": profile_exists(i),
			"has_active_run": false,
			"profile_name": "Profile " + str(i),
			"lifetime_money": 0
		}
		
		if summary.exists:
			var profile = load_profile(i)
			if profile:
				summary.has_active_run = profile.active_run_data != null
				summary.lifetime_money = profile.lifetime_money
				if profile.active_run_data:
					summary.active_run_day = profile.active_run_data.run_orchestrator_data.current_day
				else:
					summary.active_run_day = 0
		
		summaries.append(summary)
	
	return summaries
