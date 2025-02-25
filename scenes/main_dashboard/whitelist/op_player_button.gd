extends Button

var whitelist:Control
@onready var player_name: Label = $"../vbox/player_name"
@onready var uuid_label: Label = $"../vbox/uuid_label"

func _ready() -> void:
	self.pressed.connect(_check_op)

func _check_op()->void:
	if(whitelist.op_player(uuid_label.text)):
		self.button_pressed = true
		self.text = "Deop player"
	else:
		self.button_pressed = false
		self.text = "Op player"
