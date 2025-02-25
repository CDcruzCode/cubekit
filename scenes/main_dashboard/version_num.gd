extends Button

@onready var change_log_dialog: Window = $change_log_dialog

func _ready() -> void:
	change_log_dialog.hide()
	self.pressed.connect(func()->void: change_log_dialog.popup_centered())
	change_log_dialog.close_requested.connect(func()->void: change_log_dialog.hide())
