extends PanelContainer

@onready var start_server: Button = %start_server
@onready var active_world: Label = $vbox/active_world
@onready var server_version: Label = $vbox/server_version
@onready var allocated_ram: Label = $vbox/allocated_ram
@onready var server_properties: PanelContainer = %"Server Properties"

func get_ready() -> void:
	start_server.server_start.connect(set_labels)
	await get_tree().process_frame
	set_labels()

func set_labels()->void:
	active_world.text = "Active world: "+server_properties.server_prop_dictionary.get("level-name")
	server_version.text = "Server version: "+ConfigSettings.config_dictionary.get("server_ver")
	allocated_ram.text = "Allocated RAM: "+str(ConfigSettings.manager_dictionary.get("allocated-ram"))+"GB"
