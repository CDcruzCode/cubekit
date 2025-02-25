extends Node
var root_path:String
var player_res: Dictionary = {}
var player_path:String

func _ready() -> void:
	if(ConfigSettings.loaded):
		root_path = ConfigSettings.config_dictionary.get("root_dir")

func fetch_playerdata(uuid: String) -> Dictionary:
	player_res.clear()
	
	if(ConfigSettings.loaded):
		root_path = ConfigSettings.config_dictionary.get("root_dir")
		player_path = root_path+"/world_management/players/"+uuid+".json"
		print(player_path)
		if(Globals.file_exists(player_path)):
			print("[player_cache] fetching - loading from file player data...")
			var player_file:Dictionary = JSON.parse_string(Globals.load_text_from_file(player_path))
			var player_skin:PackedByteArray = string_to_packedbytearray(player_file["skin"])
			var player_skin_img:Image = Image.new()
			var err: Error = player_skin_img.load_png_from_buffer(player_skin)
			if err == OK:
				player_skin_img.load_png_from_buffer(player_skin)
			else:
				push_error("Failed to load skin image from cache!")
			player_file["skin"] = player_skin_img
			
			var player_face:PackedByteArray = string_to_packedbytearray(player_file["face"])
			var player_face_img:Image = Image.new()
			var err2: Error = player_face_img.load_png_from_buffer(player_face)
			if err2 == OK:
				player_file["face"] = player_face_img
			else:
				push_error("Failed to load face image from cache!")
			return player_file
	
	print("[player_cache] fetching - downloading player data...")
	# Use await to ensure this runs asynchronously
	var url: String = "https://sessionserver.mojang.com/session/minecraft/profile/{0}".format([uuid])
	var http: HTTPClientHelper = HTTPClientHelper.new(self)
	http.threaded = true
	http.download_complete.connect(_on_playerdata_downloaded)
	
	# Start download and wait for it
	http.download(url)
	
	# Wait for the dictionary to be populated
	while player_res.is_empty():
		await get_tree().process_frame
	
	var player_save_res:Dictionary = player_res.duplicate()
	var edit_skin:Image = player_save_res["skin"]
	var edit_skin2:PackedByteArray = edit_skin.save_png_to_buffer()
	player_save_res["skin"] = edit_skin2
	var edit_face:Image = player_save_res["face"]
	var edit_face2:PackedByteArray = edit_face.save_png_to_buffer()
	player_save_res["face"] = edit_face2
	
	Globals.save_file(player_path, JSON.stringify(player_save_res).to_utf8_buffer())
	print(player_res)
	return player_res


func _on_playerdata_downloaded(result: PackedByteArray) -> void:
	var res_dict: Dictionary = JSON.parse_string(result.get_string_from_utf8())
	var img_string: String = res_dict.properties[0].value
	var img_data: Dictionary = JSON.parse_string(Marshalls.base64_to_utf8(img_string))
	var img_url: String = img_data["textures"]["SKIN"]["url"]
	
	# Start image download
	var http: HTTPClientHelper = HTTPClientHelper.new(self)
	http.threaded = true
	http.download_complete.connect(func(texture_buffer: Variant) -> void:
		var img_temp: Image = Image.new()
		var err: Error = img_temp.load_png_from_buffer(texture_buffer)
		if err == OK:
			# Populate player_res dictionary
			player_res = {
				"skin": img_temp,
				"face": extract_face_from_skin(img_temp),
				"name": res_dict["name"],
				"uuid": Globals.format_uuid(res_dict["id"]),
				"op": false
			}
		else:
			print("Failed to load image")
	)
	http.download(img_url)


# Function to extract the face from the skin
func extract_face_from_skin(skin_texture: Image) -> Image:
	var face_image: Image = Image.create_empty(8, 8, false, skin_texture.get_format())
	face_image.blit_rect(skin_texture, Rect2(8, 8, 8, 8), Vector2(0, 0))
	
	#var face_texture: ImageTexture = ImageTexture.create_from_image(face_image)
	return face_image

func string_to_packedbytearray(byte_string: String) -> PackedByteArray:
	# Remove unwanted characters like brackets and spaces
	byte_string = byte_string.strip_edges().replace(" ", "")
	
	# Split the string by commas to get individual byte values
	var byte_values: Array = byte_string.split(",")
	
	# Convert the string array to integers
	var packed_array: PackedByteArray = PackedByteArray()
	for value:String in byte_values:
		packed_array.append(value.to_int())
	
	return packed_array



# Function to get a player's UUID from usercache.json
func get_uuid_from_usercache(file_path: String, username: String) -> Dictionary:
	var file:FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		print("File does not exist: ", file_path)
		return {"error": "usercache.json does not exist."}
	
	var json_data:String = file.get_as_text()
	file.close()
	
	# Parse the JSON
	var parsed_data:Array = JSON.parse_string(json_data)
	if parsed_data == null:
		print("Error parsing JSON")
		return {"error": "Error passing JSON."}
	
	# Search for the username in the cached data
	for player:Dictionary in parsed_data:
		if player["name"].to_lower() == username.to_lower():
			return player
	
	# Username not found
	print("Username not found in usercache.json: ", username)
	return {"error": "Username not found in usercache.json."}



func add_value_to_player(uuid:String, key:String, value:Variant)->void:
	player_path = root_path+"/world_management/players/"+uuid+".json"
	if(!Globals.file_exists(player_path)):
		printerr("[player_cache] Could not add value to player! File does not exist.")
		return
	
	var player:Dictionary = await fetch_playerdata(uuid)
	player[key] = value
	
	var skin:Image = player["skin"]
	player["skin"] = skin.save_png_to_buffer()
	var face:Image = player["face"]
	player["face"] = face.save_png_to_buffer()
	
	Globals.save_file(player_path, JSON.stringify(player).to_utf8_buffer())
