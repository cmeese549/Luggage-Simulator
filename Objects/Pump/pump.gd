extends Node3D

class_name Pump

@export var base_wps: float = 1
@export var base_quality: float = .5
@export var price: int = 100

var cur_wps: float = 0
var cur_quality: float 
var built: bool = false

@export var speed_upgrades: Array[pump_upgrade]
@export var quality_upgrades: Array[pump_upgrade]

var upgrade_slots: Array[pump_upgrade] = [null, null, null, null, null]
@export var upgrade_markers: Array[Marker3D]

@onready var upgrade_menu : UpgradeMenu = get_tree().get_first_node_in_group("UpgradeMenu")

@onready var build_audio : AudioStreamPlayer3D = $BuildAudio
@onready var ambience : AudioStreamPlayer3D = $Ambience

@onready var water : Node3D = get_tree().get_first_node_in_group("Water")

var money

func _ready():
	cur_quality = base_quality
	$Geo.visible = built
	$Sign.visible = true
	$Sign/BuyLabel.text = "$"+str(price)
	Events.all_ready.connect(all_ready)
	$Upgrades/PumpUpgrade/CollisionShape3D.disabled = true

func all_ready():
	money = %Money

func do_pump(delta):
	if water.empty:
		return
	var water_amount = cur_wps * delta
	var money_amount = water_amount * cur_quality
	Events.make_money.emit(money_amount)
	return water_amount
	
func start_ambience() -> void:
	ambience.play()

func build():
	build_audio.play()
	start_ambience()
	built = true
	$Geo.visible = true
	$Sign.visible = false
	$Sign/PumpBuy/CollisionShape3D.disabled = true
	$Upgrades/PumpUpgrade/CollisionShape3D.disabled = false
	cur_wps = base_wps
	Events.add_pump.emit(self)
	$AnimationPlayer.play("build")

func attempt_buy() -> bool:
	if money.try_buy(price):
		build()
		return true
	return false

func attempt_upgrade():
	upgrade_menu.open(self)

func apply_upgrade(new_upgrade: pump_upgrade):
	var did_upgrade = false
	var i = 0
	for slot in upgrade_slots:
		if slot == null:
			upgrade_slots[i] = new_upgrade
			match new_upgrade.type:
				pump_upgrade.upgrade_type.QUALITY: 
					print("quality")
					cur_quality += new_upgrade.effect
				pump_upgrade.upgrade_type.SPEED:
					print("speed")
					cur_wps += new_upgrade.effect
			if new_upgrade.model:
				var new_model: Node3D = new_upgrade.model.instantiate()
				$Upgrades.add_child(new_model)
				new_model.global_position = upgrade_markers[i].global_position
			did_upgrade = true
			break
		i += 1
	if not did_upgrade:
		push_error("Tried to add an upgrade to a full pump")
	if upgrade_menu.visible:
		upgrade_menu.render_upgrades(self)

func update_price(new_price: int):
	price = new_price
	$Sign/BuyLabel.text = "$"+str(price)
