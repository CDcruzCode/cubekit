extends Node

@onready var start_server: Button = %start_server
@onready var update_checker_timer: Timer = $update_checker_timer
@onready var prog_popup: Window = %progress_bar_popup
@onready var prog_text: Label = %progress_bar_popup.get_node("mcon/vbox/prog_text")
@onready var prog_bar: ProgressBar = %progress_bar_popup.get_node("mcon/vbox/prog_bar")
@onready var notification_layer_list: VBoxContainer = %notification_layer_list

const SERVER_META_URL:StringName = "https://launchermeta.mojang.com/mc/game/version_manifest_v2.json"

var http_request_versions: HTTPRequest
var versions_json:Array = []
var new_version:String
var root_path:String

func _ready() -> void:
	root_path = ConfigSettings.config_dictionary.get("root_dir")
	
	update_checker_timer.stop()
	if(ConfigSettings.manager_dictionary.get("auto-update", false)):
		print("[update_checker] Starting checker")
		update_checker_timer.wait_time = 86400 #86400 == 1 day
		if(!update_checker_timer.is_connected("timeout", _update_check)):
			update_checker_timer.timeout.connect(_update_check)
		update_checker_timer.start()


func _update_check()->void:
	if(ConfigSettings.manager_dictionary.get("auto-update", false) == false):
		print("[update_checker] Update checker stopping...")
		update_checker_timer.stop()
		return
	
	print("[update_checker] CHECKING...")
	print( ConfigSettings.config_dictionary.get("server_ver") )
	set_mc_versions_list()


func set_mc_versions_list()->void:
	# Initialize the HTTPRequest node
	if(http_request_versions == null):
		http_request_versions = HTTPRequest.new()
		self.add_child(http_request_versions)
		http_request_versions.request_completed.connect(_on_request_completed_versions)
	http_request_versions.request(SERVER_META_URL)


# Callback for handling HTTP requests
func _on_request_completed_versions(_result:Variant, response_code:int, _headers:Variant, body:Variant)->void:
	http_request_versions.queue_free()
	if(response_code == 200):
		print("[update_checker] HTTP: File downloaded!");
		var json_data:Dictionary = JSON.parse_string(body.get_string_from_utf8())
		versions_json = json_data.versions
		
		if(versions_json.is_empty()):
			print_debug("[update_checked] Error: Version List empty")
			return
	
		
		for i:int in versions_json.size():
			if versions_json[i].type == "release":
				print(versions_json[i])
				if(versions_json[i].id != ConfigSettings.config_dictionary.get("server_ver")):
					print("[update_checker] New version available!")
					new_version = versions_json[i].id
					if(start_server.process_io != null):
						start_server.process_io.store_string("/say A new Minecraft version has been found. The server will be stopping to update in roughly 1 minute!\n")
					fetch_jar(versions_json[i].url)
				return
	else:
		print_debug("[update_checker] HTTP Error: ", response_code)
		versions_json = []




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
	http_request_jar_json.queue_free()
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
		prog_text.text = "Downloading server.jar version "+new_version+"..."
		prog_popup.popup_centered()

#On server.jar file downloaded
func _downloaded(data:PackedByteArray)->void:
	Globals.save_file(root_path+"/server.jar", data)
	print("[update_checker] Server.jar downloaded!")
	prog_popup.hide()
	ConfigSettings.config_dictionary["server_ver"] = new_version
	ConfigSettings.save_config()
	Globals.add_notif(notification_layer_list, "Server auto updated to version "+new_version+" successfully!")
	if(start_server.process_io != null):
		await get_tree().create_timer(60.0).timeout
		start_server._server_stop()
		#await start_server.server_stop
		await get_tree().create_timer(10.0).timeout
		start_server._server_start()



func _progress(percent_progress:int, _chunk:int, _total_size:int)->void:
	prog_bar.value = percent_progress
