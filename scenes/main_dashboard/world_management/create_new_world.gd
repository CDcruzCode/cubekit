extends Button

@onready var notification_layer_list: VBoxContainer = %notification_layer_list
@onready var create_world_dialog: ConfirmationDialog = $create_world_dialog
@onready var level_name: LineEdit = $"create_world_dialog/mcon/scon/vbox/level_name/level-name"
@onready var level_seed: LineEdit = $"create_world_dialog/mcon/scon/vbox/level_seed/level-seed"
@onready var level_type: OptionButton = $"create_world_dialog/mcon/scon/vbox/level_type/level-type"
@onready var generate_structures: CheckButton = $"create_world_dialog/mcon/scon/vbox/generate_structures/generate-structures"
@onready var generator_settings: LineEdit = $"create_world_dialog/mcon/scon/vbox/generator_settings/generator-settings"

@onready var start_server: Button = $"../../../../../../hbox/start_server"
@onready var world_management: PanelContainer = $"../../../.."

var root_path:String
var new_world:bool = false
var old_world_name:String

func _ready() -> void:
	create_world_dialog.hide()
	root_path = ConfigSettings.config_dictionary.get("root_dir")
	self.pressed.connect(_init_create_world_popup )
	
	create_world_dialog.confirmed.connect(_create_world)
	start_server.server_start.connect(_world_start)

func _init_create_world_popup()->void:
	if($"../../../../../../hbox/start_server".process_io != null):
		Globals.add_notif(notification_layer_list, "[World creation] Error: Server must be shut down before creating a new world!", Color.CORAL)
		return
	
	level_name.text = ""
	level_seed.text = ""
	create_world_dialog.popup_centered()

func _create_world()->void:
	if(level_name.text.strip_edges().is_empty()):
		Globals.add_notif(notification_layer_list, "[World creation] Error: World name is empty!", Color.CORAL)
		return
	
	var invalid_names:PackedStringArray = ["crash-reports", "libraries", "logs", "versions", "world_management"]
	if( invalid_names.has(level_name.text.strip_edges()) ):
		Globals.add_notif(notification_layer_list, "[World creation] Error: Invalid world name!", Color.CORAL)
		return
	
	
	if(!level_name.text.is_valid_filename()):
		Globals.add_notif(notification_layer_list, "[World creation] Error: Invalid world name!", Color.CORAL)
		return
	
	var server_properties_node:Control = $"../../../../../Server Properties"
	new_world = true
	old_world_name = ""
	
	var server_prop_dictionary:Dictionary = server_properties_node.parse_server_properties(Globals.load_text_from_file(ConfigSettings.config_dictionary.get("root_dir") + "/server.properties"))
	old_world_name = server_prop_dictionary["level-name"]
	
	server_prop_dictionary["level-name"] = level_name.text.strip_edges()
	server_prop_dictionary["level-type"] = level_type.get_item_text(level_type.selected)
	server_prop_dictionary["generate-structures"] = generate_structures.button_pressed
	server_prop_dictionary["generator-settings"] = generator_settings.text.strip_edges()
	
	#Copy old world to management folder
	if(Globals.dir_exists(root_path+"/"+old_world_name)):
		if( !Globals.deep_copy_dir(root_path+"/"+old_world_name, root_path+"/world_management/worlds") ):
			Globals.add_notif(notification_layer_list, "[World creation] Error: Failed to save previous world before creating new world!", Color.CORAL)
			return
		
		#var remove_dir_err:Error = DirAccess.remove_absolute(root_path+"/"+old_world_name)
		if(!Globals.deep_remove_dir(root_path+"/"+old_world_name)):
			#print(error_string(remove_dir_err))
			Globals.add_notif(notification_layer_list, "[World creation] Error: Failed to clean up old world!", Color.CORAL)
			return
	
	server_properties_node.write_server_properties(root_path+"/server.properties", server_prop_dictionary)
	ConfigSettings.config_dictionary["world_name"] = server_prop_dictionary["level-name"]
	ConfigSettings.save_config()
	Globals.add_notif(notification_layer_list, "[World creation] Success: Starting the server to create the world: "+server_prop_dictionary["level-name"] )
	old_world_name = server_prop_dictionary["level-name"]
	start_server._server_start()
	create_world_dialog.hide()

func _world_start()->void:
	if(!new_world):
		return
	
	if( !Globals.deep_copy_dir(root_path+"/"+old_world_name, root_path+"/world_management/worlds") ):
		Globals.add_notif(notification_layer_list, "[World creation] Error: Failed to save previous world before creating new world!", Color.CORAL)
		return
	
	world_management.refresh_world_list()
