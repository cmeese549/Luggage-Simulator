extends Control

class_name UI

@onready var player : Player = get_tree().get_first_node_in_group("Player")
@onready var splashscreen : VideoStreamPlayer = $VideoStreamPlayer
@onready var main_menu : MainMenu = $MainMenu

var money: Money

var pauseable : bool = true

func _ready():
	Events.all_ready.connect(all_ready)
	if !player.ready_to_start_game:
		print("Yesss")
		splashscreen.visible = true
		splashscreen.play()
		splashscreen.finished.connect(main_menu.start)
	else:
		main_menu.start()

func all_ready():
	money = %Money
