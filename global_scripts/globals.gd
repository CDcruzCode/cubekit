extends Node

const NOTICE_POPUP:PackedScene = preload("res://scenes/general/notice_popup.tscn")

func get_pc_ip() -> String:
	# Get the local IP addresses
	var local_ips:PackedStringArray = IP.get_local_addresses()
	
	# Find the first non-loopback IP
	for ip:String in local_ips:
		if ip != "127.0.0.1" and "." in ip:  # Ignore the loopback address
			return ip
	
	# Return a fallback message if no valid IP is found
	return "No valid IP found"


func get_drive_and_last_two_folders(full_path: String) -> String:
	var path_parts:PackedStringArray = full_path.replace("\\", "/").split("/")
	if path_parts.size() < 4:
		return full_path  # Not enough parts to extract two folders
	
	var drive:String = path_parts[0]
	var folder1:String = path_parts[path_parts.size() - 2]
	var folder2:String = path_parts[path_parts.size() - 1]
	
	return drive + "/.../" + folder1 + "/" + folder2

func dir_exists(path: String) -> bool:
	# Check if the directory exists
	if DirAccess.open(path) == null:
		return false
	return true

func file_exists(path: String) -> bool:
	if(OS.has_feature("editor")):
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file:
			file.close()
			return true
		return false
	else:
		if(path.get_extension() in ["png", "svg", "ttf"]):
			if(ResourceLoader.exists(path)):
				return true
			else:
				return false
		else:
			var file: FileAccess = FileAccess.open(path, FileAccess.READ)
			if file:
				file.close()
				return true
			return false

#func resolve_path(path:String)->String:
	#if OS.has_feature("editor"):
		## Running from an editor binary.
		## `path` will contain the absolute path to `hello.txt` located in the project root.
		#if(path.begins_with("res://")):
			#path = ProjectSettings.globalize_path(path)
	#else:
		## Running from an exported project.
		## `path` will contain the absolute path to `hello.txt` next to the executable.
		## This is *not* identical to using `ProjectSettings.globalize_path()` with a `res://` path,
		## but is close enough in spirit.
		#if(path.get_extension() in ["png"]):
			#path = path+".import"
		##path = OS.get_executable_path().get_base_dir().path_join(path.trim_prefix("res://").replace("//", "/"))
	#
	#return path

func load_resource(path: String) -> PackedByteArray:
	#Only required for exported projects. Loads internal res:// files as Resources and returns the file as a PackedByteArray.
	var extension:String = path.get_extension().to_lower()
	var type:String = ""
	match extension:
		"png":
			type = "Texture"
		"ttf":
			type = "Font"
		_:
			print("Unsupported resource type")
			return []

	var resource:Resource = ResourceLoader.load(path, type)
	print("RESOURCE TYPE: ", resource.get_class())
	if resource:
		match extension:
			"png":
				if resource is Texture2D:
					var img:Image = resource.get_image()
					return img.save_png_to_buffer()
				elif resource is Image:
					return resource.save_png_to_buffer()
			"ttf":
				if resource is FontFile:
					return resource.data
			_:
				print("Unsupported resource type")
				return []
		return []
	else:
		print("Failed to load resource at %s" % path)
		return []


func create_directory(path: String) -> bool:
	# Check if the directory already exists
	if DirAccess.open(path) != null:
		return true  # Directory already exists
	
	# Attempt to create the directory
	var result:Error = DirAccess.make_dir_absolute(path)
	if result == OK:
		print("[create_directory] Directory created: "+path)
		return true  # Successfully created the directory
	
	# Failed to create the directory
	push_error("[create_directory] Failed to create dir for: "+path)
	return false

func list_folders_in_directory(directory_path: String) -> PackedStringArray:
	var dir:DirAccess= DirAccess.open(directory_path)
	var folder_list: PackedStringArray = []
	
	if DirAccess.get_open_error() == OK:
		dir.list_dir_begin()  # Start listing directory contents
		while true:
			var file_or_folder:String = dir.get_next()
			if file_or_folder == "":
				break  # No more files or folders
			if dir.current_is_dir() and file_or_folder != "." and file_or_folder != "..":
				folder_list.append(file_or_folder)
		dir.list_dir_end()  # Clean up
	else:
		push_error("Failed to open directory: " + directory_path)
	
	return folder_list

func deep_copy_dir(source_path:String, dest_path:String)->bool:
	var source_dir:DirAccess = DirAccess.open(source_path)
	var dest_dir:DirAccess = DirAccess.open(dest_path)
	#var source_end:String = source_path.get_slice("/", source_path.get_slice_count("/")-1)
	var source_end:String = source_path.get_file()
	
	if(!dir_exists(source_path)):
		push_error("Source dir does not exist! ", source_path )
		return false
	
	# Open the source directory
	if (source_end.contains(".") ) && DirAccess.get_open_error() != OK:
		push_error("\nFailed to open source directory: " + source_path, "\nError: ", error_string(DirAccess.get_open_error() ))
		return false
	
	var new_dest_path:String = dest_path+"/"+source_end
	#print(new_dest_path)
	# Ensure the destination directory exists
	if DirAccess.get_open_error() == OK:
		var make_dir_err:Error = dest_dir.make_dir(new_dest_path)
		if make_dir_err != OK && make_dir_err != ERR_ALREADY_EXISTS:
			push_error("\nFailed to make destination directory: " + dest_path, "\nError: ", error_string(make_dir_err))
			return false
	else:
		push_error("\nFailed to open destination directory! ", dest_path)
		return false
	
	source_dir.list_dir_begin()  # Begin listing the directory
	while true:
		var item:String = source_dir.get_next()
		if item == "":
			break  # No more items
		
		if item == "." or item == "..":
			continue  # Skip special directories
		
		var source_item_path:String = source_path + "/" + item
		var dest_item_path:String = new_dest_path
		
		#print("Coping: ", source_item_path)
		
		if source_dir.current_is_dir():
			# Recursively copy subdirectories
			if not deep_copy_dir(source_item_path, dest_item_path):
				return false
		else:
			# Copy files
			var file:FileAccess = FileAccess.open(source_item_path, FileAccess.READ)
			if FileAccess.get_open_error() != OK:
				push_error("Failed to open file: " + source_item_path)
				return false
			var data:PackedByteArray = file.get_buffer(file.get_length())
			file.close()
			
			file = FileAccess.open(dest_item_path + "/" + item, FileAccess.WRITE)
			if FileAccess.get_open_error() != OK:
				push_error("Failed to create file: " + dest_item_path+ "/" + item)
				return false
			file.store_buffer(data)
			file.close()
	
	source_dir.list_dir_end()  # Clean up
	return true

func deep_remove_dir(dir_path: String) -> bool:
	"""
	Recursively removes a directory and all its contents.
	
	:param dir_path: The path of the directory to remove.
	:return: `true` if successful, `false` otherwise.
	"""
	if( !dir_exists(dir_path) ):
		push_error("Directory does not exist: " + dir_path)
		return false
	
	var dir:DirAccess = DirAccess.open(dir_path)
	
	# Attempt to open the directory
	if DirAccess.get_open_error() != OK:
		push_error("Failed to open directory: " + dir_path)
		return false
	
	# Ensure the directory is empty before deletion
	if dir.list_dir_begin() != OK:
		push_error("Failed to begin listing directory: " + dir_path)
		return false
	
	while true:
		var item_name:String = dir.get_next()
		
		# Break if no more items
		if item_name == "":
			break
		
		# Skip special directories
		if item_name == "." or item_name == "..":
			continue
		
		var item_path:String = dir_path + "/" + item_name
		
		# Check if the item is a directory or file
		if dir.current_is_dir():
			# Recursively remove subdirectory
			if not deep_remove_dir(item_path):
				dir.list_dir_end()
				return false
		else:
			# Remove file
			if dir.remove(item_path) != OK:
				push_error("Failed to remove file: " + item_path)
				dir.list_dir_end()
				return false
	
	# End listing
	dir.list_dir_end()
	
	# Finally, remove the empty directory
	if dir.remove(dir_path) != OK:
		push_error("Failed to remove directory: " + dir_path)
		return false
	
	return true

func save_file(filepath:String, content:PackedByteArray)->bool:
	var file:FileAccess = FileAccess.open(filepath, FileAccess.WRITE);
	if file != null:
		file.store_buffer(content)
		file = null
		return true
	else:
		return false

func load_text_from_file(file_path: String) -> String:
	var file:FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var content:String = file.get_as_text()
		file.close()
		return content
	else:
		push_error("Failed to open file: " + file_path)
		return ""


func find_node_by_name(node_name: String, root: Node) -> Node:
	for child:Node in root.get_children():
		if child.name == node_name:
			return child
		var found:Node = find_node_by_name(node_name, child)
		if found:
			return found
	return null

func to_bool(st: String) -> bool:
	var lower_str:String = st.to_lower()
	return lower_str == "true" # Returns true for "true", false for anything else

func set_option_button(button:OptionButton, value:String)->void:
	for i:int in button.item_count:
		if(button.get_item_text(i).to_lower() == value.to_lower()):
			button.select(i)
			return

func delay(time:float)->void:
	await get_tree().create_timer(time).timeout

func add_notif(parent:Node, message:String, msg_color:Color=Color.LIME_GREEN)->void:
	var popup:Node = NOTICE_POPUP.instantiate()
	popup.message = message
	popup.msg_color = msg_color
	parent.add_child(popup)


func format_uuid(uuid_string: String) -> String:
	# Ensure the input string has the correct length for a UUID
	if uuid_string.length() != 32:
		print("Invalid UUID string length: ", uuid_string.length())
		return ""

	# Insert hyphens at the appropriate positions
	var formatted_uuid:String = uuid_string.substr(0, 8) + "-" + uuid_string.substr(8, 4) + "-" +uuid_string.substr(12, 4) + "-" +uuid_string.substr(16, 4) + "-" +uuid_string.substr(20, 12)
	return formatted_uuid


func remove_all_children(parent_node: Node) -> void:
	"""
	Removes all children from the specified parent node.
	
	:param parent_node: The node whose children will be removed.
	"""
	while parent_node.get_child_count() > 0:
		var child:Node = parent_node.get_child(0)
		parent_node.remove_child(child)
		child.queue_free()


func load_image_texture(path: String) -> Texture2D:
	var image:Image = Image.new()
	var error:Error = image.load(path)
	
	if error != OK:
		push_error("[load_image_texture] Failed to load image: %s" % path)
		return null
	
	return ImageTexture.create_from_image(image)
