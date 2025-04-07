extends Node3D

@onready var label_3d: Label3D = $Label3D

enum tutorial_steps {
	PICKUP_WATER,
	DUMP_WATER,
	BUY_PUMP,
	SHOP,
	FIND_ITEM,
	DONE
}

@export var tutorial_texts: Dictionary[tutorial_steps, String] = {
	tutorial_steps.PICKUP_WATER: "Your task is to drain the depths of this here lake. Please use your thimble on the water here with the mouse primary button.",
	tutorial_steps.DUMP_WATER: "Now you can sell your water over here by once again using your thimble on this receptacle",
	tutorial_steps.BUY_PUMP: "Well done! But that's a lot of work, over here you can buy a pump to automatically remove water and sell it for you. You can also click by the pipes sticking out to buy and apply upgrades.",
	tutorial_steps.SHOP: "Pumps and their upgrades aren't the only thing you can buy! Uncle Upgrade over here can sell you upgraded tools.",
	tutorial_steps.FIND_ITEM: "Unfortunately Uncle Upgrade has lost some of his favorite things. You'll need to help him find them if you want him to sell you more upgrades",
	tutorial_steps.DONE: "That's all I can teach you, good luck!"
}

@export var tutorial_locations: Dictionary[tutorial_steps, Marker3D] = {
	tutorial_steps.PICKUP_WATER: null,
	tutorial_steps.DUMP_WATER: null,
	tutorial_steps.BUY_PUMP: null,
	tutorial_steps.SHOP: null,
	tutorial_steps.FIND_ITEM: null,
	tutorial_steps.DONE: null
}

@export var cur_step: tutorial_steps = tutorial_steps.PICKUP_WATER

func _ready():
	do_next_step(cur_step)
	Events.remove_water.connect(water_removed)
	Events.water_dumped.connect(water_dumped)
	Events.pump_upgrade_menu.connect(pump_bought)
	Events.close_shop.connect(shop_closed)
	Events.item_pickedup.connect(item_found)

func do_next_step(next_step: tutorial_steps):
	print("Doing next step: "+str(next_step))
	label_3d.text = tutorial_texts[next_step]
	print("Next location: "+str(tutorial_locations[next_step].global_position))
	global_position = tutorial_locations[next_step].global_position
	cur_step = next_step
	if next_step == tutorial_steps.DONE:
		await get_tree().create_timer(60).timeout
		queue_free()


func water_removed(amount):
	if cur_step == tutorial_steps.PICKUP_WATER:
		print("Water picked up moving to dump water")
		do_next_step(tutorial_steps.DUMP_WATER)

func water_dumped(amount):
	if cur_step == tutorial_steps.DUMP_WATER:
		do_next_step(tutorial_steps.BUY_PUMP)

func pump_bought(pump):
	if cur_step == tutorial_steps.BUY_PUMP:
		do_next_step(tutorial_steps.SHOP)

func shop_closed():
	if cur_step == tutorial_steps.SHOP:
		do_next_step(tutorial_steps.FIND_ITEM)

func item_found(item):
	if cur_step == tutorial_steps.FIND_ITEM:
		do_next_step(tutorial_steps.DONE)
