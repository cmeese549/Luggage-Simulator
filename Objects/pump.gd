extends Node

class_name Pump

@export var base_wps: float = 1
@export var base_quality: float = 1
@export var price: int = 100

var cur_wps: float = 0
var cur_quality: float 
var built: bool = false

var upgrade_slots

var money

func _ready():
	cur_quality = base_quality
	$Geo.visible = built
	$Sign.visible = true
	$Sign/BuyLabel.text = "$"+str(price)
	Events.all_ready.connect(all_ready)
	$Upgrades/PumpUpgrade.monitorable = false
	$Upgrades/PumpUpgrade.monitoring = false

func all_ready():
	money = %Money

func do_pump(delta):
	var water_amount = cur_wps * delta
	var money_amount = water_amount * cur_quality
	Events.make_money.emit(money_amount)
	return water_amount

func build():
	built = true
	$Geo.visible = true
	$Sign.visible = false
	$Sign/PumpBuy.monitorable = false
	$Sign/PumpBuy.monitoring = false
	$Upgrades/PumpUpgrade.monitorable = true
	$Upgrades/PumpUpgrade.monitoring = true
	cur_wps = base_wps
	Events.add_pump.emit(self)

func attempt_buy():
	if money.try_buy(price):
		build()

func attempt_upgrade():
	#Open upgrade menu
	print("doin an upgrade")
	pass
