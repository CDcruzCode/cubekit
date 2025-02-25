extends Button
@onready var web_server: Node = %web_server

func _ready() -> void:
	self.pressed.connect(func()->void: OS.shell_open("http://localhost:"+str(web_server.tcp_port)))
