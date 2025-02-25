extends PanelContainer

@onready var select_button: Button = $hbox/select_button
@onready var delete_button: Button = $hbox/delete_button
@onready var world_name: Label = $hbox/vbox/world_name

var management_node:Control
var delete_popup:ConfirmationDialog
var select_popup:ConfirmationDialog

func _ready() -> void:
	select_button.pressed.connect(_select_popup)
	#management_node._select_backup.bind(world_name.get_meta("folder_name"))
	delete_button.pressed.connect(_delete_popup)
	
	self.mouse_entered.connect(func()->void: select_button.show())
	self.mouse_exited.connect(func()->void: select_button.hide())

func _delete_popup()->void:
	delete_popup = ConfirmationDialog.new()
	delete_popup.dialog_text = "Do you want to delete '"+world_name.get_meta("folder_name")+"'?\nYou cannot undo this!\nThis does not delete the world from the world list."
	delete_popup.title = "Delete backup"
	delete_popup.ok_button_text = "Delete"
	delete_popup.dialog_hide_on_ok = false
	delete_popup.dialog_autowrap = true
	delete_popup.dialog_close_on_escape = false
	delete_popup.size = Vector2i(400, 50)
	
	delete_popup.confirmed.connect(_confirm_delete)
	delete_popup.canceled.connect(func()->void: delete_popup.queue_free())
	
	self.add_child(delete_popup)
	delete_popup.popup_centered(Vector2i(400, 50))

func _confirm_delete()->void:
	if(Globals.deep_remove_dir(management_node.root_path+"/world_management/backups/"+world_name.get_meta("folder_name"))):
		self.queue_free()
		Globals.add_notif(management_node.notification_layer_list, "[Backups] World '"+world_name.get_meta("folder_name")+"' deleted!")
	else:
		Globals.add_notif(management_node.notification_layer_list, "[Backups] Failed to delete world '"+world_name.get_meta("folder_name")+"'!", Color.CORAL)


func _select_popup()->void:
	select_popup = ConfirmationDialog.new()
	select_popup.dialog_text = "Do you want to select '"+world_name.get_meta("folder_name")+"' as your active world?\nYou cannot undo this!\nThis will save the current world to the world list before switching worlds."
	select_popup.title = "Select backup"
	select_popup.ok_button_text = "Confirm"
	select_popup.dialog_hide_on_ok = false
	select_popup.dialog_autowrap = true
	select_popup.dialog_close_on_escape = false
	select_popup.size = Vector2i(400, 50)
	
	select_popup.confirmed.connect(func()->void: management_node._select_backup(world_name.get_meta("folder_name")); select_popup.call_deferred("queue_free"))
	select_popup.canceled.connect(func()->void: select_popup.queue_free())
	
	self.add_child(select_popup)
	select_popup.popup_centered(Vector2i(400, 50))
