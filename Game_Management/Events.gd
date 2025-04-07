extends Node

signal all_ready()

signal remove_water(amount)
signal water_dumped(amount)

signal make_money(amount, log)
signal add_pump(new_pump: Pump)

signal pump_upgrade_menu(this_pump: Pump)

signal tool_purchased(item: ShopItem)
signal speed_purchased(item: ShopItem)

signal open_shop()
signal close_shop()

signal item_pickedup(item)
