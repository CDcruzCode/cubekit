extends PanelContainer

const WORLD_OPTION_CON:PackedScene = preload("res://scenes/main_dashboard/world_management/world_option_con.tscn")
var con_colour:Color = Color("#1A6025")
var selected_colour:Color = Color("#0E6195")

@onready var start_server: Button = %start_server
@onready var notification_layer_list: VBoxContainer = %notification_layer_list
@onready var world_list: VBoxContainer = $mcon/vbox/scon/world_list
@onready var server_properties_node: PanelContainer = $"../Server Properties"

var root_path:String
var selected_world:String = "world"

#signal world_selected(name:String)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if(ConfigSettings.loaded):
		root_path = ConfigSettings.config_dictionary.get("root_dir")
	else:
		push_error("[world_management] No root path")
		return
	
	
	#Else will be the default "world"
	
	refresh_world_list()


func refresh_world_list()->void:
	Globals.remove_all_children(world_list)
	
	if(ConfigSettings.config_dictionary.has("world_name")):
		selected_world = ConfigSettings.config_dictionary["world_name"]
	
	var world_list_arr:PackedStringArray = Globals.list_folders_in_directory(root_path+"/world_management/worlds")
	if(world_list_arr.is_empty()):
		print("world_list empty")
		if(Globals.dir_exists(root_path+"/"+selected_world)):
			print("minecraft world exists")
			#DirAccess.copy_absolute(root_path+"/"+selected_world, root_path+"/world_management/worlds")
			if( !Globals.deep_copy_dir(root_path+"/"+selected_world, root_path+"/world_management/worlds") ):
				Globals.add_notif(notification_layer_list, "Failed to initialize worlds list!")
				push_error("[world_management] Failed to initialize worlds list!")
				return
			
			#sucessfully copied first world to world management folder
			ConfigSettings.config_dictionary["world_name"] = selected_world
			ConfigSettings.save_config()
	
	for folder:String in world_list_arr:
		if(Globals.dir_exists(root_path+"/world_management/worlds/"+folder) ):
			var con:Control = WORLD_OPTION_CON.instantiate()
			if(folder == selected_world):
				con.self_modulate = selected_colour
			else:
				con.self_modulate = con_colour
			
			var icon_file:String = root_path+"/world_management/worlds/"+folder+"/icon.png"
			if(FileAccess.file_exists(icon_file)):
				var icon:Texture = Globals.load_image_texture(icon_file)
				if(icon != null):
					con.get_node("hbox/world_icon").texture = icon
			
			con.management_node = self
			
			con.get_node("hbox/vbox/world_name").text = folder
			con.get_node("hbox/vbox/hbox/latest_save").text = "Last saved: "+Time.get_datetime_string_from_unix_time(FileAccess.get_modified_time(root_path+"/world_management/worlds/"+folder+"/level.dat"), true) 
			
			world_list.add_child(con)



func select_world(selected:String)->void:
	if(start_server.process_io != null):
		Globals.add_notif(notification_layer_list, "[world management] Cannot change world while server is running.", Color.CORAL)
		return
	
	if(selected_world == selected):
		Globals.add_notif(notification_layer_list, "[world management] World is already selected!", Color.CORAL)
		return
	
	if(!Globals.dir_exists(root_path+"/world_management/worlds/"+selected)):
		Globals.add_notif(notification_layer_list, "[world management] Failed to select world! Could not find folder.", Color.CORAL)
		return
	
	if( !Globals.deep_copy_dir(root_path+"/world_management/worlds/"+selected, root_path) ):
		Globals.add_notif(notification_layer_list, "Failed to set selected world as the active world!", Color.CORAL)
		push_error("[world_management] Failed to set selected world as the active world!")
		return
	
	if(Globals.dir_exists(root_path+"/"+selected_world)):
		if(!Globals.deep_remove_dir(root_path+"/"+selected_world)):
			Globals.add_notif(notification_layer_list, "[world management] Error: Failed to clean up old world!", Color.CORAL)
			return
	
	selected_world = selected
	ConfigSettings.config_dictionary["world_name"] = selected
	ConfigSettings.save_config()
	
	var server_prop_dictionary:Dictionary = server_properties_node.parse_server_properties(Globals.load_text_from_file(ConfigSettings.config_dictionary.get("root_dir") + "/server.properties"))
	server_prop_dictionary["level-name"] = selected
	server_properties_node.write_server_properties(root_path+"/server.properties", server_prop_dictionary)
	refresh_world_list()
