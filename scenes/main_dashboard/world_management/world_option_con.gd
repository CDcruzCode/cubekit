extends PanelContainer

@onready var world_name: Label = $hbox/vbox/world_name
@onready var delete_button: Button = $hbox/delete_button
@onready var select_button: Button = $hbox/select_button

var management_node:Control
var delete_popup:ConfirmationDialog

func _ready() -> void:
	select_button.hide()
	delete_button.pressed.connect(_delete_popup)
	select_button.pressed.connect(management_node.select_world.bind(world_name.text))
	
	self.mouse_entered.connect(func()->void: select_button.show())
	self.mouse_exited.connect(func()->void: select_button.hide())


func _delete_popup()->void:
	delete_popup = ConfirmationDialog.new()
	delete_popup.dialog_text = "Do you want to delete '"+world_name.text+"'?\nYou cannot undo this!"
	delete_popup.title = "Delete world"
	delete_popup.ok_button_text = "Delete"
	delete_popup.dialog_hide_on_ok = false
	delete_popup.dialog_autowrap = true
	delete_popup.dialog_close_on_escape = false
	
	delete_popup.confirmed.connect(_confirm_delete)
	delete_popup.canceled.connect(func()->void: delete_popup.queue_free())
	
	self.add_child(delete_popup)
	delete_popup.popup_centered(Vector2i(300, 100))

func _confirm_delete()->void:
	if(management_node.selected_world == world_name.text):
		delete_popup.queue_free()
		delete_popup = ConfirmationDialog.new()
		delete_popup.dialog_text = "Are you sure you want to delete '"+world_name.text+"'? This is the currently active world!\nYou cannot undo this!"
		delete_popup.title = "Confirm delete active world"
		delete_popup.ok_button_text = "Delete"
		delete_popup.dialog_hide_on_ok = false
		delete_popup.dialog_autowrap = true
		delete_popup.dialog_close_on_escape = false
		delete_popup.confirmed.connect(_confirm_active_delete)
		delete_popup.canceled.connect(func()->void: delete_popup.queue_free())
		
		self.add_child(delete_popup)
		delete_popup.popup_centered(Vector2i(300, 100))
		return
	
	if(Globals.deep_remove_dir(management_node.root_path+"/world_management/worlds/"+world_name.text)):
		self.queue_free()
		Globals.add_notif(management_node.notification_layer_list, "[World management] World '"+world_name.text+"' deleted!")
	else:
		Globals.add_notif(management_node.notification_layer_list, "[World management] Failed to delete world '"+world_name.text+"'!", Color.CORAL)

func _confirm_active_delete()->void:
	if(Globals.deep_remove_dir(management_node.root_path+"/world_management/worlds/"+world_name.text)):
		Globals.deep_remove_dir(management_node.root_path+"/"+world_name.text)
		self.queue_free()
		Globals.add_notif(management_node.notification_layer_list, "[World management] World '"+world_name.text+"' deleted!")
	else:
		Globals.add_notif(management_node.notification_layer_list, "[World management] Failed to delete world '"+world_name.text+"'!", Color.CORAL)
