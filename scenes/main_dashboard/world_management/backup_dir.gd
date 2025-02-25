extends Button

@onready var backup_select: FileDialog = $backup_select

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.pressed.connect(func()->void: backup_select.popup_centered(Vector2i(300,400)))
	backup_select.dir_selected.connect(_select_dir)


func _select_dir(path:String) -> void:
	var path_dir:String = Globals.get_drive_and_last_two_folders(path)
	self.text = path_dir
	self.set_meta("dir", path.replace("\\", "/"))
