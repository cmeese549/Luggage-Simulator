extends Control
class_name KillfeedEntry

@export var green_bg: Color
@export var red_bg: Color

@onready var rich_label: RichTextLabel = $AnimationWrapper/RichTextLabel
@onready var wrapper: Control = $AnimationWrapper
@onready var bg: ColorRect = $AnimationWrapper/ColorRect

func setup(money_amount: int, box: Box, success: bool):
	var color = "green" if money_amount > 0 else "red"
	var sign = "+" if money_amount > 0 else ""
	var status = "✔️" if success else "❌"
	bg.color = green_bg if color == "green" else red_bg
	var destination = box.destination.id if (box.has_valid_destination or not box.disposable) else "Trash"
	rich_label.text = "[font_size=28][color=%s]%s$%d[/color] %s[/font_size]" % [color, sign, money_amount, status]
	# Start wrapper offscreen to the left
	wrapper.position.x = -300
	modulate.a = 0
	animate_in()

func setup_notification(message: String, color: String = "white"):
	var bg_colors = {
		"green": green_bg,
		"red": red_bg,
		"blue": Color(0.0, 0.4, 0.8, 0.32),
		"yellow": Color(0.8, 0.7, 0.0, 0.32),
		"white": Color(0.2, 0.2, 0.2, 0.32)
	}
	
	bg.color = bg_colors.get(color, bg_colors.white)
	rich_label.text = "[font_size=28][color=%s]%s[/color][/font_size]" % [color, message]
	
	# Start wrapper offscreen to the left
	wrapper.position.x = -300
	modulate.a = 0
	animate_in()

func animate_in():
	var tween = create_tween()
	tween.parallel().tween_property(wrapper, "position:x", 0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.2)

func animate_out():
	var tween = create_tween()
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)
