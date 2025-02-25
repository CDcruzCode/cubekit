extends PanelContainer

var process_thread:Thread = null
var process_io:FileAccess = null
var process_err:FileAccess = null
var process_id:int = 0

@onready var ip_label: Label = $hbox/ip_label
@onready var server_properties: PanelContainer = %"Server Properties"
var default_ip:String

func _ready() -> void:
	var root_path:String = ConfigSettings.config_dictionary.get("root_dir")
	if(root_path == null || !Globals.file_exists(root_path.path_join("server.properties"))):
		return
	
	process_thread = Thread.new()
	process_thread.start(get_ip_address, Thread.PRIORITY_HIGH)
	pass

func get_ip_address() -> void:
	var args:PackedStringArray = ["/c", "ipconfig"]
	var info: Dictionary = OS.execute_with_pipe("cmd", args)
	print(args)
	#process = info["process"]
	process_io = info["stdio"]
	process_err = info["stderr"]
	process_id = info["pid"]
	
	var final_output:String = ""
	while process_io.is_open() and process_io.get_error() == OK:
		var output:String = process_io.get_line()
		if output != "":
			#call_deferred("_process_output", output)
			final_output += output+"\n"
		#var err:String = process_err.get_line()
		#if err != "":
			#call_deferred("_process_output", "ERROR: "+err)
		OS.delay_msec(1)  # Delay to avoid busy-waiting
	
	#print(final_output)
	print("DONE TERMINAL")
	#print("IP SELECTED: ", extract_ethernet_ipv4(final_output))
	
	call_deferred("_process_output", final_output)

func _process_output(output:String)->void:
	#print(output)
	default_ip = extract_ethernet_ipv4(output)
	var port:String = server_properties.server_prop_dictionary.get("query.port", 25565)
	ip_label.text = default_ip+":"+port
	pass

func extract_ethernet_ipv4(output: String) -> String:
	var lines:PackedStringArray = output.split("\n")
	var in_ethernet_section:bool = false
	
	for line:String in lines:
		line = line.strip_edges()
		
		# Check for the start of the Ethernet adapter section
		if line.begins_with("Ethernet adapter Ethernet"):
			print("FOUND ETHERNET")
			in_ethernet_section = true
			continue
		
		# Exit the section if we encounter a line without indentation
		#if in_ethernet_section and not line.begins_with(" "):
		#	break
		
		# Look for the IPv4 Address line
		if in_ethernet_section and "IPv4 Address" in line:
			return line.split(":")[1].strip_edges()
	
	return "Could not find the IPv4 address."



func get_default_ipv4() -> String:
	# Get all local addresses
	var addresses:PackedStringArray = IP.get_local_addresses()
	for address:String in addresses:
		# Only include IPv4 addresses
		if is_valid_ipv4(address):
			# Skip localhost (127.0.0.1)
			if not address.begins_with("127."):
				return address
	return "127.0.0.1"  # Fallback to localhost if no valid address is found

func is_valid_ipv4(ip: String) -> bool:
	# Split the IP address into its parts
	var parts:PackedStringArray = ip.split(".")
	if parts.size() != 4:
		return false
	
	for part:String in parts:
		# Check if each part is an integer between 0 and 255
		if not part.is_valid_int():
			return false
		var num:int = int(part)
		if num < 0 or num > 255:
			return false
	
	return true


func debug_all_addresses()->void:
	var addresses:PackedStringArray = IP.get_local_addresses()
	for address:String in addresses:
		print("Address:", address, "IPv4:", is_valid_ipv4(address))
