extends Node

var config:ConfigFile = ConfigFile.new()
var loaded:bool = false
var config_dictionary:Dictionary = {}
var manager_dictionary:Dictionary = {}

var sections_dict:Dictionary = {
		"server": config_dictionary,
		"manager": manager_dictionary
	}

func _ready() -> void:
	if(config.load("user://config.cfg") != OK):
		print("[ConfigSettings] No config file found!")
		return
	
	loaded = true
	_config_to_dict()

func save_config() -> bool:
	for section:String in sections_dict:
		for key:String in sections_dict[section].keys():
			config.set_value(section, key, sections_dict[section][key])
	
	if config.save("user://config.cfg") == OK:
		print("[ConfigSettings] Config saved successfully!")
		loaded = true
		return true
	else:
		print("[ConfigSettings] Failed to save config.")
		return false



func _config_to_dict() -> void:
	for section:String in config.get_sections():
		if section in sections_dict:
			var target_dict:Dictionary = sections_dict[section]
			for key:String in config.get_section_keys(section):
				target_dict[key] = config.get_value(section, key)


func clear_config()->void:
	config_dictionary = {}
	manager_dictionary = {}
	loaded = false
	var dir:DirAccess = DirAccess.open("user://")
	if(dir != null):
		dir.remove("user://config.cfg")
	print("[Config_settings] Config cleared!")
