extends TextureButton

@export var copy_node:Control
@export var copy_text:String


func _ready() -> void:
	self.pressed.connect(_copy)


func _copy()->void:
	if(copy_node):
		match(copy_node.get_class().to_lower()):
			"label":
				var node:Label = copy_node as Label
				DisplayServer.clipboard_set(node.text)
			"lineedit":
				var node:LineEdit = copy_node as LineEdit
				DisplayServer.clipboard_set(node.text)
			_:
				push_error("[copy_button] Failed to copy. Invalid node type: ",copy_node.get_class())
