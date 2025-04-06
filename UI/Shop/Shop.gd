extends MarginContainer

class_name Shop

@onready var dialogue_box  : DialogueBox = $PanelContainer/MarginContainer/Rows/HBoxContainer/RichTextLabel
@onready var hud : Control = $"../HUD"

var rng = RandomNumberGenerator.new()

var unused_quips : Array[String] = [
	"Howdy there young weak child, Welcome to my shop.  I am [b]UNCLE UPGRADE[/b], the greatest upgrade purveyor in all the lands...{pause=1.0}... now please [rainbow]buy something.[/rainbow]{pause=0.5} You interrupted my nap.",
	"Boy I sure do love sellin upgrades.  {pause=0.5}And napping.  {pause=0.5}Mostly napping.  {pause=0.5}I actually only even started selling upgrades so that I could afford a better place to nap. {pause=1.0} God I love napping...."
]

var used_quips : Array[String] = []

func _ready() -> void:
	render_shop_items()

func _input(event) -> void:
	if Input.is_action_just_pressed("OpenShopDebug"):
		open_shop()

func open_shop() -> void:
	self.visible = true
	hud.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
	display_random_quip()
	
func close_shop() -> void:
	self.visible = false
	hud.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().paused = false
	
func display_random_quip() -> void:
	rng.randomize()
	var quip : String = unused_quips[rng.randi_range(0, unused_quips.size() - 1)]
	dialogue_box.render_dialogue(quip)
	unused_quips.erase(quip)
	used_quips.append(quip)
	if unused_quips.size() == 0:
		unused_quips = used_quips
		used_quips = []
	
func render_shop_items() -> void:
	pass
