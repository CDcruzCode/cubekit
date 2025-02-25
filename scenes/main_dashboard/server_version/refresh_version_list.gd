extends Button

const SERVER_META_URL:StringName = "https://launchermeta.mojang.com/mc/game/version_manifest_v2.json"

@onready var version_options: OptionButton = $"../version_options"
@onready var checkbox_releases: CheckBox = $"../../hbox2/checkbox_releases"
@onready var checkbox_snapshots: CheckBox = $"../../hbox2/checkbox_snapshots"
@onready var checkbox_betas: CheckBox = $"../../hbox2/checkbox_betas"
@onready var download_minecraft_ver_button: Button = $"../../download_minecraft_ver_button"

var http_request_versions: HTTPRequest
var versions_json:Array = []

func _ready() -> void:
	download_minecraft_ver_button.disabled = true
	self.pressed.connect(set_mc_versions_list)


func set_mc_versions_list()->void:
	self.disabled = true
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
	
	self.disabled = false
	download_minecraft_ver_button.disabled = false
