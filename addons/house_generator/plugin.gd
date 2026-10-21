@tool
extends EditorPlugin

var _dock: EditorDock


func _enter_tree() -> void:
	var content := preload("res://addons/house_generator/house_dock.gd").new()
	content.name = "HouseDock"
	_dock = EditorDock.new()
	_dock.title = "Houses"
	_dock.default_slot = EditorDock.DOCK_SLOT_RIGHT_BL
	_dock.available_layouts = EditorDock.DOCK_LAYOUT_VERTICAL | EditorDock.DOCK_LAYOUT_FLOATING
	var icon := load("res://addons/house_generator/icon.svg") as Texture2D
	if icon != null:
		_dock.dock_icon = icon
	_dock.add_child(content)
	add_dock(_dock)


func _exit_tree() -> void:
	if _dock == null:
		return
	remove_dock(_dock)
	_dock.queue_free()
	_dock = null
