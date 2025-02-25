extends PanelContainer

var root_path:String
var input_arr:Array[Control] = []

@onready var save_settings: Button = $vbox/hbox/save_settings
@onready var restore_defaults: Button = $vbox/hbox/restore_defaults
@onready var settings_list: VBoxContainer = $vbox/scon/vbox
@onready var notification_layer_list: VBoxContainer = %notification_layer_list


func _ready() -> void:
	if(!ConfigSettings.loaded):
		push_error("[manager_settings] No config file loaded!")
		return
	
	if(!ConfigSettings.config_dictionary || !ConfigSettings.manager_dictionary):
		printerr("[manager_settings] No manager settings found in config. Resetting to defaults.")
		reset_defaults()
	
	save_settings.pressed.connect(save_settings_config)
	restore_defaults.pressed.connect(reset_defaults)
	
	root_path = ConfigSettings.config_dictionary.get("root_dir")
	input_arr.append_array([
		$"vbox/scon/vbox/hbox10/stop-backup",
		$"vbox/scon/vbox/hbox5/auto-backup",
		$"vbox/scon/vbox/hbox/backup-dir",
		$"vbox/scon/vbox/backup-freq",
		$"vbox/scon/vbox/backup-limit",
		$"vbox/scon/vbox/hbox3/enable-schedule",
		$"vbox/scon/vbox/schedule-time",
		$"vbox/scon/vbox/hbox7/allocated-ram",
		$"vbox/scon/vbox/hbox6/auto-restart",
		$"vbox/scon/vbox/hbox8/auto-update",
		$"vbox/scon/vbox/hbox9/auto-startup"
	])
	
	if(ConfigSettings.manager_dictionary.is_empty()):
		#Set default settings
		reset_defaults()
		return
	
	load_from_dict()

func minutes_to_timeframe(total_minutes: int) -> Dictionary:
	return {
		"hours": int(float(total_minutes) / 60.0),
		"minutes": total_minutes % 60
	}

func timeframe_to_minutes(hours:int, minutes:int) -> int:
	return (hours*60) + minutes

func reset_defaults()->void:
	for input:Control in input_arr:
		var value:Variant = null
		
		match(input.name):
			"stop-backup", "auto-backup":
				value = true
				input = input as CheckButton
				input.button_pressed = value
			"enable-schedule", "auto-restart", "auto-update", "auto-startup":
				value = false
				input = input as CheckButton
				input.button_pressed = value
			"backup-dir":
				value = root_path+"/world_management/backups"
				input = input as Button
				input.text = Globals.get_drive_and_last_two_folders(value)
				input.set_meta("dir", value)
			"backup-freq":
				value = {"amount": 30, "time_unit": "minutes"}
				var amount_node:SpinBox = input.get_node("num") as SpinBox
				var time_unit_node:OptionButton = input.get_node("time_unit") as OptionButton
				amount_node.value = value["amount"]
				Globals.set_option_button(time_unit_node, value["time_unit"])
			"backup-limit":
				value = 10
				var amount_node:SpinBox = input.get_node("num") as SpinBox
				amount_node.value = value
			"schedule-time":
				value = {"start-time": 0, "end-time": 0} #In seconds in unix time. Convert to proper time when setting value
				var start_hr:SpinBox = input.get_node("start-time/hrs") as SpinBox
				var start_min:SpinBox = input.get_node("start-time/mins") as SpinBox
				var end_hr:SpinBox = input.get_node("end-time/hrs") as SpinBox
				var end_min:SpinBox = input.get_node("end-time/mins") as SpinBox
				
				var start_time:Dictionary = minutes_to_timeframe(value["start-time"])
				var end_time:Dictionary = minutes_to_timeframe(value["end-time"])
				start_hr.value = start_time["hours"]
				start_min.value = start_time["minutes"]
				
				end_hr.value = end_time["hours"]
				end_min.value = end_time["minutes"]
			"allocated-ram":
				value = 4
				input = input as SpinBox
				input.value = value
		
		ConfigSettings.manager_dictionary[input.name] = value
	ConfigSettings.save_config()
	Globals.add_notif(notification_layer_list, "Manager settings reset to defaults!")

func load_from_dict()->void:
	for input_name:String in ConfigSettings.manager_dictionary:
		var value:Variant = ConfigSettings.manager_dictionary[input_name]
		var input:Control = Globals.find_node_by_name(input_name, settings_list)
		
		match(input_name):
			"stop-backup":
				input = input as CheckButton
				input.button_pressed = value
			"auto-backup":
				input = input as CheckButton
				input.button_pressed = value
			"backup-dir":
				input = input as Button
				input.text = Globals.get_drive_and_last_two_folders(value)
				input.set_meta("dir", value)
			"backup-freq":
				var amount_node:SpinBox = input.get_node("num") as SpinBox
				var time_unit_node:OptionButton = input.get_node("time_unit") as OptionButton
				amount_node.value = value["amount"]
				Globals.set_option_button(time_unit_node, value["time_unit"])
			"backup-limit":
				var amount_node:SpinBox = input.get_node("num") as SpinBox
				amount_node.value = value if value != null else 1
			"enable-schedule":
				input = input as CheckButton
				input.button_pressed = value
			"schedule-time":
				var start_hr:SpinBox = input.get_node("start-time/hrs") as SpinBox
				var start_min:SpinBox = input.get_node("start-time/mins") as SpinBox
				var end_hr:SpinBox = input.get_node("end-time/hrs") as SpinBox
				var end_min:SpinBox = input.get_node("end-time/mins") as SpinBox
				
				var start_time:Dictionary = minutes_to_timeframe(value["start-time"])
				var end_time:Dictionary = minutes_to_timeframe(value["end-time"])
				start_hr.value = start_time["hours"]
				start_min.value = start_time["minutes"]
				
				end_hr.value = end_time["hours"]
				end_min.value = end_time["minutes"]
			"allocated-ram":
				input = input as SpinBox
				input.value = value
			"auto-restart":
				input = input as CheckButton
				input.button_pressed = value
			"auto-update":
				input = input as CheckButton
				input.button_pressed = value
			"auto-startup":
				input = input as CheckButton
				input.button_pressed = value



func save_settings_config()->void:
	for input:Control in input_arr:
		var value:Variant = null
		
		match(input.name):
			"stop-backup":
				input = input as CheckButton
				value = input.button_pressed
			"auto-backup":
				input = input as CheckButton
				value = input.button_pressed
			"backup-dir":
				print(input.get_meta("dir", value))
				value = input.get_meta("dir", value)
			"backup-freq":
				var backup_dict:Dictionary = {}
				var amount_node:SpinBox = input.get_node("num") as SpinBox
				var time_unit_node:OptionButton = input.get_node("time_unit") as OptionButton
				backup_dict["amount"] = int(amount_node.value)
				backup_dict["time_unit"] = time_unit_node.get_item_text(time_unit_node.selected)
				value = backup_dict
			"backup-limit":
				var amount_node:SpinBox = input.get_node("num") as SpinBox
				value = int(amount_node.value)
			"enable-schedule":
				input = input as CheckButton
				value = input.button_pressed
				if(value == true && %uptime_timer.is_stopped()):
					print("[manager_settings] Starting uptime timer.")
					%uptime_timer.start()
			"schedule-time":
				var schedule_time_dict:Dictionary = {}
				var start_hr:SpinBox = input.get_node("start-time/hrs") as SpinBox
				var start_min:SpinBox = input.get_node("start-time/mins") as SpinBox
				var end_hr:SpinBox = input.get_node("end-time/hrs") as SpinBox
				var end_min:SpinBox = input.get_node("end-time/mins") as SpinBox
				
				schedule_time_dict["start-time"] = timeframe_to_minutes(int(start_hr.value), int(start_min.value))
				schedule_time_dict["end-time"] = timeframe_to_minutes(int(end_hr.value), int(end_min.value))
				
				%uptime_schedule.start_time = schedule_time_dict["start-time"]
				%uptime_schedule.end_time = schedule_time_dict["end-time"]
				
				value = schedule_time_dict
			"allocated-ram":
				input = input as SpinBox
				value = input.value
			"auto-restart":
				input = input as CheckButton
				value = input.button_pressed
			"auto-update":
				input = input as CheckButton
				value = input.button_pressed
			"auto-startup":
				input = input as CheckButton
				value = input.button_pressed
				set_launch_at_startup(value)
		
		ConfigSettings.manager_dictionary[input.name] = value
	ConfigSettings.save_config()
	
	%update_checker._ready()
	Globals.add_notif(notification_layer_list, "Manager settings saved!")



####
#AUTO START UP CODE
####

func set_launch_at_startup(enabled: bool) -> void:
	var os_name:String = OS.get_name()

	match os_name:
		"Windows":
			set_launch_at_startup_windows(enabled)
		"X11":  # Linux
			set_launch_at_startup_linux(enabled)
		"OSX":
			set_launch_at_startup_macos(enabled)
		_:
			push_error("[Manager Settings - Auto Launch] Unsupported OS")


func set_launch_at_startup_windows(enabled: bool) -> void:
	var exe_path:String = OS.get_executable_path().replace("/", "\\")  # Use Windows-style paths
	var key_name:String = "Cubekit"
	var reg_cmd:String = "reg"
	var args:PackedStringArray = []

	if enabled:
		args = ["add", "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run", "/v", key_name, "/t", "REG_SZ", "/d", exe_path, "/f"]
	else:
		args = ["delete", "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run", "/v", key_name, "/f"]

	var exit_code:int = OS.execute(reg_cmd, args)
	print("Attempted setting autoload: ", exit_code)



func set_launch_at_startup_linux(enabled: bool) -> void:
	var autostart_dir:String = OS.get_environment("HOME") + "/.config/autostart"
	var desktop_file:String = autostart_dir + "/Cubekit.desktop"
	var exe_path:String = OS.get_executable_path()
	var dir:DirAccess

	if enabled:
		# Escape spaces in the executable path
		var escaped_exe_path:String = exe_path.replace(" ", "\\ ")
		var desktop_content:String = """
			[Desktop Entry]
			Type=Application
			Name=Cubekit
			Exec=%s
			Terminal=false
			""" % escaped_exe_path

		dir.make_dir_recursive(autostart_dir)
		var file:FileAccess = FileAccess.open(desktop_file, FileAccess.WRITE)
		if FileAccess.get_open_error() == OK:
			file.store_string(desktop_content)
			file.close()
	else:
		if dir && dir.file_exists(desktop_file):
			dir.remove(desktop_file)


func set_launch_at_startup_macos(enabled: bool) -> void:
	var exe_path:String = OS.get_executable_path()
	var args:PackedStringArray = []

	if enabled:
		args = ["-e", 'tell application "System Events" to make login item at end with properties {path: "%s", hidden: false}' % exe_path]
	else:
		args = ["-e", 'tell application "System Events" to delete login item "Cubekit"']

	OS.execute("osascript", args)
