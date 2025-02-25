extends ColorRect

@onready var start_server: Button = $mcon/vbox/hbox/start_server
@onready var stop_server: Button = $mcon/vbox/hbox/stop_server
@onready var notification_layer_list: VBoxContainer = %notification_layer_list

enum STATE {OFFLINE, ONLINE, PAUSED}
var server_state:STATE = STATE.OFFLINE


func _ready()->void:
	$loading_cover.show()
	if(!Globals.file_exists("user://config.cfg")):
		printerr("NO CONFIG FILE DETECTED!")
		manager_error()
		return
	
	var dir:String = ConfigSettings.config_dictionary.get("root_dir")
	
	if(dir == null):
		printerr("NO ROOT DIR FOUND!")
		manager_error()
		return
	
	if(!Globals.dir_exists(dir)):
		printerr("NO ROOT DIR EXISTS!")
		manager_error()
		return
	
	if(!Globals.file_exists(dir.path_join("server.jar"))):
		printerr("NO SERVER JAR EXISTS!")
		manager_error()
		return
	
	if(!Globals.file_exists(dir.path_join("server.properties"))):
		printerr("NO SERVER PROPERTIES FILE!")
		manager_error()
		return
	
	%web_server.get_ready()
	%players_online.get_ready()
	%server_overview.get_ready()
	$loading_cover.queue_free()

func manager_error()->void:
	await get_tree().process_frame
	printerr("INVALID SERVER, BACK TO SET UP!")
	ConfigSettings.clear_config()
	OS.alert("An error occurred loading the server.\nPlease delete any server files and set up the server again.\nYou will be taken back to the set up screen.")
	get_tree().change_scene_to_file("res://scenes/jar_download/jar_download.tscn")
	#print( get_tree().change_scene_to_file("res://scenes/jar_download/jar_download.tscn") )
