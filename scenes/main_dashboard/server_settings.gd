extends PanelContainer

var root_path:String
var server_prop_dictionary:Dictionary
@onready var settings_node_list: VBoxContainer = $vbox/scon/vbox
@onready var notification_layer_list: VBoxContainer = %notification_layer_list
@onready var save_server_properties: Button = $vbox/HBoxContainer/save_server_properties
@onready var reset_default_settings: Button = $vbox/HBoxContainer/reset_default_settings

var input_arr:Array[Node] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	root_path = ConfigSettings.config_dictionary.get("root_dir")
	server_prop_dictionary = parse_server_properties(Globals.load_text_from_file(root_path + "/server.properties"))
	save_server_properties.pressed.connect(save_server_props)
	reset_default_settings.pressed.connect(default_settings)
	
	if(Globals.file_exists(root_path.path_join("server.properties"))):
		load_server_properties()
	else:
		printerr("SERVER PROPERTIES DOES NOT EXIST")

func load_server_properties()->void:
	for prop:String in server_prop_dictionary:
		#print(prop)
		var prop_input:Control = Globals.find_node_by_name(prop.replace(".", "+"), settings_node_list)
		var prop_value:String = server_prop_dictionary[prop]
		if(prop_input != null):
			if(!prop_input.visible):
				continue #Keep hidden inputs out of the list.
			
			match(prop_input.get_class()):
				"CheckButton":
					prop_input = prop_input as CheckButton
					prop_input.button_pressed = Globals.to_bool(prop_value)
					input_arr.append(prop_input)
				"OptionButton":
					prop_input = prop_input as OptionButton
					#prop_input.selected = prop_input.get_item_index()
					Globals.set_option_button(prop_input, prop_value)
					input_arr.append(prop_input)
				"SpinBox":
					prop_input = prop_input as SpinBox
					prop_input.value = prop_value.to_int()
					input_arr.append(prop_input)
				"LineEdit":
					prop_input = prop_input as LineEdit
					prop_input.text = prop_value
					input_arr.append(prop_input)
				_:
					print( prop_input.get_class() )
					pass


func parse_server_properties(text: String) -> Dictionary:
	var properties:Dictionary = {}
	var lines:PackedStringArray = text.split("\n")
	
	for line:String in lines:
		line = line.strip_edges()  # Remove leading/trailing whitespace
		# Skip comments and empty lines
		if line.begins_with("#") or line == "":
			continue
		
		# Split key and value
		var split_index:int = line.find("=")
		if split_index != -1:
			var key:String = line.substr(0, split_index).strip_edges()
			var value:String = line.substr(split_index + 1).strip_edges()
			properties[key] = value
	
	return properties


func save_server_props()->void:
	for input:Node in input_arr:
		if(server_prop_dictionary.has(input.name)):
			match(input.get_class()):
				"CheckButton":
					input = input as CheckButton
					server_prop_dictionary[input.name] = str(input.button_pressed)
				"OptionButton":
					input = input as OptionButton
					server_prop_dictionary[input.name] = input.get_item_text(input.selected)
				"SpinBox":
					input = input as SpinBox
					server_prop_dictionary[input.name] = input.value
				"LineEdit":
					input = input as LineEdit
					server_prop_dictionary[input.name] = input.text
				_:
					print( "[save_server_props] "+input.name + " not valid input!" )
					pass
	
	write_server_properties(root_path+"/server.properties", server_prop_dictionary)

func write_server_properties(file_path: String, properties: Dictionary) -> void:
	var file:FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if(file == null):
		push_error(FileAccess.get_open_error())
		Globals.add_notif(notification_layer_list, "Failed to save server properties!", Color.CORAL)
		return
	
	if(!file.is_open()):
		print(file.get_error())
		push_error("[SERVER SETTINGS] Unable to save server properties.")
		Globals.add_notif(notification_layer_list, "Failed to save server properties!", Color.CORAL)
		return
	
	# Add a comment header if needed
	file.store_line("#Minecraft server properties")
	file.store_line("#" + get_formatted_time())
	
	for key:String in properties.keys():
		file.store_line("%s=%s" % [key, str(properties[key])])
	
	file.close()
	Globals.add_notif(notification_layer_list, "Server properties saved!")


func default_settings()->void:
	var active_world:String = server_prop_dictionary["level-name"]
	server_prop_dictionary = parse_server_properties(Globals.load_text_from_file("res://scenes/main_dashboard/server.txt"))
	server_prop_dictionary["level-name"] = active_world
	load_server_properties()
	write_server_properties(root_path + "/server.properties", server_prop_dictionary)
	print("Set to default settings!")
	Globals.add_notif(notification_layer_list, "Server properties reset to default settings!")


func get_formatted_time() -> String:
	var datetime:Dictionary = Time.get_datetime_dict_from_system() # Get current date and time
	var days:PackedStringArray = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
	var months:PackedStringArray = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	
	# Extract components
	var day_of_week:String = days[datetime.weekday]  # Weekday (0=Sunday, 6=Saturday)
	var month:String = months[datetime.month - 1]   # Month (1=January, so subtract 1 for index)
	var day:String = str(datetime.day)              # Day of the month
	var hour:String = str(datetime.hour).pad_zeros(2)   # Hour (2-digit)
	var minute:String = str(datetime.minute).pad_zeros(2) # Minute (2-digit)
	var second:String = str(datetime.second).pad_zeros(2) # Second (2-digit)
	var year:String = str(datetime.year)            # Year
	
	# Get the timezone abbreviation (custom implementation needed)
	var timezone:String = "AEST"  # Replace this with your desired time zone abbreviation
	
	# Format the string
	return "%s %s %s %s:%s:%s %s %s" % [day_of_week, month, day, hour, minute, second, timezone, year]
