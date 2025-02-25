extends Node

@onready var start_server: Button = %start_server
@onready var uptime_timer: Timer = $uptime_timer

const TRIGGER_TOLERANCE:int = 2

var start_time:int = 0
var start_diff:int = 0
var end_time:int = 0
var end_diff:int = 0


func _ready() -> void:
	if(!ConfigSettings.loaded):
		push_error("[uptime_schedule] No config file loaded!")
		return
	
	if(!ConfigSettings.manager_dictionary.has("enable-schedule") || !ConfigSettings.manager_dictionary.has("schedule-time")):
		push_error("[uptime_schedule] No schedule keys found!")
		return
	
	if(!ConfigSettings.manager_dictionary.get("enable-schedule")):
		return
	
	uptime_timer.timeout.connect(_check_schedule)
	uptime_timer.start()
	
	var schedule_dict:Dictionary = ConfigSettings.manager_dictionary.get("schedule-time")
	start_time = schedule_dict["start-time"]
	end_time = schedule_dict["end-time"]

func _check_schedule()->void:
	if(!ConfigSettings.manager_dictionary.has("enable-schedule") || !ConfigSettings.manager_dictionary.get("enable-schedule")):
		print("[uptime_schedule] Timer stopped")
		uptime_timer.stop()
		return
	
	var now:int = int( Time.get_unix_time_from_system() )
	#var midnight:int = int( now - now % 86400 ) # Subtract the time since midnight to get to the start of the day
	var timezone:Dictionary = Time.get_time_zone_from_system()
	var bias:int = timezone["bias"]*60
	var current_min_time:int = int( float((now+bias) % 86400) / 60.0 )
	start_diff = current_min_time - start_time
	end_diff = current_min_time - end_time
	
	print("[uptime_schedule] Checking schedule...\nStart diff: ",start_diff,"\nEnd diff: ", end_diff)
	
	if(start_server.process_io == null && start_diff <= TRIGGER_TOLERANCE && start_diff >= 0):
		print("[uptime_schedule] Starting server at scheduled time!")
		start_server._server_start()
		return
	
	if(start_server.process_io != null && end_diff <= TRIGGER_TOLERANCE && end_diff >= 0):
		print("[uptime_schedule] Stopping server at scheduled time!")
		start_server._server_stop()
		return
