extends Button
@onready var notification_layer_list: VBoxContainer = %notification_layer_list

var process_thread:Thread = null
#var process = null
var process_io:FileAccess = null
var process_err:FileAccess = null
var process_id:int = 0
var bat_content:String
var bat_path:String
 
var SERVER_PATH:String

var jar_pids:PackedInt32Array = []

signal player_joined
signal player_left
signal server_start
signal server_stop

@onready var stop_server: Button = $"../stop_server"
@onready var server_online_status: TextureRect = $"../server_online_status"
const NIL_STATUS:Texture2D = preload("res://images/nil_status.png")
const WAIT_STATUS:Texture2D = preload("res://images/wait_status.png")
const BAD_STATUS:Texture2D = preload("res://images/bad_status.png")
const GOOD_STATUS:Texture2D = preload("res://images/good_status.png")

@onready var console_output_display: TextEdit = $"../../tcon/Console/mcon/vbox/console_output_display"
@onready var console_input: LineEdit = $"../../tcon/Console/mcon/vbox/console_input"
@onready var tab_con: TabContainer = $"../../tcon"
@onready var world_backup: Node = %world_backup

var root_path:String
var backup_path:String


func _exit_tree()->void:
	await get_tree().process_frame
	if(process_io != null):
		_server_stop()

func _ready()->void:
	if(ConfigSettings.loaded && ConfigSettings.config_dictionary && ConfigSettings.manager_dictionary):
		root_path = ConfigSettings.config_dictionary.get("root_dir")
		backup_path = ConfigSettings.manager_dictionary.get("backup-dir")
	
	server_online_status.texture = BAD_STATUS
	self.pressed.connect(_server_start)
	stop_server.pressed.connect(_server_stop)
	console_input.text_submitted.connect(_console_input)
 
func _server_stop()->void:
	server_online_status.texture = WAIT_STATUS
	print("[START SERVER] Cleaning up before closing...")
	call_deferred("_process_output", "STOPPING SERVER...")
	if(process_io != null):
		process_io.store_string("/stop\n")
		call_deferred("_process_output", "[INTERNAL] /stop")
	#Clears the terminal process that was running to start the server.jar
	if(process_id != 0):
		OS.kill(process_id)
		print("Server process "+str(process_id)+" killed!")
		process_id = 0
	
	##Clear any Java.exe processes running before shutting down
	#if(!jar_pids.is_empty()):
		#for pid:int in jar_pids:
			#OS.kill(pid)
			#print("Process: "+str(pid)+" killed!")
		#jar_pids.clear()
	
	if process_thread:
		process_thread.wait_to_finish()
		process_thread = null
	
	server_stop.emit()
	process_io = null
	process_err = null
	call_deferred("_process_output", "Server stopped!")
	server_online_status.texture = BAD_STATUS
	Globals.add_notif(notification_layer_list, "Server stopped!")
	self.disabled = false
	
	world_backup.check_backup_limit()
	
	if(ConfigSettings.manager_dictionary.has("stop-backup") && ConfigSettings.manager_dictionary.get("stop-backup")):
		var selected_world:String = "world"
		if(ConfigSettings.config_dictionary.has("world_name")):
			selected_world = ConfigSettings.config_dictionary["world_name"]
		
		var backup_name:String = Time.get_datetime_string_from_system().replace("-", "").replace(":", "") + "-" + selected_world
		
		if( world_backup.backup_copy(root_path+"/"+selected_world, backup_path, backup_name) ):
			Globals.add_notif(notification_layer_list, "Backup complete: '"+selected_world+"' has been saved.")
		else:
			Globals.add_notif(notification_layer_list, "Backup failed: An error occurred saving the world '"+selected_world+"'.")


func _server_start()->void:
	if(process_io != null):
		%web_socket.send_all(JSON.stringify({"msg": "cannot_start"}))
		print("[start server] Server already started, cannot restart while active!")
		return
	
	if(ConfigSettings.loaded):
		self.disabled = true
		stop_server.disabled = true
		Globals.add_notif(notification_layer_list, "Attempting to start server...", Color.CORAL)
		server_online_status.texture = WAIT_STATUS
		tab_con.current_tab = 1
		SERVER_PATH = ConfigSettings.config_dictionary.get("root_dir")
		if(ConfigSettings.config_dictionary.get("root_dir") == null):
			push_error("[Start Server] No root dir found!")
			Globals.add_notif(notification_layer_list, "Could not start server! No root directory found!", Color.FIREBRICK)
			self.disabled = false
			return
	else:
		push_error("[Start Server] No config file found!")
		Globals.add_notif(notification_layer_list, "Could not start server! No config file found!", Color.FIREBRICK)
		return
	
	
	var RAM_AMT:String = "-Xmx1G"
	if(ConfigSettings.manager_dictionary.has("allocated-ram")):
		print("[start server] Starting with "+str(ConfigSettings.manager_dictionary["allocated-ram"])+"GB allocated RAM.")
		RAM_AMT = "-Xmx{0}G".format([str(ConfigSettings.manager_dictionary["allocated-ram"])])
	
	bat_content = """
@echo off
cd /d "{0}"
start /b java "{2}" "{2}" -jar "{1}" nogui
for /f "tokens=2" %%i in ('tasklist /fi "IMAGENAME eq java.exe" /nh') do (
	echo [INTERNAL] PROCESSID:%%i
)

""".format([ConfigSettings.config_dictionary.get("root_dir"), "server.jar", RAM_AMT])
	bat_path = ConfigSettings.config_dictionary.get("root_dir")+"/start.bat"
	Globals.save_file(bat_path, bat_content.to_ascii_buffer())
	
	
	%web_socket.send_all(JSON.stringify({"msg": "attempting_start"}))
	process_thread = Thread.new()
	process_thread.start(_run_process, Thread.PRIORITY_HIGH)

func _run_process()->void:
	jar_pids.clear()
	var java_command:String = "cmd"
	var args:PackedStringArray = ["/c", bat_path]
	var info: Dictionary = OS.execute_with_pipe(java_command, args)
	print(args)
	#process = info["process"]
	process_io = info["stdio"]
	process_err = info["stderr"]
	process_id = info["pid"]
	print("[START SERVER] Server Process created! ID: "+str(process_id))
	
	if(process_io.get_error() != OK):
		push_error("[START SERVER] An error occurred trying to start the server.jar file!")
		Globals.add_notif(notification_layer_list, "Could not start server! Server.jar file error!", Color.FIREBRICK)
	
	while process_io.is_open() and process_io.get_error() == OK:
		var output:String = process_io.get_line()
		if output != "":
			call_deferred("_process_output", output)
		#var err:String = process_err.get_line()
		#if err != "":
			#call_deferred("_process_output", "ERROR: "+err)
		OS.delay_msec(100)  # Delay to avoid busy-waiting
 
var full_console_log:String = ""
func _process_output(output:String)->void:
	#Getting the jar process ID's for further use
	%web_socket.send_all(JSON.stringify({"msg": "console", "output": output}))
	if(output.begins_with("[INTERNAL] PROCESSID")):
		var split:PackedStringArray = output.split(":")
		jar_pids.append(int(split[-1]))
		print(jar_pids)
	
	if(output.contains("[Server thread/INFO]: Done")):
		server_online_status.texture = GOOD_STATUS
		Globals.add_notif(notification_layer_list, "Server started!")
		server_start.emit()
		stop_server.disabled = false
		#monitor_external_process_windows(jar_pids[0])
		#call_deferred("_process_output", "[CUBEKIT] Your IP is: "+Globals.get_pc_ip())
	
	var join_regex:RegEx = RegEx.new()
	join_regex.compile("\\[Server thread\\/INFO\\]: (.+?) joined the game")
	var join_regex_res:RegExMatch = join_regex.search(output)
	if(join_regex_res != null):
		self.emit_signal("player_joined", join_regex_res.get_string(1))
	
	var leave_regex:RegEx = RegEx.new()
	leave_regex.compile("\\[Server thread\\/INFO\\]: (.+?) left the game")
	var leave_regex_res:RegExMatch = leave_regex.search(output)
	if(leave_regex_res != null):
		self.emit_signal("player_left", leave_regex_res.get_string(1))
	
	if(output.substr(11).begins_with("[ServerMain/ERROR]: Failed to start the minecraft server")):
		print("[start_server] SERVER FAILED TO START! Attempting restart...")
		#restart_thread = Thread.new()
		#restart_thread.start(attempt_server_restart, Thread.PRIORITY_HIGH)
		self.call_deferred("attempt_server_restart")
	
	
	print(output)
	full_console_log += "\n"+output
	console_output_display.text += "\n"+output
	await get_tree().create_timer(0.2).timeout
	console_output_display.scroll_vertical = console_output_display.get_line_count()
 

func _console_input(input:String)->void:
	print("input: ", input)
	console_input.clear()
	if process_io:
		if(is_custom_command(input)):
			return
		process_io.store_string(input+"\n")
		call_deferred("_process_output", "[USER] "+input)
	else:
		call_deferred("_process_output", "[USER] "+input)
		call_deferred("_process_output", "!The console can only be used while the server is running!")


func is_custom_command(input:String)->bool:
	return false #CUSTOM COMMANDS NOT SET UP
	
	input = input.strip_edges()
	if(input.begins_with("--")):
		call_deferred("_process_output", "[USER] "+input)
		input = input.trim_prefix("--").to_lower()
		match(input):
			"help":
				print("HELP")
				var output:String = """[Cubekit Commands]
--help | Provides a list of all Cubekit commands.
--backup | Force the currently active world to be backed up.
--forcestop | Forcefully clears any server processes that are running."""
				call_deferred("_process_output", output)
				return true
		
		
		
	
	return false




#####
#####
func attempt_server_restart()->void:
	Globals.add_notif(notification_layer_list, "Server failed to start! Process already running. Attempting restart...", Color.CORAL)
	
	if(process_id != 0):
		OS.kill(process_id)
		print("Server process "+str(process_id)+" killed!")
		process_id = 0
	
	if process_thread:
		await process_thread.wait_to_finish()
		process_thread = null
	
	console_output_display.text = "Server failed to start! Process already running. Attempting restart..."
	
	process_io = null
	process_err = null
	server_online_status.texture = BAD_STATUS
	
	OS.execute("cmd", ["/C", "taskkill", "/IM", "java.exe", "/F"], [], false)

	_server_start()
