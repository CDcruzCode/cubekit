extends Button

@onready var import_dialog: FileDialog = $import_dialog
@onready var notification_layer_list: VBoxContainer = %notification_layer_list
@onready var world_management: PanelContainer = %"World Management"

var root_path:String

func _ready() -> void:
	if(ConfigSettings.loaded):
		root_path = ConfigSettings.config_dictionary.get("root_dir")
	else:
		push_error("[world_management - Import World] No root path")
		return
	
	self.pressed.connect(func()->void: import_dialog.popup_centered())
	import_dialog.dir_selected.connect(_import_world)

func _import_world(path:String)->void:
	if(!is_valid_minecraft_world(path)):
		return
	
	if( !Globals.deep_copy_dir(path, root_path+"/world_management/worlds") ):
		Globals.add_notif(notification_layer_list, "Failed to import world!", Color.CORAL)
		push_error("[world_management - Import World] Failed to import world: "+path)
		return
	
	world_management.refresh_world_list()
	Globals.add_notif(notification_layer_list, "World imported successfully!")

func is_valid_minecraft_world(folder_path: String) -> bool:
	# Check if the folder exists
	if not DirAccess.dir_exists_absolute(folder_path):
		Globals.add_notif(notification_layer_list, "[Import world] Failed import: No folder found.", Color.CORAL)
		return false
	
	# Check for critical files/directories
	var level_dat:String = folder_path.path_join("level.dat")
	var regions_dir:String = folder_path.path_join("region")
	var _db_dir:String = folder_path.path_join("db") #For bedrock worlds only
	
	# Check for level.dat and regions directory
	if(!FileAccess.file_exists(level_dat)):
		Globals.add_notif(notification_layer_list, "[Import world] Failed import: No level.dat found.", Color.CORAL)
		return false
	
	if(!DirAccess.dir_exists_absolute(regions_dir)):
		Globals.add_notif(notification_layer_list, "[Import world] Failed import: No region folder found.", Color.CORAL)
		return false
	
	return true
