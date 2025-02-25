extends PanelContainer

const ONLINE_PLAYER_CON:PackedScene = preload("res://scenes/main_dashboard/dashboard/online_player_con.tscn")

@onready var web_socket: Node = %web_socket
@onready var player_cache: Node = %player_cache
@onready var start_server: Button = %start_server
@onready var online_list: VBoxContainer = $vbox/scon/online_list
@onready var timer: Timer = $Timer
@onready var players_online_title: Label = $vbox/players_online_title
@onready var server_properties: PanelContainer = %"Server Properties"

var root_path:String
const frequency:int = 60 #in seconds
var online_arr:Array[Dictionary] = []
var max_players:int = 0

func get_ready()->void:
	start_server.player_joined.connect(_on_player_join)
	start_server.player_left.connect(_on_player_leave)
	start_server.server_stop.connect(_clear_list)
	timer.timeout.connect(_update_players_online)
	timer.wait_time = frequency
	timer.one_shot = false
	timer.start()
	
	root_path = ConfigSettings.config_dictionary.get("root_dir")
	await get_tree().process_frame
	max_players = int(server_properties.server_prop_dictionary.get("max-players"))
	players_online_title.text = "Players online (0/"+str(max_players)+")"
	web_socket.send_all(JSON.stringify({"msg": "online_count", "active": 0, "max": max_players}))

func _update_players_online() -> void:
	if start_server.process_io == null:
		return

	print("Online check...")
	
	# Get the current time once
	var now: int = int(Time.get_unix_time_from_system())
	
	var pos:int = 0
	for line:Dictionary in online_arr:
		if not line.has("join_time"):
			continue
		
		var child:Node = online_list.get_node_or_null(line["name"])
		if(child == null):
			online_arr.remove_at(pos)
			print("[players_online] Could not find node.")
			continue
		
		# Calculate the time difference
		var diff: int = now - int(line["join_time"])
		var time_dict: Dictionary = Time.get_time_dict_from_unix_time(diff)
		
		# Format the time string
		var time_string: String = str(time_dict["minute"]) + "ms"
		if time_dict["hour"] > 0:
			time_string = str(time_dict["hour"]) + "." + str(time_dict["minute"]) + "hs"
		
		# Update the UI
		child.get_node("hbox/time_online").text = time_string
		pos = pos+1
	
	players_online_title.text = "Players online ("+str(online_arr.size())+"/"+str(max_players)+")"
	web_socket.send_all(JSON.stringify({"msg": "online_count", "active": online_arr.size(), "max": max_players}))


func _on_player_join(user:String)->void:
	print("[players_online] PLAYER HAS JOINED ", user)
	var player_data:Dictionary = player_cache.get_uuid_from_usercache(root_path+"/usercache.json", user)
	if(player_data.has("error")):
		print("[players_online] Joining: Could not find player in usercache.json.")
		return
	
	var player_dict:Dictionary = await player_cache.fetch_playerdata(player_data["uuid"])
	var online_con:Control = ONLINE_PLAYER_CON.instantiate()
	var online_name:Label = online_con.get_node("hbox/player_name")
	online_name.text = player_dict["name"]
	var online_time:Label = online_con.get_node("hbox/time_online")
	online_time.text = "0ms"
	var online_skull:TextureRect = online_con.get_node("hbox/player_skull")
	online_skull.texture = ImageTexture.create_from_image(player_dict["face"])
	online_con.name = player_dict["name"]
	online_list.add_child(online_con)
	
	
	online_arr.append({"name": player_dict["name"], "join_time": Time.get_unix_time_from_system()})
	#var player_path:String = root_path + "/world_management/players/"+player_data["uuid"]+".json"
	#var json_data:Dictionary = JSON.parse_string(Globals.load_text_from_file(player_path)) 
	#json_data["join_time"] = Time.get_unix_time_from_system()
	#Globals.save_file(player_path, JSON.stringify(json_data).to_utf8_buffer() )
	players_online_title.text = "Players online ("+str(online_arr.size())+"/"+str(max_players)+")"
	web_socket.send_all(JSON.stringify({"msg": "online_count", "active": online_arr.size(), "max": max_players}))
	web_socket.send_all(JSON.stringify({"msg": "online_players", "players": online_arr}))

func _on_player_leave(user:String)->void:
	print("[players_online] PLAYER HAS LEFT ", user)
	var player_data:Dictionary = player_cache.get_uuid_from_usercache(root_path+"/usercache.json", user)
	if(player_data.has("error")):
		print("[players_online] Leaving: Could not find player in usercache.json.")
		return
	
	var player_con:Control = online_list.get_node_or_null(user)
	if(player_con != null):
		player_con.queue_free()
	
	var pos:int = 0
	for line:Dictionary in online_arr:
		if(line["name"] == user):
			online_arr.remove_at(pos)
			break
		
		pos += 1
	
	players_online_title.text = "Players online ("+str(online_arr.size())+"/"+str(max_players)+")"
	web_socket.send_all(JSON.stringify({"msg": "online_count", "active": online_arr.size(), "max": max_players}))
	web_socket.send_all(JSON.stringify({"msg": "online_players", "players": online_arr}))

func _clear_list()->void:
	for child:Node in online_list.get_children():
		child.queue_free()
	
	players_online_title.text = "Players online (0/"+str(max_players)+")"
	online_arr.clear()
