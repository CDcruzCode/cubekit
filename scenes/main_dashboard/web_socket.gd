extends Node
@onready var web_server: Node = %web_server
@onready var start_server: Button = %start_server
@onready var notification_layer_list: VBoxContainer = %notification_layer_list

# The port we will listen to
var PORT: int = 9080
# Our WebSocketServer instance
var _server: WebSocketServer = WebSocketServer.new()

var peer_connections:PackedInt32Array = []


func _exit_tree()->void:
	if _server.tcp_server.is_listening():
		_server.stop()

func _ready()->void:
	PORT = web_server.tcp_port + 1
	
	# Connect base signals to get notified of new client connections,
	# disconnections, and disconnect requests.
	_server.client_connected.connect(_connected)
	_server.client_disconnected.connect(_disconnected)
	#_server.client_close_request.connect(_close_request)
	# This signal is emitted when not using the Multiplayer API every time a
	# full packet is received.
	# Alternatively, you could check get_peer(PEER_ID).get_available_packets()
	# in a loop for each connected peer.
	_server.message_received.connect(_on_data)
	# Start listening on the given port.
	var err:Error = _server.listen(PORT) as Error
	if err != OK:
		print("[web socket] Unable to start server: ", error_string(err))
		set_process(false)
		return
	
	print("[web_socket] Web socket starting...")
	
	start_server.server_start.connect(send_all.bind(JSON.stringify({"msg": "server_started"})))
	start_server.server_stop.connect(send_all.bind(JSON.stringify({"msg": "server_stopped"})))


func reload_web_socket()->void:
	print("[web_socket] Reloading web socket...")
	set_process(true)
	if _server.tcp_server.is_listening():
		_server.stop()
	
	if( start_server.is_connected("server_start", send_all.bind(JSON.stringify({"msg": "server_started"}))) ):
		start_server.disconnect("server_start", send_all.bind(JSON.stringify({"msg": "server_started"})))
	
	if( start_server.is_connected("server_stop", send_all.bind(JSON.stringify({"msg": "server_stopped"}))) ):
		start_server.disconnect("server_stop", send_all.bind(JSON.stringify({"msg": "server_stopped"})))
	
	_server = WebSocketServer.new()
	_ready()


func _connected(id:int, proto:Variant=null)->void:
	# This is called when a new peer connects, "id" will be the assigned peer id,
	# "proto" will be the selected WebSocket sub-protocol (which is optional)
	print("Client %d connected with protocol: %s" % [id, proto])
	if(!peer_connections.has(id)):
		peer_connections.append(id)
	
	_server.send(id, "You have connected! Hello world.")
	
	var process_on:bool = false
	if(%start_server.process_io != null):
		process_on = true
	
	_server.send(id, JSON.stringify({
		"msg": "init",
		"data": {
			"server_on": process_on,
			"default_ip": $"../../mcon/vbox/tcon/Dashboard/vbox/hbox/vbox/ip_address".default_ip,
			"port": %"Server Properties".server_prop_dictionary["server-port"]
		}
	}))

func _close_request(id:int, code:int, reason:String)->void:
	# This is called when a client notifies that it wishes to close the connection,
	# providing a reason string and close code.
	print("Client %d disconnecting with code: %d, reason: %s" % [id, code, reason])
	if(peer_connections.has(id)):
		peer_connections.remove_at(peer_connections.find(id))

func _disconnected(id:int, was_clean:bool = false)->void:
	# This is called when a client disconnects, "id" will be the one of the
	# disconnecting client, "was_clean" will tell you if the disconnection
	# was correctly notified by the remote peer before closing the socket.
	print("Client %d disconnected, clean: %s" % [id, str(was_clean)])
	if(peer_connections.has(id)):
		peer_connections.remove_at(peer_connections.find(id))

func _on_data(id:int, msg:String)->void:
	# Print the received packet, you MUST always use get_peer(id).get_packet to receive data,
	# and not get_packet directly when not using the MultiplayerAPI.
	#var pkt:PackedByteArray = _server.get_peer(id).get_packet()
	#print("Got data from client %d: %s ... echoing" % [id, msg])
	#print(msg)
	#_server.get_peer(id).put_packet(pkt)
	parse_incoming_data(id, msg)

func _process(_delta:float)->void:
	# Call this in _process or _physics_process.
	# Data transfer, and signals emission will only happen when calling this function.
	_server.poll()


func parse_incoming_data(id:int, msg:String)->void:
	var msg_dict:Dictionary = JSON.parse_string(msg)
	
	if(msg_dict["type"] != "ping"):
		print("Got data from client %d: %s ... echoing" % [id, msg])
	
	match msg_dict["type"]:
		"ping":
			_server.send(id, "pong")
		"command":
			match msg_dict["msg"]:
				"startserver":
					print("[web socket] Start server request")
					start_server.call_deferred("_server_start")
					_server.send(id, "server_starting")
				"stopserver":
					print("[web socket] Stop server request")
					start_server.call_deferred("_server_stop")
					_server.send(id, "server_stopping")
		"console_com":
			start_server._console_input(msg_dict["msg"])
		_:
			push_error("[web socket] Received invalid message type from peer: "+msg_dict["type"]+" // "+msg_dict["msg"])

func send_all(msg:String)->void:
	if(peer_connections.size() == 0):
		return
	
	for peer:int in peer_connections:
		_server.send(peer, msg)
