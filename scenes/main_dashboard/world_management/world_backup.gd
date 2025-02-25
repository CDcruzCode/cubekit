extends Node

@onready var start_server: Button = $"../mcon/vbox/hbox/start_server"
@onready var world_management: PanelContainer = $"../mcon/vbox/tcon/World Management"
@onready var notification_layer_list: VBoxContainer = %notification_layer_list

var root_path:String
var backup_path:String
var backup_enabled:bool = false
var backup_timer:Timer
var backup_freq:int= 60*5

func _ready() -> void:
	if(ConfigSettings.loaded):
		root_path = ConfigSettings.config_dictionary.get("root_dir")
		backup_path = ConfigSettings.manager_dictionary.get("backup-dir")
	
	start_server.server_start.connect(_copy_active_world)
	start_server.server_start.connect(set_backup)
	start_server.server_stop.connect(func()->void:
		if(ConfigSettings.manager_dictionary["stop-backup"]):
			_copy_active_world())

func set_backup(option:bool=true)->void:
	
	backup_enabled = option
	
	if(option):
		if(ConfigSettings.manager_dictionary.has("backup-freq")):
			var freq_dict:Dictionary = ConfigSettings.manager_dictionary["backup-freq"]
			match(freq_dict["time_unit"]):
				"minutes":
					backup_freq = int(freq_dict["amount"]) * 60
				"hours":
					backup_freq = int(freq_dict["amount"]) * 60 * 60
				"days":
					backup_freq = int(freq_dict["amount"]) * 60 * 60 * 24
		
		print("[world backup] Setting backup timer. Freq: ", str(backup_freq))
		backup_timer = Timer.new()
		backup_timer.one_shot = false
		backup_timer.autostart = true
		self.add_child(backup_timer)
		backup_timer.timeout.connect(_initiate_backup)
		backup_timer.start(backup_freq)
	else:
		if(backup_timer != null):
			backup_timer.queue_free()

@onready var players_online: PanelContainer = $"../mcon/vbox/tcon/Dashboard/vbox/hbox/vbox/players_online"
var no_players:bool = false

func _initiate_backup()->void:
	if(start_server.process_io == null):
		return
	
	#If no players on the server, only back up once, and then do not back up again until a player joins again.
	if (players_online.online_arr.size() > 0):
		no_players = false
	elif (!no_players):
		no_players = true
	else:
		print("[world backup] Skipping backup - No players online.")
		return
	
	print("[world backup] Backing up world...")
	
	check_backup_limit()
	
	
	start_server.process_io.store_string("/save-all flush\n")
	OS.delay_msec(100)
	var selected_world:String = "world"
	if(ConfigSettings.config_dictionary.has("world_name")):
		selected_world = ConfigSettings.config_dictionary["world_name"]
	
	var backup_name:String = Time.get_datetime_string_from_system().replace("-", "").replace(":", "") + "-" + selected_world
	
	if( backup_copy(root_path+"/"+selected_world, backup_path, backup_name) ):
		Globals.add_notif(notification_layer_list, "Backup complete: '"+selected_world+"' has been saved.")
		start_server.process_io.store_string("/say World has been backed up!\n")
	else:
		Globals.add_notif(notification_layer_list, "Backup failed: An error occurred saving the world '"+selected_world+"'.")

func check_backup_limit()->void:
	var backup_limit:int = 1
	if(ConfigSettings.manager_dictionary.has("backup-limit")):
		backup_limit = ConfigSettings.manager_dictionary["backup-limit"]
	
	var backup_arr:PackedStringArray = Globals.list_folders_in_directory(backup_path)
	while(backup_arr.size() >= backup_limit):
		if( Globals.deep_remove_dir(backup_path.path_join(backup_arr[0])) ):
			backup_arr.remove_at(0)
			print("[world_backup] Oldest backup deleted.")
		else:
			print("[world_backup] Failed to delete overflow backup!")
			return


func _copy_active_world()->void:
	var selected_world:String = "world"
	if(ConfigSettings.config_dictionary.has("world_name")):
		selected_world = ConfigSettings.config_dictionary["world_name"]
	
	if( !Globals.deep_copy_dir(root_path+"/"+selected_world, root_path+"/world_management/worlds") ):
		push_error("[world backup] Failed to back up active world: "+selected_world+"\nNo folder found.")
	
	world_management.refresh_world_list()


func backup_copy(source_path:String, dest_path:String, file_name:String="")->bool:
	
	var source_dir:DirAccess = DirAccess.open(source_path)
	var dest_dir:DirAccess = DirAccess.open(dest_path)
	var source_end:String = source_path.get_slice("/", source_path.get_slice_count("/")-1)
	
	if(!Globals.dir_exists(source_path)):
		push_error("Source dir does not exist! ", source_path )
		return false
	
	# Open the source directory
	if (source_end.contains(".") ) && DirAccess.get_open_error() != OK:
		push_error("\nFailed to open source directory: " + source_path, "\nError: ", error_string(DirAccess.get_open_error() ))
		return false
	
	var new_dest_path:String = dest_path+"/"+file_name
	# Ensure the destination directory exists
	if DirAccess.get_open_error() == OK:
		var make_dir_err:Error = dest_dir.make_dir(new_dest_path)
		if make_dir_err != OK && make_dir_err != ERR_ALREADY_EXISTS:
			push_error("\nFailed to make destination directory: " + dest_path, "\nError: ", error_string(make_dir_err))
			return false
	else:
		push_error("\nFailed to open destination directory! ", dest_path)
		return false
	
	source_dir.list_dir_begin()  # Begin listing the directory
	while true:
		var item:String = source_dir.get_next()
		if item == "":
			break  # No more items
		
		if item == "." or item == "..":
			continue  # Skip special directories
		
		var source_item_path:String = source_path + "/" + item
		var dest_item_path:String = new_dest_path
		
		#print("Coping: ", source_item_path)
		
		if source_dir.current_is_dir():
			# Recursively copy subdirectories
			if not backup_copy(source_item_path, dest_item_path, item):
				return false
		else:
			# Copy files
			var file:FileAccess = FileAccess.open(source_item_path, FileAccess.READ)
			if FileAccess.get_open_error() != OK:
				push_error("Failed to open file: " + source_item_path)
				return false
			var data:PackedByteArray = file.get_buffer(file.get_length())
			file.close()
			
			file = FileAccess.open(dest_item_path + "/" + item, FileAccess.WRITE)
			if FileAccess.get_open_error() != OK:
				push_error("Failed to create file: " + dest_item_path+ "/" + item)
				return false
			file.store_buffer(data)
			file.close()
	
	source_dir.list_dir_end()  # Clean up
	return true
