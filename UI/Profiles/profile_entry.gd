extends Panel

class_name ProfileEntry

@onready var load_button : Button = $VBoxContainer2/HBoxContainer/Load
@onready var delete_button : Button = $VBoxContainer2/HBoxContainer/Delete
@onready var create_button : Button = $VBoxContainer2/HBoxContainer/Create

@onready var name_label : Label = $"VBoxContainer2/VBoxContainer/Profile Name"
@onready var active_run_label : Label = $VBoxContainer2/VBoxContainer/ActiveRun
@onready var lifetime_money_label : Label = $"VBoxContainer2/VBoxContainer/LifetimeMoney"
