extends Button

@onready var version_options: OptionButton = $"../hbox/version_options"
@onready var refresh_version_list: Button = $"../hbox/refresh_version_list"
@onready var prog_popup: Window = %progress_bar_popup
@onready var prog_text: Label = %progress_bar_popup.get_node("mcon/vbox/prog_text")
@onready var prog_bar: ProgressBar = %progress_bar_popup.get_node("mcon/vbox/prog_bar")
@onready var notification_layer_list: VBoxContainer = %notification_layer_list
@onready var checkbox_snapshots: CheckBox = $"../hbox2/checkbox_snapshots"


var root_path:String
var dialog:ConfirmationDialog
var selected_ver:String


func _ready() -> void:
	root_path = ConfigSettings.config_dictionary.get("root_dir")
	self.pressed.connect(_confirm_version_download)


func _confirm_version_download()->void:
	dialog = ConfirmationDialog.new()
	dialog.title = "Download version"
	dialog.dialog_text = "Would you like to change your server version to "+version_options.get_item_text(version_options.selected)+"?\nNote: if you revert to an older server version; worlds saved on newer versions may become corrupted if you attempt to load them!\nPlease ensure the version you're switching to is compatible with your current setup."
	dialog.dialog_autowrap = true
	dialog.canceled.connect(func()->void: dialog.queue_free())
	dialog.confirmed.connect(_confirmed_download)
	dialog.size = Vector2i(500, 100)
	self.add_child(dialog)
	
	dialog.popup_centered(Vector2i(450, 100))


func _confirmed_download()->void:
	dialog.queue_free()
	
	selected_ver = refresh_version_list.versions_json[version_options.get_item_id( version_options.selected ) ].id
	
	
	var jar_url:String = refresh_version_list.versions_json[version_options.get_item_id( version_options.selected ) ].url
	if(version_options.get_item_text( version_options.selected ) == "Latest" && !checkbox_snapshots.button_pressed):
		for version_dict:Dictionary in refresh_version_list.versions_json:
			var version_type:String = version_dict.get("type")
			if(version_type == "release"):
				jar_url = version_dict.get("url")
				selected_ver = version_dict.get("id")
				break
	
	if( ConfigSettings.config_dictionary["server_ver"] == selected_ver ):
		Globals.add_notif(notification_layer_list, "Server already on version "+str(selected_ver)+"!", Color.CORAL)
		return
	
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
		prog_text.text = "Downloading server.jar version "+selected_ver+"..."
		prog_popup.popup_centered()

#On server.jar file downloaded
func _downloaded(data:PackedByteArray)->void:
	Globals.save_file(root_path+"/server.jar", data)
	print("Server.jar downloaded!")
	prog_popup.hide()
	ConfigSettings.config_dictionary["server_ver"] = selected_ver
	ConfigSettings.save_config()
	Globals.add_notif(notification_layer_list, "Server changed version to "+selected_ver+" successfully!")


func _progress(percent_progress:int, _chunk:int, _total_size:int)->void:
	prog_bar.value = percent_progress
