extends Node

@onready var prog_popup: Window = $"../prog_popup"
@onready var prog_bar: ProgressBar = $"../prog_popup/mcon/vbox/prog_bar"
@onready var prog_text: Label = $"../prog_popup/mcon/vbox/prog_text"
var java_url:String = ""
var install_command:Array

signal java_downloaded

func download_java()->void:
	var server_var:String = ConfigSettings.config_dictionary.get("server_ver")
	var server_arr:PackedStringArray = server_var.split(".")
	print(server_arr)
	
	
	if(server_arr.size() > 1 && int(server_arr[1]) < 17 ):
		#Download Java v8
		#Used for MC 1.16 and below
		pass
	elif(server_arr.size() > 1 && int(server_arr[1]) > 16 && int(server_arr[1]) < 19 ):
		#Download Java v17
		#Used for MC 1.17 & 1.18
		pass
	else:
		#Download Latest Java
		#Used for MC 1.19 and above
		match OS.get_name():
			"Windows":
				print("Welcome to Windows!")
				java_url = "https://download.oracle.com/java/23/latest/jdk-23_windows-x64_bin.exe"
			"macOS":
				print("Welcome to macOS!")
				java_url = "https://download.oracle.com/java/23/latest/jdk-23_macos-x64_bin.dmg"
			"Linux":
				print("Welcome to Linux!")
				java_url = "https://download.oracle.com/java/23/latest/jdk-23_linux-x64_bin.tar.gz"
			_:
				printerr("[Java Download] Unsupported OS!")
				return
	
	var http:HTTPClientHelper = HTTPClientHelper.new(self)
	http.threaded = true
	http.download_progress.connect(_progress)
	http.download_complete.connect(_downloaded)
	#http.download(json_data.downloads.server.url)
	prog_text.text = "Downloading java JDK..."
	http.download(java_url)



func _downloaded(data:PackedByteArray)->void:
	
	print("Java downloaded!")
	prog_bar.value = 0
	prog_text.text = "Installing java JDK..."
	var java_path:String = ConfigSettings.config_dictionary["root_dir"]+"/"+java_url.get_file()
	Globals.save_file(java_path, data)
	
	
	match OS.get_name():
		"Windows":
			# Include the path to the .exe file
			install_command = ["cmd.exe", "/c", '"'+java_path+'"' + " /s"]
		"macOS":
			print("Welcome to macOS!")
			# For .dmg file installation
			install_command = ["bash", "-c", "hdiutil attach {} && sudo installer -pkg /Volumes/JavaInstaller/JavaInstaller.pkg -target / && hdiutil detach /Volumes/JavaInstaller".format(java_path)]
		"Linux":
			# For .deb file installation
			#install_command = ["sudo", "dpkg", "-i", java_path]
			# For .tar.gz installation:
			install_command = ["bash", "-c", "tar -xzvf {} && ./install.sh".format(java_path)]
		_:
			printerr("[Java Install] Unsupported OS!")
			return
	
	# Execute the install command
	print(install_command.slice(1))
	var output:Array = []
	var result:Error = OS.execute(install_command[0], install_command.slice(1), output, true) as Error
	print(output)
	
	# Handle the result
	if result == OK:
		print("Java installed successfully on ", OS.get_name())
		prog_bar.value = 100
		prog_text.text = "Java JDK installed!"
		java_downloaded.emit()
	else:
		print("Installation failed on ", OS.get_name())
	
	#get_tree().change_scene_to_file("res://scenes/main_dashboard/main_dashboard.tscn")

func _progress(percent_progress:int, _chunk:int, _total_size:int)->void:
	prog_bar.value = percent_progress
