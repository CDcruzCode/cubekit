extends Button

const BACKUP_LIST_CON:PackedScene = preload("res://scenes/main_dashboard/world_management/backup_list_con.tscn")

@onready var start_server: Button = %start_server
@onready var backups_list: VBoxContainer = $view_backups_dialog/pcon/scon/backups_list
@onready var view_backups_dialog: AcceptDialog = $view_backups_dialog
@onready var notification_layer_list: VBoxContainer = %notification_layer_list
@onready var server_properties_node: PanelContainer = %"Server Properties"
@onready var world_management: PanelContainer = %"World Management"

var root_path:String
var backup_path:String

func _ready() -> void:
	if(ConfigSettings.loaded && ConfigSettings.config_dictionary && ConfigSettings.manager_dictionary):
		root_path = ConfigSettings.config_dictionary.get("root_dir")
		backup_path = ConfigSettings.manager_dictionary.get("backup-dir")
	else:
		push_error("[world_management - backups] No root path")
		return
	
	self.pressed.connect(func()->void: refresh_backup_list(); view_backups_dialog.popup_centered(Vector2i(600, 450)))
	refresh_backup_list()


func refresh_backup_list()->void:
	Globals.remove_all_children(backups_list)
	
	var backups_list_arr:PackedStringArray = Globals.list_folders_in_directory(backup_path)
	if(backups_list_arr.is_empty()):
		var label:Label = Label.new()
		label.text = "No backups found.\nEnable backups in the settings tab."
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		backups_list.add_child(label)
		return
	
	backups_list_arr.reverse()
	
	for folder:String in backups_list_arr:
		var con:Control = BACKUP_LIST_CON.instantiate()
		con.self_modulate = Color("#1A6025")
		
		var icon_file:String = backup_path.path_join(folder)+"/icon.png"
		if(FileAccess.file_exists(icon_file)):
			var cicon:Texture = Globals.load_image_texture(icon_file)
			if(cicon != null):
				con.get_node("hbox/world_icon").texture = cicon
		
		con.management_node = self
		
		con.get_node("hbox/vbox/world_name").text = folder.split("-", false, 1)[1]
		con.get_node("hbox/vbox/world_name").set_meta("folder_name", folder)
		con.get_node("hbox/vbox/date_created").text = "Created: "+Time.get_datetime_string_from_unix_time(FileAccess.get_modified_time(backup_path.path_join(folder)), true) 
		
		backups_list.add_child(con)



func _select_backup(backup_name:String)->void:
	if(start_server.process_io != null):
		Globals.add_notif(notification_layer_list, "[Backups] Cannot change world while server is running.", Color.CORAL)
		return
	
	if(!Globals.dir_exists(backup_path+backup_name)):
		push_error("[Backups] Failed to select backup named: "+backup_name)
		return
	
	var selected_world:String = ConfigSettings.config_dictionary["world_name"]
	
	#Save currently active world to worlds folder
	if(!Globals.dir_exists(root_path+"/"+selected_world)):
		Globals.add_notif(notification_layer_list, "Skipping saving previously active world!", Color.CORAL)
	else:
		if(!Globals.deep_copy_dir(root_path+"/"+selected_world, root_path+"/world_management/worlds/"+selected_world)):
			Globals.add_notif(notification_layer_list, "Failed to save previously active world!", Color.CORAL)
		else:
			Globals.add_notif(notification_layer_list, "Previously active world saved to world list!")
		
		if(!Globals.deep_remove_dir(root_path+"/"+selected_world)):
			Globals.add_notif(notification_layer_list, "[world management] Error: Failed to clean up old world!", Color.CORAL)
	
	#Copy backup to be new active world
	if( !Globals.deep_copy_dir(backup_path+backup_name, root_path) ):
		Globals.add_notif(notification_layer_list, "Failed to set backup world to active world!", Color.CORAL)
		push_error("[Backups] Failed to set backup world to active world!")
		return
	
	selected_world = backup_name.split("-", false, 1)[1]
	#Rename backup to exclude timestamp in name
	var err:Error = DirAccess.rename_absolute(root_path+"/"+backup_name, root_path+"/"+selected_world)
	print("[Backups] Failed to rename backup world: "+error_string(err))
	#Change server properties settings to set new active world
	
	ConfigSettings.config_dictionary["world_name"] = selected_world
	ConfigSettings.save_config()
	
	var server_prop_dictionary:Dictionary = server_properties_node.parse_server_properties(Globals.load_text_from_file(ConfigSettings.config_dictionary.get("root_dir") + "/server.properties"))
	server_prop_dictionary["level-name"] = selected_world
	server_properties_node.write_server_properties(root_path+"/server.properties", server_prop_dictionary)
	world_management.refresh_world_list()
	Globals.add_notif(notification_layer_list, "Backup '"+backup_name+"' set as the active world!")
