extends Node

signal all_ready()

signal make_money(amount, log)


signal tool_purchased(item: ShopItem)
signal speed_purchased(item: ShopItem)

signal open_shop()
signal close_shop()

signal item_pickedup(item)

signal game_loaded()

signal box_deposited(money_amount: int, destination: String, success: bool)
