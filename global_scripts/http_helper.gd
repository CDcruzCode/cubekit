class_name HTTPClientHelper extends Node

var _http_client: HTTPClient
var threaded:bool = false
var thread:Thread

signal download_progress(progress: float, downloaded: int, total: int)
signal download_complete(response:int, data:PackedByteArray)

func _init(parent:Node)->void:
	print("[HTTPClientHelper] Init starting...")
	self.name = "HTTPClientHelper"
	_http_client = HTTPClient.new()
	parent.add_child(self)

func _get_hostname(url:String)->String:
	var regex:RegEx = RegEx.new()
	regex.compile("^https?://([^/:]+)")
	var result:RegExMatch = regex.search(url)
	return result.strings[0]

# This function will be called on the main thread to update progress
func _on_download_progress(percent_progress:int, chunk:int, total_size:int) -> void:
	download_progress.emit(percent_progress, chunk, total_size)

func _on_download_complete(data:PackedByteArray)->void:
	download_complete.emit(data)

func _exit_tree()->void:
	if thread.is_alive():
		thread.wait_to_finish()

func download(url:String)->void:
	if(threaded):
		thread = Thread.new()
		thread.start(_download.bind(url), Thread.PRIORITY_NORMAL)
		print("[HTTPClientHelper] thread downloaded started...")
	else:
		_download(url)


func _download(url:String)->void:
	print("[HTTPClientHelper] Download of ", url, " starting...")
	var err:Error = _http_client.connect_to_host(_get_hostname(url))
	assert(err == OK)
	
	
	# Wait until resolved and connected.
	while _http_client.get_status() == HTTPClient.STATUS_CONNECTING or _http_client.get_status() == HTTPClient.STATUS_RESOLVING:
		_http_client.poll()
		#print("Connecting...")
		#await get_tree().process_frame
	
	assert(_http_client.get_status() == HTTPClient.STATUS_CONNECTED) # Check if the connection was made successfully.
	
	# Some headers
	var headers:PackedStringArray = [
		"User-Agent: Pirulo/1.0 (Godot)",
		"Accept: */*"
	]
	var url_path:String = url.trim_prefix(_get_hostname(url))
	err = _http_client.request(HTTPClient.METHOD_GET, url_path, headers) # Request a page from the site (this one was chunked..)
	assert(err == OK) # Make sure all is OK.
	
	while _http_client.get_status() == HTTPClient.STATUS_REQUESTING:
		# Keep polling for as long as the request is being processed.
		_http_client.poll()
		#print("Requesting...")
		
		#await get_tree().process_frame
	
	assert(_http_client.get_status() == HTTPClient.STATUS_BODY or _http_client.get_status() == HTTPClient.STATUS_CONNECTED) # Make sure request finished well.

	#print("response? ", _http_client.has_response()) # Site might not have a response.
	
	if _http_client.has_response():
		# If there is a response...
		var bl:int = 0
		
		#var rheaders:Dictionary = _http_client.get_response_headers_as_dictionary() # Get response headers.
		#print("code: ", _http_client.get_response_code()) # Show response code.
		#print("**headers:\\n", headers) # Show headers.

		# Getting the HTTP Body

		if _http_client.is_response_chunked():
			# Does it use chunks?
			#print("Response is Chunked!")
			pass
		else:
			# Or just plain Content-Length
			bl = _http_client.get_response_body_length()
			#print("Response Length: ", bl)

		# This method works for both anyway

		var rb:PackedByteArray = PackedByteArray() # Array that will hold the data.

		while _http_client.get_status() == HTTPClient.STATUS_BODY:
			# While there is body left to be read
			_http_client.poll()
			# Get a chunk.
			var chunk:PackedByteArray = _http_client.read_response_body_chunk()
			if chunk.size() == 0:
				#await get_tree().process_frame
				pass
			else:
				#print( chunk.size() )
				rb = rb + chunk # Append to read buffer.
				var percent_progress:int = roundi(rb.size()*100.0/ bl)
				call_deferred_thread_group("_on_download_progress", percent_progress, chunk.size(), bl  )
				#download_progress.emit(percent_progress, chunk.size(), bl)
		# Done!

		#print("bytes got: ", rb.size())
		call_deferred_thread_group("_on_download_complete", rb)
		#download_complete.emit(rb)
