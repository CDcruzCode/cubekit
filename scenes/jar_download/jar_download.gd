extends ColorRect

const SERVER_META_URL:StringName = "https://launchermeta.mojang.com/mc/game/version_manifest_v2.json"
var download_url:String = ""
var download_path:String = ""
var http_request_versions: HTTPRequest

@onready var version_options: OptionButton = $ccon/vbox/hbox/version_options
@onready var button_refresh_list: Button = $ccon/vbox/hbox/button_refresh_list
@onready var checkbox_releases: CheckBox = $ccon/vbox/hbox2/checkbox_releases
@onready var checkbox_snapshots: CheckBox = $ccon/vbox/hbox2/checkbox_snapshots
@onready var checkbox_betas: CheckBox = $ccon/vbox/hbox2/checkbox_betas

@onready var dialog_download_location: FileDialog = $dialog_download_location
@onready var button_file_location: Button = $ccon/vbox/button_file_location

@onready var button_download_version: Button = $ccon/vbox/button_download_version
@onready var prog_popup: Window = $prog_popup
@onready var prog_bar: ProgressBar = $prog_popup/mcon/vbox/prog_bar
@onready var prog_text: Label = $prog_popup/mcon/vbox/prog_text

@onready var eula_popup: ConfirmationDialog = $eula_popup
@onready var setup_complete_popup: AcceptDialog = $setup_complete_popup


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	OS.low_processor_usage_mode = true
	OS.low_processor_usage_mode_sleep_usec = 6900
	
	if(ConfigSettings.loaded && ConfigSettings.config_dictionary):
		download_path = ConfigSettings.config_dictionary.get("root_dir")
		print(download_path)
		
		Globals.create_directory(download_path+"/world_management")
		Globals.create_directory(download_path+"/world_management/worlds")
		Globals.create_directory(download_path+"/world_management/backups")
		Globals.create_directory(download_path+"/world_management/players")
		
		if(ConfigSettings.config_dictionary.get("init_setup", 0) > 3 && FileAccess.file_exists(download_path + "/server.jar")):
			get_tree().call_deferred("change_scene_to_file", "res://scenes/main_dashboard/main_dashboard.tscn")
			return
	
	button_refresh_list.pressed.connect(set_mc_versions_list)
	button_file_location.pressed.connect(func()->void: dialog_download_location.popup_centered(Vector2i(400, 300)))
	dialog_download_location.dir_selected.connect(_download_loc_selected)
	
	button_download_version.disabled = true
	button_download_version.pressed.connect(_start_jar_download)
	set_mc_versions_list()
	
	print("[jar_download] Config loaded? ", ConfigSettings.loaded)
	if(ConfigSettings.loaded):
		match ConfigSettings.config_dictionary.get("init_setup", 0):
			0: #Nothing set-up
				pass
			1: #Server.jar downloaded
				check_java()
			2: #Java downloaded
				init_server_jar()
			3: #Server.jar loaded but need to accept EULA
				await_eula()
			4: #Server set up complete
				print("[jar_download] loading dashboard")
				get_tree().call_deferred("change_scene_to_file", "res://scenes/main_dashboard/main_dashboard.tscn")
				pass
			_:
				printerr("[Invalid setup state]")
				OS.alert("An error occurred loading the server.\nPlease delete any server files set up the server again.")
				#get_tree().call_deferred("change_scene_to_file", "res://scenes/main_dashboard/main_dashboard.tscn")

var versions_json:Array = []
func set_mc_versions_list()->void:
	button_refresh_list.disabled = true
	# Initialize the HTTPRequest node
	if(http_request_versions == null):
		http_request_versions = HTTPRequest.new()
		self.add_child(http_request_versions)
		http_request_versions.request_completed.connect(_on_request_completed_versions)
	http_request_versions.request(SERVER_META_URL)


# Callback for handling HTTP requests
func _on_request_completed_versions(_result:Variant, response_code:int, _headers:Variant, body:Variant)->void:
	if(response_code == 200):
		print("HTTP: File downloaded!");
		var json_data:Dictionary = JSON.parse_string(body.get_string_from_utf8())
		versions_json = json_data.versions
		
		if(versions_json.is_empty()):
			print_debug("Error: Version List empty")
			return
	
		version_options.clear()
		version_options.add_item("Latest")
		for i:int in versions_json.size():
			
			if checkbox_releases.button_pressed and versions_json[i].type == "release":
				version_options.add_item(versions_json[i].id, i)
			elif checkbox_snapshots.button_pressed and versions_json[i].type == "snapshot":
				version_options.add_item(versions_json[i].id, i)
			elif checkbox_betas.button_pressed and versions_json[i].type == "old_beta":
				version_options.add_item(versions_json[i].id, i)
	else:
		print_debug("HTTP Error: ", response_code)
		versions_json = []
	
	button_refresh_list.disabled = false

func _download_loc_selected(dir:String)->void:
	print(dir)
	button_file_location.text = Globals.get_drive_and_last_two_folders(dir)
	button_file_location.tooltip_text = dir
	download_path = dir
	button_download_version.disabled = false
	
	ConfigSettings.config_dictionary.root_dir = dir.replace("\\", "/")
	ConfigSettings.save_config()


func _start_jar_download()->void:
	if(versions_json.is_empty()):
		return
	
	button_file_location.disabled = true
	button_refresh_list.disabled = true
	version_options.disabled = true
	button_download_version.disabled = true
	
	ConfigSettings.config_dictionary.server_ver = versions_json[version_options.get_item_id( version_options.selected ) ].id
	
	var jar_url:String = versions_json[version_options.get_item_id( version_options.selected ) ].url
	if(version_options.get_item_text( version_options.selected ) == "Latest" && !checkbox_snapshots.button_pressed):
		for version_dict:Dictionary in versions_json:
			var version_type:String = version_dict.get("type")
			if(version_type == "release"):
				jar_url = version_dict.get("url")
				ConfigSettings.config_dictionary.server_ver = version_dict.get("id")
				break
	
	fetch_jar(jar_url)

var http_request_jar_json:HTTPRequest
func fetch_jar(url:String)->void:
	print(url)
	# Initialize the HTTPRequest node
	if(http_request_jar_json == null):
		http_request_jar_json = HTTPRequest.new()
		self.add_child(http_request_jar_json)
		http_request_jar_json.request_completed.connect(_on_request_completed_jar_json)
	http_request_jar_json.request(url)

#Downloading server.jar file
var http_request_jar:HTTPRequest
func _on_request_completed_jar_json(_result:Variant, response_code:int, _headers:Variant, body:Variant)->void:
	if(response_code == 200):
		print("HTTP: Jar JSON fetched!");
		var json_data:Dictionary = JSON.parse_string(body.get_string_from_utf8())
		print(json_data.downloads.server.url)
		
		var http:HTTPClientHelper = HTTPClientHelper.new(self)
		http.threaded = true
		http.download_progress.connect(_progress)
		http.download_complete.connect(_downloaded)
		http.download(json_data.downloads.server.url)
		#http.download("https://cdcruz.com/index.html")
		
		prog_bar.value = 0
		prog_text.text = "Downloading server.jar..."
		prog_popup.popup_centered()

#On server.jar file downloaded
func _downloaded(data:PackedByteArray)->void:
	Globals.save_file(download_path+"/server.jar", data)
	print("Server.jar downloaded!")
	ConfigSettings.config_dictionary.init_setup = 1
	ConfigSettings.save_config()
	check_java()

func check_java()->void:
	print("Checking Java")
	prog_popup.popup_centered()
	if(is_java_installed()):
		_java_installed()
	else:
		$java_download.download_java()
		$java_download.java_downloaded.connect(_java_installed)

func _progress(percent_progress:int, _chunk:int, _total_size:int)->void:
	prog_bar.value = percent_progress



func is_java_installed() -> bool:
	var result:Error = OS.execute("cmd", ["/c", "java -version"], [], true) as Error
	
	if result == OK:
		print("Java is installed!")
		return true
	else:
		print("Java is not installed or not in PATH.")
		return false



func _java_installed()->void:
	print("Java installed now. Starting server.jar...")
	ConfigSettings.config_dictionary.init_setup = 2
	ConfigSettings.save_config()
	init_server_jar()

#func init_server_jar()->void:
	#var jar_path:String = download_path+"/server.jar"
	#print(jar_path)
	#prog_text.text = "Initializing server.jar file..."
	#
	##Create .bat or .sh file to init loading the server.jar file in the correct location
	#var bat_content:String = ""
	#var script_path:String = ""
	#match OS.get_name():
		#"macOS":
			#pass
		#"Linux":
			#pass
		#"Windows":
			#bat_content = """
#@echo off
#cd /d "{0}"
#java -Xmx1024M -Xms1024M -jar "{1}" nogui
#""".format([download_path, "server.jar"])
			#script_path = download_path+"/init.bat"
			#Globals.save_file(script_path, bat_content.to_ascii_buffer())
		#_:
			#printerr("[Server Init] Unsupported OS!")
			#return
	#
	#var output:Array = []
	#var result:Error = OS.execute("cmd", ["/c", script_path], output, true)
	#
	#print(output)
	#
	#if result == OK:
		#print("JAR file ran successfully!")
		#await_eula()
	#else:
		#print("Failed to run the JAR file.")

func init_server_jar() -> void:
	if(Globals.file_exists(download_path.path_join("eula.txt"))):
		await_eula()
		return
	
	var jar_path: String = download_path + "/server.jar"
	print(jar_path)
	prog_text.text = "Initializing server.jar file..."
	
	# Create the appropriate script for the OS to run the server.jar file
	var script_content: String = ""
	var script_path: String = ""
	# Execute the script
	var output: Array = []
	var result: Error
	
	
	match OS.get_name():
		"macOS", "Linux":
			script_content = """
#!/bin/bash
cd "{0}"
java -Xmx1024M -Xms1024M -jar "{1}" nogui
""".format([download_path, "server.jar"])
			script_path = download_path + "/init.sh"
			Globals.save_file(script_path, script_content.to_utf8_buffer())
			
			# Make the script executable
			result = OS.execute("chmod", ["+x", script_path], output, true) as Error
			if result != OK:
				push_error("[init_server_jar] Unable to make script executable.")
				return
		"Windows":
			script_content = """
@echo off
cd /d "{0}"
java -Xmx1024M -Xms1024M -jar "{1}" nogui
""".format([download_path, "server.jar"])
			script_path = download_path + "/init.bat"
			Globals.save_file(script_path, script_content.to_ascii_buffer())
		_:
			printerr("[Server Init] Unsupported OS!")
			return
	
	
	
	if OS.get_name() in ["macOS", "Linux"]:
		result = OS.execute("bash", [script_path], output, true) as Error
	elif OS.get_name() == "Windows":
		result = OS.execute("cmd", ["/c", script_path], output, true) as Error
	
	print(output)
	
	if result == OK:
		print("JAR file ran successfully!")
		await_eula()
	else:
		print("Failed to run the JAR file.")






func await_eula()->void:
	ConfigSettings.config_dictionary.init_setup = 3
	ConfigSettings.save_config()
	prog_popup.hide()
	eula_popup.confirmed.connect(eula_confirmed)
	eula_popup.popup_centered()

func eula_confirmed()->void:
	eula_popup.hide()
	var eula_file:String = Globals.load_text_from_file(download_path+"/eula.txt")
	eula_file = eula_file.replace("false", "true")
	var result:bool = Globals.save_file(download_path+"/eula.txt", eula_file.to_ascii_buffer())
	if(!result):
		push_error("An error occurred trying to change the eula.txt file!")
	
	
	ConfigSettings.config_dictionary.init_setup = 4
	ConfigSettings.save_config()
	setup_complete_popup.confirmed.connect(func()->void: get_tree().change_scene_to_file("res://scenes/main_dashboard/main_dashboard.tscn"))
	setup_complete_popup.popup_centered()
