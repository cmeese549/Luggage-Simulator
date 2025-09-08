extends Node

const PROFILE_1_PATH = "user://player_profile_1.tres"
const PROFILE_2_PATH = "user://player_profile_2.tres"
const PROFILE_3_PATH = "user://player_profile_3.tres"

var current_profile: PlayerProfile
var current_profile_id: int = -1

var debug_auto_select_profile: bool = false  # Set to true for testing

@onready var profile_container : HBoxContainer = get_tree().get_first_node_in_group("ProfileUI")
@onready var player : Player = get_tree().get_first_node_in_group("Player")
var profile_entry : PackedScene = preload("res://UI/Profiles/profile_entry.tscn")

func _ready():
	populate_profile_data()
	if debug_auto_select_profile:
		select_profile(1)

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
	# Initialize default values
	profile.player_data = {}
	profile.hotkeys = {}
	profile.active_run_data = null
	
	save_profile(profile)
	return profile

func save_profile(profile: PlayerProfile) -> bool:
	var path = get_profile_path(profile.profile_id)
	return ResourceSaver.save(profile, path) == OK

func select_profile(profile_id: int) -> bool:
	if profile_id < 1 or profile_id > 3:
		return false
	
	var profile = load_profile(profile_id)
	if not profile:
		profile = create_new_profile(profile_id)
	
	current_profile = profile
	current_profile_id = profile_id
	restore_hotkeys_to_building_system()
	player.load_save_data(profile.player_data)
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
	DirAccess.remove_absolute(get_profile_path(profile_id))
	show_empty_profile_data(profile_id, entry)
	
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
		
func populate_profile_data():
	var profile_summaries = get_all_profile_summaries()
	var i = 1
	for summary in profile_summaries:
		var entry: ProfileEntry = profile_entry.instantiate()
		profile_container.add_child(entry)
		await get_tree().process_frame
		if summary.exists:
			entry.active_run_label.text = "Day " + summary.active_run_day if summary.has_active_run else "No Active Run"
			entry.name_label.text = "Profile " + str(i)
			entry.lifetime_money_label.text = "Lifetime $: " + str(summary.lifetime_money)
			entry.load_button.pressed.connect(select_profile.bind(i))
			entry.create_button.visible = false
			entry.delete_button.pressed.connect(delete_profile.bind(i))
		else:
			show_empty_profile_data(i, entry)
		i += 1
		

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
					summary.active_run_day = profile.active_run_data.current_day
				else:
					summary.active_run_day = 0
		
		summaries.append(summary)
	
	return summaries
