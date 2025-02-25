extends MarginContainer

@onready var close_button:Button = $pcon/hbox/close_button
@onready var popup_text:RichTextLabel = $pcon/hbox/popup_text
@onready var indicator:ColorRect = $pcon/hbox/indicator

const DELAY:float = 3.0
var message:String = ""
var msg_color:Color = Color.LIME_GREEN

var tween:Tween

func _notification(what:int)->void:
	if what == NOTIFICATION_PREDELETE:
		# destructor logic
		if(tween):
			tween.kill()

func _ready()->void:
	tween = get_tree().create_tween()
	tween.tween_property(self, "modulate", Color(1,1,1,0), 3).set_trans(Tween.TRANS_QUAD).set_delay(DELAY)
	tween.tween_callback(self.queue_free)
	tween.pause()
	self.gui_input.connect(on_hover)
	
	popup_text.meta_clicked.connect(func(meta:Variant)->void: OS.shell_open(str(meta)))
	close_button.pressed.connect(func()->void: self.queue_free(); tween.kill() )
	popup_text.text = message
	indicator.color = msg_color
	
	
	await Globals.delay(2.0)
	tween.play()

func on_hover(_event:InputEvent)->void:
	self.modulate = Color(1,1,1,0.98)
	if(tween):
		tween.kill()
	
	tween = get_tree().create_tween()
	tween.tween_property(self, "modulate", Color(1,1,1,0), 3).set_trans(Tween.TRANS_QUAD).set_delay(DELAY)
	
	tween.tween_callback(self.queue_free)
