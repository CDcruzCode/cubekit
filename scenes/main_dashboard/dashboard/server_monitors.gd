extends Control

@onready var web_socket: Node = %web_socket

@onready var start_server: Button = %start_server
@onready var monitor_timer: Timer = $monitor_timer

@onready var cpu_box: ColorRect = $cpu_monitor/cpu_box
@onready var ram_box: ColorRect = $ram_monitor/ram_box

const INTERVAL:float = 1.0

var monitor_thread:Thread

func _exit_tree()->void:
	_stop_monitoring()

func _ready() -> void:
	start_server.server_start.connect(_start_monitoring)
	start_server.server_stop.connect(_stop_monitoring)
	monitor_timer.timeout.connect(_monitor)
	
	var _s:String = 'Id       CPU WorkingSet
--       --- ----------
17864 52.890625  575881216'
	#print(s.split("\n", false)[2].split(" ", false))

func _start_monitoring()->void:
	print("[server_monitors] start monitor")
	monitor_timer.wait_time = INTERVAL
	monitor_timer.start()

func _stop_monitoring()->void:
	print("[server_monitors] Stopping monitor")
	monitor_timer.stop()
	if monitor_thread:
			monitor_thread.wait_to_finish()
			monitor_thread = null
	
	#await get_tree().create_timer(INTERVAL).timeout
	cpu_box.clear_points()
	ram_box.clear_points()

func _monitor()->void:
	#print("MONITOR")
	
	if monitor_thread:
		monitor_thread.wait_to_finish()
		monitor_thread = null
	monitor_thread = Thread.new()
	monitor_thread.start(monitor_external_process_windows.bind(start_server.jar_pids[1]))


var prev_cpu_tstamp:float
var prev_cpu_time:float

func monitor_external_process_windows(pid: int) -> void:
	var output_lines:Array = []
	var cmd:String = "cmd.exe"
	#var commandline:String = 'wmic path Win32_PerfFormattedData_PerfProc_Process where "IDProcess=%s" get PercentProcessorTime,WorkingSet /format:csv' % str(pid)
	#var commandline:String = 'Get-Process -Id %s | Select-Object Id, CPU, WorkingSet' % str(pid)
	var commandline:String = 'for /f "tokens=*" %i in (\'powershell -command "Get-Process -Id '+str(pid)+' | Select-Object Id, CPU, WorkingSet"\') do @echo %i'
	#var commandline:String = 'echo $(Get-Process -Id '+str(pid)+' | Select-Object Id, CPU, WorkingSet)'
	var args:PackedStringArray = ["/C", commandline]
	#var exit_code = OS.execute(cmd, args, true, output-lines)
	var exit_code:int = OS.execute(cmd, args, output_lines, true, false)
	if exit_code != 0 or output_lines.is_empty():
		print(exit_code)
		print("Error retrieving process info")
		return

	# The output is CSV formatted. Skip header lines.
	for line:String in output_lines:
		#print("||"+line)
		#if line.strip_edges() == "" or line.begins_with("Node"):
			#continue
		#var parts = line.split(",")
		#if parts.size() < 3:
			#continue
		
		var output_split:PackedStringArray = line.split("\n", false)[2].split(" ", false)
		#print(output_split)
		var cpu_usage:float = float( output_split[1].strip_edges()) #  PercentProcessorTime
		var working_set:float = float( output_split[2].strip_edges())  # WorkingSet (RAM usage in bytes)
		
		##CPU CALCULATION
		if(prev_cpu_time == null):
			call_deferred("set", "prev_cpu_tstamp", Time.get_unix_time_from_system())
			call_deferred("set", "prev_cpu_time", cpu_usage)
			return
		
		var elapsed_time:float = (Time.get_unix_time_from_system() - prev_cpu_tstamp)
		var cpu_per:float = ((cpu_usage - prev_cpu_time) / (elapsed_time * OS.get_processor_count()))
		
		call_deferred("set", "prev_cpu_tstamp", Time.get_unix_time_from_system())
		call_deferred("set", "prev_cpu_time", cpu_usage)
		
		#var cpu_per:float = float(cpu_usage)/ OS.get_processor_count()
		cpu_per = remap(cpu_per, 0.0,1.0,0.0,1.0)
		#print("CPU: ", cpu_per)
		cpu_box.call_deferred("process_redraw", cpu_per)
		web_socket.send_all(JSON.stringify({"msg": "cpu_usage", "amount": snapped((cpu_per*100), 0.1)}))
		####RAM CALCULATION
		var allocated_ram:float = ConfigSettings.manager_dictionary["allocated-ram"]
		var ram_usage:float = (working_set/1000000000) / allocated_ram
		
		ram_box.call_deferred("process_redraw", ram_usage)
		web_socket.send_all(JSON.stringify({"msg": "ram_usage", "amount": snapped((ram_usage*100), 0.1)}))
		#print("CPU: %s%%, RAM: %s bytes" % [cpu_usage, working_set])
