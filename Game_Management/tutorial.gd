extends Node3D

@onready var label_3d = $TutorialTodd/Label3D

@onready var cough_timer : Timer = $TutorialTodd/AhemTimer
@onready var cough : AudioStreamPlayer3D = $TutorialTodd/AudioStreamPlayer3D
@onready var animation_player = $AnimationPlayer

var started : bool = false

enum tutorial_steps {
	WELCOME,
	PICKUP_WATER,
	DUMP_WATER,
	BUY_PUMP,
	UPGRADE_PUMP,
	SHOP,
	FIND_ITEM,
	DONE
}

@export var tutorial_texts: Dictionary[tutorial_steps, String] = {
	tutorial_steps.WELCOME: "Hi! My name is Tutorial Todd and welcome to Mr. Money's Phenomenally Soggy Water Removal Romp",
	tutorial_steps.PICKUP_WATER: "Your task is to drain the depths of this here lake. Please use your thimble on the water here with the mouse primary button.",
	tutorial_steps.DUMP_WATER: "Now you can sell your water over here by once again using your thimble on this receptacle",
	tutorial_steps.BUY_PUMP: "Well done! But that's a lot of work, over here you can buy a pump to automatically remove water and sell it for you.",
	tutorial_steps.UPGRADE_PUMP: "Wonderful! Look at that automation go! Now check out the upgrades available by clicking near the pipes sticking out.",
	tutorial_steps.SHOP: "Pumps and their upgrades aren't the only thing you can buy! Uncle Upgrade over here can sell you upgraded tools.",
	tutorial_steps.FIND_ITEM: "Unfortunately Uncle Upgrade has lost some of his favorite things. You'll need to help him find them if you want him to sell you more upgrades",
	tutorial_steps.DONE: "That's all I can teach you, good luck!"
}

@export var tutorial_locations: Dictionary[tutorial_steps, Marker3D] = {
	tutorial_steps.WELCOME: null,
	tutorial_steps.PICKUP_WATER: null,
	tutorial_steps.DUMP_WATER: null,
	tutorial_steps.BUY_PUMP: null,
	tutorial_steps.UPGRADE_PUMP: null,
	tutorial_steps.SHOP: null,
	tutorial_steps.FIND_ITEM: null,
	tutorial_steps.DONE: null
}

@export var cur_step: tutorial_steps = tutorial_steps.WELCOME

func _ready():
	do_next_step(cur_step)
	Events.remove_water.connect(water_removed)
	Events.water_dumped.connect(water_dumped)
	Events.add_pump.connect(pump_bought)
	Events.pump_upgrade_menu.connect(pump_upgraded)
	Events.close_shop.connect(shop_closed)
	Events.item_pickedup.connect(item_found)
	await get_tree().create_timer(15).timeout
	do_next_step(tutorial_steps.PICKUP_WATER)

func do_next_step(next_step: tutorial_steps):
	print("Doing next step: "+str(next_step))
	label_3d.text = tutorial_texts[next_step]
	animation_player.play("down")
	await animation_player.animation_finished
	print("todd down")
	global_position = tutorial_locations[next_step].global_position
	animation_player.play("up")
	print("todd going up")
	if started:
		cur_step = next_step
		cough_timer.stop()
		cough.play()
	started = true
	cough_timer.start()
	if next_step == tutorial_steps.DONE:
		await get_tree().create_timer(60).timeout
		animation_player.play("down")
		await animation_player.animation_finished
		queue_free()


func water_removed(_amount):
	if cur_step == tutorial_steps.PICKUP_WATER:
		do_next_step(tutorial_steps.DUMP_WATER)

func water_dumped(_amount):
	if cur_step == tutorial_steps.DUMP_WATER:
		do_next_step(tutorial_steps.BUY_PUMP)

func pump_bought(_pump):
	if cur_step == tutorial_steps.BUY_PUMP:
		do_next_step(tutorial_steps.UPGRADE_PUMP)

func pump_upgraded(_pump):
	if cur_step == tutorial_steps.UPGRADE_PUMP:
		do_next_step(tutorial_steps.SHOP)

func shop_closed():
	if cur_step == tutorial_steps.SHOP:
		do_next_step(tutorial_steps.FIND_ITEM)

func item_found(_item):
	if cur_step == tutorial_steps.FIND_ITEM:
		do_next_step(tutorial_steps.DONE)
