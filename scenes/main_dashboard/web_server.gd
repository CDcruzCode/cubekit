extends Node
@onready var notification_layer_list: VBoxContainer = %notification_layer_list
@onready var refresh_web_server: Button = $"../mcon/vbox/hbox/refresh_web_server"
@onready var web_server_port: SpinBox = $"../mcon/vbox/hbox/web_server_port"
@onready var web_socket: Node = %web_socket

var tcp_server: TCPServer = TCPServer.new()
var tcp_port: int = 8081
var web_root: String = "res://web/"

var tcp_thread:Thread
var tcp_loop:bool = false

@onready var start_server: Button = %start_server

func get_ready() -> void:
	web_server_port.value = tcp_port
	web_server_port.value_changed.connect(func(val:float)->void: tcp_port = int(val) )
	refresh_web_server.pressed.connect(reload_web_server)
	
	var err: Error = tcp_server.listen(tcp_port)
	print("[web server] Ready error: " + error_string(err) )
	print("[web server] Server is listening on http://127.0.0.1:%d" % tcp_port)
	
	if(err != OK):
		Globals.add_notif(notification_layer_list, "Failed to launch web server on port "+str(tcp_port)+": "+ error_string(err), Color.CORAL)
		return
	
	tcp_thread = Thread.new()
	tcp_loop = true
	tcp_thread.start(_process_server)
	Globals.add_notif(notification_layer_list, "Web server started on http://127.0.0.1:%d\nUse the default IP if accessing from another device on the same network." % tcp_port)

func reload_web_server()->void:
	if tcp_thread != null:
		tcp_server.stop()
		tcp_loop = false
		await tcp_thread.wait_to_finish()
		tcp_thread = null
	
	var err: Error = tcp_server.listen(tcp_port)
	print("[web server] Ready error: " + error_string(err) )
	print("[web server] Server is listening on http://127.0.0.1:%d" % tcp_port)
	
	if(err != OK):
		Globals.add_notif(notification_layer_list, "Failed to launch web server on port "+str(tcp_port)+": "+ error_string(err), Color.CORAL)
		return
	
	tcp_thread = Thread.new()
	tcp_loop = true
	tcp_thread.start(_process_server)
	web_socket.reload_web_socket()
	Globals.add_notif(notification_layer_list, "Web server started on http://127.0.0.1:%d" % tcp_port)


func _exit_tree()->void:
	if tcp_thread:
		tcp_loop = false
		tcp_thread.wait_to_finish()
		tcp_thread = null

func _process_server() -> void:
	while(tcp_loop):
		if tcp_server.is_connection_available():
			var connection: StreamPeerTCP = tcp_server.take_connection()
			if connection:
				handle_request(connection)
		
		OS.delay_msec(100)

func handle_request(connection: StreamPeerTCP) -> void:
	var request_data: String = connection.get_utf8_string(connection.get_available_bytes())
	#print(request_data)
	if request_data.is_empty():
		connection.disconnect_from_host()
		return

	var request_line: String = request_data.split("\r\n")[0]
	var request_parts: PackedStringArray = request_line.split(" ")
	if request_parts.size() < 2:
		send_response(connection, 400, "Bad Request", "Malformed request")
		return

	var method: String = request_parts[0]
	var path: String = request_parts[1]
	
	#print("Method: " + method)
	#print("Path: " + path)
	
	if method != "GET" && method != "POST":
		send_response(connection, 405, "Method Not Allowed", "Only GET requests are supported")
		return
	
	if(method == "POST"):
		print("[web server] Post request: "+path)
		#handle_post_request(connection, path)
		return
	#ELSE Get request
	
	if path == "/":
		path = "/index.html"
	
	var file_path: String = web_root + path
	
	print("[web_server] Attempt to server file: ", file_path)
	#file_path = Globals.resolve_path(file_path)
	#print("[web_server] Attempt globalize path: ", file_path)
	if Globals.file_exists(file_path):
		print("[web_server] file exists")
		#send_response(connection, 200, "Success", "Testing request..")
		serve_file(connection, file_path)
	else:
		send_response(connection, 404, "Not Found", "File not found")

func serve_file(connection: StreamPeerTCP, file_path: String) -> void:
	#print("[web server] Serving file...")
	#print("[web server] is connected: ", connection.get_status())
	var response_body: PackedByteArray
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	
	if not file:
		if(OS.has_feature("editor")):
			send_response(connection, 500, "Internal Server Error", "Unable to open file")
			return
		else:
			response_body = Globals.load_resource(file_path)
	else:
		response_body = FileAccess.get_file_as_bytes(file_path)
		file.close()
	
	#response_body = "<html><body>Hello, World!</body></html>"
	
	var content_type: String = get_content_type(file_path)
	var response_headers: String = "HTTP/1.1 200 OK\r\nContent-Type: %s\r\nContent-Length: %d\r\n\r\n" % [content_type, response_body.size()]
	#print(response_headers + response_body)
	#print("[web server] response body size: " + str(response_body.size()))
	#connection.put_utf8_string(response_headers + response_body)
	var response_arr:PackedByteArray = response_headers.to_utf8_buffer()
	response_arr.append_array(response_body)
	var _err:Error = connection.put_data( response_arr )
	#print( error_string(err) )
	connection.disconnect_from_host()

func send_response(connection: StreamPeerTCP, response_code: int, response_message: String, response_body: String) -> void:
	var response_headers: String = "HTTP/1.1 %d %s\r\nContent-Type: text/plain\r\nContent-Length: %d\r\n\r\n" % [response_code, response_message, response_body.length()]
	
	connection.put_data((response_headers + response_body).to_utf8_buffer())
	connection.disconnect_from_host()

#func handle_post_request(connection:StreamPeerTCP, path:String)->void:
	#match path:
		#"/startserver":
			#print("[web server] Start server request")
			#start_server.call_deferred("_server_start")
			#send_response(connection, 200, "success", "Server starting...")
		#"/stopserver":
			#print("[web server] Stop server request")
			#start_server.call_deferred("_server_stop")
			#send_response(connection, 200, "success", "Server stopping...")
		#_:
			#push_error("[web server] Unrecognized post request: "+path)



func get_content_type(file_path: String) -> String:
	if file_path.ends_with(".html"):
		return "text/html"
	elif file_path.ends_with(".css"):
		return "text/css"
	elif file_path.ends_with(".js"):
		return "application/javascript"
	elif file_path.ends_with(".png"):
		return "image/png"
	elif file_path.ends_with(".jpg") or file_path.ends_with(".jpeg"):
		return "image/jpeg"
	elif file_path.ends_with(".svg"):
		return "image/svg+xml"
	elif file_path.ends_with(".ttf"):
		return "font/ttf"
	else:
		return "application/octet-stream"
