extends PanelContainer

const WHITELIST_PLAYER_CON:PackedScene = preload("res://scenes/main_dashboard/whitelist/whitelist_player_con.tscn")

var root_path:String
var whitelist_arr:Array

@onready var notification_layer_list: VBoxContainer = %notification_layer_list
@onready var start_server: Button = $"../../hbox/start_server"
@onready var player_cache: Node = %player_cache
@onready var whitelist_playerlist: VBoxContainer = $mcon/vbox/scon/whitelist_playerlist
@onready var whitelist_player_name: LineEdit = $mcon/vbox/pcon/vbox/hbox/whitelist_player_name
@onready var whitelist_player_add: Button = $mcon/vbox/pcon/vbox/hbox/whitelist_player_add

func _ready() -> void:
	whitelist_player_add.pressed.connect(_add_to_whitelist)
	whitelist_player_name.text_submitted.connect(_add_to_whitelist.unbind(1))
	
	
	root_path = ConfigSettings.config_dictionary.get("root_dir")
	
	var whitelist_string:String = Globals.load_text_from_file(root_path+"/whitelist.json")
	if(whitelist_string == null || whitelist_string.is_empty()):
		return
	whitelist_arr = JSON.parse_string(whitelist_string)
	print(whitelist_arr)
	
	for user:Dictionary in whitelist_arr:
		print(user)
		await add_whitelist_con(user.uuid)

func add_whitelist_con(uuid:String)->void:
	var res:Dictionary = await player_cache.fetch_playerdata(uuid)
	var con:Node = WHITELIST_PLAYER_CON.instantiate()
	
	var player_skull:TextureRect = con.get_node("vbox/player_skull")
	player_skull.texture = ImageTexture.create_from_image(res.face)
	
	var player_name_con:Label = con.get_node("vbox/vbox/player_name")
	player_name_con.text = res.name
	
	var player_uuid_con:Label = con.get_node("vbox/vbox/uuid_label")
	player_uuid_con.text = res.uuid
	
	var op_button:Button = con.get_node("vbox/op_player_button")
	op_button.whitelist = self
	print("[WHITELIST] ", res.get("op", false))
	if(res.get("op", false)):
		op_button.button_pressed = true
		op_button.text = "Deop player"
	else:
		op_button.button_pressed = false
		op_button.text = "Op player"
	
	var delete_button:Button = con.get_node("vbox/delete_button")
	delete_button.pressed.connect(_delete_player.bind(con, res.name))
	
	whitelist_playerlist.add_child(con)


func _add_to_whitelist()->void:
	whitelist_player_add.disabled = true
	whitelist_player_name.editable = false
	if(whitelist_player_name.text.strip_edges() == ""):
		whitelist_player_add.disabled = false
		whitelist_player_name.editable = true
		return
	
	if(check_name_exists(whitelist_player_name.text.strip_edges())):
		print("name exists")
		Globals.add_notif(notification_layer_list, whitelist_player_name.text.strip_edges() +" already in whitelist!", Color.CORAL)
		whitelist_player_add.disabled = false
		whitelist_player_name.editable = true
		return
	
	var http: HTTPClientHelper = HTTPClientHelper.new(self)
	http.threaded = true
	http.download_complete.connect(func(res: PackedByteArray) -> void:
		var res_dict:Dictionary = JSON.parse_string(res.get_string_from_utf8()) 
		if(res_dict.has("name")):
			res_dict["uuid"] = Globals.format_uuid( res_dict["id"] )
			res_dict.erase("id")
			whitelist_arr.append(res_dict)
			await add_whitelist_con(res_dict["uuid"])
			whitelist_player_name.text = ""
			save_whitelist_file()
			Globals.add_notif(notification_layer_list, res_dict["name"] +" is added to the whitelist!")
			if(start_server.process_io != null):
				start_server.process_io.store_string("/whitelist reload\n")
				start_server.call_deferred("_process_output", "[INTERNAL] /whitelist reload")
		else:
			Globals.add_notif(notification_layer_list, whitelist_player_name.text.strip_edges() +" does not exist! Not added to whitelist.", Color.CORAL)
		whitelist_player_add.disabled = false
		whitelist_player_name.editable = true
	)
	http.download("https://api.mojang.com/users/profiles/minecraft/{0}".format([whitelist_player_name.text.strip_edges()]))


func save_whitelist_file()->void:
	Globals.save_file(root_path+"/whitelist.json", JSON.stringify(whitelist_arr).to_utf8_buffer())


func check_name_exists(target_name: String) -> bool:
	print(whitelist_arr)
	# Iterate through the array and check the "name" field
	for item:Dictionary in whitelist_arr:
		if item.has("name") and item["name"].to_lower() == target_name.to_lower():
			return true
	
	return false


func _delete_player(con:Node, target_name:String)->void:
	var pos:int = 0
	for item:Dictionary in whitelist_arr:
		if item.has("name") and item["name"].to_lower() == target_name.to_lower():
			whitelist_arr.remove_at(pos)
			save_whitelist_file()
			if(start_server.process_io != null):
				start_server.process_io.store_string("/whitelist reload\n")
				start_server.call_deferred("_process_output", "[INTERNAL] /whitelist reload")
			
			
			op_player(item["uuid"], true)
			Globals.add_notif(notification_layer_list, target_name +" deleted from whitelist!")
			con.queue_free()
			return
		
		pos = pos+1


func op_player(uuid:String, force_deop:bool=false)->bool:
	
	var player_data:Dictionary = player_cache.fetch_playerdata(uuid)
	
	if(start_server.process_io != null):
		if(!player_data.get("op", false) && force_deop==false):
			start_server.process_io.store_string("/op "+player_data["name"]+"\n")
			player_cache.add_value_to_player(uuid, "op", true)
			Globals.add_notif(notification_layer_list, player_data["name"] +" has been opped!")
			return true
		else:
			start_server.process_io.store_string("/deop "+player_data["name"]+"\n")
			player_cache.add_value_to_player(uuid, "op", false)
			Globals.add_notif(notification_layer_list, player_data["name"] +" has been de-opped!")
			return false
	
	#The rest of this code is only used if the server is offline.
	var ops_data:Array = []
	
	#No op file found, Op player and add ops.json file.
	if(!Globals.file_exists(root_path+"/ops.json") && force_deop==false):
		var player_op_dict:Dictionary = {
			"uuid": player_data["uuid"],
			"name": player_data["name"],
			"level": 4,
			"bypassesPlayerLimit": false
		}
		ops_data.append(player_op_dict)
		
		Globals.save_file(root_path+"/ops.json", JSON.stringify(ops_data).to_utf8_buffer())
		return true
	
	
	var ops_file:FileAccess = FileAccess.open(root_path+"/ops.json",FileAccess.READ_WRITE)
	if(ops_file == null):
		return false
	
	var player_is_opped:int = -1
	ops_data = JSON.parse_string( ops_file.get_as_text() )
	var count:int = 0
	for player:Dictionary in ops_data:
		print(player)
		if(player["uuid"] == uuid):
			player_is_opped = count
			break
		
		count += 1
	
	if(player_is_opped == -1 && force_deop==false):
		#Player is not opped, need to op now
		var player_op_dict:Dictionary = {
			"uuid": player_data["uuid"],
			"name": player_data["name"],
			"level": 4,
			"bypassesPlayerLimit": false
		}
		ops_data.append(player_op_dict)
		
		player_cache.add_value_to_player(uuid, "op", true)
		Globals.save_file(root_path+"/ops.json", JSON.stringify(ops_data).to_utf8_buffer())
		Globals.add_notif(notification_layer_list, player_data["name"] +" has been opped!")
		return true
	else:
		#Player is opped and needs to be de-opped
		player_cache.add_value_to_player(uuid, "op", false)
		Globals.add_notif(notification_layer_list, player_data["name"] +" has been de-opped!")
		if(force_deop==false):
			ops_data.remove_at(player_is_opped)
			Globals.save_file(root_path+"/ops.json", JSON.stringify(ops_data).to_utf8_buffer())
		return false
